import { CloudFnService } from './CloudFnService';

export interface RoomMember {
  user_id: string;
  role: string;
  joined_at: number;
  nickname?: string;
  focus_minutes?: number;
}

export interface Room {
  id: string;
  name: string;
  owner_id: string;
  need_password: boolean;
  created_at: number;
  updated_at: number;
  role: string;
  member_count: number;
  members?: RoomMember[];
}

interface FnError {
  message: string;
}

interface RoomResp {
  success: boolean;
  data: Room;
  error?: FnError;
}

interface RoomListData {
  list: Room[];
}

interface RoomListResp {
  success: boolean;
  data: RoomListData;
  error?: FnError;
}

interface OkResp {
  success: boolean;
  error?: FnError;
}

function errMsg(e: FnError | undefined): string {
  return e ? e.message : '请求失败';
}

// 自习室房间 · 走三端共用的云函数 studyRoomFunctions（房间号 = room.id，UUID）
export class CloudRoomService {
  static async listMine(userId: string): Promise<Room[]> {
    const empty: Record<string, Object> = {};
    const text = await CloudFnService.call('room.listMine', empty, userId);
    const r = JSON.parse(text) as RoomListResp;
    if (!r.success) {
      throw new Error(errMsg(r.error));
    }
    return r.data.list ? r.data.list : [];
  }

  static async create(userId: string, name: string, password: string): Promise<Room> {
    const data: Record<string, Object> = {};
    data['name'] = name;
    data['password'] = password;
    const text = await CloudFnService.call('room.create', data, userId);
    const r = JSON.parse(text) as RoomResp;
    if (!r.success) {
      throw new Error(errMsg(r.error));
    }
    return r.data;
  }

  static async join(userId: string, roomId: string, password: string): Promise<Room> {
    const data: Record<string, Object> = {};
    data['roomId'] = roomId;
    data['password'] = password;
    const text = await CloudFnService.call('room.join', data, userId);
    const r = JSON.parse(text) as RoomResp;
    if (!r.success) {
      throw new Error(errMsg(r.error));
    }
    return r.data;
  }

  // room.get 返回的 member_count 是准确的（listMine 的不准，恒为 1）
  static async get(userId: string, roomId: string): Promise<Room> {
    const data: Record<string, Object> = {};
    data['roomId'] = roomId;
    const text = await CloudFnService.call('room.get', data, userId);
    const r = JSON.parse(text) as RoomResp;
    if (!r.success) {
      throw new Error(errMsg(r.error));
    }
    return r.data;
  }

  static async remove(userId: string, roomId: string): Promise<void> {
    const data: Record<string, Object> = {};
    data['roomId'] = roomId;
    const text = await CloudFnService.call('room.delete', data, userId);
    const r = JSON.parse(text) as OkResp;
    if (!r.success) {
      throw new Error(errMsg(r.error));
    }
  }

  static async leave(userId: string, roomId: string): Promise<void> {
    const data: Record<string, Object> = {};
    data['roomId'] = roomId;
    const text = await CloudFnService.call('room.leave', data, userId);
    const r = JSON.parse(text) as OkResp;
    if (!r.success) {
      throw new Error(errMsg(r.error));
    }
  }

  // 上报本人在本房间的专注时长（云函数支持 focus.record 时生效；不支持则忽略）
  static async recordFocus(userId: string, roomId: string, minutes: number): Promise<void> {
    if (roomId.length === 0 || minutes <= 0) return;
    const data: Record<string, Object> = {};
    data['roomId'] = roomId;
    data['minutes'] = minutes;
    const text = await CloudFnService.call('focus.record', data, userId);
    const r = JSON.parse(text) as OkResp;
    if (!r.success) {
      throw new Error(errMsg(r.error));
    }
  }
}
