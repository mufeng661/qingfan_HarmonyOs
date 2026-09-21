import { router } from '@kit.ArkUI';
import { AppState } from '../model/AppState';
import { themeOf, FRIEND_RANK, FriendRankItem, ThemeDef, FONT_DISPLAY } from '../model/Types';
import { TabBar } from '../components/TabBar';

interface RankRow {
  name: string;
  minutes: number;
  xp: number;
  isMe: boolean;
  color: string;
  rank: number;
}

@Entry
@Component
struct Rank {
  private t: ThemeDef = themeOf(AppState.instance.themeKey);
  private medalColors: string[] = ['#D9A441', '#9AA6B2', '#C08A5E'];

  build() {
    Column() {
      // 顶栏
      Row() {
        Text('好友排行')
          .fontFamily(FONT_DISPLAY)
          .fontSize(24)
          .fontColor(this.t.ink)
          .layoutWeight(1)
        Text('本周')
          .fontSize(12.5)
          .fontColor('#FFFFFF')
          .padding({ left: 13, right: 13, top: 7, bottom: 7 })
          .borderRadius(99)
          .backgroundColor(this.t.leaf)
      }
      .width('100%')
      .padding({ left: 22, right: 22, top: 20, bottom: 16 })

      Scroll() {
        Column() {
          this.myCard()
          Column({ space: 10 }) {
            ForEach(this.sorted(), (r: RankRow) => {
              this.rankRow(r)
            }, (r: RankRow) => r.name)
          }
          .width('100%')
          Column().height(16)
        }
        .width('100%')
        .padding({ left: 22, right: 22, top: 4 })
      }
      .layoutWeight(1)
      .scrollBar(BarState.Off)
      .edgeEffect(EdgeEffect.Spring)

      TabBar({ active: 'rank' })
    }
    .width('100%')
    .height('100%')
    .backgroundColor(this.t.bg)
  }

  // ====== 我的排名卡 ======
  @Builder
  myCard() {
    Row({ space: 14 }) {
      Text(this.meRank() + '')
        .fontFamily(FONT_DISPLAY)
        .fontSize(30)
        .fontColor('#FFFFFF')
        .opacity(0.9)
        .width(40)
        .textAlign(TextAlign.Center)

      Column() {
        Text(this.myName().slice(0, 1))
          .fontSize(17).fontWeight(FontWeight.Medium).fontColor('#FFFFFF')
      }
      .width(40).height(40)
      .borderRadius(20)
      .backgroundColor('rgba(255,255,255,0.25)')
      .justifyContent(FlexAlign.Center)

      Column() {
        Row({ space: 6 }) {
          Text(this.myName())
            .fontSize(15).fontWeight(FontWeight.Medium).fontColor('#FFFFFF')
          Text('我').fontSize(11).fontColor('rgba(255,255,255,0.7)')
        }
        Text(this.overtakeHint())
          .fontSize(11.5)
          .fontColor('rgba(255,255,255,0.8)')
          .margin({ top: 2 })
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)

      Column() {
        Text() {
          Span((this.me()?.minutes ?? 0) + '').fontFamily(FONT_DISPLAY).fontSize(18).fontColor('#FFFFFF')
          Span(' 分钟').fontSize(11).fontColor('rgba(255,255,255,0.7)')
        }
        Text('⭐ ' + (this.me()?.xp ?? 0) + ' 经验')
          .fontSize(11)
          .fontColor('rgba(255,255,255,0.8)')
          .margin({ top: 4 })
      }
      .alignItems(HorizontalAlign.End)
    }
    .width('100%')
    .padding({ left: 18, right: 18, top: 16, bottom: 16 })
    .backgroundColor(this.t.leafDeep)
    .borderRadius(18)
    .shadow({ radius: 20, color: '#4C7A3E4D', offsetY: 8 })
    .margin({ bottom: 16 })
  }

  @Builder
  rankRow(r: RankRow) {
    Row({ space: 14 }) {
      Column() {
        Text(r.rank + '')
          .fontSize(14)
          .fontWeight(FontWeight.Medium)
          .fontColor(r.rank <= 3 ? '#FFFFFF' : this.t.ink3)
      }
      .width(26).height(26)
      .borderRadius(13)
      .backgroundColor(r.rank <= 3 ? this.medalColors[r.rank - 1] : Color.Transparent)
      .justifyContent(FlexAlign.Center)

      Column() {
        Text(this.rowName(r).slice(0, 1))
          .fontSize(16).fontWeight(FontWeight.Medium).fontColor('#FFFFFF')
      }
      .width(38).height(38)
      .borderRadius(19)
      .backgroundColor(r.color)
      .justifyContent(FlexAlign.Center)

      Column() {
        Row({ space: 6 }) {
          Text(this.rowName(r)).fontSize(14).fontWeight(FontWeight.Medium).fontColor(this.t.ink)
          if (r.isMe) {
            Text('我').fontSize(10).fontColor(this.t.leafDeep)
          }
        }
        Text('⭐ ' + r.xp + ' 经验')
          .fontSize(11)
          .fontColor(this.t.ink3)
          .margin({ top: 2 })
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)

      Text() {
        Span(r.minutes + '').fontFamily(FONT_DISPLAY).fontSize(16).fontColor(this.t.ink)
        Span(' 分钟').fontSize(10).fontColor(this.t.ink3)
      }
    }
    .width('100%')
    .padding({ left: 16, right: 16, top: 13, bottom: 13 })
    .backgroundColor(r.isMe ? this.t.surface2 : this.t.surface)
    .borderRadius(16)
    .border({ width: 1, color: r.isMe ? this.t.leaf : this.t.line })
  }

  // ===== 数据 =====
  sorted(): RankRow[] {
    const arr: FriendRankItem[] = [];
    for (let i = 0; i < FRIEND_RANK.length; i++) {
      arr.push(FRIEND_RANK[i]);
    }
    arr.sort((a, b) => b.minutes - a.minutes);
    const out: RankRow[] = [];
    for (let i = 0; i < arr.length; i++) {
      const f = arr[i];
      const row: RankRow = {
        name: f.name,
        minutes: f.minutes,
        xp: f.xp,
        isMe: f.isMe,
        color: f.color,
        rank: i + 1
      };
      out.push(row);
    }
    return out;
  }

  me(): FriendRankItem | undefined {
    return FRIEND_RANK.find(f => f.isMe);
  }

  myName(): string {
    return AppState.instance.user?.nickname ?? this.me()?.name ?? '我';
  }

  rowName(r: RankRow): string {
    return r.isMe ? this.myName() : r.name;
  }

  meRank(): number {
    const arr = this.sorted();
    const idx = arr.findIndex(r => r.isMe);
    return idx < 0 ? 2 : idx + 1;
  }

  overtakeHint(): string {
    const arr = this.sorted();
    const top = arr[0];
    const me = this.me();
    if (!top || !me) return '继续加油';
    if (top.isMe) return '你已是本周榜首 🎉';
    return '再专注 ' + (top.minutes - me.minutes + 1) + ' 分钟可超越第 1 名';
  }
}
