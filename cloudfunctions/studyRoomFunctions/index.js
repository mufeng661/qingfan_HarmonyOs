const { db } = require("./cloudbase");
const { hashPassword, verifyPassword } = require("./password");
const { verifyToken } = require("./token");
const auth = require("./auth");
const ai = require("./ai");
const { now, dateKeyOf, todayKey, dateKeyOffset, ok, fail, toPositiveInt, isValidRoomId, resolveRole, roleAdmin } = require("./utils");

const DEFAULT_PAGE_SIZE = 20;
const MAX_PAGE_SIZE = 100;
const MAX_CONTENT_LENGTH = 1000;

function dbError(error) {
  const message = error && (error.message || error.error_description || error.error || error.details);
  return new Error(typeof message === "string" ? message : "数据库访问失败");
}

async function run(builder) {
  const result = await builder;
  if (result && result.error) throw dbError(result.error);
  return result;
}

async function selectRows(builder) {
  const { data } = await run(builder);
  if (Array.isArray(data)) return data;
  return data ? [data] : [];
}

async function selectOne(builder) {
  const rows = await selectRows(builder);
  return rows.length ? rows[0] : null;
}

function toArray(value) {
  if (Array.isArray(value)) return value.slice();
  if (typeof value === "string" && value) {
    try {
      const parsed = JSON.parse(value);
      return Array.isArray(parsed) ? parsed : [];
    } catch (error) {
      return [];
    }
  }
  return [];
}

function publicRoom(row, extra) {
  return Object.assign(
    {
      id: row.room_no,
      name: row.name,
      owner_id: row.owner_id,
      need_password: Boolean(row.password_hash),
      join_code: row.join_code || "",
      daily_min: row.daily_min || 0,
      created_at: row.created_at,
      updated_at: row.updated_at,
    },
    extra || {}
  );
}

function decorateComment(row, userId, isAdmin) {
  const likedBy = toArray(row.liked_by);
  const isOwner = Boolean(userId) && row.user_id === userId;
  const copy = Object.assign({}, row);
  delete copy.liked_by;
  copy.liked = Boolean(userId) && likedBy.indexOf(userId) > -1;
  copy.is_owner = isOwner;
  copy.can_delete = isOwner || isAdmin;
  return copy;
}

async function fetchRoomRow(roomId) {
  return selectOne(
    db
      .from("rooms_self")
      .select("id,room_no,name,owner_id,password_hash,password_salt,is_deleted,created_at,updated_at,join_code,daily_min")
      .eq("room_no", roomId)
      .eq("is_deleted", 0)
      .limit(1)
  );
}

// 按「6 位房间号」或「8 位加入码」解析房间
async function resolveRoom(identifier) {
  const s = String(identifier || "").trim();
  if (!s) return null;
  if (/^\d{6}$/.test(s)) return fetchRoomRow(s);
  const code = s.toUpperCase();
  return selectOne(
    db
      .from("rooms_self")
      .select("id,room_no,name,owner_id,password_hash,password_salt,is_deleted,created_at,updated_at,join_code,daily_min")
      .eq("join_code", code)
      .eq("is_deleted", 0)
      .limit(1)
  );
}

// 成员在当前房间的当日数据（含跨天重置）
async function memberToday(roomId, userId) {
  const m = await selectOne(
    db
      .from("room_members_self")
      .select("id,role,focus_minutes,today_minutes,today_date,streak_days,total_days,last_met_date,focusing")
      .eq("room_id", roomId)
      .eq("user_id", userId)
      .limit(1)
  );
  if (m && m.today_date !== todayKey()) {
    await run(
      db.from("room_members_self").update({ today_minutes: 0, today_date: todayKey(), focusing: 0 }).eq("id", m.id)
    );
    m.today_minutes = 0;
    m.today_date = todayKey();
    m.focusing = 0;
  }
  return m;
}

async function isMember(roomId, userId) {
  if (!userId) return false;
  const rows = await selectRows(
    db
      .from("room_members_self")
      .select("user_id")
      .eq("room_id", roomId)
      .eq("user_id", userId)
      .limit(1)
  );
  return rows.length > 0;
}

async function generateRoomNo() {
  for (let i = 0; i < 20; i++) {
    const roomNo = String(Math.floor(100000 + Math.random() * 900000));
    const exist = await selectRows(
      db.from("rooms_self").select("room_no").eq("room_no", roomNo).limit(1)
    );
    if (!exist.length) return roomNo;
  }
  throw new Error("房间号生成失败，请重试");
}

function randomJoinCode() {
  const chars = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789";
  let s = "";
  for (let i = 0; i < 8; i++) s += chars[Math.floor(Math.random() * chars.length)];
  return s;
}

async function generateJoinCode() {
  for (let i = 0; i < 20; i++) {
    const code = randomJoinCode();
    const exist = await selectRows(
      db.from("rooms_self").select("join_code").eq("join_code", code).limit(1)
    );
    if (!exist.length) return code;
  }
  throw new Error("加入码生成失败，请重试");
}

async function roomCreate(params, ctx) {
  const userId = ctx.userId || "";
  if (!userId) return fail("未获取到用户身份，请稍后重试", "NO_USER");

  const name = String(params.name || "").trim();
  if (!name) return fail("请输入房间名称", "EMPTY_NAME");
  if (name.length > 60) return fail("房间名称不能超过 60 个字", "NAME_TOO_LONG");

  const password = params.password ? String(params.password) : "";
  if (password.length > 32) return fail("房间密码不能超过 32 位", "PASSWORD_TOO_LONG");

  // 一人一室：已在其他未解散的自习室时不能再创建
  const occupied = await activeRoomOf(userId, "");
  if (occupied) {
    return fail("你已在自习室 " + occupied + " 中，请先退出再创建", "ALREADY_IN_ROOM", {
      roomId: occupied,
    });
  }

  const roomId = await generateRoomNo();
  const joinCode = await generateJoinCode();
  let dailyMin = parseInt(params.dailyMin, 10);
  if (!Number.isFinite(dailyMin) || dailyMin < 0) dailyMin = 30;
  if (dailyMin > 1440) dailyMin = 1440;
  const timestamp = now();
  let hash = null;
  let salt = null;
  if (password) {
    const hashed = hashPassword(password);
    hash = hashed.hash;
    salt = hashed.salt;
  }

  await run(
    db.from("rooms_self").insert([
      {
        room_no: roomId,
        join_code: joinCode,
        daily_min: dailyMin,
        name,
        owner_id: userId,
        password_hash: hash,
        password_salt: salt,
        is_deleted: 0,
        created_at: timestamp,
        updated_at: timestamp,
      },
    ])
  );

  await run(
    db.from("room_members_self").insert([
      {
        room_id: roomId,
        user_id: userId,
        role: "owner",
        joined_at: timestamp,
        updated_at: timestamp,
        last_active_at: timestamp,
        focus_minutes: 0,
        today_minutes: 0,
        today_date: todayKey(),
        streak_days: 0,
        total_days: 0,
        focusing: 0,
      },
    ])
  );

  return ok({
    id: roomId,
    name,
    owner_id: userId,
    need_password: Boolean(hash),
    join_code: joinCode,
    daily_min: dailyMin,
    created_at: timestamp,
    updated_at: timestamp,
    role: "owner",
    member_count: 1,
  });
}

// 用户当前所在的（未解散）自习室号；排除 exceptRoomId
async function activeRoomOf(userId, exceptRoomId) {
  const memberships = await selectRows(
    db.from("room_members_self").select("room_id").eq("user_id", userId)
  );
  if (!memberships.length) return null;
  const ids = memberships.map((m) => m.room_id);
  const rooms = await selectRows(
    db.from("rooms_self").select("room_no").in("room_no", ids).eq("is_deleted", 0)
  );
  const active = rooms.map((r) => r.room_no).filter((id) => id !== exceptRoomId);
  return active.length ? active[0] : null;
}

async function roomJoin(params, ctx) {
  const userId = ctx.userId || "";
  if (!userId) return fail("未获取到用户身份，请稍后重试", "NO_USER");

  const input = String(params.roomId || "").trim();
  if (!input) return fail("请输入房间号或加入码", "MISSING_ROOM_ID");

  const room = await resolveRoom(input);
  if (!room) return fail("房间不存在或已解散", "ROOM_NOT_FOUND");
  const roomId = room.room_no;

  // 一人一室：已加入其他未解散的自习室时不能再加入
  const occupied = await activeRoomOf(userId, roomId);
  if (occupied) {
    return fail("你已在自习室 " + occupied + " 中，请先退出再加入其他自习室", "ALREADY_IN_ROOM", {
      roomId: occupied,
    });
  }

  if (room.password_hash) {
    const passed = verifyPassword(params.password || "", room.password_salt, room.password_hash);
    if (!passed) return fail("房间密码不正确", "WRONG_PASSWORD");
  }

  const existing = await selectRows(
    db
      .from("room_members_self")
      .select("role")
      .eq("room_id", roomId)
      .eq("user_id", userId)
      .limit(1)
  );

  if (!existing.length) {
    const ts = now();
    await run(
      db.from("room_members_self").insert([
        {
          room_id: roomId,
          user_id: userId,
          role: "member",
          joined_at: ts,
          updated_at: ts,
          last_active_at: ts,
          focus_minutes: 0,
          today_minutes: 0,
          today_date: todayKey(),
          streak_days: 0,
          total_days: 0,
          focusing: 0,
        },
      ])
    );
  }

  const role = existing.length ? existing[0].role : "member";
  return ok(publicRoom(room, { role }));
}

async function roomListMine(params, ctx) {
  const userId = ctx.userId || "";
  if (!userId) return ok({ list: [] });

  const memberships = await selectRows(
    db
      .from("room_members_self")
      .select("room_id,role,joined_at,focus_minutes")
      .eq("user_id", userId)
      .order("joined_at", { ascending: false })
  );
  if (!memberships.length) return ok({ list: [] });

  const roomIds = memberships.map((item) => item.room_id);
  const rooms = await selectRows(
    db
      .from("rooms_self")
      .select("id,room_no,name,owner_id,password_hash,is_deleted,created_at,updated_at")
      .in("room_no", roomIds)
      .eq("is_deleted", 0)
  );
  const memberRows = await selectRows(
    db.from("room_members_self").select("room_id,user_id").in("room_id", roomIds)
  );

  const counts = {};
  memberRows.forEach((row) => {
    counts[row.room_id] = (counts[row.room_id] || 0) + 1;
  });
  const roleByRoom = {};
  const focusByRoom = {};
  memberships.forEach((item) => {
    roleByRoom[item.room_id] = item.role;
    focusByRoom[item.room_id] = item.focus_minutes || 0;
  });
  const roomById = {};
  rooms.forEach((room) => {
    roomById[room.room_no] = room;
  });

  const list = roomIds
    .map((id) => {
      const room = roomById[id];
      if (!room) return null;
      return publicRoom(room, {
        role: roleByRoom[id] || "member",
        member_count: counts[id] || 0,
        my_focus_minutes: focusByRoom[id] || 0,
      });
    })
    .filter(Boolean);

  return ok({ list });
}

async function roomGet(params, ctx) {
  const userId = ctx.userId || "";
  const roomId = String(params.roomId || "").trim();
  if (!roomId) return fail("缺少房间号", "MISSING_ROOM_ID");
  if (!isValidRoomId(roomId)) return fail("房间号不正确", "INVALID_ROOM_ID");

  const room = await fetchRoomRow(roomId);
  if (!room) return fail("房间不存在或已解散", "ROOM_NOT_FOUND");

  await memberToday(roomId, userId);
  const members = await selectRows(
    db
      .from("room_members_self")
      .select("user_id,role,joined_at,focus_minutes,today_minutes,today_date,streak_days,total_days,focusing")
      .eq("room_id", roomId)
      .order("focus_minutes", { ascending: false })
  );
  const mine = members.find((item) => item.user_id === userId);
  if (!mine) return fail("你不是该房间成员", "NOT_MEMBER");

  return ok(
    publicRoom(room, {
      role: mine.role,
      member_count: members.length,
      members,
      my_focus_minutes: mine.focus_minutes || 0,
      my_today_minutes: mine.today_minutes || 0,
    })
  );
}

// 开始专注（标记「正在专注中」）
async function focusStart(params, ctx) {
  const userId = ctx.userId || "";
  if (!userId) return fail("未获取到用户身份，请稍后重试", "NO_USER");
  const roomId = String(params.roomId || "").trim();
  if (!isValidRoomId(roomId)) return fail("房间号不正确", "INVALID_ROOM_ID");
  if (!(await isMember(roomId, userId))) return fail("你不是该房间成员", "NOT_MEMBER");
  const member = await memberToday(roomId, userId);
  if (!member) return fail("你不是该房间成员", "NOT_MEMBER");
  const ts = now();
  await run(
    db
      .from("room_members_self")
      .update({ focusing: 1, today_date: member.today_date, last_active_at: ts, updated_at: ts })
      .eq("id", member.id)
  );
  return ok({ roomId });
}

// 上报专注时长（房间模式完成一个番茄时调用），累加到成员记录
async function focusRecord(params, ctx) {
  const userId = ctx.userId || "";
  if (!userId) return fail("未获取到用户身份，请稍后重试", "NO_USER");

  const roomId = String(params.roomId || "").trim();
  if (!isValidRoomId(roomId)) return fail("房间号不正确", "INVALID_ROOM_ID");
  const minutes = toPositiveInt(params.minutes, 0);
  if (!minutes) return fail("缺少专注时长", "EMPTY_MINUTES");

  const room = await fetchRoomRow(roomId);
  if (!room) return fail("房间不存在或已解散", "ROOM_NOT_FOUND");
  if (!(await isMember(roomId, userId))) return fail("你不是该房间成员", "NOT_MEMBER");

  const member = await memberToday(roomId, userId);
  if (!member) return fail("你不是该房间成员", "NOT_MEMBER");

  const nextTotal = (member.focus_minutes || 0) + minutes;
  const nextToday = (member.today_minutes || 0) + minutes;
  const ts = now();
  await run(
    db
      .from("room_members_self")
      .update({
        focus_minutes: nextTotal,
        today_minutes: nextToday,
        today_date: member.today_date,
        focusing: 0,
        last_active_at: ts,
        updated_at: ts,
      })
      .eq("id", member.id)
  );
  return ok({ roomId, focus_minutes: nextTotal, today_minutes: nextToday });
}

// 房主移除成员（长按成员卡片，二次确认后调用）
async function roomKick(params, ctx) {
  const userId = ctx.userId || "";
  const roomId = String(params.roomId || "").trim();
  if (!isValidRoomId(roomId)) return fail("房间号不正确", "INVALID_ROOM_ID");

  const room = await fetchRoomRow(roomId);
  if (!room) return fail("房间不存在或已解散", "ROOM_NOT_FOUND");
  if (room.owner_id !== userId) return fail("只有房主可以移除成员", "FORBIDDEN");

  const target = String(params.userId || "").trim();
  if (!target) return fail("缺少成员标识", "MISSING_MEMBER");
  if (target === userId) return fail("不能移除房主自己", "CANNOT_KICK_SELF");

  await run(db.from("room_members_self").delete().eq("room_id", roomId).eq("user_id", target));
  return ok({ roomId, userId: target });
}

// 每日结算（定时触发）：达标累计连续/共专注天数；未达标移出（房主除外）
async function roomSettle() {
  const prev = dateKeyOffset(-1);
  const prevPrev = dateKeyOffset(-2);
  const today = todayKey();
  const rooms = await selectRows(
    db.from("rooms_self").select("room_no,daily_min").eq("is_deleted", 0)
  );
  let removed = 0;
  let met = 0;
  for (const room of rooms) {
    const min = room.daily_min || 0;
    if (min <= 0) continue;
    const members = await selectRows(
      db
        .from("room_members_self")
        .select("id,user_id,role,joined_at,today_minutes,today_date,streak_days,total_days,last_met_date")
        .eq("room_id", room.room_no)
    );
    for (const m of members) {
      const okDay = m.today_date === prev && (m.today_minutes || 0) >= min;
      if (okDay) {
        const streak = m.last_met_date === prevPrev ? (m.streak_days || 0) + 1 : 1;
        await run(
          db
            .from("room_members_self")
            .update({ streak_days: streak, total_days: (m.total_days || 0) + 1, last_met_date: prev })
            .eq("id", m.id)
        );
        met += 1;
      } else if (m.role !== "owner" && dateKeyOf(m.joined_at) !== today) {
        await run(db.from("room_members_self").delete().eq("id", m.id));
        removed += 1;
        continue;
      }
      await run(
        db
          .from("room_members_self")
          .update({ today_minutes: 0, today_date: today, focusing: 0 })
          .eq("id", m.id)
      );
    }
  }
  return ok({ rooms: rooms.length, met, removed });
}

async function roomLeave(params, ctx) {
  const userId = ctx.userId || "";
  const roomId = String(params.roomId || "").trim();
  if (!isValidRoomId(roomId)) return fail("房间号不正确", "INVALID_ROOM_ID");

  const room = await fetchRoomRow(roomId);
  if (!room) return fail("房间不存在或已解散", "ROOM_NOT_FOUND");
  if (room.owner_id === userId) return fail("房主不能退出，请直接解散房间", "OWNER_CANNOT_LEAVE");

  await run(
    db.from("room_members_self").delete().eq("room_id", roomId).eq("user_id", userId)
  );
  return ok({ roomId });
}

async function roomDelete(params, ctx) {
  const userId = ctx.userId || "";
  const roomId = String(params.roomId || "").trim();
  if (!isValidRoomId(roomId)) return fail("房间号不正确", "INVALID_ROOM_ID");

  const room = await fetchRoomRow(roomId);
  if (!room) return fail("房间不存在或已解散", "ROOM_NOT_FOUND");
  if (room.owner_id !== userId) return fail("只有房主可以解散房间", "FORBIDDEN");

  const timestamp = now();
  await run(
    db.from("rooms_self").update({ is_deleted: 1, updated_at: timestamp }).eq("room_no", roomId)
  );
  await run(db.from("room_members_self").delete().eq("room_id", roomId));
  await run(
    db.from("comments_self").update({ is_deleted: 1, updated_at: timestamp }).eq("project_id", roomId)
  );
  return ok({ roomId });
}

async function commentList(params, ctx) {
  const userId = ctx.userId || "";
  const roomId = String(params.roomId || "").trim();
  if (!isValidRoomId(roomId)) return fail("房间号不正确", "INVALID_ROOM_ID");
  if (!(await isMember(roomId, userId))) return fail("你不是该房间成员", "NOT_MEMBER");

  const page = toPositiveInt(params.page, 1);
  const pageSize = Math.min(MAX_PAGE_SIZE, toPositiveInt(params.pageSize, DEFAULT_PAGE_SIZE));
  const offset = (page - 1) * pageSize;

  const rootsResult = await run(
    db
      .from("comments_self")
      .select("*", { count: "exact" })
      .eq("project_id", roomId)
      .eq("is_deleted", 0)
      .is("parent_id", null)
      .order("created_at", { ascending: false })
      .range(offset, offset + pageSize - 1)
  );
  const roots = Array.isArray(rootsResult.data) ? rootsResult.data : [];
  const total = typeof rootsResult.count === "number" ? rootsResult.count : roots.length;

  const rootIds = roots.map((row) => row.id);
  let replies = [];
  if (rootIds.length) {
    replies = await selectRows(
      db
        .from("comments_self")
        .select("*")
        .eq("project_id", roomId)
        .eq("is_deleted", 0)
        .in("root_id", rootIds)
        .order("created_at", { ascending: true })
    );
  }

  const isAdmin = resolveRole(userId) === roleAdmin();
  const list = roots.concat(replies).map((row) => decorateComment(row, userId, isAdmin));

  return ok({
    list,
    total,
    page,
    pageSize,
    hasMore: offset + roots.length < total,
  });
}

async function commentAdd(params, ctx) {
  const userId = ctx.userId || "";
  const roomId = String(params.roomId || "").trim();
  if (!isValidRoomId(roomId)) return fail("房间号不正确", "INVALID_ROOM_ID");
  if (!(await isMember(roomId, userId))) return fail("你不是该房间成员", "NOT_MEMBER");

  // 需完成当日最低专注时长后才能留言
  const room = await fetchRoomRow(roomId);
  const needMin = room ? room.daily_min || 0 : 0;
  if (needMin > 0) {
    const m = await memberToday(roomId, userId);
    const t = m ? m.today_minutes || 0 : 0;
    if (t < needMin) {
      return fail("今日专注未满 " + needMin + " 分钟，达标后才能留言", "NEED_FOCUS", {
        need: needMin - t,
      });
    }
  }

  const content = String(params.content || "").trim();
  if (!content) return fail("留言内容不能为空", "EMPTY_CONTENT");
  if (content.length > MAX_CONTENT_LENGTH) {
    return fail(`留言内容不能超过 ${MAX_CONTENT_LENGTH} 个字`, "CONTENT_TOO_LONG");
  }

  const role = resolveRole(userId);
  const nickname = String(params.nickname || "").trim().slice(0, 50) || "匿名";
  const avatar = params.avatar ? String(params.avatar).slice(0, 500) : null;
  const platform = String(params.platform || ctx.platform || "wechat").slice(0, 20);
  const parentId =
    params.parentId === undefined || params.parentId === null || params.parentId === ""
      ? null
      : params.parentId;

  let rootId = null;
  let replyToName = null;
  if (parentId !== null) {
    const parent = await selectOne(
      db
        .from("comments_self")
        .select("id,root_id,nickname")
        .eq("id", parentId)
        .eq("project_id", roomId)
        .eq("is_deleted", 0)
        .limit(1)
    );
    if (!parent) return fail("被回复的留言不存在或已删除", "PARENT_NOT_FOUND");
    rootId = parent.root_id === null ? parent.id : parent.root_id;
    replyToName = parent.nickname;
  }

  const timestamp = now();
  const inserted = await selectRows(
    db
      .from("comments_self")
      .insert([
        {
          project_id: roomId,
          parent_id: parentId,
          root_id: rootId,
          reply_to_name: replyToName,
          nickname,
          avatar,
          content,
          user_id: userId,
          role,
          platform,
          likes: 0,
          liked_by: [],
          is_deleted: 0,
          created_at: timestamp,
          updated_at: timestamp,
        },
      ])
      .select()
  );

  const row =
    inserted[0] ||
    {
      project_id: roomId,
      parent_id: parentId,
      root_id: rootId,
      reply_to_name: replyToName,
      nickname,
      avatar,
      content,
      user_id: userId,
      role,
      platform,
      likes: 0,
      created_at: timestamp,
    };

  const decorated = decorateComment(row, userId, resolveRole(userId) === roleAdmin());
  decorated.is_owner = true;
  decorated.can_delete = true;
  return ok(decorated);
}

async function commentDelete(params, ctx) {
  const userId = ctx.userId || "";
  const roomId = String(params.roomId || "").trim();
  if (!isValidRoomId(roomId)) return fail("房间号不正确", "INVALID_ROOM_ID");
  if (!(await isMember(roomId, userId))) return fail("你不是该房间成员", "NOT_MEMBER");

  const id = params.id;
  if (id === undefined || id === null || id === "") return fail("缺少留言 id", "MISSING_ID");

  const found = await selectOne(
    db.from("comments_self").select("id,user_id").eq("id", id).eq("project_id", roomId).limit(1)
  );
  if (!found) return fail("留言不存在", "NOT_FOUND");

  const isAdmin = resolveRole(userId) === roleAdmin();
  if (!isAdmin && (!userId || String(found.user_id || "") !== userId)) {
    return fail("只能删除自己的留言", "FORBIDDEN");
  }

  const timestamp = now();
  await run(
    db.from("comments_self").update({ is_deleted: 1, updated_at: timestamp }).eq("id", id).eq("project_id", roomId)
  );
  await run(
    db.from("comments_self").update({ is_deleted: 1, updated_at: timestamp }).eq("root_id", id).eq("project_id", roomId)
  );
  return ok({ id });
}

async function commentLike(params, ctx) {
  const userId = ctx.userId || "";
  const roomId = String(params.roomId || "").trim();
  if (!isValidRoomId(roomId)) return fail("房间号不正确", "INVALID_ROOM_ID");
  if (!(await isMember(roomId, userId))) return fail("你不是该房间成员", "NOT_MEMBER");

  const id = params.id;
  if (id === undefined || id === null || id === "") return fail("缺少留言 id", "MISSING_ID");
  if (!userId) return fail("缺少用户标识，无法点赞", "MISSING_USER");

  const row = await selectOne(
    db
      .from("comments_self")
      .select("id,likes,liked_by")
      .eq("id", id)
      .eq("project_id", roomId)
      .eq("is_deleted", 0)
      .limit(1)
  );
  if (!row) return fail("留言不存在或已删除", "NOT_FOUND");

  const likedBy = toArray(row.liked_by);
  const has = likedBy.indexOf(userId) > -1;
  const action = params.action === "unlike" ? "unlike" : "like";
  let likes = row.likes || 0;
  let liked = has;

  if (action === "like" && !has) {
    likedBy.push(userId);
    likes += 1;
    liked = true;
  } else if (action === "unlike" && has) {
    likedBy.splice(likedBy.indexOf(userId), 1);
    likes = Math.max(likes - 1, 0);
    liked = false;
  }

  await run(
    db
      .from("comments_self")
      .update({ likes, liked_by: likedBy, updated_at: now() })
      .eq("id", id)
      .eq("project_id", roomId)
  );

  return ok({ id, likes, liked });
}

const handlers = {
  "auth.register": auth.register,
  "auth.login": auth.login,
  "auth.profile": auth.profile,
  "room.create": roomCreate,
  "room.join": roomJoin,
  "room.listMine": roomListMine,
  "room.get": roomGet,
  "room.leave": roomLeave,
  "room.delete": roomDelete,
  "room.kick": roomKick,
  "room.settle": roomSettle,
  "focus.start": focusStart,
  "focus.record": focusRecord,
  "comment.list": commentList,
  "comment.add": commentAdd,
  "comment.delete": commentDelete,
  "comment.like": commentLike,
  "ai.chat": ai.aiChat,
  "ai.insight": ai.aiInsight,
};

function parseHttpEvent(event) {
  let body = event.body;
  if (event.isBase64Encoded && body) {
    body = Buffer.from(body, "base64").toString("utf8");
  }
  let data = {};
  if (body) {
    try {
      data = typeof body === "string" ? JSON.parse(body) : body;
    } catch (error) {
      data = {};
    }
  }
  // 若 HTTP 事件没有 body（例如经网关调用，参数直接放在事件根上），回退到事件本身
  if (!body && (event.action || event.type)) data = event;
  return Object.assign({}, event.queryStringParameters || {}, data);
}

function buildContext(event, params, isHttp) {
  // 身份来源：登录签发的 token（请求体 token 或请求头 x-user-token）→ 手机号
  const headers = (event && event.headers) || {};
  const lower = {};
  Object.keys(headers).forEach((key) => {
    lower[String(key).toLowerCase()] = headers[key];
  });

  const token = String((params && params.token) || lower["x-user-token"] || "").trim();
  const phone = verifyToken(token);

  const platform = isHttp
    ? String(lower["x-user-platform"] || (params && params.platform) || "web").slice(0, 20) || "web"
    : "wechat";

  if (phone) return { platform, userId: phone };

  if (isHttp) {
    // 兼容未接登录的 Web / 鸿蒙调用（显式传身份，仅过渡用）
    const headerUserId = String(lower["x-user-id"] || "").trim();
    const bodyUserId = String((params && params.userId) || "").trim();
    return { platform, userId: headerUserId || bodyUserId };
  }

  return { platform, userId: "" };
}

function httpResponse(result) {
  return {
    statusCode: result.success ? 200 : 400,
    headers: {
      "Content-Type": "application/json; charset=utf-8",
      "Access-Control-Allow-Origin": "*",
      "Access-Control-Allow-Methods": "GET,POST,OPTIONS",
      "Access-Control-Allow-Headers": "Content-Type,Authorization,x-user-id,x-user-platform,x-user-token",
    },
    body: JSON.stringify(result),
  };
}

exports.main = async (event = {}, context) => {
  // 定时触发器：每日结算（未达标移出）
  if (event.Type === "Timer" || event.TriggerName) {
    try {
      return await roomSettle();
    } catch (error) {
      console.error("[studyRoomFunctions] settle error:", error && error.message);
      return fail(error && error.message ? error.message : "结算失败", "INTERNAL_ERROR");
    }
  }

  const isHttp = Boolean(event.httpMethod || event.requestContext || event.headers);

  if (isHttp && event.httpMethod === "OPTIONS") {
    return httpResponse(ok(null));
  }

  const params = isHttp ? parseHttpEvent(event) : event;
  const ctx = buildContext(event, params, isHttp);

  let result;
  try {
    const handler = handlers[params.action || params.type];
    if (!handler) {
      result = fail("未知操作: " + (params.action || params.type || "空"), "UNKNOWN_ACTION");
    } else {
      result = await handler(params, ctx);
    }
  } catch (error) {
    console.error("[studyRoomFunctions] error:", error);
    result = fail(error.message || "服务器内部错误", "INTERNAL_ERROR");
  }

  return isHttp ? httpResponse(result) : result;
};
