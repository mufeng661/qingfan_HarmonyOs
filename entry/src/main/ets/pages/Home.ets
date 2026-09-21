import { router, display } from '@kit.ArkUI';
import { promptAction } from '@kit.ArkUI';
import { AppState } from '../model/AppState';
import { themeOf, TaskItem, ThemeDef, FONT_DISPLAY } from '../model/Types';
import { Store, greet, genId, todayKey } from '../model/Store';
import { TabBar } from '../components/TabBar';

interface GuideStep {
  icon: string;
  title: string;
  desc: string;
}

interface TargetRect {
  x: number;
  y: number;
  w: number;
  h: number;
}

@Entry
@Component
struct Home {
  @State uiTick: number = 0;
  @State showAdd: boolean = false;
  @State showGoalPicker: boolean = false;
  @State newTitle: string = '';
  @State newDurationMin: number = 25;
  @State useCustomDuration: boolean = false;
  @State customDuration: string = '';
  @State dragIndex: number = 0;
  @State showGuide: boolean = false;
  @State guideStep: number = 0;
  @State bubbleH: number = 170;
  @State signedToday: boolean = false;
  @State streakDays: number = 0;
  @State showDeleteConfirm: boolean = false;
  @State pendingDeleteId: string = '';
  @State pendingDeleteTitle: string = '';
  @State tasks: TaskItem[] = [];
  private t: ThemeDef = themeOf(AppState.instance.themeKey);
  private todayFocusedMin: number = 0;
  private todayFinished: number = 0;
  private midnightTimerId: number = -1;
  private lastDayKey: string = '';
  private rectSign: TargetRect = { x: 0, y: 0, w: 0, h: 0 };
  private rectChallenge: TargetRect = { x: 0, y: 0, w: 0, h: 0 };
  private rectAi: TargetRect = { x: 0, y: 0, w: 0, h: 0 };
  private rectTodo: TargetRect = { x: 0, y: 0, w: 0, h: 0 };
  private rectTab: TargetRect = { x: 0, y: 0, w: 0, h: 0 };
  private rootX: number = 0;
  private rootY: number = 0;

  private toRect(a: Area): TargetRect {
    return {
      x: (a.globalPosition.x as number) - this.rootX,
      y: (a.globalPosition.y as number) - this.rootY,
      w: a.width as number,
      h: a.height as number
    };
  }

  aboutToAppear() {
    this.lastDayKey = todayKey();
    this.refreshTodayStats();
    this.refreshTasks();
    this.syncUserState();
    this.checkGuide();
    this.midnightTimerId = setInterval(() => {
      const k = todayKey();
      if (k !== this.lastDayKey) {
        this.lastDayKey = k;
        this.refreshTodayStats();
        this.syncUserState();
        this.uiTick += 1;
        this.toast('新的一天，记得签到');
      }
    }, 30000);
  }

  aboutToDisappear() {
    if (this.midnightTimerId !== -1) {
      clearInterval(this.midnightTimerId);
      this.midnightTimerId = -1;
    }
  }

  syncUserState() {
    const s = AppState.recomputeStreak();
    AppState.saveUser();
    this.signedToday = AppState.isSignedToday();
    this.streakDays = s;
  }

  signGain(): number {
    const s = AppState.instance.user?.streak ?? 0;
    return s >= 7 ? 15 : 10;
  }

  async checkGuide(): Promise<void> {
    const seen: boolean = await Store.getBool('qf_home_guide', false);
    if (!seen) {
      this.showGuide = true;
    }
  }

  guideSteps(): GuideStep[] {
    return [
      { icon: '🎁', title: '每日签到', desc: '点右上角「签到 +10」领取经验，连续签到奖励会递增。' },
      { icon: '🏆', title: '今日挑战', desc: '完成目标番茄数即达成挑战，额外 +50 经验；点「调整」可自定义目标。' },
      { icon: '✨', title: 'AI 助手', desc: '点这张卡片，让青番 AI 帮你排待办、找高效时段、看专注洞察。' },
      { icon: '📝', title: '今日待办', desc: '长按待办可拖动排序；点「开始」进入专注计时，完成后种下一棵树。' },
      { icon: '🧭', title: '底部导航', desc: '今日 / 自习室 / 统计 / 排行 / 我的，随时切换。' }
    ];
  }

  spot(): TargetRect {
    let r: TargetRect = this.rectSign;
    if (this.guideStep === 1) {
      r = this.rectChallenge;
    } else if (this.guideStep === 2) {
      r = this.rectAi;
    } else if (this.guideStep === 3) {
      r = this.rectTodo;
    } else if (this.guideStep >= 4) {
      r = this.rectTab;
    }
    const pad = 6;
    return { x: r.x - pad, y: r.y - pad, w: r.w + pad * 2, h: r.h + pad * 2 };
  }

  screenW(): number {
    return px2vp(display.getDefaultDisplaySync().width);
  }

  screenH(): number {
    return px2vp(display.getDefaultDisplaySync().height);
  }

  bubbleW(): number {
    return Math.min(this.screenW() * 0.84, 320);
  }

  bubbleX(): number {
    const s = this.spot();
    const cx = s.x + s.w / 2;
    let x = cx - this.bubbleW() / 2;
    const maxX = this.screenW() - this.bubbleW() - 12;
    if (x < 12) {
      x = 12;
    }
    if (x > maxX) {
      x = maxX;
    }
    return x;
  }

  bubbleBelow(): boolean {
    const s = this.spot();
    return s.y < this.screenH() * 0.55;
  }

  bubbleY(): number {
    const s = this.spot();
    if (this.bubbleBelow()) {
      return s.y + s.h + 14;
    }
    return s.y - this.bubbleH - 14;
  }

  arrowX(): number {
    const s = this.spot();
    return s.x + s.w / 2 - this.bubbleX() - 10;
  }

  arrowY(): number {
    if (this.bubbleBelow()) {
      return this.bubbleY() - 9;
    }
    return this.bubbleY() + this.bubbleH - 1;
  }

  arrowCommands(): string {
    if (this.bubbleBelow()) {
      return 'M0 10 L10 0 L20 10 Z';
    }
    return 'M0 0 L10 10 L20 0 Z';
  }

  finishGuide(): void {
    this.showGuide = false;
    this.guideStep = 0;
    Store.setBool('qf_home_guide', true);
  }

  refreshTodayStats() {
    const key = todayKey();
    const s = AppState.instance.stats[key];
    this.todayFocusedMin = s ? s.focusMinutes : 0;
    this.todayFinished = s ? s.pomodoroCount : 0;
  }

  refreshTasks() {
    this.tasks = AppState.instance.tasks.slice();
  }

  nickName(): string {
    return AppState.instance.user?.nickname ?? '同学';
  }

  dateStr(): string {
    const d = new Date();
    const w = ['日', '一', '二', '三', '四', '五', '六'][d.getDay()];
    return `${d.getMonth() + 1} 月 ${d.getDate()} 日 · 周${w}`;
  }

  toast(msg: string) {
    promptAction.showToast({ message: msg, duration: 1500 });
  }

  startSignIn() {
    if (!AppState.isLoggedIn()) {
      this.toast('登录后即可签到，请到「我的」登录');
      return;
    }
    const gain = AppState.signInToday();
    if (gain < 0) {
      this.toast('今天已经签过啦，明天再来哦');
      return;
    }
    this.syncUserState();
    this.uiTick += 1;
    this.toast(`签到成功 +${gain} 经验`);
  }

  startFocus(task: TaskItem) {
    AppState.instance.currentTaskId = task.id;
    AppState.instance.currentRoomMode = 'solo';
    router.pushUrl({ url: 'pages/Focus', params: { taskId: task.id } });
  }

  toggleTask(task: TaskItem) {
    const idx = AppState.instance.tasks.findIndex(x => x.id === task.id);
    if (idx < 0) return;
    const t = AppState.instance.tasks[idx];
    t.status = t.status === 'done' ? 'todo' : 'done';
    if (t.status === 'done') {
      const u = AppState.instance.user;
      if (u) {
        u.exp += 20;
        while (u.exp >= u.nextLevelExp) {
          u.level += 1;
          u.exp -= u.nextLevelExp;
          u.nextLevelExp = Math.floor(u.nextLevelExp * 1.5);
        }
        AppState.saveUser();
      }
      this.toast(`完成「${t.title}」 +20 经验`);
    }
    AppState.instance.tasks = [...AppState.instance.tasks];
    AppState.saveTasks();
    this.refreshTasks();
    this.uiTick += 1;
  }

  aiSortTasks() {
    const order: Record<string, number> = { 'hard': 0, 'medium': 1, 'easy': 2 };
    AppState.instance.tasks.sort((a, b) => {
      if (a.status !== b.status) return a.status === 'todo' ? -1 : 1;
      const oa = order[a.difficulty] ?? 3;
      const ob = order[b.difficulty] ?? 3;
      return oa - ob;
    });
    AppState.instance.tasks.forEach((t, i) => { t.order = i; });
    AppState.instance.tasks = [...AppState.instance.tasks];
    AppState.saveTasks();
    this.refreshTasks();
    this.uiTick += 1;
    this.toast('已按「困难 → 中等 → 简单」排序');
  }

  setChallengeGoal(g: number) {
    AppState.instance.challengeGoal = g;
    AppState.saveChallenge();
    this.uiTick += 1;
    this.toast(`今日目标已设为 ${g} 个番茄`);
  }

  durationPresets(): number[] {
    return [15, 25, 45, 60];
  }

  effectiveDuration(): number {
    if (this.useCustomDuration) {
      const n = parseInt(this.customDuration, 10);
      if (!isNaN(n) && n > 0) {
        return Math.min(n, 600);
      }
      return 25;
    }
    return this.newDurationMin;
  }

  addTask() {
    const title = this.newTitle.trim();
    if (!title) return;
    const t: TaskItem = {
      id: genId('t'),
      title,
      durationMin: this.effectiveDuration(),
      status: 'todo',
      difficulty: 'medium',
      order: AppState.instance.tasks.length,
      createdAt: Date.now(),
      bgSeed: 'sky'
    };
    AppState.instance.tasks = [...AppState.instance.tasks, t];
    AppState.saveTasks();
    this.refreshTasks();
    this.uiTick += 1;
    this.showAdd = false;
    this.newTitle = '';
    this.newDurationMin = 25;
    this.useCustomDuration = false;
    this.customDuration = '';
    this.toast('已添加待办');
  }

  build() {
    Stack() {
      Column() {
        // 头部
        Row() {
          Column() {
            Text(this.dateStr())
              .fontFamily(FONT_DISPLAY)
              .fontSize(13)
              .fontColor(this.t.ink2)
            Text(`${greet()}，${this.nickName()}`)
              .fontFamily(FONT_DISPLAY)
              .fontSize(26)
              .maxFontSize(26)
              .minFontSize(14)
              .maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
              .fontColor(this.t.ink)
              .width('100%')
              .margin({ top: 4 })
          }
          .alignItems(HorizontalAlign.Start)
          .layoutWeight(1)

          Column({ space: 3 }) {
            Text(this.signedToday ? '🎁' : '🎁')
              .fontSize(18)
              .fontColor(this.signedToday ? this.t.ink3 : this.t.tomato)
            Text(this.signedToday ? '已签到' : ('签到 +' + this.signGain()))
              .fontSize(11)
              .fontColor(this.signedToday ? this.t.ink3 : this.t.tomato)
              .fontWeight(FontWeight.Medium)
          }
          .padding({ left: 14, right: 14, top: 8, bottom: 8 })
          .borderRadius(14)
          .backgroundColor(this.signedToday ? this.t.surface : this.t.tomatoSoft)
          .border({ width: 1, color: this.signedToday ? this.t.line : '#F0C9B8' })
          .onAreaChange((o: Area, n: Area) => { this.rectSign = this.toRect(n); })
          .onClick(() => { this.startSignIn(); })
        }
        .width('100%')
        .padding({ left: 22, right: 22, top: 20, bottom: 12 })

        this.overviewCard()
        this.challengeCard()
        this.aiTipCard()
        this.todoHeader()
        this.todoList()

        Column() {
          TabBar({ active: 'home' })
        }
        .width('100%')
        .onAreaChange((o: Area, n: Area) => { this.rectTab = this.toRect(n); })
      }
      .width('100%')
      .height('100%')
      .backgroundColor(this.t.bg)
      .onAreaChange((o: Area, n: Area) => {
        this.rootX = n.globalPosition.x as number;
        this.rootY = n.globalPosition.y as number;
      })

      if (this.showAdd) {
        this.addPanel()
      }
      if (this.showGoalPicker) {
        this.goalPicker()
      }
      if (this.showDeleteConfirm) {
        this.deleteConfirmPanel()
      }
      if (this.showGuide) {
        this.guideOverlay()
      }
    }
  }

  // ====== 今日概览（三栏数据卡） ======
  @Builder
  overviewCard() {
    Row() {
      this.ovItem('专注', this.todayFocusedMin + '', '分钟', '⏱', this.t.leafDeep, true)
      this.ovItem('番茄', this.todayFinished + '', '个', '🍅', this.t.tomato, true)
      this.ovItem('连续', this.streakDays + '', '天', '🔥', this.t.tomato, false)
    }
    .width('100%')
    .padding({ top: 16, bottom: 16, left: 18, right: 18 })
    .backgroundColor(this.t.surface)
    .borderRadius(18)
    .border({ width: 1, color: this.t.line })
    .margin({ left: 22, right: 22 })
  }

  @Builder
  ovItem(k: string, v: string, u: string, icon: string, c: string, divider: boolean) {
    Column() {
      Row({ space: 5 }) {
        Text(icon).fontSize(16).fontColor(c)
        Text(k).fontSize(11).fontColor(this.t.ink2)
      }
      Text() {
        Span(v)
          .fontFamily(FONT_DISPLAY)
          .fontSize(22)
          .fontColor(this.t.ink)
        Span(' ' + u)
          .fontSize(12)
          .fontColor(this.t.ink3)
      }
      .margin({ top: 5 })
    }
    .layoutWeight(1)
    .alignItems(HorizontalAlign.Center)
    .border(divider ? { width: { right: 1 }, color: this.t.line } : { width: 0 })
  }

  // ====== 今日挑战 ======
  @Builder
  challengeCard() {
    Row() {
      Column() {
        Text('🏆').fontSize(24).fontColor(this.t.gold)
      }
      .width(42)
      .height(42)
      .borderRadius(12)
      .backgroundColor(this.t.goldSoft)
      .justifyContent(FlexAlign.Center)

      Column() {
        Row({ space: 6 }) {
          Text(`今日挑战 · 专注 ${AppState.instance.challengeGoal} 个番茄`)
            .fontSize(13.5)
            .fontWeight(FontWeight.Medium)
            .fontColor(this.t.ink)
          if (this.todayFinished >= AppState.instance.challengeGoal) {
            Text('✓').fontSize(13).fontColor(this.t.gold).fontWeight(FontWeight.Bold)
          }
        }
        Text(this.todayFinished >= AppState.instance.challengeGoal
          ? '挑战完成！+50 经验已到账'
          : `已完成 ${this.todayFinished} / ${AppState.instance.challengeGoal}，达成奖励 +50 经验`)
          .fontSize(11)
          .fontColor(this.todayFinished >= AppState.instance.challengeGoal ? this.t.gold : this.t.ink3)
          .margin({ top: 3 })
        Stack() {
          Row().width('100%').height(6).borderRadius(99).backgroundColor(this.t.surface2)
          Row().width(this.progressWidth()).height(6).borderRadius(99)
            .backgroundColor(this.todayFinished >= AppState.instance.challengeGoal ? this.t.gold : this.t.leaf)
        }
        .width('100%')
        .margin({ top: 8 })
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)
      .margin({ left: 12 })

      Row({ space: 4 }) {
        Text('调整').fontSize(11).fontColor(this.t.ink2).fontWeight(FontWeight.Medium)
        Text('›').fontSize(12).fontColor(this.t.ink3)
      }
      .padding({ left: 10, right: 10, top: 6, bottom: 6 })
      .borderRadius(10)
      .backgroundColor(this.t.surface2)
      .border({ width: 1, color: this.t.line })
      .onClick(() => { this.showGoalPicker = true; })
    }
    .width('100%')
    .padding({ left: 16, right: 16, top: 14, bottom: 14 })
    .backgroundColor(this.t.surface)
    .borderRadius(16)
    .border({ width: 1, color: this.t.line })
    .margin({ left: 22, right: 22, top: 12 })
    .onAreaChange((o: Area, n: Area) => { this.rectChallenge = this.toRect(n); })
  }

  progressWidth(): string {
    const g = AppState.instance.challengeGoal;
    if (g <= 0) return '0%';
    return (Math.min(100, Math.round(this.todayFinished / g * 100))) + '%';
  }

  // ====== AI 建议卡 ======
  @Builder
  aiTipCard() {
    Row() {
      Column() {
        Text('AI').fontFamily(FONT_DISPLAY).fontSize(13).fontColor('#FFFFFF')
      }
      .width(24)
      .height(24)
      .borderRadius(8)
      .backgroundColor(this.t.leaf)
      .justifyContent(FlexAlign.Center)

      if (AppState.isLoggedIn()) {
        Text() {
          Span('你下午 ')
          Span('14:00–16:00').fontColor(this.t.leafDeep).fontWeight(FontWeight.Medium)
          Span(' 专注效率最高，建议把「写周报」排在这个时段，预计 2 个番茄完成。')
        }
        .fontSize(12.5)
        .fontColor(this.t.ink)
        .lineHeight(20)
        .layoutWeight(1)
        .margin({ left: 10 })
      } else {
        Text('登录后解锁 AI 助手')
          .fontSize(12.5)
          .fontColor(this.t.ink2)
          .lineHeight(20)
          .layoutWeight(1)
          .margin({ left: 10 })
      }

      Text(AppState.isLoggedIn() ? '›' : '🔒').fontSize(16).fontColor(this.t.ink3)
    }
    .width('100%')
    .padding({ left: 16, right: 16, top: 13, bottom: 13 })
    .backgroundColor(this.t.leafSoft)
    .borderRadius(16)
    .margin({ left: 22, right: 22, top: 12 })
    .onAreaChange((o: Area, n: Area) => { this.rectAi = this.toRect(n); })
    .onClick(() => { this.openAi(); })
  }

  openAi() {
    if (!AppState.isLoggedIn()) {
      this.toast('登录后即可使用 AI 助手，请到「我的」登录');
      return;
    }
    router.pushUrl({ url: 'pages/AIChat' });
  }

  // ====== 待办 ======
  @Builder
  todoHeader() {
    Row() {
      Text('今日待办')
        .fontFamily(FONT_DISPLAY)
        .fontSize(17)
        .fontColor(this.t.ink)
        .layoutWeight(1)
      Row({ space: 4 }) {
        Text('＋').fontSize(16).fontColor(this.t.leafDeep)
        Text('添加').fontSize(13).fontColor(this.t.leafDeep).fontWeight(FontWeight.Medium)
      }
      .onClick(() => { this.showAdd = true; })
    }
    .width('100%')
    .padding({ left: 22, right: 22, top: 18, bottom: 10 })
    .onAreaChange((o: Area, n: Area) => { this.rectTodo = this.toRect(n); })
  }

  @Builder
  todoList() {
    List({ space: 10 }) {
      if (this.tasks.length === 0) {
        ListItem() {
          Column() {
            Text('📝').fontSize(48)
            Text('今天还没有待办').fontSize(14).fontColor(this.t.ink2).margin({ top: 12 })
          }
          .width('100%')
          .padding({ top: 60, bottom: 60 })
          .alignItems(HorizontalAlign.Center)
        }
      } else {
        ForEach(this.tasks, (t: TaskItem, index: number) => {
          ListItem() {
            this.taskCard(t)
          }
          .swipeAction({ start: { builder: () => { this.swipeDeleteBtn(t) } } })
        }, (t: TaskItem) => t.id)
      }
    }
    .layoutWeight(1)
    .width('100%')
    .padding({ left: 22, right: 22, top: 4, bottom: 8 })
    .scrollBar(BarState.Off)
    .edgeEffect(EdgeEffect.Spring)
    .onItemDragStart((event: ItemDragInfo, itemIndex: number) => {
      this.dragIndex = itemIndex;
      return this.taskDragPreview();
    })
    .onItemDrop((event: ItemDragInfo, itemIndex: number, insertIndex: number, isSuccess: boolean) => {
      if (isSuccess) {
        this.reorderTasks(itemIndex, insertIndex);
      }
    })
  }

  @Builder
  taskDragPreview() {
    Row() {
      Text('⋮⋮').fontSize(14).fontColor(this.t.ink3).margin({ right: 10 })
      Text(AppState.instance.tasks[this.dragIndex]?.title ?? '')
        .fontSize(14.5)
        .fontWeight(FontWeight.Medium)
        .fontColor(this.t.ink)
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .layoutWeight(1)
    }
    .width(240)
    .padding({ left: 16, right: 16, top: 14, bottom: 14 })
    .backgroundColor(this.t.surface)
    .borderRadius(16)
    .border({ width: 1, color: this.t.leaf })
    .shadow({ radius: 30, color: 'rgba(44,58,40,0.18)', offsetY: 14 })
  }

  reorderTasks(from: number, to: number) {
    const arr = AppState.instance.tasks;
    if (from < 0 || from >= arr.length) return;
    let target = to;
    if (target < 0) target = 0;
    if (target >= arr.length) target = arr.length - 1;
    if (target === from) return;
    const moved = arr.splice(from, 1)[0];
    arr.splice(target, 0, moved);
    arr.forEach((t, i) => { t.order = i; });
    AppState.instance.tasks = [...arr];
    AppState.saveTasks();
    this.refreshTasks();
    this.uiTick += 1;
    this.toast('已调整待办顺序');
  }

  // ====== 侧滑删除 ======
  @Builder
  swipeDeleteBtn(t: TaskItem) {
    Row() {
      Text('删除').fontSize(14).fontWeight(FontWeight.Medium).fontColor('#FFFFFF')
    }
    .width(76)
    .height('100%')
    .backgroundColor(this.t.tomato)
    .borderRadius(16)
    .justifyContent(FlexAlign.Center)
    .onClick(() => { this.askDelete(t); })
  }

  askDelete(t: TaskItem) {
    this.pendingDeleteId = t.id;
    this.pendingDeleteTitle = t.title;
    this.showDeleteConfirm = true;
  }

  confirmDelete() {
    const id = this.pendingDeleteId;
    AppState.instance.tasks = AppState.instance.tasks.filter(x => x.id !== id);
    AppState.instance.tasks.forEach((x, i) => { x.order = i; });
    AppState.saveTasks();
    this.refreshTasks();
    this.showDeleteConfirm = false;
    this.pendingDeleteId = '';
    this.pendingDeleteTitle = '';
    this.uiTick += 1;
    this.toast('已删除待办');
  }

  @Builder
  taskCard(t: TaskItem) {
    Row() {
      // 复选框
      Column() {
        if (t.status === 'done') {
          Text('✓').fontSize(15).fontColor('#FFFFFF').fontWeight(FontWeight.Bold)
        }
      }
      .width(24)
      .height(24)
      .borderRadius(8)
      .backgroundColor(t.status === 'done' ? this.t.leaf : Color.Transparent)
      .border({ width: 1.5, color: t.status === 'done' ? this.t.leaf : this.t.ink3 })
      .justifyContent(FlexAlign.Center)
      .onClick(() => { this.toggleTask(t); })

      Column() {
        Row({ space: 6 }) {
          Text(t.title)
            .fontSize(14.5)
            .fontWeight(FontWeight.Medium)
            .fontColor(this.t.ink)
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .decoration(t.status === 'done' ? { type: TextDecorationType.LineThrough } : { type: TextDecorationType.None })
          this.diffTag(t.difficulty)
        }
        Row({ space: 4 }) {
          Text('🍅').fontSize(12)
          Text(`${Math.max(1, Math.round(t.durationMin / 25))} 个番茄 · ${t.durationMin} 分钟`)
            .fontSize(11.5)
            .fontColor(this.t.ink3)
        }
        .margin({ top: 3 })
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)
      .margin({ left: 12 })

      if (t.status === 'todo') {
        Row({ space: 5 }) {
          Text('▶').fontSize(10).fontColor('#FFFFFF')
          Text('开始').fontSize(12.5).fontColor('#FFFFFF').fontWeight(FontWeight.Medium)
        }
        .padding({ left: 12, right: 12, top: 7, bottom: 7 })
        .borderRadius(99)
        .backgroundColor(this.t.leaf)
        .onClick(() => { this.startFocus(t); })
      }
    }
    .width('100%')
    .padding({ left: 16, right: 16, top: 14, bottom: 14 })
    .backgroundColor(t.status === 'done' ? this.t.surface2 : this.t.surface)
    .borderRadius(16)
    .border({ width: 1, color: this.t.line })
    .opacity(t.status === 'done' ? 0.6 : 1)
    .alignItems(VerticalAlign.Center)
  }

  @Builder
  diffTag(d: string) {
    if (d === 'easy') {
      Text('简单').fontSize(10).fontColor(this.t.leaf).fontWeight(FontWeight.Medium)
        .padding({ left: 7, right: 7, top: 2, bottom: 2 }).borderRadius(99).backgroundColor(this.t.leafSoft)
    } else if (d === 'hard') {
      Text('困难').fontSize(10).fontColor(this.t.tomato).fontWeight(FontWeight.Medium)
        .padding({ left: 7, right: 7, top: 2, bottom: 2 }).borderRadius(99).backgroundColor(this.t.tomatoSoft)
    } else {
      Text('中等').fontSize(10).fontColor(this.t.gold).fontWeight(FontWeight.Medium)
        .padding({ left: 7, right: 7, top: 2, bottom: 2 }).borderRadius(99).backgroundColor(this.t.goldSoft)
    }
  }

  // ====== 添加待办弹窗 ======
  @Builder
  addPanel() {
    Stack() {
      Column()
        .width('100%').height('100%')
        .backgroundColor('rgba(30,40,26,0.42)')
        .onClick(() => { this.showAdd = false; })
      Column() {
        Text('添加待办')
          .fontFamily(FONT_DISPLAY)
          .fontSize(17)
          .fontColor(this.t.ink)
          .width('100%')
          .margin({ bottom: 14 })
        TextInput({ placeholder: '想专注做什么？', text: this.newTitle })
          .fontSize(14)
          .fontColor(this.t.ink)
          .placeholderColor(this.t.ink3)
          .backgroundColor(this.t.surface2)
          .borderRadius(12)
          .height(46)
          .width('100%')
          .onChange((v: string) => { this.newTitle = v; })

        Text('专注时长')
          .fontSize(12)
          .fontColor(this.t.ink3)
          .width('100%')
          .margin({ top: 14, bottom: 6 })
        Flex({ wrap: FlexWrap.Wrap }) {
          ForEach(this.durationPresets(), (d: number) => {
            Text(d + ' 分钟')
              .fontSize(13)
              .fontColor(!this.useCustomDuration && this.newDurationMin === d ? '#FFFFFF' : this.t.ink)
              .backgroundColor(!this.useCustomDuration && this.newDurationMin === d ? this.t.leaf : this.t.surface2)
              .borderRadius(12)
              .border({ width: 1, color: !this.useCustomDuration && this.newDurationMin === d ? this.t.leaf : this.t.line })
              .padding({ left: 12, right: 12, top: 8, bottom: 8 })
              .margin({ right: 8, top: 8 })
              .onClick(() => { this.newDurationMin = d; this.useCustomDuration = false; })
          }, (d: number) => 'dur_' + d)

          Text('自定义')
            .fontSize(13)
            .fontColor(this.useCustomDuration ? '#FFFFFF' : this.t.ink)
            .backgroundColor(this.useCustomDuration ? this.t.leaf : this.t.surface2)
            .borderRadius(12)
            .border({ width: 1, color: this.useCustomDuration ? this.t.leaf : this.t.line })
            .padding({ left: 12, right: 12, top: 8, bottom: 8 })
            .margin({ right: 8, top: 8 })
            .onClick(() => { this.useCustomDuration = true; })
        }
        .width('100%')

        if (this.useCustomDuration) {
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

        Row({ space: 10 }) {
          Row() {
            Text('取消').fontSize(14).fontColor(this.t.ink2)
          }
          .layoutWeight(1)
          .height(42)
          .borderRadius(12)
          .border({ width: 1, color: this.t.line })
          .justifyContent(FlexAlign.Center)
          .onClick(() => { this.showAdd = false; })

          Row() {
            Text('添加').fontSize(14).fontColor('#FFFFFF').fontWeight(FontWeight.Medium)
          }
          .layoutWeight(1)
          .height(42)
          .borderRadius(12)
          .backgroundColor(this.t.leaf)
          .justifyContent(FlexAlign.Center)
          .onClick(() => { this.addTask(); })
        }
        .width('100%')
        .margin({ top: 16 })
      }
      .width('80%')
      .padding(22)
      .backgroundColor(this.t.surface)
      .borderRadius(22)
    }
  }

  // ====== 挑战目标弹窗 ======
  @Builder
  goalPicker() {
    Stack() {
      Column()
        .width('100%').height('100%')
        .backgroundColor('rgba(30,40,26,0.42)')
        .onClick(() => { this.showGoalPicker = false; })
      Column() {
        Column() {
          Text('🏆').fontSize(28).fontColor(this.t.gold)
        }
        .width(48).height(48).borderRadius(14)
        .backgroundColor(this.t.goldSoft)
        .justifyContent(FlexAlign.Center)

        Text('自定义每日挑战')
          .fontFamily(FONT_DISPLAY)
          .fontSize(17)
          .fontColor(this.t.ink)
          .margin({ top: 12 })
        Text('每天想专注几个番茄？达成奖励 +50 经验')
          .fontSize(12)
          .fontColor(this.t.ink2)
          .margin({ top: 4 })

        Row({ space: 10 }) {
          ForEach([2, 4, 6, 8], (g: number) => {
            Column() {
              Text(g + '').fontSize(17).fontWeight(FontWeight.Bold)
                .fontColor(AppState.instance.challengeGoal === g ? '#FFFFFF' : this.t.ink)
            }
            .layoutWeight(1)
            .height(56)
            .borderRadius(14)
            .backgroundColor(AppState.instance.challengeGoal === g ? this.t.leaf : this.t.surface2)
            .border({ width: 1, color: AppState.instance.challengeGoal === g ? this.t.leaf : this.t.line })
            .justifyContent(FlexAlign.Center)
            .onClick(() => { this.setChallengeGoal(g); this.showGoalPicker = false; })
          }, (g: number) => g + '')
        }
        .width('100%')
        .margin({ top: 16 })

        Text('目标越高越有挑战，完成后经验照常到账。')
          .fontSize(11)
          .fontColor(this.t.ink3)
          .margin({ top: 12 })
      }
      .width('80%')
      .padding(22)
      .backgroundColor(this.t.surface)
      .borderRadius(22)
      .alignItems(HorizontalAlign.Center)
    }
  }

  // ====== 删除确认弹窗 ======
  @Builder
  deleteConfirmPanel() {
    Stack() {
      Column()
        .width('100%')
        .height('100%')
        .backgroundColor('rgba(30,40,26,0.42)')
        .onClick(() => { this.showDeleteConfirm = false; })
      Column() {
        Text('删除待办？')
          .fontFamily(FONT_DISPLAY)
          .fontSize(17)
          .fontColor(this.t.ink)
        Text('「' + this.pendingDeleteTitle + '」将被删除，此操作不可恢复。')
          .fontSize(12.5)
          .fontColor(this.t.ink2)
          .lineHeight(20)
          .textAlign(TextAlign.Center)
          .margin({ top: 8 })
        Row({ space: 10 }) {
          Row() {
            Text('取消').fontSize(14).fontColor(this.t.ink2)
          }
          .layoutWeight(1).height(44).borderRadius(12)
          .border({ width: 1, color: this.t.line })
          .justifyContent(FlexAlign.Center)
          .onClick(() => { this.showDeleteConfirm = false; })

          Row() {
            Text('删除').fontSize(14).fontColor('#FFFFFF').fontWeight(FontWeight.Medium)
          }
          .layoutWeight(1).height(44).borderRadius(12)
          .backgroundColor(this.t.tomato)
          .justifyContent(FlexAlign.Center)
          .onClick(() => { this.confirmDelete(); })
        }
        .width('100%')
        .margin({ top: 18 })
      }
      .width(290)
      .padding(22)
      .backgroundColor(this.t.surface)
      .borderRadius(22)
      .alignItems(HorizontalAlign.Center)
    }
  }

  // ====== 首页新手引导（高亮目标区域 + 气泡箭头）======
  @Builder
  guideOverlay() {
    Stack() {
      // 拦截点击
      Column()
        .width('100%')
        .height('100%')
        .backgroundColor('rgba(0,0,0,0.001)')
        .onClick(() => {})

      // 遮罩：用超大边框在目标处留出镂空
      Column()
        .width(this.spot().w)
        .height(this.spot().h)
        .borderRadius(18)
        .border({ width: 1000, color: 'rgba(20,28,18,0.62)' })
        .position({ x: this.spot().x, y: this.spot().y })

      // 高亮描边
      Column()
        .width(this.spot().w)
        .height(this.spot().h)
        .borderRadius(18)
        .border({ width: 2, color: this.t.leaf })
        .position({ x: this.spot().x, y: this.spot().y })

      // 气泡箭头
      Path()
        .width(20)
        .height(10)
        .commands(this.arrowCommands())
        .fill(this.t.surface)
        .position({ x: this.arrowX(), y: this.arrowY() })

      // 气泡卡片
      Column() {
        Row({ space: 10 }) {
          Column() {
            Text(this.guideSteps()[this.guideStep].icon).fontSize(22)
          }
          .width(42).height(42).borderRadius(13)
          .backgroundColor(this.t.leafSoft)
          .justifyContent(FlexAlign.Center)

          Text(this.guideSteps()[this.guideStep].title)
            .fontFamily(FONT_DISPLAY)
            .fontSize(17)
            .fontColor(this.t.ink)
            .layoutWeight(1)
        }
        .width('100%')

        Text(this.guideSteps()[this.guideStep].desc)
          .fontSize(12.5)
          .fontColor(this.t.ink2)
          .lineHeight(20)
          .width('100%')
          .margin({ top: 8 })

        Row({ space: 6 }) {
          ForEach(this.guideSteps(), (s: GuideStep, i: number) => {
            Column()
              .width(i === this.guideStep ? 18 : 6)
              .height(6)
              .borderRadius(99)
              .backgroundColor(i === this.guideStep ? this.t.leaf : this.t.surface2)
          }, (s: GuideStep, i: number) => 'guide_' + i)
        }
        .margin({ top: 12 })

        Row({ space: 10 }) {
          Row() {
            Text('跳过').fontSize(13.5).fontColor(this.t.ink2)
          }
          .layoutWeight(1)
          .height(40)
          .borderRadius(12)
          .border({ width: 1, color: this.t.line })
          .justifyContent(FlexAlign.Center)
          .onClick(() => { this.finishGuide(); })

          Row() {
            Text(this.guideStep >= this.guideSteps().length - 1 ? '开始使用' : '下一步')
              .fontSize(13.5).fontColor('#FFFFFF').fontWeight(FontWeight.Medium)
          }
          .layoutWeight(1)
          .height(40)
          .borderRadius(12)
          .backgroundColor(this.t.leaf)
          .justifyContent(FlexAlign.Center)
          .onClick(() => {
            if (this.guideStep >= this.guideSteps().length - 1) {
              this.finishGuide();
            } else {
              this.guideStep += 1;
            }
          })
        }
        .width('100%')
        .margin({ top: 14 })
      }
      .width(this.bubbleW())
      .padding(16)
      .backgroundColor(this.t.surface)
      .borderRadius(18)
      .shadow({ radius: 30, color: 'rgba(0,0,0,0.25)', offsetY: 10 })
      .alignItems(HorizontalAlign.Start)
      .position({ x: this.bubbleX(), y: this.bubbleY() })
      .onAreaChange((o: Area, n: Area) => {
        const h = n.height as number;
        if (Math.abs(h - this.bubbleH) > 0.5) {
          this.bubbleH = h;
        }
      })
    }
    .width('100%')
    .height('100%')
  }
}
