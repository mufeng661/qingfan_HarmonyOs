import { promptAction } from '@kit.ArkUI';
import { AppState } from '../model/AppState';
import { themeOf, ThemeDef, FONT_DISPLAY, FocusRecord } from '../model/Types';
import { pad2, formatHM } from '../model/Store';
import { TabBar } from '../components/TabBar';

type RangeKey = 'day' | 'week' | 'month';

interface TimeLineRow {
  date: string;
  start: string;
  end: string;
  title: string;
  mins: number;
}

@Entry
@Component
struct Stats {
  @State range: RangeKey = 'day';
  @State refreshing: boolean = false;
  @State rows: TimeLineRow[] = [];
  private t: ThemeDef = themeOf(AppState.instance.themeKey);

  aboutToAppear() {
    this.refresh();
  }

  onPageShow() {
    this.refresh();
  }

  onRefresh() {
    this.refreshing = true;
    this.refresh();
    setTimeout(() => {
      this.refreshing = false;
      promptAction.showToast({ message: '已刷新', duration: 1200 });
    }, 600);
  }

  refresh() {
    this.rows = this.timelineRows();
  }

  setRange(k: RangeKey) {
    this.range = k;
    this.refresh();
  }

  rangeTitle(): string {
    if (this.range === 'day') return '今日完成时间轴';
    if (this.range === 'week') return '本周完成时间轴';
    return '本月完成时间轴';
  }

  emptyHint(): string {
    if (this.range === 'day') return '今天还没有完成记录';
    if (this.range === 'week') return '本周还没有完成记录';
    return '本月还没有完成记录';
  }

  build() {
    Column() {
      // 顶栏
      Row() {
        Text('时间轴')
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

      Refresh({ refreshing: $$this.refreshing }) {
        Scroll() {
          Column() {
            Text(this.rangeTitle())
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
        .scrollBar(BarState.Off)
        .edgeEffect(EdgeEffect.Spring)
      }
      .layoutWeight(1)
      .onRefreshing(() => { this.onRefresh(); })

      TabBar({ active: 'timeline' })
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
      .onClick(() => { this.setRange(key); })
  }

  // ====== 时间轴 ======
  @Builder
  timeline() {
    if (this.rows.length === 0) {
      Column() {
        Text('🕒').fontSize(30)
        Text(this.emptyHint())
          .fontSize(12.5).fontColor(this.t.ink2).margin({ top: 8 })
        Text('完成一个番茄后，这里会显示时间轴')
          .fontSize(11).fontColor(this.t.ink3).margin({ top: 4 })
      }
      .width('100%')
      .padding({ top: 26, bottom: 26 })
      .alignItems(HorizontalAlign.Center)
    } else {
      Stack({ alignContent: Alignment.TopStart }) {
        // 竖线
        Column()
          .width(2)
          .height('100%')
          .backgroundColor(this.t.leafSoft)
          .margin({ left: 6, top: 8 })

        Column() {
          ForEach(this.rows, (r: TimeLineRow, i: number) => {
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
                  Text((this.range === 'day' ? '' : r.date + ' ') + r.start + ' – ' + r.end)
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
          }, (r: TimeLineRow, i: number) => i + '_' + r.date + '_' + r.start)
        }
        .width('100%')
      }
      .width('100%')
    }
  }

  // ===== 数据 =====
  inRange(ts: number): boolean {
    const d = new Date(ts);
    const now = new Date();
    if (this.range === 'day') {
      return d.getFullYear() === now.getFullYear()
        && d.getMonth() === now.getMonth()
        && d.getDate() === now.getDate();
    }
    if (this.range === 'week') {
      const dow = (now.getDay() + 6) % 7;
      const monday = new Date(now.getFullYear(), now.getMonth(), now.getDate() - dow, 0, 0, 0, 0);
      const next = new Date(monday.getFullYear(), monday.getMonth(), monday.getDate() + 7, 0, 0, 0, 0);
      return ts >= monday.getTime() && ts < next.getTime();
    }
    return d.getFullYear() === now.getFullYear() && d.getMonth() === now.getMonth();
  }

  timelineRows(): TimeLineRow[] {
    const recs = AppState.instance.records
      .filter((r: FocusRecord) => this.inRange(r.startAt))
      .sort((a: FocusRecord, b: FocusRecord) => a.startAt - b.startAt);
    const out: TimeLineRow[] = [];
    recs.forEach((r: FocusRecord) => {
      const sd = new Date(r.startAt);
      out.push({
        date: pad2(sd.getMonth() + 1) + '-' + pad2(sd.getDate()),
        start: formatHM(sd),
        end: formatHM(new Date(r.endAt)),
        title: r.taskTitle || '专注',
        mins: Math.floor(r.durationSec / 60)
      });
    });
    return out;
  }
}
