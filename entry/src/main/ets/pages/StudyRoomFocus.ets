import { router } from '@kit.ArkUI';
import { AppState } from '../model/AppState';
import { themeOf, BACKGROUNDS, WHITE_NOISES } from '../model/Types';
import { formatMMSS, genId, todayKey } from '../model/Store';

@Entry
@Component
struct StudyRoomFocus {
  @State roomId: string = '';
  @State roomName: string = '';
  @State durationSec: number = 25 * 60;
  @State remainingSec: number = 25 * 60;
  @State elapsedSec: number = 0;
  @State running: boolean = false;
  @State bgKey: string = 'sky';
  @State noiseKey: string = 'mute';
  @State showPanel: boolean = false;
  @State treeTick: number = 0;
  private timerId: number = -1;

  aboutToAppear() {
    const p = router.getParams() as Record<string, Object>;
    if (p) {
      this.roomId = (p['roomId'] ?? '') as string;
      this.roomName = (p['roomName'] ?? '自习室') as string;
    }

    const first = AppState.instance.tasks.filter(t => t.status === 'todo')[0];
    if (first) {
      this.durationSec = first.durationMin * 60;
      this.remainingSec = this.durationSec;
      AppState.instance.currentTaskId = first.id;
    }
  }

  aboutToDisappear() {
    if (this.timerId !== -1) clearInterval(this.timerId);
  }

  startTimer() {
    if (this.running) return;
    this.running = true;
    const startTs = Date.now() - this.elapsedSec * 1000;
    this.timerId = setInterval(() => {
      const elapsed = Math.floor((Date.now() - startTs) / 1000);
      this.elapsedSec = Math.min(this.durationSec, elapsed);
      this.remainingSec = Math.max(0, this.durationSec - elapsed);
      if (this.remainingSec <= 0) {
        this.finishFocus();
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

  finishFocus() {
    this.pauseTimer();
    // 加统计
    const k = todayKey();
    const s = AppState.instance.stats[k] ?? { date: k, focusMinutes: 0, pomodoroCount: 0, doneTaskCount: 0, interruptCounts: {} };
    s.focusMinutes += Math.floor(this.elapsedSec / 60);
    s.pomodoroCount += 1;
    AppState.instance.stats[k] = s;
    AppState.recomputeStreak();
    AppState.saveStats();
    AppState.saveUser();

    // 加经验
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
    router.replaceUrl({ url: 'pages/Complete', params: { exp: 20 } });
  }

  bgGrad(): LinearGradient {
    const m = BACKGROUNDS.find(b => b.key === this.bgKey) ?? BACKGROUNDS[0];
    return { direction: GradientDirection.Bottom, colors: [[m.from, 0], [m.to, 1]] };
  }

  build() {
    Column() {
      Row() {
        Text('‹').fontSize(28).fontColor('#FFFFFFCC')
          .padding({ left: 8, right: 8 })
          .onClick(() => { router.back(); })
        Column() {
          Text(this.roomName.length > 0 ? this.roomName : '自习室')
            .fontSize(16).fontWeight(FontWeight.Bold).fontColor('#FFFFFF')
          Text('一起专注中')
            .fontSize(11).fontColor('#FFFFFFCC').margin({ top: 2 })
        }
        .layoutWeight(1)
        .margin({ left: 4 })
        .alignItems(HorizontalAlign.Start)
        Text('⋯').fontSize(22).fontColor('#FFFFFFCC')
          .padding({ left: 8, right: 8 })
          .onClick(() => { this.showPanel = !this.showPanel; })
      }
      .width('100%')
      .padding({ top: 44, bottom: 8, left: 12, right: 12 })

      Blank().layoutWeight(1)

      Stack() {
        Column()
          .width(260).height(260).borderRadius(130)
          .borderWidth(8).borderColor('#FFFFFF22')
        Column() {
          Text(formatMMSS(this.remainingSec))
            .fontSize(54).fontWeight(FontWeight.Bold).fontColor('#FFFFFF')
          Text(this.running ? '自习中…' : '已暂停')
            .fontSize(13).fontColor('#FFFFFFBB').margin({ top: 8 })
        }
        .width(260).height(260)
        .justifyContent(FlexAlign.Center).alignItems(HorizontalAlign.Center)
      }
      .width(280).height(280)

      Blank().layoutWeight(1)

      Row({ space: 24 }) {
        Column() {
          Text('🌲').fontSize(20)
          Text('背景').fontSize(11).fontColor('#FFFFFFCC').margin({ top: 4 })
        }
        .padding({ left: 14, right: 14, top: 8, bottom: 8 })
        .backgroundColor('#FFFFFF22').borderRadius(14)
        .onClick(() => { this.cycle('bg'); })
        Column() {
          Text('🔊').fontSize(20)
          Text('白噪音').fontSize(11).fontColor('#FFFFFFCC').margin({ top: 4 })
        }
        .padding({ left: 14, right: 14, top: 8, bottom: 8 })
        .backgroundColor('#FFFFFF22').borderRadius(14)
        .onClick(() => { this.cycle('noise'); })
      }
      .width('100%').justifyContent(FlexAlign.Center).margin({ top: 20 })

      Button(this.running ? '暂停' : '开始')
        .fontSize(20).fontWeight(FontWeight.Bold).fontColor('#1A1A1A')
        .backgroundColor('#FFFFFFEE').width('70%').height(60).borderRadius(30)
        .margin({ top: 24, bottom: 40 })
        .onClick(() => {
          if (this.running) this.pauseTimer();
          else this.startTimer();
        })
    }
    .width('100%')
    .height('100%')
    .linearGradient(this.bgGrad())
  }

  cycle(kind: 'bg' | 'noise') {
    if (kind === 'bg') {
      const arr = BACKGROUNDS.map(b => b.key);
      const i = arr.indexOf(this.bgKey);
      this.bgKey = arr[(i + 1) % arr.length];
    } else {
      const arr = WHITE_NOISES.map(n => n.key);
      const i = arr.indexOf(this.noiseKey);
      this.noiseKey = arr[(i + 1) % arr.length];
    }
  }
}