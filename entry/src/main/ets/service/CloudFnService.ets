import { http } from '@kit.NetworkKit';
import { CLOUD_FN_URL, CLOUD_PLATFORM } from '../model/CloudBase';

// 云函数调用客户端：POST { action, userId, platform, ...data }
// 与 Web / 小程序端同构（小程序 wx.cloud.callFunction、Web fetch fnUrl）。
export class CloudFnService {
  static async call(action: string, data: Record<string, Object>, userId: string): Promise<string> {
    const body: Record<string, Object> = {};
    body['action'] = action;
    body['userId'] = userId;
    body['platform'] = CLOUD_PLATFORM;
    const keys: string[] = Object.keys(data);
    for (let i = 0; i < keys.length; i++) {
      body[keys[i]] = data[keys[i]];
    }

    const header: Record<string, string> = {};
    header['Content-Type'] = 'application/json; charset=utf-8';
    header['x-user-id'] = userId;
    header['x-user-platform'] = CLOUD_PLATFORM;

    const req = http.createHttp();
    try {
      const res = await req.request(CLOUD_FN_URL, {
        method: http.RequestMethod.POST,
        header: header,
        extraData: JSON.stringify(body),
        connectTimeout: 10000,
        readTimeout: 15000
      });
      if (res.responseCode !== 200) {
        throw new Error('HTTP ' + res.responseCode);
      }
      return res.result as string;
    } finally {
      req.destroy();
    }
  }
}
