# 青番 · DATA_MODEL

> 数据分两类：**本地模型**（`model/Types.ets`，Preferences 持久化，按账号隔离）与**云端数据**（CloudBase 云函数 `studyRoomFunctions`）。

## 1. 本地模型（`model/Types.ets`）

```ts
UserProfile {
  id, phone, nickname, avatarSeed, bio,
  level, exp, nextLevelExp, streak, lastSignDate,
  signDates: string[], theme: ThemeKey, notifyEnabled, bonusTrees?
}
TaskItem   { id, title, durationMin, status:'todo'|'done', difficulty:'easy'|'medium'|'hard', order, createdAt, bgSeed }
FocusRecord{ id, taskId, taskTitle, startAt, endAt, durationSec, finished, interruptReason, backgroundKey, whiteNoise, roomId }
BadgeItem  { id, name, desc, icon, unlocked, unlockedAt }
StudyRoom  { id, name, theme, hostId, members, onlineCount, hotScore, todayMinutes, events, joined }  // 旧模型，已被云房间取代
DailyStats { date, focusMinutes, pomodoroCount, doneTaskCount, interruptCounts: Record<string,number> }
ThemeDef   { key, name, desc, bg, surface, surface2, ink, ink2, ink3, leaf, leafDeep, leafSoft, tomato, tomatoSoft, line, gold, goldSoft, brandGrad1/2, bar, ... }
```

常量：`THEMES`（4 主题）、`BACKGROUNDS`（天空/晨雾/夕阳）、`WHITE_NOISES`（森林/雨声/海浪/静音）、`DURATIONS`（25/15/5/1）、`INTERRUPT_REASONS`、`BADGE_CATALOG`、`FRIEND_RANK`。

## 2. 本地存储（`model/Store.ets` + `model/AppState.ets`）

Preferences 库名 `qf_store`。**业务数据按账号隔离**：key = `基础key + '_' + 手机号`（游客为 `guest`）。

| 基础 key | 内容 | 隔离 |
|---|---|---|
| `qf_user` | 当前用户资料 | 否（当前账号） |
| `qf_onboarded` | 是否看过引导 | 否 |
| `qf_theme` | 当前主题 | 否 |
| `qf_tasks` | 待办列表 | 是 |
| `qf_records` | 专注记录 | 是 |
| `qf_stats` | 每日统计（含 interruptCounts） | 是 |
| `qf_badges` | 徽章 | 是 |
| `qf_challenge_goal` / `qf_done_count` | 每日挑战目标 / 今日完成数 | 是 |
| `qf_room_focus` | 本人各房间专注时长（分钟） | 是 |
| `qf_account` | 旧本地账号（已弃用，登录改走云函数） | 否 |

## 3. 云端数据（CloudBase · env `cloud1-d5g8q89yd66340db4`）

云函数：`studyRoomFunctions`（HTTP 访问服务）。统一返回 `{ success, data?, error?:{code,message} }`。

### 3.1 action 出入参

| action | 入参 | 出参 data |
|---|---|---|
| `auth.register` | `{ username, phone, password }` | `{ token, user:{ id, phone, username, nickname, avatarSeed, bio, created_at } }` |
| `auth.login` | `{ phone, password }` | 同上 |
| `room.create` | `{ name, password? }` | `Room` |
| `room.listMine` | `{}` | `{ list: Room[] }` |
| `room.get` | `{ roomId }` | `Room & { members: RoomMember[] }` |
| `room.join` | `{ roomId, password? }` | `Room` |
| `room.leave` | `{ roomId }` | `{ roomId }` |
| `room.delete` | `{ roomId }` | `{ roomId }` |
| `comment.list` | `{ roomId, page, pageSize }` | `{ list: Comment[], total, page, pageSize, hasMore }` |
| `comment.add` | `{ roomId, nickname, content, parentId? }` | `Comment` |
| `comment.like` | `{ roomId, id, action }` | `{ likes, liked }` |
| `comment.delete` | `{ roomId, id }` | — |
| `ai.chat` | `{ messages:[{role,content}], prompt?, context?, wantPlan? }` | `{ reply, todos?: AiTodo[] }` |
| `ai.insight` | `{ prompt?, context? }` | `{ reply }` |

公共字段：请求体带 `action` / `userId` / `platform:'harmony'`，请求头 `x-user-id` / `x-user-platform`。

```ts
Room       { id:string(6 位房间号), name, owner_id, need_password, created_at, updated_at, role:'owner'|'member', member_count, members?: RoomMember[] }
RoomMember { user_id, role, joined_at, nickname?, focus_minutes? }   // 后两者为「待后端支持」的可选字段
Comment    { id:number, project_id(=roomId), parent_id, root_id, reply_to_name, nickname, content, role, likes, liked, can_delete, created_at }
AiTodo     { title:string, durationMin:number, difficulty:'easy'|'medium'|'hard' }   // ai.chat 的 wantPlan=true 时返回，前端自动加入待办
```

### 3.2 云表（MySQL）

- `rooms_self`：房间（`id` bigint 自增 PK / `room_no` varchar(32) 唯一（6 位房间号，对外即 `Room.id`）/ name / owner_id / password_hash / password_salt / is_deleted / created_at / updated_at）。**创建时由云函数生成唯一 `room_no` 写入**。
- `room_members_self`：房间成员（`room_id` char(6)=房间号 / user_id / role / joined_at / updated_at / last_active_at）。
- `comments_self`：留言（id/project_id(=房间号)/parent_id/root_id/nickname/content/role/likes/liked_by/created_at/updated_at）。
- `ai_usage_self`：AI 用量（`user_id` + `usage_date`(北京时间 YYYY-MM-DD) 唯一 / `used` 当日次数 / `last_at` 上次调用毫秒）。**列名用 `used` 而非 `count`**（CloudBase rdb 会把 `count` 当聚合函数，不能与其他字段一起 select）。

> 待办：如需「成员真实专注时长排行」，需在 `room_members_self` 增加 `focus_minutes`、`nickname`，并新增云函数 action `focus.record`、在 `room.get` 返回这两个字段。

## 4. 校验规则

- 手机号：`^1[3-9]\d{9}$`；密码 ≥ 6 位；用户名 ≥ 2 字符（注册）。
- 注册验证码：演示码 `1234`（前端校验）。
- 待办时长：预设 15/25/45/60，自定义 1–600 分钟。
- 提前退出：不计番茄；待办保持未完成；记录中断原因（`INTERRUPT_REASONS`）。
- 签到：每日 0 点刷新；连续天数 = 连续满足「当日已签到 且 当日专注 ≥10 分钟」；签到经验：连续≥7 天 +15，否则 +10。
- 森林：树 = `floor(累计番茄 / 10) + 复活奖励树`；复活消耗 50 经验。

## 5. 身份模型（三端）

三端使用**同一套数据模型与云表**（`rooms_self` / `room_members_self` / `comments_self`），功能一致；本地数据（待办 / 专注统计 / 成长体系）各端按账号隔离存储。

| 端 | 未登录 | 登录后 | 请求携带 |
|---|---|---|---|
| 鸿蒙 | `harmony-guest` | 手机号（`AppState.userKey()`） | 头 `x-user-id` / `x-user-platform: harmony` |
| Web | 设备 UUID（localStorage `qingfan:userId`） | 手机号 | 头 `x-user-id` / `x-user-platform: web` / `x-user-token`；body 带 `token` |
| 小程序 | 微信 OPENID（自动） | OPENID | `wx.cloud.callFunction` 事件体 |

- 云函数优先用 **token** 解析出手机号作为身份（Web/鸿蒙登录后一致）。
- 账号由 `auth.register` / `auth.login` 签发 `{ token, user }`；`user = { id, phone, username, nickname, avatarSeed, bio, created_at }`。
- **房间归属**按 `userId` 记录；三端未登录时的身份不同（UUID / guest / OPENID），登录后统一为手机号，因此**登录状态下的自习室归属可跨端一致**。
