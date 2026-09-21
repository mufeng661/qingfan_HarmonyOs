import { router } from '@kit.ArkUI';
import { AppState } from '../model/AppState';
import { themeOf, THEMES, ThemeKey, ThemeDef } from '../model/Types';

@Entry
@Component
struct ThemePicker {
  @State uiTick: number = 0;
  private t: ThemeDef = themeOf(AppState.instance.themeKey);

  build() {
    Column() {
      Row() {
        Text('‹').fontSize(28).fontColor(this.t.ink)
          .padding({ left: 8, right: 8 })
          .onClick(() => { router.back(); })
        Text('外观主题').fontSize(18).fontWeight(FontWeight.Bold).fontColor(this.t.ink)
          .layoutWeight(1).textAlign(TextAlign.Center)
        Text(' ').fontSize(18).padding({ left: 8, right: 8 })
      }
      .width('100%')
      .padding({ top: 44, bottom: 16, left: 12, right: 12 })

      Text('选择一款契合你心境的主题，切换即时生效。')
        .fontSize(13).fontColor(this.t.ink2)
        .width('100%')
        .padding({ left: 16 })

      Scroll() {
        Column({ space: 12 }) {
          ForEach(THEMES, (th: ThemeDef) => {
            Row() {
              Column()
                .width(56).height(56).borderRadius(14)
                .linearGradient({ angle: 135, colors: [[th.leaf, 0], [th.bg, 1]] })

              Column() {
                Text(th.name)
                  .fontSize(16).fontWeight(FontWeight.Bold).fontColor(this.t.ink)
                Text(th.desc).fontSize(12).fontColor(this.t.ink2).margin({ top: 2 })
              }
              .margin({ left: 14 })
              .layoutWeight(1)
              .alignItems(HorizontalAlign.Start)

              if (AppState.instance.themeKey === th.key) {
                Text('✓').fontSize(20).fontColor(this.t.leaf)
              }
            }
            .width('100%')
            .padding(14)
            .backgroundColor(this.t.surface)
            .borderRadius(16)
            .border(AppState.instance.themeKey === th.key ? { width: 2, color: this.t.leaf } : { width: 1, color: this.t.line })
            .shadow({ radius: 8, color: 'rgba(0,0,0,0.05)', offsetY: 2 })
            .onClick(() => {
              AppState.instance.themeKey = th.key;
              AppState.saveTheme();
              this.t = themeOf(th.key);
              this.uiTick += 1;
              router.back();
            })
          })
        }
        .padding({ left: 16, right: 16, top: 12 })
      }
      .layoutWeight(1)
      .scrollBar(BarState.Off)
      .edgeEffect(EdgeEffect.Spring)
    }
    .width('100%')
    .height('100%')
    .backgroundColor(this.t.bg)
  }
}
