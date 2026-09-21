import { preferences } from '@kit.ArkData';

// 极简 KV 持久化封装：基于 Preferences
// 所有方法 fail-soft：出错时返回默认值，不阻塞 UI

const STORE_NAME = 'qf_store';

export class Store {
  private static async getPrefs(): Promise<preferences.Preferences | null> {
    try {
      return await preferences.getPreferences(getContext(), STORE_NAME);
    } catch (e) {
      return null;
    }
  }

  static async setStr(key: string, value: string): Promise<void> {
    const p = await Store.getPrefs();
    if (!p) return;
    try { await p.put(key, value); await p.flush(); } catch (e) {}
  }

  static async getStr(key: string, defVal: string = ''): Promise<string> {
    const p = await Store.getPrefs();
    if (!p) return defVal;
    try {
      const v = await p.get(key, defVal);
      return typeof v === 'string' ? v : defVal;
    } catch (e) { return defVal; }
  }

  static async setInt(key: string, value: number): Promise<void> {
    const p = await Store.getPrefs();
    if (!p) return;
    try { await p.put(key, value); await p.flush(); } catch (e) {}
  }

  static async getInt(key: string, defVal: number = 0): Promise<number> {
    const p = await Store.getPrefs();
    if (!p) return defVal;
    try {
      const v = await p.get(key, defVal);
      return typeof v === 'number' ? v : defVal;
    } catch (e) { return defVal; }
  }

  static async setBool(key: string, value: boolean): Promise<void> {
    const p = await Store.getPrefs();
    if (!p) return;
    try { await p.put(key, value); await p.flush(); } catch (e) {}
  }

  static async getBool(key: string, defVal: boolean = false): Promise<boolean> {
    const p = await Store.getPrefs();
    if (!p) return defVal;
    try {
      const v = await p.get(key, defVal);
      return typeof v === 'boolean' ? v : defVal;
    } catch (e) { return defVal; }
  }

  static async setObj<T>(key: string, value: T): Promise<void> {
    const p = await Store.getPrefs();
    if (!p) return;
    try {
      await p.put(key, JSON.stringify(value));
      await p.flush();
    } catch (e) {}
  }

  static async getObj<T>(key: string): Promise<T | null> {
    const p = await Store.getPrefs();
    if (!p) return null;
    try {
      const v = await p.get(key, '');
      if (typeof v !== 'string' || v === '') return null;
      return JSON.parse(v) as T;
    } catch (e) { return null; }
  }

  static async setArr<T>(key: string, value: T[]): Promise<void> {
    await Store.setObj(key, value);
  }

  static async getArr<T>(key: string): Promise<T[]> {
    const v = await Store.getObj<T[]>(key);
    return v ?? [];
  }

  static async del(key: string): Promise<void> {
    const p = await Store.getPrefs();
    if (!p) return;
    try { await p.delete(key); await p.flush(); } catch (e) {}
  }
}

// 简易格式化
export function pad2(n: number): string {
  return n < 10 ? '0' + n : '' + n;
}

export function formatMMSS(totalSec: number): string {
  const s = Math.max(0, totalSec);
  const m = Math.floor(s / 60);
  const ss = s % 60;
  return `${pad2(m)}:${pad2(ss)}`;
}

export function formatMin(totalSec: number): string {
  const m = Math.floor(totalSec / 60);
  return m + ' 分钟';
}

export function formatHM(d: Date): string {
  return `${pad2(d.getHours())}:${pad2(d.getMinutes())}`;
}

export function todayKey(): string {
  const d = new Date();
  return `${d.getFullYear()}-${pad2(d.getMonth() + 1)}-${pad2(d.getDate())}`;
}

export function greet(): string {
  const h = new Date().getHours();
  if (h < 6) return '深夜好';
  if (h < 11) return '上午好';
  if (h < 14) return '中午好';
  if (h < 18) return '下午好';
  return '晚上好';
}

// 简易 ID 生成
let _idSeed = 0;
export function genId(prefix: string): string {
  _idSeed += 1;
  return prefix + '_' + Date.now().toString(36) + '_' + _idSeed.toString(36);
}