import { router } from '@kit.ArkUI';
import { promptAction } from '@kit.ArkUI';
import { AppState } from '../model/AppState';
import { themeOf, THEMES, ThemeDef, ThemeKey, BadgeItem, FONT_DISPLAY, TomatoCell, BADGE_TIER_NAMES, expForLevel, tierOfLevel, LevelTier, firstCp } from '../model/Types';
import { Store, todayKey } from '../model/Store';
import { TabBar } from '../components/TabBar';
import { BadgeIcon } from '../components/BadgeIcon';
import { CoinBadge } from '../components/CoinBadge';

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
@State badgePreviewNext: boolean = false;
  @State notifyFocus: boolean = true;
  @State notifySign: boolean = true;
  @State notifyFriend: boolean = false;
  @State privacyTime: boolean = true;
  @State privacyOnline: boolean = false;
  @State signedToday: boolean = false;
  @State streakDays: number = 0;
  @State loggedIn: boolean = false;
  @State refreshing: boolean = false;
  // 资料字段的 @State 镜像。
  // AppState.instance.user 是普通对象，直接改它的属性不会触发渲染；而 uiTick 虽然一直在自增，
  // 却从没被 build 读过（ArkUI 只重绘「读到了该状态」的节点），所以从「编辑资料」返回后
  // 要手动下拉刷新才会显示新昵称/签名。这里把资料抄成 @State，配合下面的跨页广播即时更新。
  @StorageLink('qfProfileTick') @Watch('onProfileTick') profileTick: number = 0;
  @State pNick: string = '';
  @State pBio: string = '';
  @State pAvatar: string = '';
  @State pLevel: number = 1;
  @State pExp: number = 0;
  @State pNextExp: number = 100;
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
    AppState.syncFromCloud().then(() => {
      this.syncUserState();
      this.uiTick += 1;
    });
  }

  onRefresh() {
    this.refreshing = true;
    AppState.syncFromCloud().then(() => {
      this.syncUserState();
      this.uiTick += 1;
      this.refreshing = false;
      promptAction.showToast({ message: '已刷新', duration: 1200 });
    });
  }

  syncUserState() {
    const s = AppState.recomputeStreak();
    AppState.saveUser();
    // 「我的」页的徽章卡直接读 AppState.instance.badges，
    // 这里即时按三端统一口径重算，才能和「我的徽章」页、Web/小程序端保持一致
    // （否则刚解锁的徽章要先进一次徽章页才会变亮）。
    AppState.recalcBadges();
    this.loggedIn = AppState.isLoggedIn();
    this.signedToday = AppState.isSignedToday();
    this.streakDays = s;
    this.pullProfile();
  }

  // 把资料从 AppState 抄进 @State 镜像（只有读到 UI 上的状态才可观察）
  pullProfile(): void {
    const u = AppState.instance.user;
    this.pNick = u?.nickname ?? '林小满';
    this.pBio = u?.bio ?? '把专注，种成一片番茄园';
    this.pAvatar = u?.avatarSeed ?? '';
    this.pLevel = u?.level ?? 1;
    this.pExp = u?.exp ?? 0;
    this.pNextExp = u?.nextLevelExp ?? expForLevel(1);
  }

  // 别的页面（编辑资料）或云端同步改了资料时，立刻刷新镜像 —— 不再需要手动刷新
  onProfileTick() {
    this.pullProfile();
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
          Refresh({ refreshing: $$this.refreshing }) {
          Scroll() {
            Column() {
              this.profileHeader()
              this.signCard()
              this.tomatoCard()
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
          .scrollBar(BarState.Off)
          .edgeEffect(EdgeEffect.Spring)
          }
          .layoutWeight(1)
          .onRefreshing(() => { this.onRefresh(); })

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
        Text('把专注，种成一片番茄园')
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

  // ====== 个人信息 + 等级卡片（仿小黑盒） ======
  @Builder
  profileHeader() {
    Stack({ alignContent: Alignment.TopStart }) {
      // 渐变背景卡
      Column() {
        Row({ space: 14 }) {
          // 头像 + 等级徽章
          Stack({ alignContent: Alignment.BottomEnd }) {
            Column() {
              Text(this.firstChar())
                .fontSize(24).fontWeight(FontWeight.Medium).fontColor('#FFFFFF')
            }
            .width(58).height(58)
            .borderRadius(29)
            .linearGradient({ angle: 135, colors: [['rgba(255,255,255,0.3)', 0], ['rgba(255,255,255,0.08)', 1]] })
            .border({ width: 2, color: 'rgba(255,255,255,0.4)' })
            .justifyContent(FlexAlign.Center)

            Text('Lv.' + this.pLevel)
              .fontSize(10).fontWeight(FontWeight.Bold).fontColor('#FFFFFF')
              .padding({ left: 7, right: 7, top: 2, bottom: 2 })
              .backgroundColor(this.tierColor())
              .borderRadius(99)
              .border({ width: 2, color: '#FFFFFF' })
              .offset({ x: 2, y: 2 })
          }

          // 昵称 + 段位名
          Column() {
            Row({ space: 6 }) {
              Text(this.pNick)
                .fontSize(18).fontWeight(FontWeight.Medium).fontColor('#FFFFFF')
              Text('›').fontSize(14).fontColor('rgba(255,255,255,0.5)')
            }
            Row({ space: 6 }) {
              Text(this.pBio)
                .fontSize(12).fontColor('rgba(255,255,255,0.7)')
                .maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
                .layoutWeight(1)
            }
            .margin({ top: 5 })
          }
          .alignItems(HorizontalAlign.Start)
          .layoutWeight(1)
        }
        .width('100%')
        .padding({ left: 20, right: 20, top: 20, bottom: 16 })

        // 经验进度条区域
        Column() {
          Row() {
            Text('经验值').fontSize(12).fontColor('rgba(255,255,255,0.6)')
            Blank()
            Text() {
              Span(this.pExp + '').fontFamily(FONT_DISPLAY).fontSize(15).fontColor('#FFFFFF')
              Span(' / ' + this.pNextExp).fontSize(11).fontColor('rgba(255,255,255,0.5)')
            }
          }
          .width('100%')
          .margin({ bottom: 8 })

          Stack({ alignContent: Alignment.Start }) {
            Row().width('100%').height(8).borderRadius(99)
              .backgroundColor('rgba(255,255,255,0.12)')
            Row().width(this.expPct() + '%').height(8).borderRadius(99)
              .linearGradient({ angle: 90, colors: [['rgba(255,255,255,0.6)', 0], ['#FFFFFF', 1]] })
          }
          .width('100%')

          Text('再获得 ' + (this.expMax() - this.pExp) + ' 经验升级到 Lv.' + (this.pLevel + 1))
            .fontSize(11).fontColor('rgba(255,255,255,0.4)')
            .margin({ top: 8 })
            .width('100%')
        }
        .width('100%')
        .padding({ left: 20, right: 20, bottom: 18 })
      }
      .width('100%')
      .borderRadius(20)
      .linearGradient({ angle: 140, colors: [[this.tierBgFrom(), 0], [this.tierBgTo(), 1]] })
      .onClick(() => { router.pushUrl({ url: 'pages/EditProfile' }); })
    }
    .width('100%')
    .margin({ bottom: 16 })
  }

  tierColor(): string {
    return tierOfLevel(this.pLevel).color;
  }

  tierBgFrom(): string {
    return tierOfLevel(this.pLevel).bgFrom;
  }

  tierBgTo(): string {
    return tierOfLevel(this.pLevel).bgTo;
  }

  firstChar(): string {
    // 优先用「编辑资料」里挑的自定义头像；没挑过则退回昵称首字。
    // 用 firstCp 按码点取，emoji 昵称不会被劈成半个字符。
    if (this.pAvatar.length > 0) return firstCp(this.pAvatar);
    return firstCp(this.pNick);
  }

  expMax(): number {
    return this.pNextExp;
  }

  expPct(): number {
    if (this.pNextExp <= 0) return 0;
    return Math.min(100, Math.round(this.pExp / this.pNextExp * 100));
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

  // ====== 我的番茄园 ======
  @Builder
  tomatoCard() {
    Column() {
      Row() {
        Row({ space: 10 }) {
          Text('我的番茄园').fontFamily(FONT_DISPLAY).fontSize(16).fontColor(this.t.ink)
          Text(AppState.tomatoStats().level).fontSize(11).fontWeight(FontWeight.Medium)
            .padding({ left: 9, right: 9, top: 3, bottom: 3 })
            .borderRadius(99)
            .backgroundColor(this.t.tomatoSoft)
            .fontColor(this.t.tomato)
        }
        Blank()
        Text('今日 +' + AppState.todayPlanted() + ' · 进度 ' + AppState.todayProgress() + '/10')
          .fontSize(11).fontColor(this.t.ink3)
      }
      .width('100%')
      .margin({ bottom: 10 })

      Stack({ alignContent: Alignment.Start }) {
        Row().width('100%').height(8).borderRadius(99).backgroundColor(this.t.surface2)
        Row().width(AppState.tomatoStats().pct + '%').height(8).borderRadius(99)
          .linearGradient({ angle: 90, colors: [[this.t.leaf, 0], [this.t.tomato, 1]] })
      }
      .width('100%')
      .margin({ bottom: 12 })

      Grid() {
        ForEach(AppState.tomatoCells(), (c: TomatoCell) => {
          GridItem() {
            Column() {
              if (c.state === 'tomato') {
                Text('🍅').fontSize(26)
              } else if (c.state === 'dead') {
                Text('🥀').fontSize(24).opacity(0.7)
              } else if (c.state === 'more') {
                Text('+' + c.more).fontSize(14).fontWeight(FontWeight.Bold).fontColor(this.t.tomato)
              } else {
                Text('+').fontSize(18).fontColor(this.t.ink3)
              }
            }
            .width('100%').height(50)
            .borderRadius(14)
            .backgroundColor(c.state === 'empty' ? Color.Transparent : (c.state === 'more' ? this.t.tomatoSoft : this.t.surface))
            .border(c.state === 'empty' ? { width: 1.5, color: this.t.line, style: BorderStyle.Dashed } : { width: 0 })
            .justifyContent(FlexAlign.Center)
            .onClick(() => {
              if (c.state === 'dead') this.clearDead();
            })
          }
        }, (c: TomatoCell) => c.idx + '_' + c.state)
      }
      .columnsTemplate('1fr 1fr 1fr 1fr')
      .columnsGap(10)
      .rowsGap(10)
      .width('100%')

      Text('已种植 ' + AppState.tomatoStats().harvested + ' 棵 · 枯萎 ' + AppState.tomatoStats().dead + ' 棵')
        .fontSize(11).fontColor(this.t.ink3)
        .margin({ top: 10 }).width('100%')
      Text(AppState.tomatoHint())
        .fontSize(11).fontColor(this.t.ink3)
        .margin({ top: 4 }).width('100%')
      if (AppState.tomatoStats().dead > 0) {
        Text('可用专注番茄 ' + AppState.tomatoStats().focusAvailable + ' · 点击枯萎番茄消耗 2 个清除')
          .fontSize(11).fontColor(this.t.tomato)
          .margin({ top: 4 }).width('100%')
      }
    }
    .width('100%')
    .padding({ left: 18, right: 18, top: 16, bottom: 16 })
    .backgroundColor(this.t.surface)
    .borderRadius(18)
    .border({ width: 1, color: this.t.line })
    .margin({ bottom: 16 })
  }

  totalPomodoros(): number {
    return AppState.totalPomodoros();
  }

  clearDead() {
    const s = AppState.tomatoStats();
    if (s.dead <= 0) return;
    if (s.focusAvailable < 2) {
      promptAction.showToast({ message: '专注番茄不足，需要 2 个才能清除', duration: 1500 });
      return;
    }
    if (AppState.clearDead()) {
      this.uiTick += 1;
      promptAction.showToast({ message: '已清除 1 棵枯萎番茄 🥀', duration: 1500 });
    }
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
            Stack({ alignContent: Alignment.BottomEnd }) {
              BadgeIcon({
                iconKey: b.iconKey,
                iconSize: 24,
                color: this.badgeColor(b)
              })
              if (!b.unlocked) {
                BadgeIcon({ iconKey: 'lock', iconSize: 12, color: this.t.ink3 })
                  .margin({ right: -7, bottom: -7 })
              }
            }
            Text(b.name).fontSize(11).fontColor(this.t.ink2)
          }
          .layoutWeight(1)
          .padding({ top: 16, bottom: 16 })
          .backgroundColor(this.t.surface)
          .borderRadius(16)
          .border({ width: 1, color: this.t.line })
          .opacity(b.unlocked ? 1 : 0.5)
          .onClick(() => {
            this.badgeIdx = i;
            this.badgePreviewNext = false;
            this.showBadge = true;
          })
        }, (b: BadgeItem) => b.id + '-' + b.tier + '-' + (b.unlocked ? 1 : 0))
      }
      .width('100%')
    }
    .width('100%')
    .margin({ bottom: 20 })
  }

  // 已获得：flame/tomato → 番茄红，其余 → 叶绿；未解锁：ink3（对齐小程序）
  badgeColor(b: BadgeItem): string {
    if (!b.unlocked) {
      return this.t.ink3;
    }
    return (b.iconKey === 'flame' || b.iconKey === 'tomato') ? this.t.tomato : this.t.leafDeep;
  }

  currentBadge(): BadgeItem | undefined {
    const list = AppState.instance.badges;
    if (this.badgeIdx < 0 || this.badgeIdx >= list.length) return undefined;
    return list[this.badgeIdx];
  }

  // 稀有度阶段取值：已解锁至少青铜（旧存档可能 unlocked=true 但 tier 缺失/为 0），未解锁为灰
  tierOf(b: BadgeItem): number {
    const t = b.tier;
    if (b.unlocked) {
      if (t === undefined || t < 1 || t > 4) {
        return 1;
      }
      return t;
    }
    return 0;
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
      Divider().color(this.t.line)
      this.settingItem('📄', '用户协议', '查看服务条款', 'agreement-user')
      Divider().color(this.t.line)
      this.settingItem('🔐', '隐私政策', '我们如何保护你的数据', 'agreement-privacy')
      Divider().color(this.t.line)
      this.settingItem('✉️', '意见反馈', '把建议告诉我们', 'feedback')
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
    .onClick(() => {
      if (key === 'about') {
        router.pushUrl({ url: 'pages/About' });
      } else if (key === 'agreement-user') {
        router.pushUrl({ url: 'pages/Agreement', params: { type: 'user' } });
      } else if (key === 'agreement-privacy') {
        router.pushUrl({ url: 'pages/Agreement', params: { type: 'privacy' } });
      } else if (key === 'feedback') {
        router.pushUrl({ url: 'pages/Feedback' });
      } else {
        this.settings = key;
      }
    })
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
          // 右上角：下一等级预览按钮（已解锁且未满级时显示）
          Row() {
            Blank()
            if (this.currentBadge()!.unlocked && this.tierOf(this.currentBadge()!) >= 1
              && this.tierOf(this.currentBadge()!) < 4) {
              Text(this.badgePreviewNext
                ? '返回当前等级'
                : '下一等级 · ' + BADGE_TIER_NAMES[this.tierOf(this.currentBadge()!) + 1])
                .fontSize(11.5).fontWeight(FontWeight.Bold)
                .fontColor(this.badgePreviewNext ? this.t.ink2 : this.t.gold)
                .padding({ left: 10, right: 10, top: 6, bottom: 6 })
                .backgroundColor(this.badgePreviewNext ? this.t.surface2 : this.t.goldSoft)
                .borderRadius(99)
                .onClick(() => { this.badgePreviewNext = !this.badgePreviewNext; })
            }
          }
          .width('100%')
          .margin({ bottom: 2 })

          CoinBadge({
            iconKey: this.currentBadge()!.iconKey,
            tier: this.badgePreviewNext ? this.tierOf(this.currentBadge()!) + 1 : this.tierOf(this.currentBadge()!)
          })

          Text('徽章自动旋转 · 可拖动检视').fontSize(11).fontColor(this.t.ink3).margin({ top: 6 })
          Text(this.currentBadge()!.name).fontFamily(FONT_DISPLAY).fontSize(18).fontColor(this.t.ink).margin({ top: 10 })
          Text(this.currentBadge()!.desc).fontSize(12).fontColor(this.currentBadge()!.unlocked ? this.t.ink2 : this.t.ink3).margin({ top: 6 }).textAlign(TextAlign.Center)

          Row() {
            Text(this.currentBadge()!.unlocked
              ? (this.badgePreviewNext
                ? '下一等级 · ' + BADGE_TIER_NAMES[this.tierOf(this.currentBadge()!) + 1]
                : '已获得 · ' + BADGE_TIER_NAMES[this.tierOf(this.currentBadge()!)])
              : '未解锁')
              .fontSize(12.5).fontWeight(FontWeight.Bold)
              .fontColor(this.currentBadge()!.unlocked ? this.t.leafDeep : this.t.ink3)
          }
          .width('100%').padding({ top: 10, bottom: 10 }).borderRadius(12)
          .backgroundColor(this.currentBadge()!.unlocked ? this.t.leafSoft : this.t.surface2)
          .justifyContent(FlexAlign.Center)
          .margin({ top: 16 })

          Row() {
            Text('知道了').fontSize(14).fontColor('#FFFFFF').fontWeight(FontWeight.Bold)
          }
          .width('100%').padding({ top: 11, bottom: 11 }).borderRadius(12)
          .backgroundColor(this.t.leaf)
          .justifyContent(FlexAlign.Center)
          .margin({ top: 16 })
          .onClick(() => { this.showBadge = false; })
        }
        .width(300)
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
            Text('把专注，种成一片番茄园。\n一款会陪你成长的专注工具。')
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
