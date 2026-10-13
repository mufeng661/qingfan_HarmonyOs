import { router, promptAction } from '@kit.ArkUI';
import { AppState } from '../model/AppState';
import { themeOf, BadgeItem, ThemeDef, FONT_DISPLAY, BADGE_TIER_NAMES } from '../model/Types';
import { BadgeIcon } from '../components/BadgeIcon';
import { CoinBadge } from '../components/CoinBadge';

@Entry
@Component
struct Badges {
  @State list: BadgeItem[] = [];
  @State refreshing: boolean = false;
  @State showPanel: boolean = false;
  @State idx: number = 0;
  @State previewNext: boolean = false;
  private t: ThemeDef = themeOf(AppState.instance.themeKey);

  aboutToAppear() {
    this.recalcBadges();
  }

  onPageShow() {
    this.recalcBadges();
  }

  onRefresh() {
    this.refreshing = true;
    this.recalcBadges();
    setTimeout(() => {
      this.refreshing = false;
      promptAction.showToast({ message: '已刷新', duration: 1200 });
    }, 600);
  }

  recalcBadges() {
    // 三端统一口径（2026-10-13）：重算逻辑已下沉到 AppState.recalcBadges()，
    // 「我的」页与本页共用同一份实现，避免两处口径漂移。
    AppState.recalcBadges();
    this.list = AppState.instance.badges.slice();
  }

  unlockedCount(): number {
    let n = 0;
    for (let i = 0; i < this.list.length; i++) {
      if (this.list[i].unlocked) {
        n += 1;
      }
    }
    return n;
  }

  curBadge(): BadgeItem | undefined {
    if (this.idx < 0 || this.idx >= this.list.length) {
      return undefined;
    }
    return this.list[this.idx];
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

  // 已获得：flame/tomato → 番茄红，其余 → 叶绿；未解锁：ink3（对齐小程序）
  iconColor(b: BadgeItem): string {
    if (!b.unlocked) {
      return this.t.ink3;
    }
    return (b.iconKey === 'flame' || b.iconKey === 'tomato') ? this.t.tomato : this.t.leafDeep;
  }

  build() {
    Stack() {
      Column() {
        Row() {
          Text('‹').fontSize(28).fontColor(this.t.ink)
            .padding({ left: 8, right: 8 })
            .onClick(() => { router.back(); })
          Text('我的徽章').fontSize(18).fontWeight(FontWeight.Bold).fontColor(this.t.ink)
            .layoutWeight(1).textAlign(TextAlign.Center)
          Text(' ').fontSize(18).padding({ left: 8, right: 8 })
        }
        .width('100%')
        .padding({ top: 44, bottom: 12, left: 12, right: 12 })

        Row() {
          Text('已获得 ' + this.unlockedCount() + ' / ' + this.list.length)
            .fontSize(13)
            .fontColor(this.t.ink2)
        }
        .width('100%')
        .padding({ left: 18, right: 18 })
        .margin({ bottom: 10 })

        Refresh({ refreshing: $$this.refreshing }) {
          Grid() {
            ForEach(this.list, (b: BadgeItem, i: number) => {
              GridItem() {
                Column({ space: 7 }) {
                  Stack({ alignContent: Alignment.BottomEnd }) {
                    BadgeIcon({
                      iconKey: b.iconKey,
                      iconSize: 24,
                      color: this.iconColor(b)
                    })
                    if (!b.unlocked) {
                      BadgeIcon({ iconKey: 'lock', iconSize: 12, color: this.t.ink3 })
                        .margin({ right: -7, bottom: -7 })
                    }
                  }
                  Text(b.name).fontSize(11).fontColor(this.t.ink2)
                }
                .width('100%')
                .padding({ top: 16, bottom: 16 })
                .backgroundColor(this.t.surface)
                .borderRadius(16)
                .border({ width: 1, color: this.t.line })
                .opacity(b.unlocked ? 1 : 0.5)
                .onClick(() => {
                  this.idx = i;
                  this.previewNext = false;
                  this.showPanel = true;
                })
              }
            }, (b: BadgeItem) => b.id + '-' + b.tier + '-' + (b.unlocked ? 1 : 0))
          }
          .columnsTemplate('1fr 1fr')
          .columnsGap(12)
          .rowsGap(12)
          .padding({ left: 18, right: 18, top: 8, bottom: 24 })
          .scrollBar(BarState.Off)
          .edgeEffect(EdgeEffect.Spring)
        }
        .layoutWeight(1)
        .onRefreshing(() => { this.onRefresh(); })
      }
      .width('100%')
      .height('100%')

      if (this.showPanel) {
        this.detailPanel()
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor(this.t.bg)
  }

  // 徽章详情弹窗：3D 金币（可拖动旋转检视）+ 已获得/未解锁胶囊 + 知道了
  @Builder
  detailPanel() {
    Stack() {
      Column()
        .width('100%').height('100%')
        .backgroundColor('rgba(30,40,26,0.42)')
        .onClick(() => { this.showPanel = false; })
      if (this.curBadge() !== undefined) {
        Column() {
          // 右上角：下一等级预览按钮（已解锁且未满级时显示）
          Row() {
            Blank()
            if (this.curBadge()!.unlocked && this.tierOf(this.curBadge()!) >= 1
              && this.tierOf(this.curBadge()!) < 4) {
              Text(this.previewNext
                ? '返回当前等级'
                : '下一等级 · ' + BADGE_TIER_NAMES[this.tierOf(this.curBadge()!) + 1])
                .fontSize(11.5).fontWeight(FontWeight.Bold)
                .fontColor(this.previewNext ? this.t.ink2 : this.t.gold)
                .padding({ left: 10, right: 10, top: 6, bottom: 6 })
                .backgroundColor(this.previewNext ? this.t.surface2 : this.t.goldSoft)
                .borderRadius(99)
                .onClick(() => { this.previewNext = !this.previewNext; })
            }
          }
          .width('100%')
          .margin({ bottom: 2 })

          CoinBadge({
            iconKey: this.curBadge()!.iconKey,
            tier: this.previewNext ? this.tierOf(this.curBadge()!) + 1 : this.tierOf(this.curBadge()!)
          })

          Text('徽章自动旋转 · 可拖动检视')
            .fontSize(11).fontColor(this.t.ink3)
            .margin({ top: 6 })

          Text(this.curBadge()!.name)
            .fontFamily(FONT_DISPLAY)
            .fontSize(18).fontColor(this.t.ink)
            .margin({ top: 10 })

          Text(this.curBadge()!.desc)
            .fontSize(12)
            .fontColor(this.curBadge()!.unlocked ? this.t.ink2 : this.t.ink3)
            .lineHeight(19.2)
            .margin({ top: 6 })
            .textAlign(TextAlign.Center)

          Row() {
            Text(this.curBadge()!.unlocked
              ? (this.previewNext
                ? '下一等级 · ' + BADGE_TIER_NAMES[this.tierOf(this.curBadge()!) + 1]
                : '已获得 · ' + BADGE_TIER_NAMES[this.tierOf(this.curBadge()!)])
              : '未解锁')
              .fontSize(12.5).fontWeight(FontWeight.Bold)
              .fontColor(this.curBadge()!.unlocked ? this.t.leafDeep : this.t.ink3)
          }
          .width('100%').padding({ top: 10, bottom: 10 }).borderRadius(12)
          .backgroundColor(this.curBadge()!.unlocked ? this.t.leafSoft : this.t.surface2)
          .justifyContent(FlexAlign.Center)
          .margin({ top: 16 })

          Row() {
            Text('知道了').fontSize(14).fontColor('#FFFFFF').fontWeight(FontWeight.Bold)
          }
          .width('100%').padding({ top: 11, bottom: 11 }).borderRadius(12)
          .backgroundColor(this.t.leaf)
          .justifyContent(FlexAlign.Center)
          .margin({ top: 16 })
          .onClick(() => { this.showPanel = false; })
        }
        .width(300)
        .padding(22)
        .backgroundColor(this.t.surface)
        .borderRadius(22)
        .alignItems(HorizontalAlign.Center)
      }
    }
  }
}
