import { router } from '@kit.ArkUI';
import { promptAction } from '@kit.ArkUI';
import { formProvider } from '@kit.FormKit';
import { Want } from '@kit.AbilityKit';
import { AppState } from '../model/AppState';
import { themeOf, ThemeDef, FONT_DISPLAY } from '../model/Types';
import { todayKey } from '../model/Store';

interface SizeOption {
  key: string;
  label: string;
  desc: string;
}

@Entry
@Component
struct WidgetPicker {
  @State pickedSize: string = '2x4';
  @State addedSize: string = '';
  @State uiTick: number = 0;
  private t: ThemeDef = themeOf(AppState.instance.themeKey);

  // 尺寸规格与 form_config.json 的 supportDimensions 保持一致（4×4 已下架）
  private sizes: SizeOption[] = [
    { key: '2x2', label: '2×2', desc: '极简' },
    { key: '2x4', label: '2×4', desc: '横条' }
  ];

  doneCount(): number {
    const k = todayKey();
    return AppState.instance.stats[k]?.pomodoroCount ?? 0;
  }

  todayMinutes(): number {
    const k = todayKey();
    return AppState.instance.stats[k]?.focusMinutes ?? 0;
  }

  goal(): number {
    return Math.max(1, AppState.instance.challengeGoal);
  }

  pct(): number {
    return Math.min(100, Math.round(this.doneCount() / this.goal() * 100));
  }

  reached(): boolean {
    return this.doneCount() >= this.goal();
  }

  totalTrees(): number {
    let t = 0;
    Object.keys(AppState.instance.stats).forEach(k => { t += AppState.instance.stats[k].pomodoroCount; });
    return Math.floor(t / 10);
  }

  streakDays(): number {
    return AppState.instance.user?.streak ?? 0;
  }

  // 与桌面卡片 2×2 的「吉祥物」同一套状态逻辑
  moodEmoji(): string {
    const d = this.doneCount();
    const g = this.goal();
    if (d >= g) {
      return '🎉';
    }
    if (d > 0) {
      return '🍅';
    }
    return '🌱';
  }

  moodText(): string {
    const d = this.doneCount();
    const g = this.goal();
    if (d >= g) {
      return '今日目标达成';
    }
    if (d > 0) {
      return '继续加油';
    }
    return '今天还没开始';
  }

  isAdded(): boolean {
    return this.addedSize === this.pickedSize;
  }

  dimensionValue(): number {
    // formInfo.FormDimension 枚举：Dimension_1_2=1 / 2_2=2 / 2_4=3 / 4_4=4
    if (this.pickedSize === '2x2') return 2;
    return 3;
  }

  addToDesktop(): void {
    const params: Record<string, Object> = {};
    params['ohos.extra.param.key.form_dimension'] = this.dimensionValue();
    params['ohos.extra.param.key.form_name'] = 'QfWidget';
    params['ohos.extra.param.key.module_name'] = 'entry';
    const want: Want = {
      bundleName: 'com.example.myapplication',
      abilityName: 'QfWidgetAbility',
      parameters: params
    };
    try {
      formProvider.openFormManager(want);
      this.addedSize = this.pickedSize;
      promptAction.showToast({ message: '请在卡片管理页把它添加到桌面', duration: 2000 });
    } catch (e) {
      promptAction.showToast({ message: '无法打开卡片管理页，请在桌面长按空白处添加', duration: 2000 });
    }
  }

  build() {
    Stack({ alignContent: Alignment.BottomStart }) {
      Column()
        .width('100%')
        .height('100%')
        .linearGradient({ angle: 160, colors: [[this.t.brandGrad1, 0], [this.t.brandGrad2, 1]] })

      // 壁纸装饰
      Shape() {
        Path()
          .commands('M-20 320C60 180 160 120 260 140c80 16 120 60 160 120-40-20-80-20-120 0s-80 40-140 40Z')
          .fill(this.t.leaf)
        Path()
          .commands('M220 300c-10-60 20-110 70-140-10 70-30 110-70 140Z')
          .fill(this.t.leafDeep)
      }
      .viewPort({ x: -20, y: 0, width: 420, height: 340 })
      .width('100%')
      .height(300)
      .opacity(0.16)
      .offset({ y: -20 })

      Column() {
        // 顶栏
        Row() {
          Column() {
            Text('桌面小组件').fontFamily(FONT_DISPLAY).fontSize(20).fontColor(this.t.ink)
            Text('把专注进度放到手机桌面 · 点卡片进今日待办').fontSize(11).fontColor(this.t.ink2).margin({ top: 2 })
          }
          .alignItems(HorizontalAlign.Start)
          .layoutWeight(1)

          Column() {
            Text('✕').fontSize(18).fontColor(this.t.ink2)
          }
          .width(34).height(34).borderRadius(17)
          .backgroundColor(this.t.surface)
          .border({ width: 1, color: this.t.line })
          .justifyContent(FlexAlign.Center)
          .onClick(() => { router.back(); })
        }
        .width('100%')
        .padding({ left: 18, right: 18, top: 14, bottom: 4 })

        // 组件预览（固定高度容器居中，切换尺寸不会错位）
        Column() {
          Stack({ alignContent: Alignment.Center }) {
            this.widgetPreview()
          }
          .width('100%')
          .height(240)
        }
        .layoutWeight(1)
        .width('100%')
        .justifyContent(FlexAlign.Center)
        .padding({ bottom: 8 })

        // 底部控制
        Column() {
          Text('选择尺寸').fontSize(11).fontColor(this.t.ink3)
            .width('100%').margin({ bottom: 10 })
          Row({ space: 10 }) {
            ForEach(this.sizes, (s: SizeOption) => {
              Column() {
                Text(s.label)
                  .fontSize(14).fontWeight(FontWeight.Bold)
                  .fontColor(this.pickedSize === s.key ? this.t.leafDeep : this.t.ink)
                Text(s.desc).fontSize(10).fontColor(this.t.ink3).margin({ top: 1 })
              }
              .layoutWeight(1)
              .padding({ top: 10, bottom: 10 })
              .borderRadius(13)
              .backgroundColor(this.pickedSize === s.key ? this.t.leafSoft : this.t.surface2)
              .border(this.pickedSize === s.key ? { width: 1.5, color: this.t.leaf } : { width: 1, color: this.t.line })
              .onClick(() => { this.pickedSize = s.key; })
            }, (s: SizeOption) => s.key)
          }
          .width('100%')

          Row({ space: 7 }) {
            Text(this.isAdded() ? '✓' : '＋').fontSize(16).fontColor(this.isAdded() ? this.t.ink2 : '#FFFFFF')
            Text(this.isAdded() ? '已添加到桌面' : '添加到桌面')
              .fontSize(14.5).fontWeight(FontWeight.Medium)
              .fontColor(this.isAdded() ? this.t.ink2 : '#FFFFFF')
          }
          .width('100%')
          .height(48)
          .borderRadius(14)
          .backgroundColor(this.isAdded() ? this.t.surface2 : this.t.leaf)
          .justifyContent(FlexAlign.Center)
          .margin({ top: 12 })
          .onClick(() => { this.addToDesktop(); })
        }
        .width('100%')
        .padding({ left: 18, right: 18, top: 14, bottom: 16 })
        .backgroundColor(this.t.bar)
        .border({ width: { top: 1 }, color: this.t.line })
      }
      .width('100%')
      .height('100%')
    }
    .width('100%')
    .height('100%')
  }

  @Builder
  widgetPreview() {
    if (this.pickedSize === '2x2') {
      // 多邻国式：吉祥物 + 大数字 + 状态文案 + 细完成度条（与桌面卡片 compactLayout 一致）
      Column() {
        Row() {
          Text('今日番茄').fontSize(9.5).fontColor(this.t.ink3)
          Blank()
          Text('🔥 ' + this.streakDays()).fontSize(9.5).fontWeight(FontWeight.Medium).fontColor(this.t.tomato)
        }
        .width('100%')

        Row() {
          Text(this.moodEmoji()).fontSize(20)
          Text(this.doneCount() + '').fontFamily(FONT_DISPLAY).fontSize(27).fontColor(this.t.leaf).margin({ left: 3 })
          Text('/' + this.goal()).fontSize(12).fontColor(this.t.ink3).margin({ left: 1 })
        }
        .alignItems(VerticalAlign.Bottom)
        .margin({ top: 1 })

        Text(this.moodText()).fontSize(9.5).fontColor(this.t.ink3).margin({ top: 2 })

        Stack() {
          Row().width('100%').height(5).borderRadius(99).backgroundColor(this.t.surface2)
          Row().width(this.pct() + '%').height(5).borderRadius(99).backgroundColor(this.t.leaf)
        }
        .width('100%')
        .margin({ top: 8 })
      }
      .width(108).height(108)
      .padding(12)
      .backgroundColor(this.t.surface)
      .borderRadius(20)
      .border({ width: 1, color: this.t.line })
      .shadow({ radius: 30, color: 'rgba(0,0,0,0.10)', offsetY: 12 })
      .justifyContent(FlexAlign.Center)
      .alignItems(HorizontalAlign.Center)
    } else {
      // 2×4 宽卡：左右两栏，信息与桌面卡片 wideLayout 一一对应
      Row() {
        Column() {
          Text('🌿 青番').fontSize(11).fontWeight(FontWeight.Bold).fontColor(this.t.leaf)
          Text(this.todayMinutes() + ' 分钟').fontFamily(FONT_DISPLAY).fontSize(21).fontColor(this.t.ink).margin({ top: 1 })
          Text('🌳 ' + this.totalTrees() + ' 棵树').fontSize(9.5).fontColor(this.t.ink3).margin({ top: 1 })
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start)
        .justifyContent(FlexAlign.Center)

        Column() {
          Row() {
            Text('🍅 ' + this.doneCount() + '/' + this.goal())
              .fontSize(11.5).fontWeight(FontWeight.Medium).fontColor(this.t.ink)
            Blank()
            Text('🔥 ' + this.streakDays() + ' 天').fontSize(10).fontColor(this.t.tomato)
          }
          .width('100%')

          Stack() {
            Row().width('100%').height(5).borderRadius(99).backgroundColor(this.t.surface2)
            Row().width(this.pct() + '%').height(5).borderRadius(99)
              .backgroundColor(this.reached() ? this.t.gold : this.t.leaf)
          }
          .width('100%')
          .margin({ top: 6 })

          Row() {
            Text('查看待办 ›').fontSize(10).fontColor(this.t.leaf)
          }
          .width('100%')
          .justifyContent(FlexAlign.End)
          .margin({ top: 6 })
        }
        .layoutWeight(1)
        .margin({ left: 10 })
        .alignItems(HorizontalAlign.Start)
        .justifyContent(FlexAlign.Center)
      }
      .width(212).height(104)
      .padding(13)
      .backgroundColor(this.t.surface)
      .borderRadius(20)
      .border({ width: 1, color: this.t.line })
      .shadow({ radius: 30, color: 'rgba(0,0,0,0.10)', offsetY: 12 })
    }
  }
}
