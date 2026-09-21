import { UserProfile, TaskItem, FocusRecord, BadgeItem, StudyRoom, DailyStats, ThemeKey, ThemeDef,
  themeOf, BADGE_CATALOG, Account } from './Types';
import { Store, genId } from './Store';

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

  // 自习室
  rooms: StudyRoom[] = [];
  currentRoomId: string = '';

  // 当前运行态（轻量，不持久化）
  currentTaskId: string = '';
  currentRoomMode: string = '';   // 'study' | 'solo'

  static instance: AppState = new AppState();

  static theme(): ThemeDef {
    return themeOf(AppState.instance.themeKey);
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

    if (AppState.isLoggedIn()) {
      s.tasks = await Store.getArr<TaskItem>(KEY_TASKS);
      s.records = await Store.getArr<FocusRecord>(KEY_RECORDS);
      s.stats = await Store.getObj<Record<string, DailyStats>>(KEY_STATS) ?? {};
      s.challengeGoal = await Store.getInt(KEY_CHALLENGE_GOAL, 4);
      s.doneCountToday = await Store.getInt(KEY_DONE_COUNT, 0);
    } else {
      // 游客态不保留业务数据：待办、专注记录、今日统计与挑战一律从空白开始
      s.tasks = [];
      s.records = [];
      s.stats = {};
      s.challengeGoal = 4;
      s.doneCountToday = 0;
      Store.setArr(KEY_TASKS, []);
      Store.setArr(KEY_RECORDS, []);
      const emptyStats: Record<string, DailyStats> = {};
      Store.setObj(KEY_STATS, emptyStats);
      Store.setInt(KEY_CHALLENGE_GOAL, 4);
      Store.setInt(KEY_DONE_COUNT, 0);
    }

    s.badges = await Store.getArr<BadgeItem>(KEY_BADGES);
    if (s.badges.length === 0) {
      s.badges = AppState.copyBadges(BADGE_CATALOG);
      Store.setArr(KEY_BADGES, s.badges);
    }

    s.rooms = await Store.getArr<StudyRoom>(KEY_ROOMS);
    if (s.rooms.length === 0) {
      s.rooms = AppState.seedRooms();
      Store.setArr(KEY_ROOMS, s.rooms);
    }
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
        unlocked: b.unlocked,
        unlockedAt: b.unlockedAt
      };
      out.push(item);
    }
    return out;
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
  static async saveUser(): Promise<void> {
    if (AppState.instance.user) {
      await Store.setObj(KEY_USER, AppState.instance.user);
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
    await Store.setArr(KEY_TASKS, AppState.instance.tasks);
  }

  static async saveRecords(): Promise<void> {
    await Store.setArr(KEY_RECORDS, AppState.instance.records);
  }

  static async saveStats(): Promise<void> {
    await Store.setObj(KEY_STATS, AppState.instance.stats);
  }

  static async saveBadges(): Promise<void> {
    await Store.setArr(KEY_BADGES, AppState.instance.badges);
  }

  static async saveRooms(): Promise<void> {
    await Store.setArr(KEY_ROOMS, AppState.instance.rooms);
  }

  static async saveChallenge(): Promise<void> {
    await Store.setInt(KEY_CHALLENGE_GOAL, AppState.instance.challengeGoal);
    await Store.setInt(KEY_DONE_COUNT, AppState.instance.doneCountToday);
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
    s.currentTaskId = '';
    s.currentRoomId = '';
    s.currentRoomMode = '';
    AppState.saveUser();
    Store.setArr(KEY_TASKS, []);
    Store.setArr(KEY_RECORDS, []);
    const emptyStats: Record<string, DailyStats> = {};
    Store.setObj(KEY_STATS, emptyStats);
    Store.setInt(KEY_CHALLENGE_GOAL, 4);
    Store.setInt(KEY_DONE_COUNT, 0);
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
      nextLevelExp: 3000,
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

  static totalFocusMinutes(): number {
    let m = 0;
    const keys: string[] = Object.keys(AppState.instance.stats);
    for (let i = 0; i < keys.length; i++) {
      m += AppState.instance.stats[keys[i]].focusMinutes;
    }
    return m;
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
    u.exp += gain;
    while (u.exp >= u.nextLevelExp) {
      u.level += 1;
      u.exp = u.exp - u.nextLevelExp;
      u.nextLevelExp = Math.floor(u.nextLevelExp * 1.5);
    }
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