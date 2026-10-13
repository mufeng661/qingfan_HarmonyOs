import { UserProfile, TaskItem, FocusRecord, BadgeItem, StudyRoom, DailyStats, ThemeKey, ThemeDef,
  themeOf, BADGE_CATALOG, BADGE_TIER_GOALS, badgeIconKey, Account, POMODOROS_PER_TOMATO, TOMATO_LEVELS, TomatoCell, TomatoStats,
  expForLevel, normalizeLevel, gainExp, tierOfLevel, LevelTier } from './Types';
import { Store, genId } from './Store';
import { CloudDataService } from '../service/CloudDataService';

const KEY_USER = 'qf_user';
const KEY_ACCOUNT = 'qf_account';
const KEY_TASKS = 'qf_tasks';
const KEY_RECORDS = 'qf_records';
const KEY_BADGES = 'qf_badges';
const KEY_ROOMS = 'qf_rooms';
const KEY_STATS = 'qf_stats';
const KEY_ONBOARDED = 'qf_onboarded';
const KEY_THEME = 'qf_theme';
const KEY_CHALLENGE_GOAL = 'qf_challenge_goal';
const KEY_DONE_COUNT = 'qf_done_count';
const KEY_SIGN_WEEK = 'qf_sign_week';
const KEY_ROOM_FOCUS = 'qf_room_focus';
const KEY_TASKS_SEEDED = 'qf_tasks_seeded';

// 全局状态单例
@Observed
export class AppState {
  // 用户与基础态
  onboarded: boolean = false;
  user: UserProfile | null = null;
  account: Account | null = null;
  themeKey: ThemeKey = 'green';

  // 今日数据
  tasks: TaskItem[] = [];
  records: FocusRecord[] = [];
  stats: Record<string, DailyStats> = {};
  badges: BadgeItem[] = [];
  challengeGoal: number = 4;
  doneCountToday: number = 0;
  roomFocus: Record<string, number> = {};

  // 自习室
  rooms: StudyRoom[] = [];
  currentRoomId: string = '';

  // 当前运行态（轻量，不持久化）
  currentTaskId: string = '';
  currentRoomMode: string = '';   // 'study' | 'solo'

  static instance: AppState = new AppState();

  // 最近一次「把资料推给云端」的时刻（毫秒）。
  // 用途：刚在本地保存过资料时（4 秒内），拉云端不要把本地值覆盖回去 ——
  // 否则「保存 → 返回「我的」页触发拉取 → 云端还是旧值」会把刚改好的昵称吃掉（回声覆盖）。
  private static lastProfilePushAt: number = 0;

  // 资料（昵称 / 头像 / 个性签名 / 等级经验）发生变化时广播一次，
  // 让已经打开的页面立刻重渲染 —— 否则从「编辑资料」返回要手动刷新才看得到。
  static notifyProfileChanged(): void {
    AppStorage.setOrCreate<number>('qfProfileTick', Date.now());
  }

  static theme(): ThemeDef {
    return themeOf(AppState.instance.themeKey);
  }

  // 业务数据按「账号」隔离：已登录用手机号，游客用 guest
  private static owner(): string {
    const u = AppState.instance.user;
    if (u !== null && u.phone !== '') {
      return u.phone;
    }
    return 'guest';
  }

  private static dk(base: string): string {
    return base + '_' + AppState.owner();
  }

  // ============= 初始化 =============
  static async loadAll(): Promise<void> {
    const s = AppState.instance;
    s.onboarded = await Store.getBool(KEY_ONBOARDED, false);
    const u = await Store.getObj<UserProfile>(KEY_USER);
    s.user = u;
    if (s.user === null) {
      s.user = AppState.guestUser();
      Store.setObj(KEY_USER, s.user);
    } else {
      // 旧档归一：等级保留、进度百分比折算到三端统一标尺，有变化才写回
      const before: string = s.user.level + ':' + s.user.exp + ':' + s.user.nextLevelExp;
      normalizeLevel(s.user);
      if (before !== s.user.level + ':' + s.user.exp + ':' + s.user.nextLevelExp) {
        Store.setObj(KEY_USER, s.user);
      }
    }
    s.themeKey = await Store.getStr(KEY_THEME, 'green') as ThemeKey;

    s.account = await Store.getObj<Account>(KEY_ACCOUNT);
    if (s.account === null) {
      const acc: Account = {
        phone: '13800008888',
        pwdHash: AppState.hashPwd('123456'),
        nickname: '林小满'
      };
      s.account = acc;
      Store.setObj(KEY_ACCOUNT, acc);
    }

    await AppState.loadBusinessData();

    s.rooms = await Store.getArr<StudyRoom>(KEY_ROOMS);
    if (s.rooms.length === 0) {
      s.rooms = AppState.seedRooms();
      Store.setArr(KEY_ROOMS, s.rooms);
    }
  }

  // 按当前账号（手机号 / guest）加载业务数据；登录、注册后需重新调用
  static async loadBusinessData(): Promise<void> {
    const s = AppState.instance;
    if (AppState.isLoggedIn()) {
      await AppState.pullCloud();
      s.tasks = await Store.getArr<TaskItem>(AppState.dk(KEY_TASKS));
      // 新账号：首次进入种入 4 条「引导待办」（只种一次，用户删光后不再重复）
      if (s.tasks.length === 0) {
        const seeded: boolean = await Store.getBool(AppState.dk(KEY_TASKS_SEEDED), false);
        if (!seeded) {
          s.tasks = AppState.tutorialTasks();
          await Store.setArr(AppState.dk(KEY_TASKS), s.tasks);
          await Store.setBool(AppState.dk(KEY_TASKS_SEEDED), true);
        }
      }
      s.records = await Store.getArr<FocusRecord>(AppState.dk(KEY_RECORDS));
      s.stats = await Store.getObj<Record<string, DailyStats>>(AppState.dk(KEY_STATS)) ?? {};
      s.challengeGoal = await Store.getInt(AppState.dk(KEY_CHALLENGE_GOAL), 4);
      s.doneCountToday = await Store.getInt(AppState.dk(KEY_DONE_COUNT), 0);
      s.roomFocus = await Store.getObj<Record<string, number>>(AppState.dk(KEY_ROOM_FOCUS)) ?? {};
      s.badges = await Store.getArr<BadgeItem>(AppState.dk(KEY_BADGES));
      if (s.badges.length === 0) {
        s.badges = AppState.copyBadges(BADGE_CATALOG);
        Store.setArr(AppState.dk(KEY_BADGES), s.badges);
      } else {
        s.badges = AppState.reconcileBadges(s.badges);
      }
    } else {
      // 游客态不保留业务数据：一律从空白开始（待办给引导项）
      s.tasks = AppState.tutorialTasks();
      s.records = [];
      s.stats = {};
      s.challengeGoal = 4;
      s.doneCountToday = 0;
      s.roomFocus = {};
      s.badges = AppState.copyBadges(BADGE_CATALOG);
    }
  }

  // 供页面 onPageShow 调用：拉取云端并刷新实例（跨端实时同步）
  static async syncFromCloud(): Promise<void> {
    if (!AppState.isLoggedIn()) return;
    await AppState.pullCloud();
    const s = AppState.instance;
    s.tasks = await Store.getArr<TaskItem>(AppState.dk(KEY_TASKS));
    s.records = await Store.getArr<FocusRecord>(AppState.dk(KEY_RECORDS));
    s.stats = await Store.getObj<Record<string, DailyStats>>(AppState.dk(KEY_STATS)) ?? {};
    s.challengeGoal = await Store.getInt(AppState.dk(KEY_CHALLENGE_GOAL), 4);
    s.badges = await Store.getArr<BadgeItem>(AppState.dk(KEY_BADGES));
    if (s.badges.length > 0) {
      s.badges = AppState.reconcileBadges(s.badges);
    }
  }

  // 旧存档里的徽章缺少 iconKey（当时用 emoji），名称/描述也可能被早期版本改写过；
  // 这里一律按 BADGE_CATALOG 校正展示字段（name / desc / icon / iconKey），
  // 只覆盖展示字段，不触碰 unlocked / unlockedAt / tier 的进度。
  private static reconcileBadges(src: BadgeItem[]): BadgeItem[] {
    const out: BadgeItem[] = [];
    for (let i = 0; i < src.length; i++) {
      const b: BadgeItem = src[i];
      const cat: BadgeItem | undefined = AppState.catalogOf(b.id);
      const key: string = b.iconKey !== undefined && b.iconKey !== '' ? b.iconKey : badgeIconKey(b.id);
      const item: BadgeItem = {
        id: b.id,
        name: cat !== undefined ? cat.name : b.name,
        desc: cat !== undefined ? cat.desc : b.desc,
        icon: cat !== undefined ? cat.icon : b.icon,
        iconKey: key,
        unlocked: b.unlocked,
        unlockedAt: b.unlockedAt,
        tier: b.tier !== undefined ? b.tier : 0
      };
      out.push(item);
    }
    return out;
  }

  private static catalogOf(id: string): BadgeItem | undefined {
    for (let i = 0; i < BADGE_CATALOG.length; i++) {
      if (BADGE_CATALOG[i].id === id) {
        return BADGE_CATALOG[i];
      }
    }
    return undefined;
  }

  private static copyBadges(src: BadgeItem[]): BadgeItem[] {
    const out: BadgeItem[] = [];
    for (let i = 0; i < src.length; i++) {
      const b: BadgeItem = src[i];
      const item: BadgeItem = {
        id: b.id,
        name: b.name,
        desc: b.desc,
        icon: b.icon,
        iconKey: b.iconKey,
        unlocked: b.unlocked,
        unlockedAt: b.unlockedAt,
        tier: b.tier
      };
      out.push(item);
    }
    return out;
  }

  // 新账号首次进入的「引导待办」：解释待办的作用，以及添加 / 删除 / 开始方法
  static tutorialTasks(): TaskItem[] {
    const now = Date.now();
    return [
      { id: 'guide_1', title: '待办是什么：把任务拆成一个个番茄，逐个专注完成', durationMin: 25, status: 'todo', difficulty: 'easy', order: 0, createdAt: now, bgSeed: 'sky' },
      { id: 'guide_2', title: '怎么添加：点右下角「＋」新增待办，可自定义时长', durationMin: 25, status: 'todo', difficulty: 'easy', order: 1, createdAt: now, bgSeed: 'mist' },
      { id: 'guide_3', title: '怎么删除：在待办卡片上向左滑动即可删除', durationMin: 25, status: 'todo', difficulty: 'easy', order: 2, createdAt: now, bgSeed: 'dusk' },
      { id: 'guide_4', title: '怎么开始：点待办右侧的「开始」，进入番茄计时并种下一棵番茄', durationMin: 25, status: 'todo', difficulty: 'easy', order: 3, createdAt: now, bgSeed: 'sky' }
    ];
  }

  static seedTasks(): TaskItem[] {
    return [
      { id: '1', title: '晨间阅读《心流》30 页', durationMin: 25, status: 'done', difficulty: 'easy', order: 0, createdAt: Date.now(), bgSeed: 'mist' },
      { id: '2', title: '写本周工作周报', durationMin: 50, status: 'todo', difficulty: 'hard', order: 1, createdAt: Date.now(), bgSeed: 'dusk' },
      { id: '3', title: '背 30 个英语单词', durationMin: 25, status: 'todo', difficulty: 'medium', order: 2, createdAt: Date.now(), bgSeed: 'mist' },
      { id: '4', title: '读《认知觉醒》第三章', durationMin: 25, status: 'todo', difficulty: 'medium', order: 3, createdAt: Date.now(), bgSeed: 'sky' }
    ];
  }

  // 演示数据：过去 7 天专注统计（用于森林/统计/排行展示）
  static seedStats(): Record<string, DailyStats> {
    const out: Record<string, DailyStats> = {};
    const demo: Array<[string, number, number]> = [
      ['d0', 50, 2],
      ['d1', 80, 3],
      ['d2', 25, 1],
      ['d3', 60, 2],
      ['d4', 95, 4],
      ['d5', 70, 3],
      ['d6', 125, 5]
    ];
    const d = new Date();
    for (let i = 0; i < demo.length; i++) {
      const x = new Date(d);
      x.setDate(d.getDate() - (6 - i));
      const k = `${x.getFullYear()}-${(x.getMonth() + 1).toString().padStart(2, '0')}-${x.getDate().toString().padStart(2, '0')}`;
      const focusMin = demo[i][1];
      const pomo = demo[i][2];
      const ic: Record<string, number> = {};
      if (i === 6) {
        ic['手机打断'] = 2;
        ic['临时有事'] = 1;
      }
      const st: DailyStats = { date: k, focusMinutes: focusMin, pomodoroCount: pomo, doneTaskCount: pomo, interruptCounts: ic };
      out[k] = st;
    }
    return out;
  }

  static seedRooms(): StudyRoom[] {
    return [
      { id: 'r1', name: '林鹿的共学自习室', theme: '共学', hostId: '林鹿', members: ['林鹿', '苏沐', '陈砚'], onlineCount: 3, hotScore: 92, todayMinutes: 240, events: ['林鹿 完成 1 个番茄', '苏沐 加入自习室'], joined: false },
      { id: 'r2', name: '青禾晨读会', theme: '晨读', hostId: '青禾', members: ['青禾', '夜辰'], onlineCount: 2, hotScore: 71, todayMinutes: 120, events: ['青禾 完成 2 个番茄'], joined: false },
      { id: 'r3', name: '期末冲刺 · 一起上分', theme: '冲刺', hostId: '陈砚', members: ['陈砚', '苏沐', '夜辰', '我'], onlineCount: 4, hotScore: 88, todayMinutes: 380, events: ['陈砚 完成 1 个番茄', '我 种下 1 棵树'], joined: true }
    ];
  }

  // ============= 持久化封装 =============
  // 从云端拉取账号数据（登录后）；云端有数据则覆盖本地缓存
  private static async pullCloud(): Promise<void> {
    try {
      const cloud = await CloudDataService.pull(AppState.userKey());
      if (cloud === null) return;
      if (cloud.tasks !== undefined && cloud.tasks.length > 0) {
        await Store.setArr(AppState.dk(KEY_TASKS), cloud.tasks as TaskItem[]);
      }
      if (cloud.records !== undefined && cloud.records.length > 0) {
        await Store.setArr(AppState.dk(KEY_RECORDS), cloud.records as FocusRecord[]);
      }
      if (cloud.stats !== undefined && Object.keys(cloud.stats).length > 0) {
        await Store.setObj(AppState.dk(KEY_STATS), cloud.stats as Record<string, DailyStats>);
      }
      const p = cloud.profile;
      if (p !== undefined) {
        const u = AppState.instance.user;
        if (u !== null) {
          if (p['level'] !== undefined) u.level = p['level'] as number;
          if (p['exp'] !== undefined) u.exp = p['exp'] as number;
          if (p['nextLevelExp'] !== undefined) u.nextLevelExp = p['nextLevelExp'] as number;
          if (p['streak'] !== undefined) u.streak = p['streak'] as number;
          if (p['lastSignDate'] !== undefined) u.lastSignDate = p['lastSignDate'] as string;
          if (p['signDates'] !== undefined) u.signDates = p['signDates'] as string[];
          // 昵称 / 头像 / 个性签名也参与跨端同步：别的端（Web / 小程序）改完名字，
          // 本端拉到云端后要能看到，否则「改了三端还是显示鸿蒙端那个名字」。
          // 刚在本地保存过（4 秒内）时以本地为准，避免把自己刚写上去的值又读回来。
          const localWins: boolean = Date.now() - AppState.lastProfilePushAt < 4000;
          if (!localWins) {
            let changed: boolean = false;
            if (p['nickname'] !== undefined && String(p['nickname']).length > 0
              && String(p['nickname']) !== u.nickname) {
              u.nickname = String(p['nickname']);
              changed = true;
            }
            if (p['avatarSeed'] !== undefined && String(p['avatarSeed']).length > 0
              && String(p['avatarSeed']) !== u.avatarSeed) {
              u.avatarSeed = String(p['avatarSeed']);
              changed = true;
            }
            // 签名允许为空字符串（用户主动清空），所以这里不做非空判断
            if (p['bio'] !== undefined && String(p['bio']) !== u.bio) {
              u.bio = String(p['bio']);
              changed = true;
            }
            if (changed) {
              AppState.notifyProfileChanged();
            }
          }
          // 等级 / 经验按三端统一标尺归一（别的端可能还带着旧标尺的值）
          normalizeLevel(u);
          await Store.setObj(KEY_USER, u);
        }
        if (p['challengeGoal'] !== undefined) {
          AppState.instance.challengeGoal = p['challengeGoal'] as number;
          Store.setInt(AppState.dk(KEY_CHALLENGE_GOAL), AppState.instance.challengeGoal);
        }
        // 月度冠军跨设备合并：月份取并集，次数取较大值
        const uu = AppState.instance.user;
        if (uu !== null) {
          if (p['championCount'] !== undefined) {
            uu.championCount = p['championCount'] as number;
          }
          const rm: string[] = (p['championMonths'] !== undefined) ? (p['championMonths'] as string[]) : [];
          const lm: string[] = uu.championMonths ?? [];
          const merged: string[] = [];
          for (let i = 0; i < lm.length; i++) { if (merged.indexOf(lm[i]) < 0) merged.push(lm[i]); }
          for (let i = 0; i < rm.length; i++) { if (merged.indexOf(rm[i]) < 0) merged.push(rm[i]); }
          if (merged.length > 0) { uu.championMonths = merged; }
          uu.championCount = Math.max(uu.championCount ?? 0, merged.length);
          if (p['tomatoCleared'] !== undefined) { uu.tomatoCleared = p['tomatoCleared'] as number; }
          await Store.setObj(KEY_USER, uu);
        }
      }
    } catch (e) {
    }
  }

  // 推送资料（等级/经验/连续/签到/挑战目标）到云端
  private static pushProfile(): void {
    if (!AppState.isLoggedIn()) return;
    const u = AppState.instance.user;
    if (u === null) return;
    const profile: Record<string, Object> = {};
    profile['level'] = u.level;
    profile['exp'] = u.exp;
    profile['nextLevelExp'] = u.nextLevelExp;
    profile['streak'] = u.streak;
    profile['lastSignDate'] = u.lastSignDate;
    profile['signDates'] = u.signDates;
    profile['challengeGoal'] = AppState.instance.challengeGoal;
    profile['nickname'] = u.nickname;
    profile['avatarSeed'] = u.avatarSeed;
    profile['bio'] = u.bio;
    profile['bonusTrees'] = u.bonusTrees ?? 0;
    profile['championCount'] = u.championCount ?? 0;
    profile['championMonths'] = u.championMonths ?? [];
    profile['tomatoCleared'] = u.tomatoCleared ?? 0;
    // 记下推送时刻：紧接着的云端拉取不要用旧值覆盖刚保存的内容
    AppState.lastProfilePushAt = Date.now();
    CloudDataService.saveProfile(AppState.userKey(), profile).catch((e: Object) => {
      console.warn('saveProfile failed: ' + e);
    });
  }

  static async saveUser(): Promise<void> {
    if (AppState.instance.user) {
      await Store.setObj(KEY_USER, AppState.instance.user);
      AppState.pushProfile();
    }
  }

  // 轻量口令散列（本地演示用，避免明文存储；真实项目应由后端加密）
  static hashPwd(s: string): string {
    let h = 0;
    for (let i = 0; i < s.length; i++) {
      h = (h * 31 + s.charCodeAt(i)) | 0;
    }
    return 'h' + (h >>> 0).toString(16);
  }

  static async saveAccount(): Promise<void> {
    if (AppState.instance.account !== null) {
      await Store.setObj(KEY_ACCOUNT, AppState.instance.account);
    }
  }

  static async saveTasks(): Promise<void> {
    await Store.setArr(AppState.dk(KEY_TASKS), AppState.instance.tasks);
    if (AppState.isLoggedIn()) {
      CloudDataService.saveTasks(AppState.userKey(), AppState.instance.tasks).catch((e: Object) => {});
    }
  }

  static async saveRecords(): Promise<void> {
    await Store.setArr(AppState.dk(KEY_RECORDS), AppState.instance.records);
    if (AppState.isLoggedIn()) {
      CloudDataService.saveRecords(AppState.userKey(), AppState.instance.records).catch((e: Object) => {});
    }
  }

  static async saveStats(): Promise<void> {
    await Store.setObj(AppState.dk(KEY_STATS), AppState.instance.stats);
    if (AppState.isLoggedIn()) {
      CloudDataService.saveStats(AppState.userKey(), AppState.instance.stats).catch((e: Object) => {});
    }
  }

  static async saveBadges(): Promise<void> {
    await Store.setArr(AppState.dk(KEY_BADGES), AppState.instance.badges);
  }

  static async saveRooms(): Promise<void> {
    await Store.setArr(KEY_ROOMS, AppState.instance.rooms);
  }

  static async saveChallenge(): Promise<void> {
    await Store.setInt(AppState.dk(KEY_CHALLENGE_GOAL), AppState.instance.challengeGoal);
    await Store.setInt(AppState.dk(KEY_DONE_COUNT), AppState.instance.doneCountToday);
    AppState.pushProfile();
  }

  static async saveTheme(): Promise<void> {
    await Store.setStr(KEY_THEME, AppState.instance.themeKey);
  }

  static async saveOnboarded(v: boolean): Promise<void> {
    AppState.instance.onboarded = v;
    await Store.setBool(KEY_ONBOARDED, v);
  }

  static logout(): void {
    const s = AppState.instance;
    s.user = AppState.guestUser();
    s.tasks = [];
    s.records = [];
    s.stats = {};
    s.challengeGoal = 4;
    s.doneCountToday = 0;
    s.roomFocus = {};
    s.currentTaskId = '';
    s.currentRoomId = '';
    s.currentRoomMode = '';
    AppState.saveUser();
    // 账号业务数据保留在其命名空间下（按手机号），下次登录同一账号自动恢复
  }

  // 游客用户：未登录也能使用「今日待办 + 专注计时」，phone 为空即视为未登录。
  static guestUser(): UserProfile {
    const u: UserProfile = {
      id: genId('guest'),
      phone: '',
      nickname: '访客',
      avatarSeed: '访',
      bio: '登录后保存你的专注数据',
      level: 1,
      exp: 0,
      nextLevelExp: expForLevel(1),
      streak: 0,
      lastSignDate: '',
      signDates: [],
      theme: AppState.instance.themeKey,
      notifyEnabled: false
    };
    return u;
  }

  static isLoggedIn(): boolean {
    const u = AppState.instance.user;
    return u !== null && u.phone !== '';
  }

  // 云函数用的稳定用户标识：登录用手机号（跨登录稳定），游客用 harmony-guest
  static userKey(): string {
    const u = AppState.instance.user;
    if (u !== null && u.phone !== '') {
      return u.phone;
    }
    return 'harmony-guest';
  }

  static totalFocusMinutes(): number {
    let m = 0;
    const keys: string[] = Object.keys(AppState.instance.stats);
    for (let i = 0; i < keys.length; i++) {
      m += AppState.instance.stats[keys[i]].focusMinutes;
    }
    return m;
  }

  static totalPomodoros(): number {
    let t = 0;
    const keys: string[] = Object.keys(AppState.instance.stats);
    for (let i = 0; i < keys.length; i++) {
      t += AppState.instance.stats[keys[i]].pomodoroCount;
    }
    return t;
  }

  static totalInterrupts(): number {
    let t = 0;
    const keys: string[] = Object.keys(AppState.instance.stats);
    for (let i = 0; i < keys.length; i++) {
      const ic: Record<string, number> = AppState.instance.stats[keys[i]].interruptCounts;
      const rk: string[] = Object.keys(ic);
      for (let j = 0; j < rk.length; j++) {
        t += ic[rk[j]];
      }
    }
    return t;
  }

  // 番茄园统计：每完成 10 个番茄种植 1 棵；枯萎=每 3 次中断 1 棵；清除 1 棵消耗 2 个专注番茄
  static tomatoStats(): TomatoStats {
    const u = AppState.instance.user;
    const pomo = AppState.totalPomodoros();
    const bonus = u?.bonusTrees ?? 0;
    const deadTotal = Math.floor(AppState.totalInterrupts() / 3);
    const cleared = Math.min(u?.tomatoCleared ?? 0, deadTotal);
    const dead = deadTotal - cleared;
    const harvested = Math.floor(pomo / POMODOROS_PER_TOMATO) + bonus;
    const focusAvailable = Math.max(0, pomo - cleared * 2);
    let level = TOMATO_LEVELS[0].name;
    for (let i = 0; i < TOMATO_LEVELS.length; i++) {
      if (harvested >= TOMATO_LEVELS[i].at) level = TOMATO_LEVELS[i].name;
    }
    let nextAt = 0;
    for (let i = 1; i < TOMATO_LEVELS.length; i++) {
      if (harvested < TOMATO_LEVELS[i].at) { nextAt = TOMATO_LEVELS[i].at; break; }
    }
    let start = 0;
    for (let i = 0; i < TOMATO_LEVELS.length; i++) {
      if (harvested >= TOMATO_LEVELS[i].at) start = TOMATO_LEVELS[i].at;
    }
    const pct = nextAt > 0 ? Math.min(100, Math.round((harvested - start) / (nextAt - start) * 100)) : 100;
    const st: TomatoStats = {
      pomo: pomo, harvested: harvested, alive: harvested, dead: dead, cleared: cleared,
      focusAvailable: focusAvailable, level: level, nextAt: nextAt, pct: pct
    };
    return st;
  }

  static tomatoHint(): string {
    const s = AppState.tomatoStats();
    if (s.nextAt <= 0) return '你的番茄园已满级，继续收获吧！';
    let nextName = '';
    for (let i = 0; i < TOMATO_LEVELS.length; i++) {
      if (TOMATO_LEVELS[i].at === s.nextAt) nextName = TOMATO_LEVELS[i].name;
    }
    return '再收获 ' + (s.nextAt - s.harvested) + ' 个番茄，升级到「' + nextName + '」';
  }

  static tomatoCells(): TomatoCell[] {
    const s = AppState.tomatoStats();
    const MIN = 8;
    const MAX = 12;
    const total = s.alive + s.dead;
    const out: TomatoCell[] = [];
    if (total > MAX) {
      const showAlive = Math.min(s.alive, MAX - 1);
      const showDead = Math.min(s.dead, MAX - 1 - showAlive);
      for (let i = 0; i < showAlive; i++) out.push({ state: 'tomato', idx: i, more: 0 });
      for (let i = 0; i < showDead; i++) out.push({ state: 'dead', idx: 100 + i, more: 0 });
      out.push({ state: 'more', idx: 300, more: total - out.length });
      return out;
    }
    for (let i = 0; i < s.alive; i++) out.push({ state: 'tomato', idx: i, more: 0 });
    for (let i = 0; i < s.dead; i++) out.push({ state: 'dead', idx: 100 + i, more: 0 });
    const target = Math.max(MIN, total);
    while (out.length < target) out.push({ state: 'empty', idx: 200 + out.length, more: 0 });
    return out;
  }

  static clearDead(): boolean {
    const s = AppState.tomatoStats();
    const u = AppState.instance.user;
    if (u === null) return false;
    if (s.dead <= 0 || s.focusAvailable < 2) return false;
    u.tomatoCleared = (u.tomatoCleared ?? 0) + 1;
    AppState.saveUser();
    return true;
  }

  static todayPlanted(): number {
    const s = AppState.instance.stats[AppState.todayKey()];
    return Math.floor((s ? s.pomodoroCount : 0) / POMODOROS_PER_TOMATO);
  }

  static todayProgress(): number {
    const s = AppState.instance.stats[AppState.todayKey()];
    return (s ? s.pomodoroCount : 0) % POMODOROS_PER_TOMATO;
  }

  static getChampionCount(): number {
    const u = AppState.instance.user;
    if (u === null) return 0;
    const months: string[] = u.championMonths ?? [];
    return Math.max(u.championCount ?? 0, months.length);
  }

  // 累计番茄个数（所有日期累加）→ 复用 totalPomodoros()
  // 累计专注分钟（所有日期累加）→ 复用 totalFocusMinutes()

  // 徽章升阶重算（三端统一口径，2026-10-13）：
  // b1 连续签到天数；b2 累计番茄个数；b3 累计专注分钟；b4 月度冠军次数。
  // 阈值见 Types.BADGE_TIER_GOALS，解锁条件统一为「达到第一档」；
  // tier 0=未解锁 / 1=青铜 / 2=白银 / 3=黄金 / 4=钻石。
  // 返回是否有徽章发生变化（用于决定是否落盘，避免每次进页无谓写存储）。
  static recalcBadges(): boolean {
    const list = AppState.instance.badges;
    if (list.length === 0) return false;
    const streak = AppState.instance.user?.streak ?? 0;
    const totalPomo = AppState.totalPomodoros();
    const totalFocusMinutes = AppState.totalFocusMinutes();
    const champion = AppState.getChampionCount();
    let changed = false;
    for (let i = 0; i < list.length; i++) {
      const b = list[i];
      let progress = 0;
      if (b.id === 'b1') progress = streak;
      if (b.id === 'b2') progress = totalPomo;
      if (b.id === 'b3') progress = totalFocusMinutes;
      if (b.id === 'b4') progress = champion;
      let tier = 0;
      const goals: number[] | undefined = BADGE_TIER_GOALS[b.id];
      if (goals !== undefined) {
        for (let j = 0; j < goals.length; j++) {
          if (progress >= goals[j]) {
            tier = j + 1;
          }
        }
      }
      const unlocked = tier > 0;
      if (b.tier !== tier || b.unlocked !== unlocked) {
        changed = true;
      }
      b.tier = tier;
      b.unlocked = unlocked;
    }
    if (changed) {
      AppState.saveBadges();
    }
    return changed;
  }

  static recordChampion(): boolean {
    const u = AppState.instance.user;
    if (u === null) return false;
    const d = new Date();
    const month = d.getFullYear() + '-' + (d.getMonth() + 1);
    const months: string[] = (u.championMonths ?? []).slice();
    if (months.indexOf(month) > -1) return false;
    months.push(month);
    u.championMonths = months;
    u.championCount = Math.max(u.championCount ?? 0, months.length - 1) + 1;
    AppState.saveUser();
    return true;
  }

  static allTasksDone(): boolean {
    const tasks = AppState.instance.tasks;
    if (tasks.length === 0) return false;
    for (let i = 0; i < tasks.length; i++) {
      if (tasks[i].status !== 'done') return false;
    }
    return true;
  }

  // 本地累计：本人在某房间的专注时长（分钟）
  static roomFocusOf(roomId: string): number {
    const v = AppState.instance.roomFocus[roomId];
    return v ? v : 0;
  }

  static addRoomFocus(roomId: string, minutes: number): void {
    if (roomId.length === 0 || minutes <= 0) return;
    const cur = AppState.roomFocusOf(roomId);
    AppState.instance.roomFocus[roomId] = cur + minutes;
    Store.setObj(AppState.dk(KEY_ROOM_FOCUS), AppState.instance.roomFocus);
  }

  static todayKey(): string {
    const d = new Date();
    const y = d.getFullYear();
    const m = (d.getMonth() + 1).toString().padStart(2, '0');
    const dd = d.getDate().toString().padStart(2, '0');
    return `${y}-${m}-${dd}`;
  }

  // 相对今天偏移 offset 天的日期 key（-1 为昨天）
  static dayKeyOffset(offset: number): string {
    const d = new Date();
    d.setDate(d.getDate() + offset);
    const y = d.getFullYear();
    const m = (d.getMonth() + 1).toString().padStart(2, '0');
    const dd = d.getDate().toString().padStart(2, '0');
    return `${y}-${m}-${dd}`;
  }

  static isSignedToday(): boolean {
    const u = AppState.instance.user;
    return u !== null && u.lastSignDate === AppState.todayKey();
  }

  static focusMinutesOf(key: string): number {
    const s = AppState.instance.stats[key];
    return s ? s.focusMinutes : 0;
  }

  // 连续天数 = 从今天往前，逐日满足「已签到 且 当天专注 ≥10 分钟」的连续天数。
  // 今天若尚未达标不打断（从昨天继续数），这样白天专注达标前不会掉连续。
  static computeStreak(): number {
    const u = AppState.instance.user;
    if (u === null) return 0;
    const signSet: Set<string> = new Set<string>();
    for (let i = 0; i < u.signDates.length; i++) {
      signSet.add(u.signDates[i]);
    }
    let streak = 0;
    for (let i = 0; i < 400; i++) {
      const k = AppState.dayKeyOffset(-i);
      const qualified = signSet.has(k) && AppState.focusMinutesOf(k) >= 10;
      if (qualified) {
        streak += 1;
        continue;
      }
      if (i === 0) {
        continue;
      }
      break;
    }
    return streak;
  }

  static recomputeStreak(): number {
    const s = AppState.computeStreak();
    const u = AppState.instance.user;
    if (u !== null) {
      u.streak = s;
    }
    return s;
  }

  // 每日签到（每天 0 点后可再签一次）。返回获得经验；-1 表示今天已签到。
  static signInToday(): number {
    const u = AppState.instance.user;
    if (u === null) return -1;
    const today = AppState.todayKey();
    if (u.lastSignDate === today) return -1;
    const gain = u.streak >= 7 ? 15 : 10;
    gainExp(u, gain);
    if (u.signDates.indexOf(today) < 0) {
      const next: string[] = [];
      for (let i = 0; i < u.signDates.length; i++) {
        next.push(u.signDates[i]);
      }
      next.push(today);
      u.signDates = next;
    }
    u.lastSignDate = today;
    AppState.recomputeStreak();
    AppState.saveUser();
    return gain;
  }

  static weekDates(): string[] {
    const out: string[] = [];
    const d = new Date();
    const dow = d.getDay() === 0 ? 7 : d.getDay();   // 周一=1 .. 周日=7
    const monday = new Date(d);
    monday.setDate(d.getDate() - (dow - 1));
    for (let i = 0; i < 7; i++) {
      const x = new Date(monday);
      x.setDate(monday.getDate() + i);
      const y = x.getFullYear();
      const m = (x.getMonth() + 1).toString().padStart(2, '0');
      const dd = x.getDate().toString().padStart(2, '0');
      out.push(`${y}-${m}-${dd}`);
    }
    return out;
  }
}