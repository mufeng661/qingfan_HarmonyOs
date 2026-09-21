import { router } from '@kit.ArkUI';
import { AppState } from '../model/AppState';
import { themeOf, ThemeDef, FONT_DISPLAY } from '../model/Types';

interface Msg {
  role: 'me' | 'ai';
  text: string;
  action: string;
}

interface Sugg {
  icon: string;
  title: string;
  desc: string;
}

@Entry
@Component
struct AIChat {
  @State messages: Msg[] = [];
  @State input: string = '';
  @State uiTick: number = 0;
  private t: ThemeDef = themeOf(AppState.instance.themeKey);
  private scroller: Scroller = new Scroller();

  aboutToAppear() {
    this.messages = [
      { role: 'ai', text: '嗨，小满。我是青番 AI，可以帮你排待办、看专注规律，还能给改进建议。想先试哪个？', action: '' }
    ];
  }

  shortName(): string {
    const n = AppState.instance.user?.nickname ?? '小满';
    return n.length > 2 ? n.slice(1) : n;
  }

  aiSort() {
    const order: Record<string, number> = { 'hard': 0, 'medium': 1, 'easy': 2 };
    AppState.instance.tasks.sort((a, b) => {
      if (a.status !== b.status) return a.status === 'todo' ? -1 : 1;
      const oa = order[a.difficulty] ?? 3;
      const ob = order[b.difficulty] ?? 3;
      return oa - ob;
    });
    AppState.instance.tasks = [...AppState.instance.tasks];
    AppState.saveTasks();
  }

  reply(userText: string, aiText: string, action: string) {
    this.messages = [...this.messages, { role: 'me', text: userText, action: '' }];
    this.uiTick += 1;
    setTimeout(() => {
      this.messages = [...this.messages, { role: 'ai', text: aiText, action: action }];
      this.uiTick += 1;
      setTimeout(() => {
        this.scroller.scrollEdge(Edge.Bottom);
      }, 50);
    }, 400);
  }

  send(text: string) {
    const t = text.trim();
    if (!t) return;
    this.messages = [...this.messages, { role: 'me', text: t, action: '' }];
    this.input = '';
    this.uiTick += 1;
    setTimeout(() => {
      this.messages = [...this.messages, { role: 'ai', text: this.genericReply(t), action: '' }];
      this.uiTick += 1;
      setTimeout(() => { this.scroller.scrollEdge(Edge.Bottom); }, 50);
    }, 500);
  }

  genericReply(q: string): string {
    if (q.indexOf('安排') >= 0 || q.indexOf('排') >= 0) {
      return '已按「困难 → 中等 → 简单」帮你重新排序，把最费脑的放在精力最旺的时候先完成。';
    }
    if (q.indexOf('时段') >= 0 || q.indexOf('高效') >= 0) {
      return '你的高效时段是 14:00–16:00 和 20:00–21:30。建议把「写周报」这类硬骨头排在下午，晚上留给轻量阅读。';
    }
    if (q.indexOf('洞察') >= 0 || q.indexOf('报告') >= 0 || q.indexOf('规律') >= 0) {
      return '本周专注 12 小时 05 分，较上周 +18%。深度专注占比 64%，被打断 3 次，主要原因是「消息通知」。';
    }
    if (q.indexOf('建议') >= 0) {
      return '建议 1：专注时开启免打扰，减少打断；建议 2：连续 4 个番茄后安排 15 分钟长休息；建议 3：把背单词挪到早晨 08:30，那时打断率最低。';
    }
    return '我已收到：「' + q + '」。你可以点下方建议卡片，或在「统计」页查看 AI 洞察报告。';
  }

  build() {
    Column() {
      // 顶栏
      Row({ space: 12 }) {
        Text('‹').fontSize(24).fontColor(this.t.ink)
          .onClick(() => { router.back(); })
        Column() {
          Text('AI').fontFamily(FONT_DISPLAY).fontSize(13).fontColor('#FFFFFF')
        }
        .width(36).height(36).borderRadius(11)
        .backgroundColor(this.t.leaf)
        .justifyContent(FlexAlign.Center)

        Column() {
          Text('青番 AI').fontSize(15).fontWeight(FontWeight.Medium).fontColor(this.t.ink)
          Row({ space: 4 }) {
            Column().width(6).height(6).borderRadius(3).backgroundColor(this.t.leaf)
            Text('在线 · 随时为你服务').fontSize(11).fontColor(this.t.leafDeep)
          }
          .margin({ top: 3 })
        }
        .alignItems(HorizontalAlign.Start)
        .layoutWeight(1)
      }
      .width('100%')
      .padding({ left: 16, right: 16, top: 14, bottom: 14 })
      .backgroundColor(this.t.surface)
      .border({ width: { bottom: 1 }, color: this.t.line })

      // 对话区
      Scroll(this.scroller) {
        Column({ space: 10 }) {
          ForEach(this.messages, (m: Msg) => {
            this.bubble(m)
          }, (m: Msg, i: number) => i + '_' + m.role + '_' + this.uiTick)
          Column().height(4)
        }
        .width('100%')
        .padding({ left: 16, right: 16, top: 16, bottom: 8 })
      }
      .layoutWeight(1)
      .scrollBar(BarState.Off)
      .edgeEffect(EdgeEffect.Spring)

      // 建议卡片
      Column() {
        Text('试试这些 AI 能力').fontSize(11).fontColor(this.t.ink3)
          .width('100%').margin({ bottom: 8 })
        Scroll() {
          Row({ space: 8 }) {
            ForEach(this.suggestions(), (s: Sugg) => {
              Column() {
                Text(s.icon).fontSize(18).fontColor(this.t.leafDeep)
                Text(s.title).fontSize(12.5).fontWeight(FontWeight.Medium).fontColor(this.t.ink)
                  .margin({ top: 6 })
                Text(s.desc).fontSize(10.5).fontColor(this.t.ink3)
                  .margin({ top: 3 }).lineHeight(15).textAlign(TextAlign.Start)
              }
              .width(128)
              .padding({ left: 12, right: 12, top: 11, bottom: 11 })
              .backgroundColor(this.t.surface)
              .borderRadius(14)
              .border({ width: 1, color: this.t.line })
              .alignItems(HorizontalAlign.Start)
              .onClick(() => { this.onSuggestion(s); })
            }, (s: Sugg) => s.title)
          }
          .padding({ left: 16, right: 16, bottom: 4 })
        }
        .scrollBar(BarState.Off)
        .scrollable(ScrollDirection.Horizontal)
        .width('100%')
      }
      .width('100%')
      .padding({ top: 6, bottom: 10 })
      .backgroundColor(this.t.bg)
      .border({ width: { top: 1 }, color: this.t.line })

      // 输入框
      Row({ space: 10 }) {
        TextInput({ placeholder: '问问 AI 你的专注情况…', text: this.input })
          .fontSize(13).fontColor(this.t.ink)
          .placeholderColor(this.t.ink3)
          .backgroundColor(this.t.surface)
          .border({ width: 1, color: this.t.line })
          .borderRadius(99)
          .height(44).layoutWeight(1)
          .padding({ left: 15, right: 15 })
          .onChange((v: string) => { this.input = v; })
          .onSubmit(() => { this.send(this.input); })

        Column() {
          Text('➤').fontSize(18).fontColor('#FFFFFF')
        }
        .width(40).height(40).borderRadius(20)
        .backgroundColor(this.t.leaf)
        .justifyContent(FlexAlign.Center)
        .onClick(() => { this.send(this.input); })
      }
      .width('100%')
      .padding({ left: 16, right: 16, top: 10, bottom: 16 })
      .backgroundColor(this.t.bg)
    }
    .width('100%')
    .height('100%')
    .backgroundColor(this.t.bg)
  }

  suggestions(): Sugg[] {
    return [
      { icon: '✨', title: '给待办排个序', desc: '按难易程度自动安排优先级' },
      { icon: '⏰', title: '最佳专注时段', desc: '看看我什么时间效率最高' },
      { icon: '📈', title: '本周专注洞察', desc: '生成我的专注报告' },
      { icon: '🔥', title: '给我点改进建议', desc: '针对我的习惯个性化建议' }
    ];
  }

  onSuggestion(s: Sugg) {
    if (s.title === '给待办排个序') {
      this.aiSort();
      this.reply('帮我给待办排个序', '已按「困难 → 中等 → 简单」帮你重新排序，把最费脑的放在精力最旺的时候先完成。', '已执行排序');
    } else if (s.title === '最佳专注时段') {
      this.reply('我今天几点专注最高效？', '你的高效时段是 14:00–16:00 和 20:00–21:30。建议把「写周报」这类硬骨头排在下午，晚上留给轻量阅读。', '');
    } else if (s.title === '本周专注洞察') {
      this.reply('看看我这周的洞察', '本周专注 12 小时 05 分，较上周 +18%。深度专注占比 64%，被打断 3 次，主要原因是「消息通知」。', '');
    } else {
      this.reply('给我点改进建议', '建议 1：专注时开启免打扰，减少打断；建议 2：连续 4 个番茄后安排 15 分钟长休息；建议 3：把背单词挪到早晨 08:30，那时打断率最低。', '');
    }
  }

  @Builder
  bubble(m: Msg) {
    if (m.role === 'ai') {
      Row() {
        Column() {
          Text('AI').fontFamily(FONT_DISPLAY).fontSize(11).fontColor('#FFFFFF')
        }
        .width(26).height(26).borderRadius(8)
        .backgroundColor(this.t.leaf)
        .justifyContent(FlexAlign.Center)
        .margin({ right: 8 })

        Column() {
          Text(m.text).fontSize(13).fontColor(this.t.ink).lineHeight(21)
          if (m.action.length > 0) {
            Row({ space: 5 }) {
              Text('✓').fontSize(12).fontColor(this.t.leafDeep)
              Text(m.action).fontSize(11).fontColor(this.t.leafDeep)
            }
            .padding({ left: 9, right: 9, top: 4, bottom: 4 })
            .borderRadius(8)
            .backgroundColor(this.t.leafSoft)
            .margin({ top: 8 })
          }
        }
        .padding({ left: 14, right: 14, top: 11, bottom: 11 })
        .backgroundColor(this.t.surface)
        .border({ width: 1, color: this.t.line })
        .borderRadius({ topLeft: 4, topRight: 14, bottomLeft: 14, bottomRight: 14 })
        .constraintSize({ maxWidth: '76%' })
        .alignItems(HorizontalAlign.Start)
      }
      .width('100%')
      .justifyContent(FlexAlign.Start)
      .alignItems(VerticalAlign.Bottom)
    } else {
      Row() {
        Column() {
          Text(m.text).fontSize(13).fontColor('#FFFFFF').lineHeight(21)
        }
        .padding({ left: 14, right: 14, top: 11, bottom: 11 })
        .backgroundColor(this.t.leaf)
        .borderRadius({ topLeft: 14, topRight: 4, bottomLeft: 14, bottomRight: 14 })
        .constraintSize({ maxWidth: '76%' })
        .alignItems(HorizontalAlign.Start)
      }
      .width('100%')
      .justifyContent(FlexAlign.End)
    }
  }
}
