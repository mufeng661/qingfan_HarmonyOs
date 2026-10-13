import { router } from '@kit.ArkUI';
import { AppState } from '../model/AppState';
import { themeOf, ThemeDef, FONT_DISPLAY } from '../model/Types';

@Entry
@Component
struct Agreement {
  @State type: string = 'user';
  private t: ThemeDef = themeOf(AppState.instance.themeKey);

  aboutToAppear() {
    const p = router.getParams() as Record<string, string>;
    if (p && p['type'] === 'privacy') {
      this.type = 'privacy';
    }
  }

  title(): string {
    return this.type === 'privacy' ? '隐私政策' : '用户协议';
  }

  body(): string {
    if (this.type === 'privacy') {
      return '我们非常重视你的隐私。\n\n1. 账号数据（待办、专注记录、统计、资料）在你登录后按手机号加密存储在云端，用于三端同步。\n\n2. 未登录时数据仅保存在本机，不会上传。\n\n3. 我们不会将你的个人数据出售或提供给第三方，除法律法规要求外不对外披露。\n\n4. 你可以随时退出登录或联系客服删除账号数据。';
    }
    return '欢迎使用青番（AI 番茄钟）。\n\n1. 本应用帮助你规划待办、进行番茄专注、记录成长数据。\n\n2. 请勿利用本应用从事任何违法违规活动。\n\n3. AI 生成内容仅供参考，请自行判断并承担使用后果。\n\n4. 我们会持续优化服务，保留对功能与条款进行调整的权利。';
  }

  build() {
    Column() {
      Row() {
        Text('‹').fontSize(26).fontColor(this.t.ink).width(26)
          .onClick(() => { router.back(); })
        Text(this.title()).fontFamily(FONT_DISPLAY).fontSize(17).fontColor(this.t.ink)
          .layoutWeight(1).textAlign(TextAlign.Center)
        Text(' ').fontSize(26).width(26)
      }
      .width('100%')
      .padding({ left: 18, right: 18, top: 14, bottom: 10 })

      Scroll() {
        Column() {
          Text(this.body())
            .fontSize(13).fontColor(this.t.ink2).lineHeight(24).width('100%')
        }
        .width('100%')
        .padding(18)
        .backgroundColor(this.t.surface)
        .borderRadius(18)
        .border({ width: 1, color: this.t.line })
      }
      .layoutWeight(1)
      .scrollBar(BarState.Off)
      .padding({ left: 22, right: 22 })
    }
    .width('100%')
    .height('100%')
    .backgroundColor(this.t.bg)
  }
}
