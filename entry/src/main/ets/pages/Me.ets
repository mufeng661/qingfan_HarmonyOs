import { router } from '@kit.ArkUI';
import { promptAction } from '@kit.ArkUI';
import { AppState } from '../model/AppState';
import { themeOf, THEMES, ThemeDef, ThemeKey, BadgeItem, FONT_DISPLAY } from '../model/Types';
import { Store, todayKey } from '../model/Store';
import { TabBar } from '../components/TabBar';

interface ForestCell {
  state: string;   // 'tree' | 'withered' | 'empty'
  idx: number;
}

interface WeekCell {
  label: string;
  done: boolean;
  isToday: boolean;
}

@Entry
@Component
struct Me {
  @State uiTick: number = 0;
  @State showLogout: boolean = false;
  @State showBadge: boolean = false;
  @State settings: string = '';
  @State badgeIdx: number = 0;
  @State notifyFocus: boolean = true;
  @State notifySign: boolean = true;
  @State notifyFriend: boolean = false;
  @State privacyTime: boolean = true;
  @State privacyOnline: boolean = false;
  @State signedToday: boolean = false;
  @State streakDays: number = 0;
  @State loggedIn: boolean = false;
  private t: ThemeDef = themeOf(AppState.instance.themeKey);
  private midnightTimerId: number = -1;
  private lastDayKey: string = '';

  aboutToAppear() {
    this.lastDayKey = todayKey();
    this.syncUserState();
    this.midnightTimerId = setInterval(() => {
      const k = todayKey();
      if (k !== this.lastDayKey) {
        this.lastDayKey = k;
        this.syncUserState();
        this.uiTick += 1;
      }
    }, 30000);
  }

  aboutToDisappear() {
    if (this.midnightTimerId !== -1) {
      clearInterval(this.midnightTimerId);
      this.midnightTimerId = -1;
    }
  }

  onPageShow() {
    this.syncUserState();
    this.uiTick += 1;
  }

  syncUserState() {
    const s = AppState.recomputeStreak();
    AppState.saveUser();
    this.loggedIn = AppState.isLoggedIn();
    this.signedToday = AppState.isSignedToday();
    this.streakDays = s;
  }

  signGain(): number {
    const s = AppState.instance.user?.streak ?? 0;
    return s >= 7 ? 15 : 10;
  }

  build() {
    Stack() {
      if (!this.loggedIn) {
        Column() {
          this.guestView()
          TabBar({ active: 'me' })
        }
        .width('100%')
        .height('100%')
        .backgroundColor(this.t.bg)
      } else {
        Column() {
          Scroll() {
            Column() {
              this.profileHeader()
              this.expCard()
              this.signCard()
              this.forestCard()
              this.weekCard()
              this.badgeCard()
              this.totalCard()
              this.themeCard()
              this.widgetEntry()
              this.guideEntry()
              this.settingsList()
              this.logoutBtn()
              Column().height(20)
            }
            .width('100%')
            .padding({ left: 22, right: 22, top: 20 })
          }
          .layoutWeight(1)
          .scrollBar(BarState.Off)
          .edgeEffect(EdgeEffect.Spring)

          TabBar({ active: 'me' })
        }
        .width('100%')
        .height('100%')
        .backgroundColor(this.t.bg)
      }

      if (this.showLogout) {
        this.logoutPanel()
      }
      if (this.showBadge) {
        this.badgePanel()
      }
      if (this.settings !== '') {
        this.settingsPanel()
      }
    }
  }

  // ====== 游客视图 ======
  @Builder
  guestView() {
    Column() {
      Column() {
        Text('🍅').fontSize(72)
        Text('青番')
          .fontFamily(FONT_DISPLAY)
          .fontSize(30)
          .fontColor(this.t.ink)
          .margin({ top: 8 })
        Text('把专注，种成一片森林')
          .fontFamily(FONT_DISPLAY)
          .fontSize(14)
          .fontColor(this.t.ink2)
          .margin({ top: 8 })
      }
      .alignItems(HorizontalAlign.Center)

      Column() {
        this.guestFeature('✅', '今日待办 + 专注计时', '无需登录，直接使用')
        this.guestFeature('🔒', 'AI 智能助手', '登录后解锁')
        this.guestFeature('🔒', '统计 / 排行', '登录后解锁')
        this.guestFeature('🔒', '自习室', '登录并专注满 25 分钟解锁')
      }
      .width('100%')
      .padding(16)
      .backgroundColor(this.t.surface)
      .borderRadius(18)
      .border({ width: 1, color: this.t.line })
      .margin({ top: 24 })

      Row() {
        Text('登录 / 注册')
          .fontSize(15)
          .fontWeight(FontWeight.Bold)
          .fontColor('#FFFFFF')
          .letterSpacing(2)
      }
      .width('100%')
      .height(50)
      .borderRadius(14)
      .backgroundColor(this.t.leaf)
      .shadow({ radius: 24, color: 'rgba(110,155,87,0.32)', offsetY: 10 })
      .justifyContent(FlexAlign.Center)
      .margin({ top: 20 })
      .onClick(() => { router.pushUrl({ url: 'pages/Login' }); })

      Text('登录后可同步专注数据、解锁全部功能')
        .fontSize(11)
        .fontColor(this.t.ink3)
        .margin({ top: 10 })
    }
    .width('100%')
    .layoutWeight(1)
    .padding({ left: 22, right: 22 })
    .justifyContent(FlexAlign.Center)
  }

  @Builder
  guestFeature(icon: string, title: string, desc: string) {
    Row({ space: 10 }) {
      Text(icon).fontSize(16)
      Column() {
        Text(title).fontSize(13.5).fontWeight(FontWeight.Medium).fontColor(this.t.ink)
        Text(desc).fontSize(11).fontColor(this.t.ink3).margin({ top: 2 })
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)
    }
    .width('100%')
    .padding({ top: 10, bottom: 10 })
  }

  // ====== 个人信息 ======
  @Builder
  profileHeader() {
    Row({ space: 14 }) {
      Stack({ alignContent: Alignment.BottomEnd }) {
        Column() {
          Text(this.firstChar())
            .fontSize(24).fontWeight(FontWeight.Medium).fontColor('#FFFFFF')
        }
        .width(58).height(58)
        .borderRadius(29)
        .linearGradient({ angle: 135, colors: [[this.t.leaf, 0], [this.t.leafDeep, 1]] })
        .justifyContent(FlexAlign.Center)

        Text('Lv.' + (AppState.instance.user?.level ?? 1))
          .fontSize(10).fontWeight(FontWeight.Bold).fontColor('#FFFFFF')
          .padding({ left: 6, right: 6, top: 2, bottom: 2 })
          .backgroundColor(this.t.gold)
          .borderRadius(99)
          .border({ width: 2, color: '#FFFFFF' })
          .offset({ x: 2, y: 2 })
      }

      Column() {
        Row({ space: 6 }) {
          Text(AppState.instance.user?.nickname ?? '林小满')
            .fontSize(18).fontWeight(FontWeight.Medium).fontColor(this.t.ink)
          Text('›').fontSize(14).fontColor(this.t.ink3)
        }
        Text(AppState.instance.user?.bio ?? '把专注，种成一片森林')
          .fontSize(12).fontColor(this.t.ink2)
          .margin({ top: 3 })
          .maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)
    }
    .width('100%')
    .margin({ bottom: 18 })
    .onClick(() => { router.pushUrl({ url: 'pages/EditProfile' }); })
  }

  firstChar(): string {
    const n = AppState.instance.user?.nickname ?? '林小满';
    return n.slice(0, 1);
  }

  // ====== 经验值 ======
  @Builder
  expCard() {
    Column() {
      Row() {
        Text('经验值').fontSize(13).fontColor(this.t.ink2)
        Blank()
        Text() {
          Span((AppState.instance.user?.exp ?? 0) + '').fontFamily(FONT_DISPLAY).fontSize(15).fontColor(this.t.ink)
          Span(' / ' + (AppState.instance.user?.nextLevelExp ?? 3000)).fontSize(11).fontColor(this.t.ink3)
        }
      }
      .width('100%')
      .margin({ bottom: 10 })

      Stack() {
        Row().width('100%').height(8).borderRadius(99).backgroundColor(this.t.surface2)
        Row().width(this.expPct() + '%').height(8).borderRadius(99)
          .linearGradient({ angle: 90, colors: [[this.t.leaf, 0], [this.t.gold, 1]] })
      }
      .width('100%')

      Text('再获得 ' + (this.expMax() - (AppState.instance.user?.exp ?? 0)) + ' 经验升级到 Lv.' + ((AppState.instance.user?.level ?? 1) + 1))
        .fontSize(11).fontColor(this.t.ink3)
        .margin({ top: 8 })
        .width('100%')
    }
    .width('100%')
    .padding({ left: 18, right: 18, top: 16, bottom: 16 })
    .backgroundColor(this.t.surface)
    .borderRadius(18)
    .border({ width: 1, color: this.t.line })
    .margin({ bottom: 16 })
  }

  expMax(): number {
    return AppState.instance.user?.nextLevelExp ?? 3000;
  }

  expPct(): number {
    const u = AppState.instance.user;
    if (!u || u.nextLevelExp <= 0) return 0;
    return Math.min(100, Math.round(u.exp / u.nextLevelExp * 100));
  }

  // ====== 签到 ======
  @Builder
  signCard() {
    Row({ space: 12 }) {
      Column() {
        Text('🎁').fontSize(20)
          .fontColor(this.signedToday ? this.t.ink3 : '#FFFFFF')
      }
      .width(40).height(40)
      .borderRadius(12)
      .backgroundColor(this.signedToday ? this.t.surface2 : this.t.tomato)
      .justifyContent(FlexAlign.Center)

      Column() {
        Text(this.signedToday ? '今日已签到' : '每日签到')
          .fontSize(15).fontWeight(FontWeight.Medium).fontColor(this.t.ink)
        Text(this.signedToday
          ? ('已连续签到 ' + this.streakDays + ' 天，明天 +' + (this.streakDays >= 7 ? 15 : 10))
          : ('签到 +' + this.signGain() + ' 经验，连续签到奖励递增'))
          .fontSize(12)
          .fontColor(this.signedToday ? this.t.ink3 : this.t.tomato)
          .margin({ top: 2 })
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)

      Text(this.signedToday ? '✓' : '签到')
        .fontSize(13)
        .fontWeight(FontWeight.Bold)
        .fontColor(this.signedToday ? this.t.ink3 : this.t.tomato)
    }
    .width('100%')
    .padding({ left: 18, right: 18, top: 16, bottom: 16 })
    .backgroundColor(this.signedToday ? this.t.surface : this.t.tomatoSoft)
    .borderRadius(18)
    .border({ width: 1, color: this.signedToday ? this.t.line : '#F0C9B8' })
    .margin({ bottom: 16 })
    .onClick(() => { this.doSign(); })
  }

  doSign() {
    const gain = AppState.signInToday();
    if (gain < 0) {
      promptAction.showToast({ message: '今天已签到', duration: 1200 });
      return;
    }
    this.syncUserState();
    this.uiTick += 1;
    promptAction.showToast({ message: '签到成功 +' + gain + ' 经验', duration: 1500 });
  }

  // ====== 我的森林 ======
  @Builder
  forestCard() {
    Column() {
      Row() {
        Row({ space: 10 }) {
          Text('我的森林').fontFamily(FONT_DISPLAY).fontSize(16).fontColor(this.t.ink)
          Text(this.forestLevel()).fontSize(11).fontWeight(FontWeight.Medium)
            .padding({ left: 9, right: 9, top: 3, bottom: 3 })
            .borderRadius(99)
            .backgroundColor(this.forestLevelBg())
            .fontColor(this.forestLevelColor())
        }
        Blank()
        Text('已种 ' + this.trees() + ' 棵 · 枯萎 ' + this.withered() + ' 棵')
          .fontSize(11).fontColor(this.t.ink3)
      }
      .width('100%')
      .margin({ bottom: 12 })

      Grid() {
        ForEach(this.forestCells(), (c: ForestCell) => {
          GridItem() {
            Stack() {
              Column() {
                if (c.state === 'tree') {
                  Text('🌳').fontSize(26).fontColor(this.t.leafDeep)
                } else if (c.state === 'withered') {
                  Text('🌳').fontSize(26).fontColor(this.t.ink3).opacity(0.75)
                } else {
                  Text('+').fontSize(18).fontColor(this.t.ink3)
                }
              }
              .width('100%').height('100%')
              .borderRadius(14)
              .backgroundColor(c.state === 'tree' ? this.t.leafSoft : (c.state === 'withered' ? this.t.surface2 : Color.Transparent))
              .border(c.state === 'empty' ? { width: 1.5, color: this.t.line, style: BorderStyle.Dashed } : { width: 0 })
              .justifyContent(FlexAlign.Center)

              if (c.state === 'withered') {
                Text('50').fontSize(9).fontWeight(FontWeight.Bold).fontColor(this.t.tomato)
                  .margin({ right: 5, bottom: 4 })
                  .align(Alignment.BottomEnd)
              }
            }
            .width('100%').height(50)
            .onClick(() => {
              if (c.state === 'withered') this.revive();
            })
          }
        }, (c: ForestCell) => c.idx + '_' + c.state)
      }
      .columnsTemplate('1fr 1fr 1fr 1fr')
      .columnsGap(10)
      .rowsGap(10)
      .width('100%')

      Text(this.forestHint())
        .fontSize(11).fontColor(this.t.ink3)
        .margin({ top: 10 })
        .width('100%')
    }
    .width('100%')
    .padding({ left: 18, right: 18, top: 16, bottom: 16 })
    .backgroundColor(this.t.surface)
    .borderRadius(18)
    .border({ width: 1, color: this.t.line })
    .margin({ bottom: 16 })
  }

  totalPomodoros(): number {
    let t = 0;
    Object.keys(AppState.instance.stats).forEach(k => { t += AppState.instance.stats[k].pomodoroCount; });
    return t;
  }

  // 每积累 10 个番茄点亮 1 棵树苗；复活获得的是额外树苗
  trees(): number {
    const bonus = AppState.instance.user?.bonusTrees ?? 0;
    return Math.floor(this.totalPomodoros() / 10) + bonus;
  }

  withered(): number {
    let t = 0;
    Object.keys(AppState.instance.stats).forEach(k => {
      const ic = AppState.instance.stats[k].interruptCounts;
      Object.keys(ic).forEach(r => { t += ic[r]; });
    });
    return Math.floor(t / 3);
  }

  forestLevel(): string {
    const t = this.trees();
    if (t < 5) return '小树苗';
    if (t < 15) return '青葱密林';
    if (t < 30) return '古老森林';
    return '梦幻森林';
  }

  forestLevelBg(): string {
    const t = this.trees();
    if (t < 5) return '#E8F0E3';
    if (t < 15) return '#F4E8CE';
    if (t < 30) return '#DCE8CF';
    return '#EDE3F0';
  }

  forestLevelColor(): string {
    const t = this.trees();
    if (t < 5) return '#6E9B57';
    if (t < 15) return '#D9A441';
    if (t < 30) return '#2C3A28';
    return '#8B6E9B';
  }

  forestHint(): string {
    const t = this.trees();
    const next = t < 5 ? 5 : t < 15 ? 15 : 30;
    let s = '';
    if (t < 30) {
      const name = t < 5 ? '青葱密林' : t < 15 ? '古老森林' : '梦幻森林';
      s = '再种 ' + (next - t) + ' 棵升级到「' + name + '」';
    } else {
      s = '你的森林已达最高等级，继续种下去吧！';
    }
    if (this.withered() > 0) s += ' · 点击枯萎树消耗 50 经验复活';
    return s;
  }

  forestCells(): ForestCell[] {
    const out: ForestCell[] = [];
    const t = this.trees();
    const w = this.withered();
    for (let i = 0; i < t; i++) out.push({ state: 'tree', idx: i });
    for (let i = 0; i < w; i++) out.push({ state: 'withered', idx: 100 + i });
    while (out.length < 8) out.push({ state: 'empty', idx: 200 + out.length });
    return out.slice(0, 12);
  }

  revive() {
    const u = AppState.instance.user;
    if (!u) return;
    if (this.withered() <= 0) return;
    if (u.exp < 50) {
      promptAction.showToast({ message: '经验不足，再专注几次来复活它吧', duration: 1500 });
      return;
    }
    u.exp -= 50;
    u.bonusTrees = (u.bonusTrees ?? 0) + 1;
    const k = todayKey();
    const s = AppState.instance.stats[k];
    if (s) {
      let total = 0;
      Object.keys(s.interruptCounts).forEach(r => { total += s.interruptCounts[r]; });
      if (total > 0) {
        const r = Object.keys(s.interruptCounts).reduce((a, b) => s.interruptCounts[a] > s.interruptCounts[b] ? a : b);
        s.interruptCounts[r] = Math.max(0, s.interruptCounts[r] - 1);
      }
    }
    AppState.saveStats();
    AppState.saveUser();
    this.uiTick += 1;
    promptAction.showToast({ message: '成功复活 1 棵树，森林又绿了 🌿', duration: 1500 });
  }

  // ====== 本周打卡 ======
  @Builder
  weekCard() {
    Column() {
      Row() {
        Text('本周打卡').fontFamily(FONT_DISPLAY).fontSize(16).fontColor(this.t.ink)
        Blank()
        Text('连续 ' + this.streakDays + ' 天 · 明天 +' + (this.streakDays >= 7 ? 15 : 10))
          .fontSize(11).fontColor(this.t.tomato)
      }
      .width('100%')
      .margin({ bottom: 14 })

      Row() {
        ForEach(this.weekCells(), (c: WeekCell) => {
          Column({ space: 6 }) {
            Column() {
              if (c.done) {
                Text('✓').fontSize(15).fontColor('#FFFFFF').fontWeight(FontWeight.Bold)
              } else {
                Text(c.isToday ? '今' : c.label).fontSize(12).fontColor(c.isToday ? this.t.tomato : this.t.ink3)
              }
            }
            .width(34).height(34).borderRadius(17)
            .backgroundColor(c.done ? this.t.leaf : (c.isToday ? this.t.tomatoSoft : Color.Transparent))
            .border(c.done ? { width: 0 } : (c.isToday ? { width: 1.5, color: this.t.tomato } : { width: 1, color: this.t.line, style: BorderStyle.Dashed }))
            .justifyContent(FlexAlign.Center)
            Text(c.label).fontSize(10).fontColor(this.t.ink3)
          }
          .layoutWeight(1)
          .alignItems(HorizontalAlign.Center)
        }, (c: WeekCell) => c.label)
      }
      .width('100%')
    }
    .width('100%')
    .padding({ left: 18, right: 18, top: 16, bottom: 16 })
    .backgroundColor(this.t.surface)
    .borderRadius(18)
    .border({ width: 1, color: this.t.line })
    .margin({ bottom: 16 })
  }

  weekCells(): WeekCell[] {
    const labels: string[] = ['一', '二', '三', '四', '五', '六', '日'];
    const list = AppState.weekDates();
    const d = new Date();
    const todayDow = d.getDay() === 0 ? 7 : d.getDay();
    const out: WeekCell[] = [];
    for (let i = 0; i < 7; i++) {
      const k = list[i];
      const signedList = AppState.instance.user?.signDates ?? [];
      const isLast = AppState.instance.user?.lastSignDate === k;
      const done = (signedList.indexOf(k) >= 0 || isLast) && k <= todayKey();
      const isToday = i + 1 === todayDow;
      out.push({ label: labels[i], done: done, isToday: isToday });
    }
    return out;
  }

  // ====== 徽章 ======
  @Builder
  badgeCard() {
    Column() {
      Text('我的徽章').fontFamily(FONT_DISPLAY).fontSize(16).fontColor(this.t.ink)
        .width('100%')
        .margin({ bottom: 12 })
      Row({ space: 12 }) {
        ForEach(AppState.instance.badges, (b: BadgeItem, i: number) => {
          Column({ space: 7 }) {
            Text(b.icon).fontSize(24).fontColor(b.unlocked ? this.badgeColor(b) : this.t.ink3)
              .opacity(b.unlocked ? 1 : 0.5)
            Text(b.name).fontSize(11).fontColor(this.t.ink2)
          }
          .layoutWeight(1)
          .padding({ top: 16, bottom: 16 })
          .backgroundColor(this.t.surface)
          .borderRadius(16)
          .border({ width: 1, color: this.t.line })
          .opacity(b.unlocked ? 1 : 0.6)
          .onClick(() => {
            this.badgeIdx = i;
            this.showBadge = true;
          })
        }, (b: BadgeItem) => b.id)
      }
      .width('100%')
    }
    .width('100%')
    .margin({ bottom: 20 })
  }

  badgeColor(b: BadgeItem): string {
    if (b.id === 'b1') return this.t.tomato;
    return this.t.leafDeep;
  }

  currentBadge(): BadgeItem | undefined {
    const list = AppState.instance.badges;
    if (this.badgeIdx < 0 || this.badgeIdx >= list.length) return undefined;
    return list[this.badgeIdx];
  }

  // ====== 累计数据 ======
  @Builder
  totalCard() {
    Row() {
      this.totalItem(this.totalFocusHours(), '累计专注', true)
      this.totalItem(this.totalPomodoros() + '', '累计番茄', true)
      this.totalItem('46', '坚持天数', false)
    }
    .width('100%')
    .padding({ top: 16, bottom: 16, left: 18, right: 18 })
    .backgroundColor(this.t.surface)
    .borderRadius(18)
    .border({ width: 1, color: this.t.line })
    .margin({ bottom: 16 })
  }

  @Builder
  totalItem(val: string, label: string, divider: boolean) {
    Column() {
      Text(val).fontFamily(FONT_DISPLAY).fontSize(19).fontColor(this.t.ink)
      Text(label).fontSize(11).fontColor(this.t.ink2).margin({ top: 3 })
    }
    .layoutWeight(1)
    .alignItems(HorizontalAlign.Center)
    .border(divider ? { width: { right: 1 }, color: this.t.line } : { width: 0 })
  }

  totalFocusHours(): string {
    let min = 0;
    Object.keys(AppState.instance.stats).forEach(k => { min += AppState.instance.stats[k].focusMinutes; });
    return Math.floor(min / 60) + ' 小时';
  }

  // ====== 外观主题 ======
  @Builder
  themeCard() {
    Column() {
      Row() {
        Text('外观主题').fontFamily(FONT_DISPLAY).fontSize(16).fontColor(this.t.ink)
        Blank()
        Text(this.t.name).fontSize(11).fontColor(this.t.ink3)
      }
      .width('100%')
      .margin({ bottom: 14 })

      Row() {
        ForEach(THEMES, (th: ThemeDef) => {
          Column({ space: 7 }) {
            Stack() {
              Column()
                .width(52).height(52)
                .borderRadius(26)
                .linearGradient({ angle: 135, colors: [[th.primary, 0], [th.bg, 1]] })
              if (AppState.instance.themeKey === th.key) {
                Column() {
                  Text('✓').fontSize(10).fontColor('#FFFFFF')
                }
                .width(16).height(16).borderRadius(8)
                .backgroundColor(th.leaf)
                .justifyContent(FlexAlign.Center)
                .position({ x: 34, y: 34 })
              }
            }
            .width(52).height(52)
            .border(AppState.instance.themeKey === th.key ? { width: 2.5, color: this.t.leaf } : { width: 1.5, color: this.t.line })

            Text(th.name)
              .fontSize(11)
              .fontColor(AppState.instance.themeKey === th.key ? this.t.ink : this.t.ink2)
              .fontWeight(AppState.instance.themeKey === th.key ? FontWeight.Medium : FontWeight.Normal)
          }
          .layoutWeight(1)
          .alignItems(HorizontalAlign.Center)
          .onClick(() => {
            AppState.instance.themeKey = th.key;
            AppState.saveTheme();
            this.t = themeOf(th.key);
            this.uiTick += 1;
            promptAction.showToast({ message: '已切换到「' + th.name + '」主题', duration: 1500 });
          })
        }, (th: ThemeDef) => th.key)
      }
      .width('100%')
    }
    .width('100%')
    .padding({ left: 18, right: 18, top: 16, bottom: 16 })
    .backgroundColor(this.t.surface)
    .borderRadius(18)
    .border({ width: 1, color: this.t.line })
    .margin({ bottom: 16 })
  }

  // ====== 桌面小组件入口 ======
  @Builder
  widgetEntry() {
    Row({ space: 14 }) {
      Column() {
        Text('📱').fontSize(22).fontColor(this.t.leafDeep)
      }
      .width(46).height(46)
      .borderRadius(13)
      .backgroundColor(this.t.leafSoft)
      .justifyContent(FlexAlign.Center)

      Column() {
        Text('桌面小组件').fontSize(14.5).fontWeight(FontWeight.Medium).fontColor(this.t.ink)
        Text('把今日专注进度放到手机桌面').fontSize(11.5).fontColor(this.t.ink3).margin({ top: 2 })
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)

      Row({ space: 8 }) {
        Column() {
          Text('🍅').fontSize(12).fontColor(this.t.tomato)
        }
        .width(34).height(22).borderRadius(6)
        .backgroundColor(this.t.surface2)
        .border({ width: 1, color: this.t.line })
        .justifyContent(FlexAlign.Center)
        Text('›').fontSize(16).fontColor(this.t.ink3)
      }
    }
    .width('100%')
    .padding({ left: 18, right: 18, top: 16, bottom: 16 })
    .backgroundColor(this.t.surface)
    .borderRadius(18)
    .border({ width: 1, color: this.t.line })
    .margin({ bottom: 16 })
    .onClick(() => { router.pushUrl({ url: 'pages/WidgetPicker' }); })
  }

  // ====== 新手指引入口 ======
  @Builder
  guideEntry() {
    Row({ space: 14 }) {
      Column() {
        Text('🧭').fontSize(22).fontColor(this.t.leafDeep)
      }
      .width(46).height(46)
      .borderRadius(13)
      .backgroundColor(this.t.leafSoft)
      .justifyContent(FlexAlign.Center)

      Column() {
        Text('新手指引').fontSize(14.5).fontWeight(FontWeight.Medium).fontColor(this.t.ink)
        Text('重新观看启动引导与首页引导').fontSize(11.5).fontColor(this.t.ink3).margin({ top: 2 })
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)

      Text('›').fontSize(16).fontColor(this.t.ink3)
    }
    .width('100%')
    .padding({ left: 18, right: 18, top: 16, bottom: 16 })
    .backgroundColor(this.t.surface)
    .borderRadius(18)
    .border({ width: 1, color: this.t.line })
    .margin({ bottom: 16 })
    .onClick(() => { this.replayGuide(); })
  }

  replayGuide() {
    Store.setBool('qf_home_guide', false);
    router.pushUrl({ url: 'pages/Onboarding', params: { replay: true } });
  }

  // ====== 设置列表 ======
  @Builder
  settingsList() {
    Column() {
      this.settingItem('👤', '账号与安全', '手机号 138****6688', 'account')
      Divider().color(this.t.line)
      this.settingItem('🔔', '消息提醒', '专注、签到提醒', 'notify')
      Divider().color(this.t.line)
      this.settingItem('🔒', '隐私设置', '公开时长、在线状态', 'privacy')
      Divider().color(this.t.line)
      this.settingItem('🌿', '关于青番', 'v1.0.0 · AI 番茄钟', 'about')
    }
    .width('100%')
    .padding({ left: 18, right: 18, top: 6, bottom: 6 })
    .backgroundColor(this.t.surface)
    .borderRadius(18)
    .border({ width: 1, color: this.t.line })
    .margin({ bottom: 16 })
  }

  @Builder
  settingItem(icon: string, label: string, desc: string, key: string) {
    Row({ space: 12 }) {
      Column() {
        Text(icon).fontSize(19).fontColor(this.t.leafDeep)
      }
      .width(36).height(36)
      .borderRadius(11)
      .backgroundColor(this.t.surface2)
      .justifyContent(FlexAlign.Center)

      Column() {
        Text(label).fontSize(14).fontWeight(FontWeight.Medium).fontColor(this.t.ink)
        Text(desc).fontSize(11).fontColor(this.t.ink3).margin({ top: 1 })
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)

      Text('›').fontSize(16).fontColor(this.t.ink3)
    }
    .width('100%')
    .padding({ top: 13, bottom: 13 })
    .onClick(() => { this.settings = key; })
  }

  // ====== 退出登录 ======
  @Builder
  logoutBtn() {
    Row({ space: 8 }) {
      Text('🚪').fontSize(18).fontColor(this.t.tomato)
      Text('退出登录').fontSize(14).fontWeight(FontWeight.Medium).fontColor(this.t.tomato)
    }
    .width('100%')
    .height(52)
    .backgroundColor(this.t.surface)
    .borderRadius(18)
    .border({ width: 1, color: this.t.line })
    .justifyContent(FlexAlign.Center)
    .margin({ bottom: 20 })
    .onClick(() => { this.showLogout = true; })
  }

  // ====== 弹窗 ======
  @Builder
  logoutPanel() {
    Stack() {
      Column()
        .width('100%').height('100%')
        .backgroundColor('rgba(30,40,26,0.42)')
        .onClick(() => { this.showLogout = false; })
      Column() {
        Text('退出登录？').fontFamily(FONT_DISPLAY).fontSize(17).fontColor(this.t.ink).margin({ bottom: 6 })
        Text('退出后本机专注数据会保留，\n下次登录即可恢复。')
          .fontSize(12.5).fontColor(this.t.ink2).lineHeight(20).textAlign(TextAlign.Center)
        Row({ space: 10 }) {
          Row() {
            Text('取消').fontSize(14).fontColor(this.t.ink2)
          }
          .layoutWeight(1).height(44).borderRadius(12)
          .border({ width: 1, color: this.t.line })
          .justifyContent(FlexAlign.Center)
          .onClick(() => { this.showLogout = false; })

          Row() {
            Text('退出').fontSize(14).fontColor('#FFFFFF').fontWeight(FontWeight.Medium)
          }
          .layoutWeight(1).height(44).borderRadius(12)
          .backgroundColor(this.t.tomato)
          .justifyContent(FlexAlign.Center)
          .onClick(() => {
            this.showLogout = false;
            AppState.logout();
            router.replaceUrl({ url: 'pages/Home' });
          })
        }
        .width('100%')
        .margin({ top: 18 })
      }
      .width(280)
      .padding(22)
      .backgroundColor(this.t.surface)
      .borderRadius(22)
      .alignItems(HorizontalAlign.Center)
    }
  }

  @Builder
  badgePanel() {
    Stack() {
      Column()
        .width('100%').height('100%')
        .backgroundColor('rgba(30,40,26,0.42)')
        .onClick(() => { this.showBadge = false; })
      if (this.currentBadge() !== undefined) {
        Column() {
          Column() {
            Text(this.currentBadge()!.icon).fontSize(30).fontColor(this.currentBadge()!.unlocked ? this.badgeColor(this.currentBadge()!) : this.t.ink3)
          }
          .width(56).height(56).borderRadius(18)
          .backgroundColor(this.currentBadge()!.unlocked ? this.t.goldSoft : this.t.surface2)
          .justifyContent(FlexAlign.Center)

          Text(this.currentBadge()!.name).fontFamily(FONT_DISPLAY).fontSize(18).fontColor(this.t.ink).margin({ top: 12 })
          Text(this.currentBadge()!.desc).fontSize(12).fontColor(this.currentBadge()!.unlocked ? this.t.ink2 : this.t.ink3).margin({ top: 6 })

          Row() {
            Text(this.currentBadge()!.unlocked ? '已获得' : '未解锁')
              .fontSize(12.5).fontWeight(FontWeight.Medium)
              .fontColor(this.currentBadge()!.unlocked ? this.t.leafDeep : this.t.ink3)
          }
          .width('100%').height(40).borderRadius(12)
          .backgroundColor(this.currentBadge()!.unlocked ? this.t.leafSoft : this.t.surface2)
          .justifyContent(FlexAlign.Center)
          .margin({ top: 16 })

          Row() {
            Text('知道了').fontSize(14).fontColor('#FFFFFF').fontWeight(FontWeight.Medium)
          }
          .width('100%').height(44).borderRadius(12)
          .backgroundColor(this.t.leaf)
          .justifyContent(FlexAlign.Center)
          .margin({ top: 16 })
          .onClick(() => { this.showBadge = false; })
        }
        .width(280)
        .padding(22)
        .backgroundColor(this.t.surface)
        .borderRadius(22)
        .alignItems(HorizontalAlign.Center)
      }
    }
  }

  @Builder
  settingsPanel() {
    Stack() {
      Column()
        .width('100%').height('100%')
        .backgroundColor('rgba(30,40,26,0.42)')
        .onClick(() => { this.settings = ''; })
      Column() {
        Row() {
          Text(this.settingsTitle()).fontFamily(FONT_DISPLAY).fontSize(17).fontColor(this.t.ink)
          Blank()
          Text('×').fontSize(22).fontColor(this.t.ink3)
            .onClick(() => { this.settings = ''; })
        }
        .width('100%')
        .margin({ bottom: 16 })

        if (this.settings === 'account') {
          Column() {
            this.kvRow('绑定手机', '138****6688')
            Divider().color(this.t.line)
            this.kvRow('绑定微信', '已绑定')
            Divider().color(this.t.line)
            this.kvRow('登录密码', '••••••••')
            Text('✓ 账号已通过实名校验，安全等级：高')
              .fontSize(11).fontColor(this.t.ink3).margin({ top: 12 }).width('100%')
          }
          .width('100%')
        } else if (this.settings === 'notify') {
          Column() {
            this.toggleRow('专注完成提醒', this.notifyFocus, (v) => { this.notifyFocus = v; })
            Divider().color(this.t.line)
            this.toggleRow('每日签到提醒', this.notifySign, (v) => { this.notifySign = v; })
            Divider().color(this.t.line)
            this.toggleRow('好友动态提醒', this.notifyFriend, (v) => { this.notifyFriend = v; })
          }
          .width('100%')
        } else if (this.settings === 'privacy') {
          Column() {
            this.toggleRow2('公开我的专注时长', '好友可见你的专注记录', this.privacyTime, (v) => { this.privacyTime = v; })
            Divider().color(this.t.line)
            this.toggleRow2('展示在线状态', '自习室中显示我在线', this.privacyOnline, (v) => { this.privacyOnline = v; })
          }
          .width('100%')
        } else {
          Column() {
            Text('🍅').fontSize(64)
            Text('青番').fontFamily(FONT_DISPLAY).fontSize(20).fontColor(this.t.ink).margin({ top: 10 })
            Text('v1.0.0 · AI 番茄钟智能助手').fontSize(12).fontColor(this.t.ink3).margin({ top: 4 })
            Text('把专注，种成一片森林。\n一款会陪你成长的专注工具。')
              .fontSize(12).fontColor(this.t.ink2).lineHeight(20).margin({ top: 14 }).textAlign(TextAlign.Center)
            Text('© 2026 青番团队').fontSize(11).fontColor(this.t.ink3).margin({ top: 14 })
          }
          .width('100%')
          .alignItems(HorizontalAlign.Center)
        }
      }
      .width(300)
      .padding(22)
      .backgroundColor(this.t.surface)
      .borderRadius(22)
    }
  }

  settingsTitle(): string {
    if (this.settings === 'account') return '账号与安全';
    if (this.settings === 'notify') return '消息提醒';
    if (this.settings === 'privacy') return '隐私设置';
    return '关于青番';
  }

  @Builder
  kvRow(k: string, v: string) {
    Row() {
      Text(k).fontSize(13.5).fontColor(this.t.ink2)
      Blank()
      Text(v).fontSize(13.5).fontColor(this.t.ink).fontWeight(FontWeight.Medium)
    }
    .width('100%')
    .padding({ top: 13, bottom: 13 })
  }

  @Builder
  toggleRow(label: string, value: boolean, onChange: (v: boolean) => void) {
    Row() {
      Text(label).fontSize(13.5).fontColor(this.t.ink).layoutWeight(1)
      Toggle({ type: ToggleType.Switch, isOn: value })
        .selectedColor(this.t.leaf)
        .onChange((v: boolean) => { onChange(v); })
    }
    .width('100%')
    .padding({ top: 13, bottom: 13 })
  }

  @Builder
  toggleRow2(label: string, desc: string, value: boolean, onChange: (v: boolean) => void) {
    Row() {
      Column() {
        Text(label).fontSize(13.5).fontColor(this.t.ink)
        Text(desc).fontSize(11).fontColor(this.t.ink3).margin({ top: 2 })
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)
      Toggle({ type: ToggleType.Switch, isOn: value })
        .selectedColor(this.t.leaf)
        .onChange((v: boolean) => { onChange(v); })
    }
    .width('100%')
    .padding({ top: 13, bottom: 13 })
  }
}
