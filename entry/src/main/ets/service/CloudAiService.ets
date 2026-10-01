import { AppState } from '../model/AppState';
import { todayKey } from '../model/Store';
import { CloudFnService } from './CloudFnService';

export interface AiMessage {
  role: string;
  content: string;
}

interface AiTaskBrief {
  title: string;
  status: string;
  durationMin: number;
}

interface AiContext {
  nickname: string;
  todayFocusMinutes: number;
  pomodoro: number;
  streak: number;
  interruptReasons: string[];
  tasks: AiTaskBrief[];
}

interface FnError {
  code?: string;
  message: string;
}

interface AiChatData {
  reply: string;
}

interface AiChatResp {
  success: boolean;
  data: AiChatData;
  error?: FnError;
}

// AI 业务错误（配额/限流等），code 用于前端区分处理
export class AiError extends Error {
  code: string;

  constructor(code: string, message: string) {
    super(message);
    this.code = code;
  }
}

function errMsg(e: FnError | undefined): string {
  return e ? e.message : '请求失败';
}

// AI 助手 · 走云函数 studyRoomFunctions（ai.chat / ai.insight）。
// 真实大模型在云端调用，API Key 只存云函数环境变量，客户端不持有密钥。
export class CloudAiService {
  static buildContextJson(): string {
    const s = AppState.instance;
    const st = s.stats[todayKey()];
    const reasons: string[] = [];
    if (st) {
      const keys: string[] = Object.keys(st.interruptCounts);
      for (let i = 0; i < keys.length; i++) {
        reasons.push(keys[i] + '×' + st.interruptCounts[keys[i]]);
      }
    }
    const tasks: AiTaskBrief[] = [];
    for (let i = 0; i < s.tasks.length && i < 10; i++) {
      const t = s.tasks[i];
      tasks.push({ title: t.title, status: t.status, durationMin: t.durationMin });
    }
    const ctx: AiContext = {
      nickname: s.user?.nickname ?? '',
      todayFocusMinutes: st ? st.focusMinutes : 0,
      pomodoro: st ? st.pomodoroCount : 0,
      streak: s.user?.streak ?? 0,
      interruptReasons: reasons,
      tasks: tasks
    };
    return JSON.stringify(ctx);
  }

  static async chat(userId: string, history: AiMessage[], prompt: string): Promise<string> {
    const data: Record<string, Object> = {};
    data['messages'] = history;
    data['prompt'] = prompt;
    data['context'] = CloudAiService.buildContextJson();
    const text = await CloudFnService.call('ai.chat', data, userId, 60000);
    const r = JSON.parse(text) as AiChatResp;
    if (!r.success) {
      throw new AiError(r.error?.code ?? 'ERROR', errMsg(r.error));
    }
    return r.data.reply;
  }

  static async insight(userId: string, prompt: string): Promise<string> {
    const data: Record<string, Object> = {};
    data['prompt'] = prompt;
    data['context'] = CloudAiService.buildContextJson();
    const text = await CloudFnService.call('ai.insight', data, userId, 60000);
    const r = JSON.parse(text) as AiChatResp;
    if (!r.success) {
      throw new AiError(r.error?.code ?? 'ERROR', errMsg(r.error));
    }
    return r.data.reply;
  }
}
