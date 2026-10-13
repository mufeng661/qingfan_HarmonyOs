// 青番 · 数据模型类型定义 + 设计令牌（对齐高保真原型）

// 字体：标题用衬线体，正文用系统无衬线体
export const FONT_DISPLAY = 'serif';

export interface UserProfile {
  id: string;
  phone: string;
  nickname: string;
  avatarSeed: string;
  bio: string;
  level: number;
  exp: number;
  nextLevelExp: number;
  streak: number;
  lastSignDate: string;
  signDates: string[];
  theme: ThemeKey;
  notifyEnabled: boolean;
  bonusTrees?: number;
  championCount?: number;
  championMonths?: string[];
  tomatoCleared?: number;
}

// 本地账号（用于手机号 + 密码登录校验；密码存哈希，不存明文）
export interface Account {
  phone: string;
  pwdHash: string;
  nickname: string;
}

export interface TaskItem {
  id: string;
  title: string;
  durationMin: number;
  status: 'todo' | 'done';
  difficulty: 'easy' | 'medium' | 'hard';
  order: number;
  createdAt: number;
  bgSeed: string;
}

export interface FocusRecord {
  id: string;
  taskId: string;
  taskTitle: string;
  startAt: number;
  endAt: number;
  durationSec: number;
  finished: boolean;
  interruptReason: string;
  backgroundKey: string;
  whiteNoise: string;
  roomId: string;
}

export interface BadgeItem {
  id: string;
  name: string;
  desc: string;
  icon: string;
  // 线性描边图标标识（对齐小程序 const I 的 flame/leaf/star/trophy）
  iconKey: string;
  unlocked: boolean;
  unlockedAt: number;
  // 稀有度阶段：0 未解锁 / 1 青铜 / 2 白银 / 3 黄金 / 4 钻石（随完成进度升级）
  tier: number;
}

export interface StudyRoom {
  id: string;
  name: string;
  theme: string;
  hostId: string;
  members: string[];
  onlineCount: number;
  hotScore: number;
  todayMinutes: number;
  events: string[];
  joined: boolean;
}

export interface DailyStats {
  date: string;
  focusMinutes: number;
  pomodoroCount: number;
  doneTaskCount: number;
  interruptCounts: Record<string, number>;
}

export type ThemeKey = 'green' | 'dark' | 'dawn' | 'ocean';

export interface ThemeDef {
  key: ThemeKey;
  name: string;
  desc: string;
  // 主色别名（兼容旧代码）
  primary: string;
  primaryLight: string;
  primaryDark: string;
  // 完整设计令牌（对齐原型 CSS 变量）
  bg: string;
  surface: string;
  surface2: string;
  ink: string;
  ink2: string;
  ink3: string;
  leaf: string;
  leafDeep: string;
  leafSoft: string;
  tomato: string;
  tomatoSoft: string;
  line: string;
  gold: string;
  goldSoft: string;
  stageBg: string;
  brandGrad1: string;
  brandGrad2: string;
  bar: string;
  // 兼容旧字段
  text: string;
  cardBg: string;
  cardText: string;
}

export const THEMES: ThemeDef[] = [
  {
    key: 'green',
    name: '青番绿',
    desc: '清新自然',
    primary: '#6E9B57',
    primaryLight: '#DCE8CF',
    primaryDark: '#4C7A3E',
    bg: '#F3F6EE',
    surface: '#FFFFFF',
    surface2: '#EAF1E2',
    ink: '#2C3A28',
    ink2: '#84917D',
    ink3: '#B4BFAE',
    leaf: '#6E9B57',
    leafDeep: '#4C7A3E',
    leafSoft: '#DCE8CF',
    tomato: '#E07A5F',
    tomatoSoft: '#F6E1D6',
    line: '#E3E9DB',
    gold: '#D9A441',
    goldSoft: '#F4E8CE',
    stageBg: '#EDF2E8',
    brandGrad1: '#F7FAF2',
    brandGrad2: '#EAF1E2',
    bar: 'rgba(255,255,255,0.96)',
    text: '#2C3A28',
    cardBg: '#FFFFFF',
    cardText: '#2C3A28'
  },
  {
    key: 'dark',
    name: '深夜墨',
    desc: '沉浸专注',
    primary: '#8CB56F',
    primaryLight: '#33412F',
    primaryDark: '#A9CC8F',
    bg: '#171C17',
    surface: '#212822',
    surface2: '#2B342B',
    ink: '#E6EDE3',
    ink2: '#97A392',
    ink3: '#677262',
    leaf: '#8CB56F',
    leafDeep: '#A9CC8F',
    leafSoft: '#33412F',
    tomato: '#ED8E72',
    tomatoSoft: '#4A332B',
    line: '#333D32',
    gold: '#E2B65F',
    goldSoft: '#463A24',
    stageBg: '#0F130E',
    brandGrad1: '#1A211A',
    brandGrad2: '#121712',
    bar: 'rgba(33,40,34,0.96)',
    text: '#E6EDE3',
    cardBg: '#212822',
    cardText: '#E6EDE3'
  },
  {
    key: 'dawn',
    name: '晨光暖',
    desc: '温暖明亮',
    primary: '#C08A4E',
    primaryLight: '#EFDFC6',
    primaryDark: '#A8743C',
    bg: '#FBF3E9',
    surface: '#FFFDF9',
    surface2: '#F3E7D7',
    ink: '#4A3A2B',
    ink2: '#9A8A76',
    ink3: '#C4B5A2',
    leaf: '#C08A4E',
    leafDeep: '#A8743C',
    leafSoft: '#EFDFC6',
    tomato: '#D96B4E',
    tomatoSoft: '#F6E1D6',
    line: '#EDE0CE',
    gold: '#D9A441',
    goldSoft: '#F4E8CE',
    stageBg: '#EFE6D8',
    brandGrad1: '#FCF6EC',
    brandGrad2: '#F1E6D4',
    bar: 'rgba(255,253,249,0.96)',
    text: '#4A3A2B',
    cardBg: '#FFFDF9',
    cardText: '#4A3A2B'
  },
  {
    key: 'ocean',
    name: '静谧蓝',
    desc: '冷静理性',
    primary: '#5C8BA6',
    primaryLight: '#D8E6EE',
    primaryDark: '#42718C',
    bg: '#EEF3F6',
    surface: '#FFFFFF',
    surface2: '#E2ECF2',
    ink: '#26343F',
    ink2: '#7C8E9A',
    ink3: '#AEBFC8',
    leaf: '#5C8BA6',
    leafDeep: '#42718C',
    leafSoft: '#D8E6EE',
    tomato: '#E07A5F',
    tomatoSoft: '#F6E1D6',
    line: '#DEE8EE',
    gold: '#D9A441',
    goldSoft: '#F4E8CE',
    stageBg: '#E4ECF1',
    brandGrad1: '#F3F8FA',
    brandGrad2: '#E4EEF3',
    bar: 'rgba(255,255,255,0.96)',
    text: '#26343F',
    cardBg: '#FFFFFF',
    cardText: '#26343F'
  }
];

export interface BgOption {
  key: string;
  name: string;
  from: string;
  to: string;
}

export interface NoiseOption {
  key: string;
  name: string;
  icon: string;
}

export interface FriendRankItem {
  name: string;
  minutes: number;
  xp: number;
  isMe: boolean;
  color: string;
}

// 专注背景（对齐原型 BG_THEMES：天空 / 晨雾 / 夕阳）
export const BACKGROUNDS: BgOption[] = [
  { key: 'sky', name: '天空', from: '#3E7BB5', to: '#86BCE4' },
  { key: 'mist', name: '晨雾', from: '#A9C79E', to: '#DCEBD2' },
  { key: 'dusk', name: '夕阳', from: '#E8A98D', to: '#C9604F' }
];

// 白噪音（对齐原型 MUSICS）
export const WHITE_NOISES: NoiseOption[] = [
  { key: 'forest', name: '森林', icon: '🍃' },
  { key: 'rain', name: '雨声', icon: '🌧' },
  { key: 'wave', name: '海浪', icon: '🌊' },
  { key: 'mute', name: '静音', icon: '🔇' }
];

export const DURATIONS: number[] = [25, 15, 5, 1];

export const INTERRUPT_REASONS = ['临时有事', '手机打断', '失去状态', '饿了/累了', '其它'];

// ====== 等级 / 经验体系（三端统一）======
// 升到下一级所需经验：200 + (level - 1) * 100
// L1→L2: 200, L2→L3: 300, L3→L4: 400, L5→L6: 600, L10→L11: 1100, L20→L21: 2100 …
// 注意语义：参数是「当前等级」，返回的是「当前等级 → 下一级」所需的经验。
export function expForLevel(level: number): number {
  return 200 + (level - 1) * 100;
}

// 加经验并进位：升级后按「新的当前等级」重算下一级门槛。
// 三端共用同一条公式（Web 端 store.addExp / 小程序端 state.addExp）。
export function gainExp(u: UserProfile, n: number): void {
  u.exp += n;
  while (u.exp >= u.nextLevelExp) {
    u.exp -= u.nextLevelExp;
    u.level += 1;
    u.nextLevelExp = expForLevel(u.level);
  }
}

// 旧档归一：早期版本的 nextLevelExp 记错了一级（升级后写成 expForLevel(level + 1)），
// 直接纠正为按当前等级计算；若发现是更老的标尺（数值与公式不符），按进度百分比折算，
// 等级不变、进度也不会突飞猛进。幂等，可重复调用。
export function normalizeLevel(u: UserProfile): void {
  const lv: number = Math.max(1, Math.floor(u.level ?? 1));
  const need: number = expForLevel(lv);
  const old: number = Math.floor(u.nextLevelExp ?? 0);
  let exp: number = Math.max(0, Math.floor(u.exp ?? 0));
  if (old > 0 && old !== need && exp <= old) {
    exp = Math.round((exp / old) * need);
  }
  u.level = lv;
  u.nextLevelExp = need;
  while (exp >= u.nextLevelExp) {
    exp -= u.nextLevelExp;
    u.level += 1;
    u.nextLevelExp = expForLevel(u.level);
  }
  u.exp = exp;
}

// 等级阶段名（仿小黑盒等级卡片分段展示）
export interface LevelTier {
  minLevel: number;
  name: string;
  color: string;       // 徽章主色
  bgFrom: string;      // 卡片渐变起色
  bgTo: string;        // 卡片渐变止色
}

export const LEVEL_TIERS: LevelTier[] = [
  { minLevel: 1,  name: '萌新叶',   color: '#6E9B57', bgFrom: '#4A6B3A', bgTo: '#2E4426' },
  { minLevel: 6,  name: '成长苗',   color: '#5B9B7E', bgFrom: '#3A6B52', bgTo: '#1F4435' },
  { minLevel: 11, name: '繁茂枝',   color: '#D9A441', bgFrom: '#8A6B1E', bgTo: '#4A380E' },
  { minLevel: 21, name: '参天木',   color: '#C08A4E', bgFrom: '#7A5420', bgTo: '#3E2A0E' },
  { minLevel: 31, name: '森林守护',  color: '#7B6EA9', bgFrom: '#4A3E6B', bgTo: '#261E3A' },
  { minLevel: 51, name: '传说之森',  color: '#E07A5F', bgFrom: '#8A3A2A', bgTo: '#3E1A14' },
];

export function tierOfLevel(level: number): LevelTier {
  let t = LEVEL_TIERS[0];
  for (let i = 0; i < LEVEL_TIERS.length; i++) {
    if (level >= LEVEL_TIERS[i].minLevel) t = LEVEL_TIERS[i];
  }
  return t;
}

export const BADGE_CATALOG: BadgeItem[] = [
  { id: 'b1', name: '连续 7 天', desc: '连续签到 7 天解锁', icon: '🔥', iconKey: 'flame', unlocked: true, unlockedAt: 0, tier: 0 },
  { id: 'b2', name: '番茄丰收', desc: '累计收获 10 个番茄解锁', icon: '🍅', iconKey: 'tomato', unlocked: true, unlockedAt: 0, tier: 0 },
  { id: 'b3', name: '专注达人', desc: '累计专注 100 小时解锁', icon: '⭐', iconKey: 'star', unlocked: true, unlockedAt: 0, tier: 0 },
  { id: 'b4', name: '月度冠军', desc: '当月排行第 1 名解锁', icon: '🏆', iconKey: 'trophy', unlocked: false, unlockedAt: 0, tier: 0 }
];

// 徽章稀有度阶段名（奖章配色在 CoinBadge 内按阶段固定）
export const BADGE_TIER_NAMES: string[] = ['未解锁', '青铜', '白银', '黄金', '钻石'];

// 各徽章升阶阈值（依次对应 青铜/白银/黄金/钻石）：
// b1 连续签到天数；b2 累计番茄个数；b3 累计专注分钟；b4 月度冠军次数。
// 解锁条件统一为「达到第一档」；重算逻辑见 AppState.recalcBadges()。
export const BADGE_TIER_GOALS: Record<string, number[]> = {
  'b1': [7, 14, 30, 60],
  'b2': [10, 50, 200, 500],
  'b3': [6000, 12000, 30000, 60000],
  'b4': [1, 2, 3, 5]
};

// 徽章 → 线性描边图标标识（对齐小程序 badges 数组的 icon 字段）
export function badgeIconKey(id: string): string {
  if (id === 'b1') return 'flame';
  if (id === 'b2') return 'tomato';
  if (id === 'b3') return 'star';
  if (id === 'b4') return 'trophy';
  return 'star';
}

// 番茄园：每 10 个番茄种植 1 棵；等级按累计收获
export const POMODOROS_PER_TOMATO = 10;

export interface TomatoLevel {
  at: number;
  name: string;
}

export const TOMATO_LEVELS: TomatoLevel[] = [
  { at: 0, name: '番茄幼苗' },
  { at: 10, name: '小番茄园' },
  { at: 50, name: '茂盛番茄园' },
  { at: 150, name: '番茄农场' }
];

export interface TomatoCell {
  state: string;   // 'tomato' | 'dead' | 'empty' | 'more'
  idx: number;
  more: number;
}

export interface TomatoStats {
  pomo: number;
  harvested: number;
  alive: number;
  dead: number;
  cleared: number;
  focusAvailable: number;
  level: string;
  nextAt: number;
  pct: number;
}

export const FRIEND_RANK: FriendRankItem[] = [
  { name: '苏叶', minutes: 480, xp: 3200, isMe: false, color: '#6E9B57' },
  { name: '林小满', minutes: 375, xp: 2450, isMe: true, color: '#E07A5F' },
  { name: '陈屿', minutes: 340, xp: 2100, isMe: false, color: '#D9A441' },
  { name: '周青', minutes: 260, xp: 1680, isMe: false, color: '#7FA1B0' },
  { name: '阿楠', minutes: 180, xp: 1120, isMe: false, color: '#B08BC0' },
  { name: '小雨', minutes: 95, xp: 620, isMe: false, color: '#C09B6E' }
];

export function themeOf(key: ThemeKey): ThemeDef {
  const t = THEMES.find(x => x.key === key);
  return t ?? THEMES[0];
}

// ====== 昵称 / 个性签名（三端统一规格）======
// 昵称必填、去首尾空格、最长 12 字；个性签名可空、最长 30 字。
export const MAX_NICK = 12;
export const MAX_BIO = 30;

// 按「码点」统计长度：emoji、生僻字都算 1 个字符。
// 直接用 String.length 会把 emoji 算成 2（UTF-16 代理对），计数会偏大。
export function cpLen(s: string): number {
  let n = 0;
  let i = 0;
  while (i < s.length) {
    const code = s.charCodeAt(i);
    if (code >= 0xD800 && code <= 0xDBFF && i + 1 < s.length) {
      i += 2;   // 高代理 + 低代理 = 一个完整 emoji，整体跳过
    } else {
      i += 1;
    }
    n += 1;
  }
  return n;
}

// 按「码点」截断：不会把 emoji 劈成半个代理对（否则界面会显示成乱码方块）。
export function cpCut(s: string, max: number): string {
  let out = '';
  let n = 0;
  let i = 0;
  while (i < s.length && n < max) {
    const code = s.charCodeAt(i);
    if (code >= 0xD800 && code <= 0xDBFF && i + 1 < s.length) {
      out += s.substring(i, i + 2);
      i += 2;
    } else {
      out += s.substring(i, i + 1);
      i += 1;
    }
    n += 1;
  }
  return out;
}

// 取首个「码点」，用于「头像 = 昵称首字」
export function firstCp(s: string): string {
  return cpCut(s, 1);
}
