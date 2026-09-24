import { CloudFnService } from './CloudFnService';

export interface RoomComment {
  id: number;
  project_id: string;
  parent_id: number | null;
  root_id: number | null;
  reply_to_name: string | null;
  nickname: string;
  content: string;
  role: string;
  likes: number;
  liked: boolean;
  can_delete: boolean;
  created_at: number;
}

interface FnError {
  message: string;
}

interface CommentListData {
  list: RoomComment[];
  total: number;
  hasMore: boolean;
}

interface CommentListResp {
  success: boolean;
  data: CommentListData;
  error?: FnError;
}

interface OkResp {
  success: boolean;
  error?: FnError;
}

function errMsg(e: FnError | undefined): string {
  return e ? e.message : '请求失败';
}

// 房间留言 · 走三端共用的云函数 studyRoomFunctions（comment.list / comment.add）
export class CloudCommentService {
  static async list(userId: string, roomId: string, page: number, pageSize: number): Promise<RoomComment[]> {
    const data: Record<string, Object> = {};
    data['roomId'] = roomId;
    data['page'] = page;
    data['pageSize'] = pageSize;
    const text = await CloudFnService.call('comment.list', data, userId);
    const r = JSON.parse(text) as CommentListResp;
    if (!r.success) {
      throw new Error(errMsg(r.error));
    }
    return r.data.list ? r.data.list : [];
  }

  static async create(userId: string, roomId: string, nickname: string, content: string, parentId: number): Promise<void> {
    const data: Record<string, Object> = {};
    data['roomId'] = roomId;
    data['nickname'] = nickname;
    data['content'] = content;
    if (parentId > 0) {
      data['parentId'] = parentId;
    }
    const text = await CloudFnService.call('comment.add', data, userId);
    const r = JSON.parse(text) as OkResp;
    if (!r.success) {
      throw new Error(errMsg(r.error));
    }
  }
}
