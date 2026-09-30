import { router, promptAction } from '@kit.ArkUI';
import { AppState } from '../model/AppState';
import { themeOf, BadgeItem, ThemeDef } from '../model/Types';

@Entry
@Component
struct Badges {
  @State list: BadgeItem[] = [];
  @State refreshing: boolean = false;
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
    const list = AppState.instance.badges;
    const totalPomo = this.totalPomo();
    const u = AppState.instance.user;
    list.forEach(b => {
      if (b.id === 'b1') b.unlocked = totalPomo >= 1;
      if (b.id === 'b2') b.unlocked = (u?.streak ?? 0) >= 7;
      if (b.id === 'b3') b.unlocked = totalPomo >= 5;
      if (b.id === 'b4') {
        const key = new Date().toISOString().slice(0, 10);
        b.unlocked = (AppState.instance.stats[key]?.pomodoroCount ?? 0) >= 4;
      }
    });
    AppState.saveBadges();
    this.list = list.slice();
  }

  totalPomo(): number {
    let total = 0;
    Object.keys(AppState.instance.stats).forEach(k => {
      total += AppState.instance.stats[k].pomodoroCount;
    });
    return total;
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

  build() {
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

      Text('已获得 ' + this.unlockedCount() + ' / ' + this.list.length)
        .fontSize(14)
        .fontColor(this.t.ink2)
        .margin({ left: 16 })

      Refresh({ refreshing: $$this.refreshing }) {
        Grid() {
          ForEach(this.list, (b: BadgeItem) => {
            GridItem() {
              Column() {
                Text(b.icon).fontSize(40)
                  .opacity(b.unlocked ? 1 : 0.3)
                Text(b.name)
                  .fontSize(13).fontWeight(FontWeight.Bold)
                  .fontColor(b.unlocked ? this.t.ink : this.t.ink3)
                  .margin({ top: 6 })
                Text(b.desc)
                  .fontSize(11)
                  .fontColor(this.t.ink3)
                  .margin({ top: 4 })
                  .textAlign(TextAlign.Center)
                Text(b.unlocked ? '✓ 已获得' : '🔒 未解锁')
                  .fontSize(11)
                  .fontColor(b.unlocked ? this.t.leaf : this.t.ink3)
                  .margin({ top: 6 })
              }
              .padding({ top: 16, bottom: 16 })
              .backgroundColor(this.t.surface)
              .borderRadius(14)
              .border({ width: 1, color: this.t.line })
              .opacity(b.unlocked ? 1 : 0.7)
              .alignItems(HorizontalAlign.Center)
              .width('100%')
            }
          })
        }
        .columnsTemplate('1fr 1fr')
        .columnsGap(10)
        .rowsGap(10)
        .padding({ left: 16, right: 16, top: 12 })
        .scrollBar(BarState.Off)
        .edgeEffect(EdgeEffect.Spring)
      }
      .layoutWeight(1)
      .onRefreshing(() => { this.onRefresh(); })
    }
    .width('100%')
    .height('100%')
    .backgroundColor(this.t.bg)
  }
}
