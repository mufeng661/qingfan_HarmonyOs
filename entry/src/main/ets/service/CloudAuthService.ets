import { CloudFnService } from './CloudFnService';

export interface AuthUser {
  id: number;
  phone: string;
  username: string;
  nickname: string;
  avatarSeed: string;
  bio: string;
  created_at: number;
}

interface FnError {
  message: string;
}

interface AuthData {
  token: string;
  user: AuthUser;
}

interface AuthResp {
  success: boolean;
  data: AuthData;
  error?: FnError;
}

function errMsg(e: FnError | undefined): string {
  return e ? e.message : '请求失败';
}

// 账号鉴权 · 走三端共用的云函数 studyRoomFunctions（与小程序/Web 同一套账号）
export class CloudAuthService {
  static async login(phone: string, password: string): Promise<AuthUser> {
    const data: Record<string, Object> = {};
    data['phone'] = phone;
    data['password'] = password;
    const text = await CloudFnService.call('auth.login', data, phone);
    const r = JSON.parse(text) as AuthResp;
    if (!r.success) {
      throw new Error(errMsg(r.error));
    }
    return r.data.user;
  }

  static async register(username: string, phone: string, password: string): Promise<AuthUser> {
    const data: Record<string, Object> = {};
    data['username'] = username;
    data['phone'] = phone;
    data['password'] = password;
    const text = await CloudFnService.call('auth.register', data, phone);
    const r = JSON.parse(text) as AuthResp;
    if (!r.success) {
      throw new Error(errMsg(r.error));
    }
    return r.data.user;
  }
}
