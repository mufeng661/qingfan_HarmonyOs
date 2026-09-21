import { router } from '@kit.ArkUI';
import { AppState } from '../model/AppState';
import { themeOf, ThemeDef, FONT_DISPLAY, FocusRecord, DailyStats } from '../model/Types';
import { todayKey, pad2, formatHM } from '../model/Store';
import { TabBar } from '../components/TabBar';

type RangeKey = 'day' | 'week' | 'month';

interface TimeLineRow {
  start: string;
  end: string;
  title: string;
  mins: number;
}

@Entry
@Component
struct Stats {
  @State range: RangeKey = 'day';
  private t: ThemeDef = themeOf(AppState.instance.themeKey);

  build() {
    Column() {
      // 顶栏
      Row() {
        Text('统计')
          .fontFamily(FONT_DISPLAY)
          .fontSize(24)
          .fontColor(this.t.ink)
          .layoutWeight(1)
        Row({ space: 6 }) {
          this.rangePill('日', 'day')
          this.rangePill('周', 'week')
          this.rangePill('月', 'month')
        }
      }
      .width('100%')
      .padding({ left: 22, right: 22, top: 20, bottom: 14 })

      Scroll() {
        Column() {
          this.dataCard()
          this.aiCard()
          Text('今日完成时间轴')
            .fontFamily(FONT_DISPLAY)
            .fontSize(16)
            .fontColor(this.t.ink)
            .width('100%')
            .margin({ top: 4, bottom: 14 })
          this.timeline()
          Column().height(16)
        }
        .width('100%')
        .padding({ left: 22, right: 22, top: 4 })
      }
      .layoutWeight(1)
      .scrollBar(BarState.Off)
      .edgeEffect(EdgeEffect.Spring)

      TabBar({ active: 'stats' })
    }
    .width('100%')
    .height('100%')
    .backgroundColor(this.t.bg)
  }

  @Builder
  rangePill(label: string, key: RangeKey) {
    Text(label)
      .fontSize(12.5)
      .fontColor(this.range === key ? '#FFFFFF' : this.t.ink2)
      .padding({ left: 13, right: 13, top: 7, bottom: 7 })
      .borderRadius(99)
      .backgroundColor(this.range === key ? this.t.leaf : Color.Transparent)
      .border(this.range === key ? { width: 1, color: 'transparent' } : { width: 1, color: this.t.line })
      .onClick(() => { this.range = key; })
  }

  // ====== 数据卡 ======
  @Builder
  dataCard() {
    Row() {
      this.dataItem('⏱', this.focusHours(), '专注时长', this.t.leafDeep, true)
      this.dataItem('🍅', this.pomoTotal() + '', '完成番茄', this.t.tomato, true)
      this.dataItem('⭐', this.completionRate() + '%', '任务完成率', this.t.gold, false)
    }
    .width('100%')
    .padding({ top: 18, bottom: 18, left: 20, right: 20 })
    .backgroundColor(this.t.surface)
    .borderRadius(18)
    .border({ width: 1, color: this.t.line })
    .margin({ bottom: 12 })
  }

  @Builder
  dataItem(icon: string, val: string, label: string, c: string, divider: boolean) {
    Column() {
      Text(icon).fontSize(16).fontColor(c)
      Text(val)
        .fontFamily(FONT_DISPLAY)
        .fontSize(20)
        .fontColor(this.t.ink)
        .margin({ top: 6 })
      Text(label).fontSize(11).fontColor(this.t.ink2).margin({ top: 5 })
    }
    .layoutWeight(1)
    .alignItems(HorizontalAlign.Center)
    .border(divider ? { width: { right: 1 }, color: this.t.line } : { width: 0 })
  }

  // ====== AI 分析 ======
  @Builder
  aiCard() {
    Column() {
      Row({ space: 8 }) {
        Column() {
          Text('AI').fontFamily(FONT_DISPLAY).fontSize(12).fontColor('#FFFFFF')
        }
        .width(22).height(22).borderRadius(7)
        .backgroundColor(this.t.leaf)
        .justifyContent(FlexAlign.Center)

        Text('本周专注洞察')
          .fontFamily(FONT_DISPLAY)
          .fontSize(14.5)
          .fontColor(this.t.ink)
      }
      .width('100%')
      .margin({ bottom: 10 })

      Column({ space: 8 }) {
        this.insight('专注总时长较上周 ', '提升 18%', '，坚持得很好。', this.t.leafDeep)
        this.insight('你的「深度专注」高峰在 ', '14:00–16:00', '，建议保留。', this.t.tomato)
        this.insight('早晨 08:30 的专注被打断率最低，适合安排阅读类任务。', '', '', this.t.ink)
      }
      .width('100%')
    }
    .width('100%')
    .padding({ left: 18, right: 18, top: 16, bottom: 16 })
    .backgroundColor(this.t.leafSoft)
    .borderRadius(18)
    .margin({ bottom: 16 })
  }

  @Builder
  insight(pre: string, hl: string, post: string, c: string) {
    Text() {
      Span(pre).fontColor(this.t.ink)
      if (hl.length > 0) {
        Span(hl).fontColor(c).fontWeight(FontWeight.Medium)
      }
      if (post.length > 0) {
        Span(post).fontColor(this.t.ink)
      }
    }
    .fontSize(12.5)
    .lineHeight(21)
    .width('100%')
  }

  // ====== 时间轴 ======
  @Builder
  timeline() {
    Stack({ alignContent: Alignment.TopStart }) {
      // 竖线
      Column()
        .width(2)
        .height('100%')
        .backgroundColor(this.t.leafSoft)
        .margin({ left: 6, top: 8 })

      Column() {
        ForEach(this.timelineRows(), (r: TimeLineRow, i: number) => {
          Row() {
            // 圆点
            Column()
              .width(14).height(14)
              .borderRadius(7)
              .backgroundColor('#FFFFFF')
              .border({ width: 3, color: this.t.tomato })
              .margin({ left: 0, top: 5 })

            Column() {
              Row() {
                Text(r.title)
                  .fontSize(12.5)
                  .fontWeight(FontWeight.Medium)
                  .fontColor(this.t.ink)
                  .layoutWeight(1)
                  .maxLines(1)
                  .textOverflow({ overflow: TextOverflow.Ellipsis })
                Text(r.start + ' – ' + r.end)
                  .fontSize(11)
                  .fontColor(this.t.ink3)
              }
              .width('100%')
              Text('专注 ' + r.mins + ' 分钟 · 完成')
                .fontSize(11)
                .fontColor(this.t.ink2)
                .margin({ top: 3 })
            }
            .layoutWeight(1)
            .margin({ left: 20 })
            .alignItems(HorizontalAlign.Start)
          }
          .width('100%')
          .padding({ bottom: 16 })
        }, (r: TimeLineRow, i: number) => i + '_' + r.start)
      }
      .width('100%')
    }
    .width('100%')
  }

  // ===== 数据 =====
  private minutesForRange(): number {
    const keys = this.rangeKeys();
    let total = 0;
    keys.forEach(k => { total += AppState.instance.stats[k]?.focusMinutes ?? 0; });
    return total;
  }

  private pomoForRange(): number {
    const keys = this.rangeKeys();
    let total = 0;
    keys.forEach(k => { total += AppState.instance.stats[k]?.pomodoroCount ?? 0; });
    return total;
  }

  focusHours(): string {
    const min = this.minutesForRange();
    const h = Math.floor(min / 60);
    const m = min % 60;
    if (h > 0) return h + ' 小时 ' + pad2(m) + ' 分';
    return min + ' 分';
  }

  pomoTotal(): number {
    return this.pomoForRange();
  }

  completionRate(): number {
    const done = AppState.instance.tasks.filter(t => t.status === 'done').length;
    const total = AppState.instance.tasks.length;
    if (total === 0) return 0;
    return Math.round(done / total * 100);
  }

  private rangeKeys(): string[] {
    if (this.range === 'day') {
      return [todayKey()];
    }
    if (this.range === 'week') {
      return AppState.weekDates();
    }
    const out: string[] = [];
    Object.keys(AppState.instance.stats).forEach(k => out.push(k));
    return out;
  }

  timelineRows(): TimeLineRow[] {
    const k = todayKey();
    const recs = AppState.instance.records.filter(r => {
      const d = new Date(r.startAt);
      const dk = `${d.getFullYear()}-${pad2(d.getMonth() + 1)}-${pad2(d.getDate())}`;
      return dk === k;
    }).sort((a, b) => a.startAt - b.startAt);

    if (recs.length > 0) {
      const out: TimeLineRow[] = [];
      recs.forEach(r => {
        const row: TimeLineRow = {
          start: formatHM(new Date(r.startAt)),
          end: formatHM(new Date(r.endAt)),
          title: r.taskTitle || '专注',
          mins: Math.floor(r.durationSec / 60)
        };
        out.push(row);
      });
      return out;
    }

    // 演示时间轴
    return [
      { start: '08:30', end: '08:55', title: '晨间阅读《心流》', mins: 25 },
      { start: '10:00', end: '10:50', title: '写本周工作周报', mins: 50 },
      { start: '14:30', end: '14:55', title: '背 30 个英语单词', mins: 25 },
      { start: '16:00', end: '16:25', title: '读《认知觉醒》第三章', mins: 25 }
    ];
  }
}
