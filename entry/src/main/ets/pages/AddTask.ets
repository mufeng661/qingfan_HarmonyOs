import { router } from '@kit.ArkUI';
import { promptAction } from '@kit.ArkUI';
import { AppState } from '../model/AppState';
import { themeOf, TaskItem, ThemeDef, FONT_DISPLAY } from '../model/Types';
import { genId } from '../model/Store';

@Entry
@Component
struct AddTask {
  @State title: string = '';
  @State difficulty: 'easy' | 'medium' | 'hard' = 'medium';
  @State durationMin: number = 25;
  @State useCustom: boolean = false;
  @State customDuration: string = '';
  private t: ThemeDef = themeOf(AppState.instance.themeKey);

  durationPresets(): number[] {
    return [15, 25, 45, 60];
  }

  effectiveDuration(): number {
    if (this.useCustom) {
      const n = parseInt(this.customDuration, 10);
      if (!isNaN(n) && n > 0) {
        return Math.min(n, 600);
      }
      return 25;
    }
    return this.durationMin;
  }

  save() {
    if (this.title.trim() === '') {
      promptAction.showToast({ message: '请输入任务标题', duration: 1500 });
      return;
    }
    const t: TaskItem = {
      id: genId('t'),
      title: this.title.trim(),
      durationMin: this.effectiveDuration(),
      difficulty: this.difficulty,
      status: 'todo',
      order: AppState.instance.tasks.length,
      createdAt: Date.now(),
      bgSeed: 'sky'
    };
    AppState.instance.tasks = [...AppState.instance.tasks, t];
    AppState.saveTasks();
    promptAction.showToast({ message: '已添加待办', duration: 1200 });
    setTimeout(() => {
      router.back();
    }, 350);
  }

  build() {
    Stack() {
      // 半透明遮罩
      Column()
        .width('100%')
        .height('100%')
        .backgroundColor('rgba(30,40,26,0.42)')
        .onClick(() => { router.back(); })

      // 居中弹窗
      Column() {
        Text('添加待办')
          .fontFamily(FONT_DISPLAY)
          .fontSize(17)
          .fontColor(this.t.ink)
          .width('100%')
          .margin({ bottom: 14 })

        TextInput({ placeholder: '想专注做什么？', text: this.title })
          .fontSize(14)
          .fontColor(this.t.ink)
          .placeholderColor(this.t.ink3)
          .backgroundColor(this.t.surface2)
          .borderRadius(12)
          .border({ width: 1, color: this.t.line })
          .height(46)
          .width('100%')
          .onChange((v: string) => { this.title = v; })

        Text('专注时长')
          .fontSize(12)
          .fontColor(this.t.ink3)
          .width('100%')
          .margin({ top: 14, bottom: 6 })
        Flex({ wrap: FlexWrap.Wrap }) {
          ForEach(this.durationPresets(), (d: number) => {
            Text(d + ' 分钟')
              .fontSize(13)
              .fontColor(!this.useCustom && this.durationMin === d ? '#FFFFFF' : this.t.ink)
              .backgroundColor(!this.useCustom && this.durationMin === d ? this.t.leaf : this.t.surface2)
              .borderRadius(12)
              .border({ width: 1, color: !this.useCustom && this.durationMin === d ? this.t.leaf : this.t.line })
              .padding({ left: 12, right: 12, top: 8, bottom: 8 })
              .margin({ right: 8, top: 8 })
              .onClick(() => { this.durationMin = d; this.useCustom = false; })
          }, (d: number) => 'dur_' + d)

          Text('自定义')
            .fontSize(13)
            .fontColor(this.useCustom ? '#FFFFFF' : this.t.ink)
            .backgroundColor(this.useCustom ? this.t.leaf : this.t.surface2)
            .borderRadius(12)
            .border({ width: 1, color: this.useCustom ? this.t.leaf : this.t.line })
            .padding({ left: 12, right: 12, top: 8, bottom: 8 })
            .margin({ right: 8, top: 8 })
            .onClick(() => { this.useCustom = true; })
        }
        .width('100%')

        if (this.useCustom) {
          Row() {
            TextInput({ placeholder: '输入分钟数（1-600）', text: this.customDuration })
              .type(InputType.Number)
              .fontSize(14)
              .fontColor(this.t.ink)
              .placeholderColor(this.t.ink3)
              .backgroundColor(Color.Transparent)
              .layoutWeight(1)
              .onChange((v: string) => { this.customDuration = v; })
            Text('分钟').fontSize(13).fontColor(this.t.ink3)
          }
          .width('100%')
          .height(46)
          .padding({ left: 14, right: 14 })
          .backgroundColor(this.t.surface2)
          .borderRadius(12)
          .border({ width: 1, color: this.t.line })
          .margin({ top: 10 })
        }

        Text('难易程度')
          .fontSize(12)
          .fontColor(this.t.ink3)
          .width('100%')
          .margin({ top: 14, bottom: 6 })
        Row({ space: 8 }) {
          this.diffChip('easy', '简单', this.t.leaf, this.t.leafSoft)
          this.diffChip('medium', '中等', this.t.gold, this.t.goldSoft)
          this.diffChip('hard', '困难', this.t.tomato, this.t.tomatoSoft)
        }
        .width('100%')

        Row({ space: 10 }) {
          Row() {
            Text('取消').fontSize(14).fontColor(this.t.ink2)
          }
          .layoutWeight(1)
          .height(44)
          .borderRadius(12)
          .border({ width: 1, color: this.t.line })
          .justifyContent(FlexAlign.Center)
          .onClick(() => { router.back(); })

          Row() {
            Text('添加').fontSize(14).fontColor('#FFFFFF').fontWeight(FontWeight.Medium)
          }
          .layoutWeight(1)
          .height(44)
          .borderRadius(12)
          .backgroundColor(this.t.leaf)
          .justifyContent(FlexAlign.Center)
          .onClick(() => { this.save(); })
        }
        .width('100%')
        .margin({ top: 18 })
      }
      .width(290)
      .padding(22)
      .backgroundColor(this.t.surface)
      .borderRadius(22)
      .shadow({ radius: 30, color: 'rgba(0,0,0,0.2)', offsetY: 12 })
    }
    .width('100%')
    .height('100%')
  }

  @Builder
  diffChip(key: string, label: string, color: string, bg: string) {
    Text(label)
      .fontSize(13)
      .fontColor(color)
      .fontWeight(this.difficulty === key ? FontWeight.Bold : FontWeight.Normal)
      .backgroundColor(this.difficulty === key ? bg : this.t.surface2)
      .borderRadius(12)
      .border({ width: this.difficulty === key ? 1.5 : 1, color: this.difficulty === key ? color : this.t.line })
      .padding({ left: 14, right: 14, top: 8, bottom: 8 })
      .onClick(() => { this.difficulty = key as 'easy' | 'medium' | 'hard'; })
  }
}
