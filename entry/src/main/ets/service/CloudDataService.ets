import { CloudFnService } from './CloudFnService';

// 账号数据云端同步（三端互通）：待办 / 专注记录 / 每日统计 / 资料
// 走同一个云函数 studyRoomFunctions 的 data.* 接口。

interface FnError {
  message: string;
}

interface PullData {
  tasks: Object[];
  records: Object[];
  stats: Record<string, Object>;
  profile: Record<string, Object>;
}

interface PullResp {
  success: boolean;
  data: PullData;
  error?: FnError;
}

export class CloudDataService {
  static async pull(userId: string): Promise<PullData | null> {
    try {
      const empty: Record<string, Object> = {};
      const text = await CloudFnService.call('data.pull', empty, userId);
      const r = JSON.parse(text) as PullResp;
      if (!r.success || r.data === undefined || r.data === null) return null;
      return r.data;
    } catch (e) {
      return null;
    }
  }

  static async saveTasks(userId: string, tasks: Object[]): Promise<void> {
    const data: Record<string, Object> = {};
    data['tasks'] = tasks;
    await CloudFnService.call('data.saveTasks', data, userId);
  }

  static async saveRecords(userId: string, records: Object[]): Promise<void> {
    const data: Record<string, Object> = {};
    data['records'] = records;
    await CloudFnService.call('data.saveRecords', data, userId);
  }

  static async saveStats(userId: string, stats: Record<string, Object>): Promise<void> {
    const data: Record<string, Object> = {};
    data['stats'] = stats;
    await CloudFnService.call('data.saveStats', data, userId);
  }

  static async saveProfile(userId: string, profile: Record<string, Object>): Promise<void> {
    const data: Record<string, Object> = {};
    data['profile'] = profile;
    await CloudFnService.call('data.saveProfile', data, userId);
  }
}
