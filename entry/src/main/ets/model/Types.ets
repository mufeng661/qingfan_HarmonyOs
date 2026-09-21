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
  unlocked: boolean;
  unlockedAt: number;
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

export const BADGE_CATALOG: BadgeItem[] = [
  { id: 'b1', name: '连续 7 天', desc: '连续签到 7 天解锁', icon: '🔥', unlocked: true, unlockedAt: 0 },
  { id: 'b2', name: '森林新芽', desc: '种下第 1 棵树解锁', icon: '🌱', unlocked: true, unlockedAt: 0 },
  { id: 'b3', name: '专注达人', desc: '累计专注 100 小时解锁', icon: '⭐', unlocked: true, unlockedAt: 0 },
  { id: 'b4', name: '月度冠军', desc: '当月排行第 1 名解锁', icon: '🏆', unlocked: false, unlockedAt: 0 }
];

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
