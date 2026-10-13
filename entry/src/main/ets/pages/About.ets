import { router } from '@kit.ArkUI';
import { AppState } from '../model/AppState';
import { themeOf, ThemeDef, FONT_DISPLAY } from '../model/Types';

@Entry
@Component
struct About {
  private t: ThemeDef = themeOf(AppState.instance.themeKey);

  build() {
    Column() {
      Row() {
        Text('‹').fontSize(26).fontColor(this.t.ink).width(26)
          .onClick(() => { router.back(); })
        Text('关于青番').fontFamily(FONT_DISPLAY).fontSize(17).fontColor(this.t.ink)
          .layoutWeight(1).textAlign(TextAlign.Center)
        Text(' ').fontSize(26).width(26)
      }
      .width('100%')
      .padding({ left: 18, right: 18, top: 14, bottom: 10 })

      Scroll() {
        Column() {
          Text('🍅').fontSize(56).margin({ top: 22 })
          Text('青番').fontFamily(FONT_DISPLAY).fontSize(22).fontColor(this.t.ink).margin({ top: 8 })
          Text('v1.0.0 · AI 番茄钟智能助手').fontSize(12).fontColor(this.t.ink3).margin({ top: 4 })

          Column() {
            Text('把专注，种成一片番茄园。\n一款会陪你成长的专注工具。')
              .fontSize(13).fontColor(this.t.ink2).lineHeight(22).textAlign(TextAlign.Center)
          }
          .width('100%')
          .padding(18)
          .backgroundColor(this.t.surface)
          .borderRadius(18)
          .border({ width: 1, color: this.t.line })
          .margin({ top: 18 })

          Text('© 2026 青番团队').fontSize(11).fontColor(this.t.ink3).margin({ top: 20, bottom: 20 })
        }
        .width('100%')
        .padding({ left: 22, right: 22 })
        .alignItems(HorizontalAlign.Center)
      }
      .layoutWeight(1)
      .scrollBar(BarState.Off)
    }
    .width('100%')
    .height('100%')
    .backgroundColor(this.t.bg)
  }
}
