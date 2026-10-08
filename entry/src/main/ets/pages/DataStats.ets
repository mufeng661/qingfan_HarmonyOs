import { promptAction } from '@kit.ArkUI';
import { AppState } from '../model/AppState';
import { themeOf, ThemeDef, FONT_DISPLAY, FocusRecord } from '../model/Types';
import { todayKey, pad2 } from '../model/Store';
import { TabBar } from '../components/TabBar';
import { CloudAiService } from '../service/CloudAiService';

type PieRange = 'day' | 'week' | 'month';

interface TaskSlice {
  name: string;
  minutes: number;
}

interface BarItem {
  name: string;
  count: number;
}

interface HeatCell {
  day: number;
  minutes: number;
}

@Entry
@Component
struct DataStats {
  @State pieRange: PieRange = 'week';
  @State monthOffset: number = 0;
  @State showHeat: boolean = false;
  @State refreshing: boolean = false;
  @State aiText: string = '';
  @State aiLoading: boolean = false;
  @State uiTick: number = 0;
  private t: ThemeDef = themeOf(AppState.instance.themeKey);
  private pieSettings: RenderingContextSettings = new RenderingContextSettings(true);
  private pieCtx: CanvasRenderingContext2D = new CanvasRenderingContext2D(this.pieSettings);
  private chartSettings: RenderingContextSettings = new RenderingContextSettings(true);
  private chartCtx: CanvasRenderingContext2D = new CanvasRenderingContext2D(this.chartSettings);

  aboutToAppear() {
    this.loadAi();
  }

  onPageShow() {
    AppState.syncFromCloud().then(() => { this.redraw(); });
  }

  redraw() {
    this.drawPie();
    this.drawMonthChart();
  }

  async loadAi(): Promise<void> {
    if (!AppState.isLoggedIn() || this.aiLoading) return;
    this.aiLoading = true;
    try {
      this.aiText = await CloudAiService.insight(AppState.userKey(), '');
    } catch (e) {
      this.aiText = '';
    } finally {
      this.aiLoading = false;
    }
  }

  onRefresh() {
    this.refreshing = true;
    this.uiTick += 1;
    this.redraw();
    setTimeout(() => {
      this.refreshing = false;
      promptAction.showToast({ message: '已刷新', duration: 1200 });
    }, 600);
  }

  setPieRange(k: PieRange) {
    this.pieRange = k;
    this.drawPie();
  }

  prevMonth() {
    this.monthOffset -= 1;
    this.drawMonthChart();
  }

  nextMonth() {
    if (this.monthOffset >= 0) return;
    this.monthOffset += 1;
    this.drawMonthChart();
  }

  build() {
    Stack() {
      Column() {
        Row() {
          Text('数据')
            .fontFamily(FONT_DISPLAY)
            .fontSize(24)
            .fontColor(this.t.ink)
            .layoutWeight(1)
        }
        .width('100%')
        .padding({ left: 22, right: 22, top: 20, bottom: 14 })

        Refresh({ refreshing: $$this.refreshing }) {
          Scroll() {
            Column() {
              this.totalCard()
              this.todayCard()
              this.pieCard()
              this.monthCard()
              this.interruptCard()
              this.aiCard()
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

        TabBar({ active: 'data' })
      }
      .width('100%')
      .height('100%')
      .backgroundColor(this.t.bg)

      if (this.showHeat) {
        this.heatModal()
      }
    }
    .width('100%')
    .height('100%')
  }

  // ====== 累计专注 ======
  @Builder
  totalCard() {
    Column() {
      Text('累计专注')
        .fontFamily(FONT_DISPLAY).fontSize(14.5).fontColor(this.t.ink)
        .width('100%').margin({ bottom: 12 })
      Row() {
        this.statBlock('专注次数', this.totalSessions() + ' 次', this.t.tomato)
        this.statBlock('累计时长', this.hoursText(this.totalMinutes()), this.t.leafDeep)
        this.statBlock('日均时长', this.avgDailyMinutes() + ' 分', this.t.gold)
      }
      .width('100%')
    }
    .width('100%')
    .padding(18)
    .backgroundColor(this.t.surface)
    .borderRadius(18)
    .border({ width: 1, color: this.t.line })
    .margin({ bottom: 12 })
  }

  // ====== 当日专注 ======
  @Builder
  todayCard() {
    Column() {
      Row() {
        Text('当日专注')
          .fontFamily(FONT_DISPLAY).fontSize(14.5).fontColor(this.t.ink)
          .layoutWeight(1)
        Text(this.todayLabel())
          .fontSize(11.5).fontColor(this.t.ink3)
      }
      .width('100%').margin({ bottom: 12 })
      Row() {
        this.statBlock('专注次数', this.todaySessions() + ' 次', this.t.tomato)
        this.statBlock('专注时长', this.todayMinutes() + ' 分', this.t.leafDeep)
      }
      .width('100%')
    }
    .width('100%')
    .padding(18)
    .backgroundColor(this.t.surface)
    .borderRadius(18)
    .border({ width: 1, color: this.t.line })
    .margin({ bottom: 12 })
  }

  @Builder
  statBlock(label: string, value: string, c: string) {
    Column() {
      Text(value)
        .fontSize(18).fontWeight(FontWeight.Bold).fontColor(c)
      Text(label)
        .fontSize(11).fontColor(this.t.ink3).margin({ top: 4 })
    }
    .layoutWeight(1)
    .alignItems(HorizontalAlign.Center)
  }

  // ====== 专注时长分布（饼图 · 按任务） ======
  @Builder
  pieCard() {
    Column() {
      Row() {
        Text('专注时长分布')
          .fontFamily(FONT_DISPLAY).fontSize(14.5).fontColor(this.t.ink)
          .layoutWeight(1)
        Row({ space: 6 }) {
          this.rangePill('日', 'day')
          this.rangePill('周', 'week')
          this.rangePill('月', 'month')
        }
      }
      .width('100%')

      if (this.taskSlices().length === 0) {
        Text('该范围暂无专注记录')
          .fontSize(12).fontColor(this.t.ink3)
          .width('100%').padding({ top: 20, bottom: 20 })
      } else {
        Row() {
          Canvas(this.pieCtx)
            .width(132)
            .height(132)
            .onReady(() => { this.drawPie(); })
          Column() {
            ForEach(this.taskSlices(), (s: TaskSlice, i: number) => {
              Row({ space: 6 }) {
                Column()
                  .width(10).height(10).borderRadius(3)
                  .backgroundColor(this.piePalette()[i % this.piePalette().length])
                Text(s.name)
                  .fontSize(11.5).fontColor(this.t.ink)
                  .layoutWeight(1).maxLines(1)
                  .textOverflow({ overflow: TextOverflow.Ellipsis })
                Text(this.percentText(s.minutes))
                  .fontSize(11).fontColor(this.t.ink3)
              }
              .width('100%')
              .margin({ bottom: 7 })
            }, (s: TaskSlice) => s.name)
          }
          .layoutWeight(1)
          .margin({ left: 14 })
          .alignItems(HorizontalAlign.Start)
        }
        .width('100%')
        .margin({ top: 12 })
      }
    }
    .width('100%')
    .padding(18)
    .backgroundColor(this.t.surface)
    .borderRadius(18)
    .border({ width: 1, color: this.t.line })
    .margin({ bottom: 12 })
  }

  @Builder
  rangePill(label: string, key: PieRange) {
    Text(label)
      .fontSize(12)
      .fontColor(this.pieRange === key ? '#FFFFFF' : this.t.ink2)
      .padding({ left: 11, right: 11, top: 5, bottom: 5 })
      .borderRadius(99)
      .backgroundColor(this.pieRange === key ? this.t.leaf : Color.Transparent)
      .border(this.pieRange === key ? { width: 1, color: 'transparent' } : { width: 1, color: this.t.line })
      .onClick(() => { this.setPieRange(key); })
  }

  // ====== 月度专注统计（年月切换 + 折线/面积图 + 热力图弹窗） ======
  @Builder
  monthCard() {
    Column() {
      Row() {
        Text('月度专注统计')
          .fontFamily(FONT_DISPLAY).fontSize(15).fontWeight(FontWeight.Medium).fontColor(this.t.tomato)
        Text(this.monthTitle())
          .fontSize(14).fontWeight(FontWeight.Medium).fontColor(this.t.tomato)
          .margin({ left: 8 })
        Blank()
        Text('🗓')
          .fontSize(17)
          .fontColor(this.showHeat ? this.t.tomato : this.t.ink3)
          .padding({ left: 8, right: 8 })
          .onClick(() => { this.showHeat = true; })
        Text('‹')
          .fontSize(22).fontColor(this.t.tomato)
          .padding({ left: 6, right: 6 })
          .onClick(() => { this.prevMonth(); })
        Text('›')
          .fontSize(22)
          .fontColor(this.monthOffset >= 0 ? this.t.line : this.t.tomato)
          .padding({ left: 6, right: 6 })
          .onClick(() => { this.nextMonth(); })
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)

      Row() {
        Column() {
          ForEach(this.yMonthLabels(), (s: string, i: number) => {
            Text(s).fontSize(10).fontColor(this.t.ink3)
          }, (s: string, i: number) => i + '_' + s)
        }
        .width(40)
        .height(158)
        .padding({ top: 4, bottom: 4 })
        .justifyContent(FlexAlign.SpaceBetween)
        .alignItems(HorizontalAlign.Start)

        Scroll() {
          Column() {
            Canvas(this.chartCtx)
              .width(this.chartW())
              .height(158)
              .onReady(() => { this.drawMonthChart(); })
            Row() {
              ForEach(this.xLabels(), (s: string, i: number) => {
                Text(s).fontSize(10).fontColor(this.t.ink3)
                  .width(44).textAlign(TextAlign.Center)
              }, (s: string, i: number) => i + '_' + s)
            }
            .width(this.chartW())
            .margin({ top: 4 })
          }
        }
        .scrollable(ScrollDirection.Horizontal)
        .scrollBar(BarState.Off)
        .edgeEffect(EdgeEffect.Spring)
        .layoutWeight(1)
        .margin({ left: 4 })
      }
      .width('100%')
      .margin({ top: 12 })
    }
    .width('100%')
    .padding(18)
    .backgroundColor(this.t.surface)
    .borderRadius(18)
    .border({ width: 1, color: this.t.line })
    .margin({ bottom: 12 })
  }

  // ====== 热力图弹窗（居中） ======
  @Builder
  heatModal() {
    Stack() {
      Column()
        .width('100%').height('100%')
        .backgroundColor('rgba(20,26,16,0.42)')
        .onClick(() => { this.showHeat = false; })

      Column() {
        Row() {
          Text('‹')
            .fontSize(26).fontColor(this.t.tomato)
            .padding({ left: 8, right: 8 })
            .onClick(() => { this.prevMonth(); })
          Text('热力图')
            .fontFamily(FONT_DISPLAY).fontSize(18).fontWeight(FontWeight.Bold).fontColor(this.t.ink)
            .layoutWeight(1).textAlign(TextAlign.Center)
          Text('›')
            .fontSize(26)
            .fontColor(this.monthOffset >= 0 ? this.t.line : this.t.tomato)
            .padding({ left: 8, right: 8 })
            .onClick(() => { this.nextMonth(); })
        }
        .width('100%')
        .alignItems(VerticalAlign.Center)

        Text(this.monthTitle())
          .fontSize(13).fontColor(this.t.ink3)
          .width('100%').textAlign(TextAlign.Center)
          .margin({ top: 6, bottom: 12 })

        Row() {
          ForEach(this.weekdayLabels(), (s: string) => {
            Text(s)
              .fontSize(10).fontColor(this.t.ink3)
              .layoutWeight(1).textAlign(TextAlign.Center)
          }, (s: string) => s)
        }
        .width('100%')
        .margin({ bottom: 6 })

        ForEach(this.heatWeeks(), (week: HeatCell[], wi: number) => {
          Row() {
            ForEach(week, (c: HeatCell, ci: number) => {
              Column() {
                if (c.day === 0) {
                  Column().width(34).height(34)
                } else {
                  Stack() {
                    Column()
                      .width(34).height(34).borderRadius(9)
                      .backgroundColor(c.minutes > 0 ? this.t.tomato : this.t.surface2)
                      .opacity(this.heatOpacity(c.minutes))
                    if (c.minutes > 0) {
                      Text(this.durText(c.minutes)).fontSize(9).fontColor('#FFFFFF')
                    }
                  }
                  .width(34).height(34)
                }
                Text(c.day > 0 ? (c.day + '') : '')
                  .fontSize(10).fontColor(this.t.ink3)
                  .margin({ top: 3 })
              }
              .layoutWeight(1)
            }, (c: HeatCell, ci: number) => wi + '_' + ci + '_' + c.day + '_' + c.minutes)
          }
          .width('100%')
        }, (week: HeatCell[], wi: number) => wi + '_' + this.monthOffset)

        Row({ space: 4 }) {
          Text('少').fontSize(10).fontColor(this.t.ink3)
          Column().width(10).height(10).borderRadius(2).backgroundColor(this.t.tomato).opacity(0.25)
          Column().width(10).height(10).borderRadius(2).backgroundColor(this.t.tomato).opacity(0.6)
          Column().width(10).height(10).borderRadius(2).backgroundColor(this.t.tomato)
          Text('多').fontSize(10).fontColor(this.t.ink3)
        }
        .margin({ top: 14 })
      }
      .width('86%')
      .padding(20)
      .backgroundColor(this.t.surface)
      .borderRadius(20)
      .alignItems(HorizontalAlign.Center)
    }
    .width('100%')
    .height('100%')
  }

  // ====== 打断原因分布 ======
  @Builder
  interruptCard() {
    Column() {
      Text(this.monthTitle() + ' 打断原因分布')
        .fontFamily(FONT_DISPLAY).fontSize(14.5).fontColor(this.t.ink)
        .width('100%').margin({ bottom: 12 })
      if (this.monthInterrupts().length === 0) {
        Text('该月暂无打断记录 🎉')
          .fontSize(12).fontColor(this.t.ink3)
          .width('100%').padding({ top: 6, bottom: 6 })
      } else {
        ForEach(this.monthInterrupts(), (b: BarItem) => {
          Row({ space: 8 }) {
            Text(b.name)
              .fontSize(11.5).fontColor(this.t.ink)
              .width(72).maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
            Stack({ alignContent: Alignment.Start }) {
              Column()
                .width('100%').height(14).borderRadius(7)
                .backgroundColor(this.t.surface2)
              Column()
                .width(this.barPct(b.count)).height(14).borderRadius(7)
                .backgroundColor(this.t.tomato)
            }
            .layoutWeight(1).height(14)
            Text(b.count + '')
              .fontSize(11).fontColor(this.t.ink3)
              .width(22).textAlign(TextAlign.End)
          }
          .width('100%')
          .margin({ bottom: 9 })
        }, (b: BarItem) => b.name)
      }
    }
    .width('100%')
    .padding(18)
    .backgroundColor(this.t.surface)
    .borderRadius(18)
    .border({ width: 1, color: this.t.line })
    .margin({ bottom: 12 })
  }

  // ====== AI 洞察 ======
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
        Text('专注洞察')
          .fontFamily(FONT_DISPLAY).fontSize(14.5).fontColor(this.t.ink)
      }
      .width('100%').margin({ bottom: 10 })

      if (this.aiText.length > 0) {
        Text(this.aiText)
          .fontSize(12.5).lineHeight(21).fontColor(this.t.ink).width('100%')
      } else if (this.aiLoading) {
        Text('AI 正在分析你的专注数据…')
          .fontSize(12.5).lineHeight(21).fontColor(this.t.ink3).width('100%')
      } else if (!AppState.isLoggedIn()) {
        Text('登录后解锁 AI 专注洞察报告')
          .fontSize(12.5).lineHeight(21).fontColor(this.t.ink2).width('100%')
      } else {
        Text('专注时开启免打扰、每 4 个番茄安排 15 分钟长休息，能有效减少打断。')
          .fontSize(12.5).lineHeight(21).fontColor(this.t.ink2).width('100%')
      }
    }
    .width('100%')
    .padding({ left: 18, right: 18, top: 16, bottom: 16 })
    .backgroundColor(this.t.leafSoft)
    .borderRadius(18)
    .margin({ bottom: 16 })
  }

  // ===== 通用统计 =====
  hoursText(min: number): string {
    const h = Math.floor(min / 60);
    const m = min % 60;
    if (h > 0) return h + 'h' + pad2(m) + 'm';
    return m + ' 分';
  }

  totalSessions(): number {
    let n = 0;
    const m = AppState.instance.stats;
    const keys: string[] = Object.keys(m);
    for (let i = 0; i < keys.length; i++) n += m[keys[i]].pomodoroCount || 0;
    return n;
  }

  totalMinutes(): number {
    let n = 0;
    const m = AppState.instance.stats;
    const keys: string[] = Object.keys(m);
    for (let i = 0; i < keys.length; i++) n += m[keys[i]].focusMinutes || 0;
    return n;
  }

  activeDays(): number {
    let n = 0;
    const m = AppState.instance.stats;
    const keys: string[] = Object.keys(m);
    for (let i = 0; i < keys.length; i++) {
      if ((m[keys[i]].focusMinutes || 0) > 0) n += 1;
    }
    return n;
  }

  avgDailyMinutes(): number {
    const d = this.activeDays();
    return d > 0 ? Math.round(this.totalMinutes() / d) : 0;
  }

  todayLabel(): string {
    const d = new Date();
    return d.getFullYear() + '-' + pad2(d.getMonth() + 1) + '-' + pad2(d.getDate());
  }

  todaySessions(): number {
    const st = AppState.instance.stats[todayKey()];
    return st ? (st.pomodoroCount || 0) : 0;
  }

  todayMinutes(): number {
    const st = AppState.instance.stats[todayKey()];
    return st ? (st.focusMinutes || 0) : 0;
  }

  // ===== 饼图数据（按任务） =====
  inRange(ts: number): boolean {
    const d = new Date(ts);
    const now = new Date();
    if (this.pieRange === 'day') {
      return d.getFullYear() === now.getFullYear()
        && d.getMonth() === now.getMonth()
        && d.getDate() === now.getDate();
    }
    if (this.pieRange === 'week') {
      const dow = (now.getDay() + 6) % 7;
      const monday = new Date(now.getFullYear(), now.getMonth(), now.getDate() - dow, 0, 0, 0, 0);
      const next = new Date(monday.getFullYear(), monday.getMonth(), monday.getDate() + 7, 0, 0, 0, 0);
      return ts >= monday.getTime() && ts < next.getTime();
    }
    return d.getFullYear() === now.getFullYear() && d.getMonth() === now.getMonth();
  }

  taskSlices(): TaskSlice[] {
    const agg: Record<string, number> = {};
    AppState.instance.records.forEach((r: FocusRecord) => {
      if (!this.inRange(r.startAt)) return;
      const name = r.taskTitle && r.taskTitle.trim().length > 0 ? r.taskTitle.trim() : '其他';
      agg[name] = (agg[name] || 0) + Math.floor(r.durationSec / 60);
    });
    const list: TaskSlice[] = [];
    const names: string[] = Object.keys(agg);
    for (let i = 0; i < names.length; i++) {
      if (agg[names[i]] > 0) list.push({ name: names[i], minutes: agg[names[i]] });
    }
    list.sort((a: TaskSlice, b: TaskSlice) => b.minutes - a.minutes);
    if (list.length <= 6) return list;
    const top = list.slice(0, 5);
    let rest = 0;
    for (let i = 5; i < list.length; i++) rest += list[i].minutes;
    if (rest > 0) top.push({ name: '其他', minutes: rest });
    return top;
  }

  sliceTotal(): number {
    let n = 0;
    this.taskSlices().forEach((s: TaskSlice) => { n += s.minutes; });
    return n;
  }

  percentText(minutes: number): string {
    const total = this.sliceTotal();
    if (total <= 0) return '0%';
    return Math.round(minutes / total * 100) + '%';
  }

  piePalette(): string[] {
    return [this.t.leaf, this.t.tomato, this.t.gold, this.t.leafDeep, this.t.ink2, this.t.tomatoSoft, this.t.goldSoft];
  }

  // ===== 月度数据 =====
  monthDate(offset: number): Date {
    const now = new Date();
    return new Date(now.getFullYear(), now.getMonth() + offset, 1);
  }

  monthTitle(): string {
    const d = this.monthDate(this.monthOffset);
    return d.getFullYear() + '年' + (d.getMonth() + 1) + '月';
  }

  daysInMonth(offset: number): number {
    const d = this.monthDate(offset);
    return new Date(d.getFullYear(), d.getMonth() + 1, 0).getDate();
  }

  dayMinutes(offset: number, day: number): number {
    const d = this.monthDate(offset);
    const k = d.getFullYear() + '-' + pad2(d.getMonth() + 1) + '-' + pad2(day);
    const st = AppState.instance.stats[k];
    return st ? (st.focusMinutes || 0) : 0;
  }

  monthMax(): number {
    const n = this.daysInMonth(this.monthOffset);
    let max = 0;
    for (let d = 1; d <= n; d++) {
      const v = this.dayMinutes(this.monthOffset, d);
      if (v > max) max = v;
    }
    return max;
  }

  monthStep(): number {
    const max = this.monthMax();
    const base = max > 0 ? max : 25;
    const raw = base / 5;
    const nice: number[] = [1, 2, 5, 10, 15, 20, 25, 30, 50, 60, 100, 120, 180, 240, 300, 600];
    for (let i = 0; i < nice.length; i++) {
      if (raw <= nice[i]) return nice[i];
    }
    return Math.ceil(raw / 60) * 60;
  }

  monthNiceMax(): number {
    const max = this.monthMax();
    const base = max > 0 ? max : 25;
    const step = this.monthStep();
    let nice = Math.max(step, Math.ceil(base / step) * step);
    while (nice / step < 4) {
      nice += step;
    }
    return nice;
  }

  yMonthLabels(): string[] {
    const step = this.monthStep();
    const niceMax = this.monthNiceMax();
    const lines = Math.round(niceMax / step);
    const out: string[] = [];
    for (let r = 0; r <= lines; r++) {
      out.push((niceMax - r * step) + '分');
    }
    return out;
  }

  xLabels(): string[] {
    const n = this.daysInMonth(this.monthOffset);
    const mo = this.monthDate(this.monthOffset).getMonth() + 1;
    const out: string[] = [];
    for (let day = 1; day <= n; day++) {
      out.push(mo + '-' + day);
    }
    return out;
  }

  chartW(): number {
    return this.daysInMonth(this.monthOffset) * 44;
  }

  heatCells(): HeatCell[] {
    const d = this.monthDate(this.monthOffset);
    const n = this.daysInMonth(this.monthOffset);
    const first = new Date(d.getFullYear(), d.getMonth(), 1);
    const lead = (first.getDay() + 6) % 7;
    const cells: HeatCell[] = [];
    for (let i = 0; i < lead; i++) cells.push({ day: 0, minutes: 0 });
    for (let day = 1; day <= n; day++) cells.push({ day, minutes: this.dayMinutes(this.monthOffset, day) });
    return cells;
  }

  heatWeeks(): HeatCell[][] {
    const cells = this.heatCells();
    const weeks: HeatCell[][] = [];
    for (let i = 0; i < cells.length; i += 7) {
      const w = cells.slice(i, i + 7);
      while (w.length < 7) {
        w.push({ day: 0, minutes: 0 });
      }
      weeks.push(w);
    }
    return weeks;
  }

  weekdayLabels(): string[] {
    return ['一', '二', '三', '四', '五', '六', '日'];
  }

  heatOpacity(minutes: number): number {
    if (minutes <= 0) return 1;
    if (minutes < 60) return 0.25;
    if (minutes < 120) return 0.6;
    return 1.0;
  }

  durText(minutes: number): string {
    if (minutes < 60) return '<1h';
    return (Math.round(minutes / 6) / 10) + 'h';
  }

  monthInterrupts(): BarItem[] {
    const d = this.monthDate(this.monthOffset);
    const prefix = d.getFullYear() + '-' + pad2(d.getMonth() + 1);
    const agg: Record<string, number> = {};
    const m = AppState.instance.stats;
    const keys: string[] = Object.keys(m);
    for (let i = 0; i < keys.length; i++) {
      if (keys[i].indexOf(prefix) !== 0) continue;
      const ic: Record<string, number> = m[keys[i]].interruptCounts;
      const rk: string[] = Object.keys(ic);
      for (let j = 0; j < rk.length; j++) agg[rk[j]] = (agg[rk[j]] || 0) + ic[rk[j]];
    }
    const list: BarItem[] = [];
    const names: string[] = Object.keys(agg);
    for (let i = 0; i < names.length; i++) list.push({ name: names[i], count: agg[names[i]] });
    list.sort((a: BarItem, b: BarItem) => b.count - a.count);
    return list.slice(0, 6);
  }

  barPct(count: number): string {
    const list = this.monthInterrupts();
    let max = 1;
    for (let i = 0; i < list.length; i++) if (list[i].count > max) max = list[i].count;
    return Math.round(count / max * 100) + '%';
  }

  // ===== Canvas 绘制（只画图形，不写字） =====
  drawPie() {
    const ctx = this.pieCtx;
    const w = ctx.width;
    const h = ctx.height;
    if (w <= 0 || h <= 0) return;
    ctx.clearRect(0, 0, w, h);
    const slices = this.taskSlices();
    let total = 0;
    slices.forEach((s: TaskSlice) => { total += s.minutes; });
    if (slices.length === 0 || total <= 0) return;

    const cx = w / 2;
    const cy = h / 2;
    const r = Math.min(w, h) / 2 - 4;
    const palette = this.piePalette();
    let start = -Math.PI / 2;
    for (let i = 0; i < slices.length; i++) {
      const end = start + slices[i].minutes / total * Math.PI * 2;
      ctx.beginPath();
      ctx.moveTo(cx, cy);
      ctx.arc(cx, cy, r, start, end);
      ctx.closePath();
      ctx.fillStyle = palette[i % palette.length];
      ctx.fill();
      start = end;
    }
  }

  drawMonthChart() {
    const ctx = this.chartCtx;
    const w = ctx.width;
    const h = ctx.height;
    if (w <= 0 || h <= 0) return;
    ctx.clearRect(0, 0, w, h);
    const n = this.daysInMonth(this.monthOffset);
    if (n === 0) return;
    const step = this.monthStep();
    const niceMax = this.monthNiceMax();
    const padT = 10;
    const padB = 10;
    const ch = h - padT - padB;
    const baseY = padT + ch;
    const dx = 44;
    const padX = dx / 2;
    const x0 = padX;
    const x1 = padX + (n - 1) * dx;

    ctx.lineWidth = 1;
    const lines = Math.round(niceMax / step);
    for (let r = 0; r <= lines; r++) {
      const y = padT + ch * r / lines;
      ctx.beginPath();
      ctx.moveTo(x0, y);
      ctx.lineTo(x1, y);
      ctx.strokeStyle = this.t.line;
      ctx.stroke();
    }
    ctx.beginPath();
    ctx.moveTo(x0, baseY);
    ctx.lineTo(x1, baseY);
    ctx.strokeStyle = this.t.ink3;
    ctx.stroke();

    const xs: number[] = [];
    const ys: number[] = [];
    for (let i = 0; i < n; i++) {
      xs.push(x0 + i * dx);
      ys.push(baseY - ch * this.dayMinutes(this.monthOffset, i + 1) / niceMax);
    }

    ctx.beginPath();
    ctx.moveTo(xs[0], baseY);
    for (let i = 0; i < n; i++) ctx.lineTo(xs[i], ys[i]);
    ctx.lineTo(xs[n - 1], baseY);
    ctx.closePath();
    ctx.fillStyle = this.t.tomatoSoft;
    ctx.fill();

    ctx.beginPath();
    for (let i = 0; i < n; i++) {
      if (i === 0) ctx.moveTo(xs[i], ys[i]);
      else ctx.lineTo(xs[i], ys[i]);
    }
    ctx.strokeStyle = this.t.tomato;
    ctx.lineWidth = 2;
    ctx.stroke();

    ctx.lineWidth = 1;
    for (let i = 0; i < n; i++) {
      ctx.beginPath();
      ctx.arc(xs[i], ys[i], 2.5, 0, Math.PI * 2);
      ctx.fillStyle = this.t.tomato;
      ctx.fill();
    }
  }
}
