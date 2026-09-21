import { router } from '@kit.ArkUI';
import { promptAction } from '@kit.ArkUI';
import { AppState } from '../model/AppState';
import { themeOf, BACKGROUNDS, WHITE_NOISES, DURATIONS, INTERRUPT_REASONS, TaskItem, FocusRecord, BgOption, NoiseOption } from '../model/Types';
import { Store, formatMMSS, genId, todayKey } from '../model/Store';

@Entry
@Component
struct Focus {
  @State taskId: string = '';
  @State durationSec: number = 25 * 60;
  @State remainingSec: number = 25 * 60;
  @State running: boolean = false;
  @State bgKey: string = 'sky';
  @State noiseKey: string = 'mute';
  @State showQuit: boolean = false;
  @State quitReason: string = '临时有事';
  @State ringTick: number = 0;
  @State startTs: number = 0;
  @State elapsedSec: number = 0;
  private timerId: number = -1;
  private context: CanvasRenderingContext2D = new CanvasRenderingContext2D(new RenderingContextSettings(true));

  aboutToAppear() {
    const params = router.getParams() as Record<string, Object>;
    if (params && params['taskId']) {
      this.taskId = params['taskId'] as string;
      const t = AppState.instance.tasks.find(x => x.id === this.taskId);
      if (t) {
        this.durationSec = t.durationMin * 60;
        this.remainingSec = this.durationSec;
        this.bgKey = t.bgSeed;
      }
    }
  }

  aboutToDisappear() {
    this.stopTimer();
  }

  task(): TaskItem | undefined {
    return AppState.instance.tasks.find(x => x.id === this.taskId);
  }

  title(): string {
    return this.task()?.title ?? '专注中';
  }

  isDark(): boolean {
    return this.bgKey === 'sky' || this.bgKey === 'dusk';
  }

  ink(): string {
    return this.isDark() ? '#FFFFFF' : '#3A3328';
  }

  dim(): string {
    return this.isDark() ? 'rgba(255,255,255,0.7)' : 'rgba(58,51,40,0.72)';
  }

  ringColor(): string {
    return this.isDark() ? '#FFFFFF' : '#4C7A3E';
  }

  ringTrack(): string {
    return this.isDark() ? 'rgba(255,255,255,0.22)' : 'rgba(58,51,40,0.16)';
  }

  panelBg(): string {
    return this.isDark() ? 'rgba(255,255,255,0.22)' : 'rgba(255,255,255,0.55)';
  }

  panelBgActive(): string {
    return this.isDark() ? 'rgba(255,255,255,0.28)' : 'rgba(255,255,255,0.85)';
  }

  accentInk(): string {
    return this.isDark() ? themeOf(AppState.instance.themeKey).leafDeep : themeOf(AppState.instance.themeKey).tomato;
  }

  statusText(): string {
    if (this.running) return '专注进行中';
    if (this.elapsedSec > 0) return '已暂停';
    return '准备开始';
  }

  curPomodoro(): number {
    const k = todayKey();
    return (AppState.instance.stats[k]?.pomodoroCount ?? 0) + 1;
  }

  startTimer() {
    if (this.running) return;
    this.running = true;
    this.startTs = Date.now() - this.elapsedSec * 1000;
    this.timerId = setInterval(() => {
      const elapsed = Math.floor((Date.now() - this.startTs) / 1000);
      this.elapsedSec = Math.min(this.durationSec, elapsed);
      this.remainingSec = Math.max(0, this.durationSec - elapsed);
      this.ringTick += 1;
      this.drawRing();
      if (this.remainingSec <= 0) {
        this.finishFocus(true);
      }
    }, 250);
  }

  pauseTimer() {
    this.running = false;
    if (this.timerId !== -1) {
      clearInterval(this.timerId);
      this.timerId = -1;
    }
  }

  stopTimer() {
    this.pauseTimer();
  }

  progressFrac(): number {
    if (this.durationSec <= 0) return 0;
    return Math.min(1, Math.max(0, this.elapsedSec / this.durationSec));
  }

  finishFocus(success: boolean, reason: string = '') {
    this.pauseTimer();
    const rec: FocusRecord = {
      id: genId('f'),
      taskId: this.taskId,
      taskTitle: this.title(),
      startAt: this.startTs,
      endAt: Date.now(),
      durationSec: this.elapsedSec,
      finished: success,
      interruptReason: reason,
      backgroundKey: this.bgKey,
      whiteNoise: this.noiseKey,
      roomId: AppState.instance.currentRoomMode === 'study' ? AppState.instance.currentRoomId : ''
    };
    AppState.instance.records = [...AppState.instance.records, rec];

    const key = todayKey();
    const s = AppState.instance.stats[key] ?? {
      date: key, focusMinutes: 0, pomodoroCount: 0, doneTaskCount: 0, interruptCounts: {}
    };
    s.focusMinutes += Math.floor(this.elapsedSec / 60);
    if (success) {
      s.pomodoroCount += 1;
    } else if (reason !== '') {
      const ic: Record<string, number> = s.interruptCounts;
      ic[reason] = (ic[reason] ?? 0) + 1;
    }
    AppState.instance.stats[key] = s;
    AppState.recomputeStreak();
    AppState.saveUser();

    if (success) {
      const idx = AppState.instance.tasks.findIndex(t => t.id === this.taskId);
      if (idx >= 0) {
        AppState.instance.tasks[idx].status = 'done';
      }
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
    }
    AppState.saveRecords();
    AppState.saveStats();
    AppState.saveTasks();
    AppState.instance.doneCountToday = s.pomodoroCount;
    AppState.saveChallenge();

    if (success) {
      router.replaceUrl({ url: 'pages/Complete', params: { taskId: this.taskId, exp: 20 } });
    } else {
      router.back();
    }
  }

  // 提前退出：不计入番茄，记录中断原因
  exitFocus() {
    this.finishFocus(false, this.quitReason);
    promptAction.showToast({ message: '已提前退出，本次不计入番茄', duration: 1500 });
  }

  applyDuration(min: number) {
    this.durationSec = min * 60;
    this.elapsedSec = 0;
    this.remainingSec = this.durationSec;
    this.startTs = Date.now();
    this.ringTick += 1;
    this.drawRing();
  }

  build() {
    Stack() {
      Column() {
        // 顶部任务
        Row() {
          Row({ space: 10 }) {
            Column() {
              Text('🍅').fontSize(18)
            }
            .width(34).height(34)
            .borderRadius(11)
            .backgroundColor('rgba(255,255,255,0.28)')
            .justifyContent(FlexAlign.Center)

            Column() {
              Text('正在专注').fontSize(12).fontColor(this.dim())
              Text(this.title())
                .fontSize(16).fontWeight(FontWeight.Medium)
                .fontColor(this.ink())
                .maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
            }
            .alignItems(HorizontalAlign.Start)
          }
          Blank()
          Text('第 ' + this.curPomodoro() + ' 个番茄')
            .fontSize(12)
            .fontColor(this.dim())
        }
        .width('100%')
        .padding({ left: 24, right: 24, top: 26 })

        // 圆环 + 时间
        Column() {
          Stack() {
            Canvas(this.context)
              .width(220).height(220)
              .onReady(() => { this.drawRing(); })
            Column() {
              Text(formatMMSS(this.remainingSec))
                .fontFamily('serif')
                .fontSize(52)
                .letterSpacing(2)
                .fontColor(this.ink())
              Text(this.statusText())
                .fontSize(12)
                .fontColor(this.dim())
                .margin({ top: 6 })
            }
            .width(220).height(220)
            .justifyContent(FlexAlign.Center)
            .alignItems(HorizontalAlign.Center)
          }
          .width(220).height(220)

          // 时长切换胶囊
          Row({ space: 8 }) {
            ForEach(DURATIONS, (d: number) => {
              Text(d + ' 分')
                .fontSize(12.5)
                .fontWeight(this.durationSec === d * 60 ? FontWeight.Bold : FontWeight.Medium)
                .fontColor(this.durationSec === d * 60
                  ? (this.isDark() ? themeOf(AppState.instance.themeKey).leafDeep : themeOf(AppState.instance.themeKey).tomato)
                  : this.ink())
                .padding({ left: 14, right: 14, top: 5, bottom: 5 })
                .borderRadius(99)
                .backgroundColor(this.durationSec === d * 60
                  ? 'rgba(255,255,255,0.9)'
                  : this.panelBg())
                .onClick(() => { this.applyDuration(d); })
            }, (d: number) => d + '')
          }
          .margin({ top: 22 })

          // 开始 / 暂停按钮
          Row({ space: 8 }) {
            Text(this.running ? '⏸' : '▶')
              .fontSize(18)
              .fontColor(this.running ? this.ink() : this.accentInk())
            Text(this.running ? '暂停' : '开始专注')
              .fontSize(16)
              .fontWeight(FontWeight.Bold)
              .fontColor(this.running ? this.ink() : this.accentInk())
          }
          .padding({ left: 40, right: 40, top: 13, bottom: 13 })
          .borderRadius(99)
          .backgroundColor(this.running ? this.panelBgActive() : 'rgba(255,255,255,0.92)')
          .border(this.running ? { width: 1, color: 'rgba(255,255,255,0.6)' } : { width: 0 })
          .shadow({ radius: 24, color: 'rgba(0,0,0,0.15)', offsetY: 8 })
          .margin({ top: 24 })
          .onClick(() => {
            if (this.running) {
              this.pauseTimer();
            } else {
              this.startTimer();
            }
          })
        }
        .margin({ top: 30 })

        Blank().layoutWeight(1)

        // 底部控制面板
        Column() {
          Text('专注背景').fontSize(12).fontColor(this.dim())
          Row({ space: 10 }) {
            ForEach(BACKGROUNDS, (b: BgOption) => {
              Column() {
                Column()
                  .width('100%')
                  .height(44)
                  .borderRadius(12)
                  .linearGradient({ angle: 160, colors: [[b.from, 0], [b.to, 1]] })
                  .border(this.bgKey === b.key ? { width: 2.5, color: '#FFFFFF' } : { width: 2, color: 'rgba(255,255,255,0.25)' })
                Text(b.name).fontSize(11).fontColor(this.dim()).margin({ top: 5 })
              }
              .layoutWeight(1)
              .alignItems(HorizontalAlign.Center)
              .onClick(() => {
                this.bgKey = b.key;
                this.ringTick += 1;
                this.drawRing();
              })
            }, (b: BgOption) => b.key)
          }
          .width('100%')
          .margin({ top: 10, bottom: 18 })

          Text('白噪音').fontSize(12).fontColor(this.dim())
          Row({ space: 8 }) {
            ForEach(WHITE_NOISES, (n: NoiseOption) => {
              Column({ space: 4 }) {
                Text(n.icon).fontSize(18).fontColor(this.ink())
                Text(n.name).fontSize(11).fontColor(this.ink())
              }
              .layoutWeight(1)
              .padding({ top: 10, bottom: 10 })
              .borderRadius(12)
              .backgroundColor(this.noiseKey === n.key
                ? 'rgba(255,255,255,0.28)'
                : 'rgba(255,255,255,0.12)')
              .border(this.noiseKey === n.key
                ? { width: 1, color: 'rgba(255,255,255,0.6)' }
                : { width: 1, color: 'transparent' })
              .onClick(() => { this.noiseKey = n.key; })
            }, (n: NoiseOption) => n.key)
          }
          .width('100%')
          .margin({ top: 10, bottom: 22 })

          // 操作
          Row() {
            Row({ space: 5 }) {
              Text('🚪').fontSize(14)
              Text('提前退出').fontSize(13).fontColor(this.dim())
            }
            .onClick(() => { this.showQuit = true; })

            Blank()

            Text('演示：快进到完成')
              .fontSize(11)
              .fontColor(this.dim())
              .opacity(0.5)
              .onClick(() => { this.finishFocus(true); })
          }
          .width('100%')
        }
        .width('100%')
        .padding({ left: 24, right: 24, bottom: 34 })
      }
      .width('100%')
      .height('100%')
      .linearGradient({ angle: 160, colors: [[this.bgFrom(), 0], [this.bgTo(), 1]] })

      if (this.showQuit) {
        this.quitPanel()
      }
    }
  }

  bgFrom(): string {
    const m = BACKGROUNDS.find(b => b.key === this.bgKey) ?? BACKGROUNDS[0];
    return m.from;
  }

  bgTo(): string {
    const m = BACKGROUNDS.find(b => b.key === this.bgKey) ?? BACKGROUNDS[0];
    return m.to;
  }

  @Builder
  quitPanel() {
    Stack() {
      Column()
        .width('100%').height('100%')
        .backgroundColor('rgba(30,40,26,0.42)')
        .onClick(() => { this.showQuit = false; })
      Column() {
        Text('要放弃这次专注吗？')
          .fontFamily('serif')
          .fontSize(17)
          .fontColor('#2C3A28')
          .margin({ bottom: 8 })
        Text('本次已专注 ' + Math.floor(this.elapsedSec / 60) + ' 分钟，提前退出将不计入完整番茄。')
          .fontSize(12.5)
          .fontColor('#84917D')
          .lineHeight(22)
          .textAlign(TextAlign.Center)

        Text('提前退出原因')
          .fontSize(12)
          .fontColor('#84917D')
          .width('100%')
          .textAlign(TextAlign.Start)
          .margin({ top: 14, bottom: 4 })
        Flex({ wrap: FlexWrap.Wrap }) {
          ForEach(INTERRUPT_REASONS, (r: string) => {
            Text(r)
              .fontSize(12)
              .fontColor(this.quitReason === r ? '#FFFFFF' : '#4C7A3E')
              .backgroundColor(this.quitReason === r ? '#6E9B57' : '#EAF1E2')
              .borderRadius(99)
              .padding({ left: 12, right: 12, top: 6, bottom: 6 })
              .margin({ right: 8, top: 8 })
              .onClick(() => { this.quitReason = r; })
          }, (r: string) => r)
        }
        .width('100%')

        Row({ space: 10 }) {
          Row() {
            Text('继续专注').fontSize(14).fontColor('#84917D')
          }
          .layoutWeight(1).height(44).borderRadius(13)
          .border({ width: 1, color: '#E3E9DB' })
          .justifyContent(FlexAlign.Center)
          .onClick(() => { this.showQuit = false; })

          Row() {
            Text('退出').fontSize(14).fontColor('#FFFFFF').fontWeight(FontWeight.Medium)
          }
          .layoutWeight(1).height(44).borderRadius(13)
          .backgroundColor('#E07A5F')
          .justifyContent(FlexAlign.Center)
          .onClick(() => {
            this.showQuit = false;
            this.exitFocus();
          })
        }
        .width('100%')
        .margin({ top: 20 })
      }
      .width(286)
      .padding(22)
      .backgroundColor('#FFFFFF')
      .borderRadius(22)
      .alignItems(HorizontalAlign.Center)
    }
  }

  // ===== Canvas 绘制圆环 =====
  drawRing() {
    const ctx = this.context;
    const size = 220;
    const cx = size / 2;
    const cy = size / 2;
    const r = 92;
    ctx.clearRect(0, 0, size, size);
    // 背景圈
    ctx.beginPath();
    ctx.arc(cx, cy, r, 0, Math.PI * 2);
    ctx.lineWidth = 11;
    ctx.strokeStyle = this.ringTrack();
    ctx.stroke();
    // 进度圈
    const frac = this.progressFrac();
    if (frac > 0) {
      ctx.beginPath();
      ctx.arc(cx, cy, r, -Math.PI / 2, -Math.PI / 2 + Math.PI * 2 * frac);
      ctx.lineWidth = 11;
      ctx.strokeStyle = this.ringColor();
      ctx.lineCap = 'round';
      ctx.stroke();
    }
  }
}
