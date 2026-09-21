import { router } from '@kit.ArkUI';
import { AppState } from '../model/AppState';
import { themeOf, ThemeDef } from '../model/Types';

@Entry
@Component
struct Notify {
  @State daily: boolean = true;
  @State weekly: boolean = true;
  @State breakReminder: boolean = true;
  @State sound: boolean = true;
  @State quietStart: string = '22:00';
  @State quietEnd: string = '08:00';
  private t: ThemeDef = themeOf(AppState.instance.themeKey);

  build() {
    Column() {
      Row() {
        Text('‹').fontSize(28).fontColor(this.t.ink)
          .padding({ left: 8, right: 8 })
          .onClick(() => { router.back(); })
        Text('通知设置').fontSize(18).fontWeight(FontWeight.Bold).fontColor(this.t.ink)
          .layoutWeight(1).textAlign(TextAlign.Center)
        Text(' ').fontSize(18).padding({ left: 8, right: 8 })
      }
      .width('100%')
      .padding({ top: 44, bottom: 16, left: 12, right: 12 })

      Scroll() {
        Column() {
          this.sectionTitle('专注提醒')
          this.toggleRow('每日打卡提醒', '每天 21:00 提示签到', this.daily, (v) => { this.daily = v; })
          Divider().color(this.t.line)
          this.toggleRow('专注结束提醒', '完成番茄后推送', this.weekly, (v) => { this.weekly = v; })
          Divider().color(this.t.line)
          this.toggleRow('久坐/打断提醒', '45 分钟提示休息', this.breakReminder, (v) => { this.breakReminder = v; })

          this.sectionTitle('通知偏好')
          this.toggleRow('声音', '通知声音提示', this.sound, (v) => { this.sound = v; })

          this.sectionTitle('免打扰')
          this.timeRow('开始时间', this.quietStart, () => {})
          Divider().color(this.t.line)
          this.timeRow('结束时间', this.quietEnd, () => {})

          Text('青番会智能避开你的高效区间，避免打扰专注。')
            .fontSize(12).fontColor(this.t.ink3).margin({ top: 16 })
            .width('100%')
        }
        .padding({ left: 16, right: 16 })
      }
      .layoutWeight(1)
      .scrollBar(BarState.Off)
      .edgeEffect(EdgeEffect.Spring)
    }
    .width('100%')
    .height('100%')
    .backgroundColor(this.t.bg)
  }

  @Builder
  sectionTitle(t: string) {
    Text(t)
      .fontSize(13)
      .fontColor(this.t.ink2)
      .width('100%')
      .margin({ top: 16, bottom: 6 })
  }

  @Builder
  toggleRow(label: string, hint: string, value: boolean, onChange: (v: boolean) => void) {
    Row() {
      Column() {
        Text(label).fontSize(15).fontColor(this.t.ink)
        Text(hint).fontSize(12).fontColor(this.t.ink3).margin({ top: 2 })
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)
      Toggle({ type: ToggleType.Switch, isOn: value })
        .selectedColor(this.t.leaf)
        .onChange((v: boolean) => { onChange(v); })
    }
    .width('100%')
    .padding({ top: 14, bottom: 14 })
    .backgroundColor(this.t.surface)
  }

  @Builder
  timeRow(label: string, value: string, onTap: () => void) {
    Row() {
      Text(label).fontSize(15).fontColor(this.t.ink).layoutWeight(1)
      Text(value).fontSize(15).fontColor(this.t.leaf)
      Text('›').fontSize(18).fontColor(this.t.ink3).margin({ left: 6 })
    }
    .width('100%')
    .padding({ top: 14, bottom: 14 })
    .backgroundColor(this.t.surface)
    .onClick(() => { onTap(); })
  }
}
