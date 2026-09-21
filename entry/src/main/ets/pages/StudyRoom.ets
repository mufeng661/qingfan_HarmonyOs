import { router } from '@kit.ArkUI';
import { promptAction } from '@kit.ArkUI';
import { AppState } from '../model/AppState';
import { themeOf, ThemeDef, StudyRoom, FONT_DISPLAY } from '../model/Types';
import { genId } from '../model/Store';
import { TabBar } from '../components/TabBar';

interface MemberView {
  name: string;
  status: string;
  color: string;
  me: boolean;
}

interface FeedItem {
  icon: string;
  text: string;
  time: string;
}

@Entry
@Component
struct StudyRoomPage {
  @State uiTick: number = 0;
  @State showCreate: boolean = false;
  @State newName: string = '';
  @State newTheme: string = '共学';
  @State showRoomDelete: boolean = false;
  @State pendingRoomId: string = '';
  @State pendingRoomName: string = '';
  @State rooms: StudyRoom[] = [];
  private t: ThemeDef = themeOf(AppState.instance.themeKey);
  private themes: string[] = ['共学', '晨读', '冲刺', '静心'];
  private memberColors: string[] = ['#6E9B57', '#E07A5F', '#D9A441', '#7FA1B0', '#B08BC0'];

  aboutToAppear() {
    this.refreshRooms();
  }

  refreshRooms() {
    this.rooms = AppState.instance.rooms.slice();
  }

  build() {
    Stack() {
      if (!AppState.isLoggedIn()) {
        Column() {
          this.lockedView()
          TabBar({ active: 'study' })
        }
        .width('100%')
        .height('100%')
        .backgroundColor(this.t.bg)
      } else {
      Column() {
        // 顶栏
        Row() {
          Column() {
            Text('自习室').fontFamily(FONT_DISPLAY).fontSize(24).fontColor(this.t.ink)
            Text('和好友一起，专注不孤单').fontSize(12).fontColor(this.t.ink2).margin({ top: 3 })
          }
          .alignItems(HorizontalAlign.Start)
          .layoutWeight(1)

          Row({ space: 5 }) {
            Text('＋').fontSize(13).fontColor('#FFFFFF')
            Text('创建').fontSize(12.5).fontColor('#FFFFFF').fontWeight(FontWeight.Medium)
          }
          .padding({ left: 13, right: 13, top: 7, bottom: 7 })
          .borderRadius(99)
          .backgroundColor(this.t.leaf)
          .onClick(() => { this.showCreate = true; })
        }
        .width('100%')
        .padding({ left: 22, right: 22, top: 20, bottom: 16 })

        Scroll() {
          Column() {
            if (this.mineRooms().length > 0) {
              ForEach(this.mineRooms(), (r: StudyRoom) => {
                this.mineCard(r)
              }, (r: StudyRoom) => r.id + '_mine')
            }

            Text('自习动态').fontFamily(FONT_DISPLAY).fontSize(16).fontColor(this.t.ink)
              .width('100%').margin({ top: 18, bottom: 12 })

            Column({ space: 8 }) {
              ForEach(this.feeds(), (f: FeedItem) => {
                this.feedRow(f)
              }, (f: FeedItem, i: number) => i + '_' + f.time)
            }
            .width('100%')
            .margin({ bottom: 18 })

            Text('好友的自习室').fontFamily(FONT_DISPLAY).fontSize(16).fontColor(this.t.ink)
              .width('100%').margin({ bottom: 12 })

            Column({ space: 10 }) {
              ForEach(this.otherRooms(), (r: StudyRoom) => {
                this.roomCard(r)
              }, (r: StudyRoom) => r.id + '_other')
            }
            .width('100%')

            Column().height(20)
          }
          .width('100%')
          .padding({ left: 22, right: 22, top: 4 })
        }
        .layoutWeight(1)
        .scrollBar(BarState.Off)
        .edgeEffect(EdgeEffect.Spring)

        TabBar({ active: 'study' })
      }
      .width('100%')
      .height('100%')
      .backgroundColor(this.t.bg)
      }

      if (this.showCreate) {
        this.createPanel()
      }
      if (this.showRoomDelete) {
        this.roomDeletePanel()
      }
    }
  }

  // ====== 未解锁视图 ======
  @Builder
  lockedView() {
    Column() {
      Text('🔒').fontSize(56)
      Text('登录后使用自习室')
        .fontFamily(FONT_DISPLAY)
        .fontSize(20)
        .fontColor(this.t.ink)
        .margin({ top: 12 })
      Text('登录后可浏览自习室；专注满 25 分钟即可加入')
        .fontSize(13)
        .fontColor(this.t.ink2)
        .textAlign(TextAlign.Center)
        .width(260)
        .margin({ top: 8 })
      Row() {
        Text('去登录').fontSize(14).fontColor('#FFFFFF').fontWeight(FontWeight.Medium)
      }
      .padding({ left: 24, right: 24, top: 11, bottom: 11 })
      .borderRadius(99)
      .backgroundColor(this.t.leaf)
      .margin({ top: 18 })
      .onClick(() => { router.pushUrl({ url: 'pages/Login' }); })
    }
    .width('100%')
    .layoutWeight(1)
    .padding({ left: 22, right: 22 })
    .justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Center)
  }

  // ====== 我的自习室（渐变卡） ======
  @Builder
  mineCard(r: StudyRoom) {
    Column() {
      Row() {
        Row({ space: 8 }) {
          Text('👥').fontSize(18).fontColor('#FFFFFF')
          Text(r.name).fontFamily(FONT_DISPLAY).fontSize(17).fontColor('#FFFFFF')
        }
        Blank()
        Text(r.onlineCount + ' 人专注中')
          .fontSize(11).fontColor('rgba(255,255,255,0.9)')
          .padding({ left: 9, right: 9, top: 3, bottom: 3 })
          .borderRadius(99)
          .backgroundColor('rgba(255,255,255,0.18)')
        Text('✕')
          .fontSize(13)
          .fontColor('rgba(255,255,255,0.9)')
          .padding({ left: 10, right: 4, top: 4, bottom: 4 })
          .onClick(() => { this.askDeleteRoom(r); })
      }
      .width('100%')
      .margin({ bottom: 3 })

      Text('一起专注，互相监督')
        .fontSize(12).fontColor('rgba(255,255,255,0.85)')
        .width('100%')
        .margin({ bottom: 14 })

      // 成员
      Row() {
        ForEach(this.memberViews(r), (m: MemberView) => {
          Column({ space: 5 }) {
            Stack({ alignContent: Alignment.BottomEnd }) {
              Column() {
                Text(m.name.slice(0, 1)).fontSize(17).fontWeight(FontWeight.Medium).fontColor('#FFFFFF')
              }
              .width(44).height(44).borderRadius(22)
              .backgroundColor(m.color)
              .border({ width: 2, color: 'rgba(255,255,255,0.5)' })
              .justifyContent(FlexAlign.Center)

              if (m.me) {
                Text('我').fontSize(9).fontWeight(FontWeight.Bold).fontColor(this.t.leafDeep)
                  .padding({ left: 4, right: 4, top: 1, bottom: 1 })
                  .backgroundColor('#FFFFFF')
                  .borderRadius(99)
              }
            }
            Text(m.status).fontSize(10).fontColor('rgba(255,255,255,0.85)')
          }
          .alignItems(HorizontalAlign.Center)
          .margin({ right: 14 })
        }, (m: MemberView) => m.name)
      }
      .width('100%')
      .alignItems(VerticalAlign.Top)

      Row() {
        Text('🔥 今日共专注 ' + r.todayMinutes + ' 分')
          .fontSize(11.5).fontColor('rgba(255,255,255,0.85)')
        Blank()
        Text('开始自习')
          .fontSize(12.5).fontWeight(FontWeight.Medium)
          .fontColor(this.t.leafDeep)
          .padding({ left: 15, right: 15, top: 7, bottom: 7 })
          .borderRadius(99)
          .backgroundColor('#FFFFFF')
          .onClick(() => { this.startFocus(r); })
      }
      .width('100%')
      .margin({ top: 14 })
      .padding({ top: 12 })
      .border({ width: { top: 1 }, color: 'rgba(255,255,255,0.18)' })
    }
    .width('100%')
    .padding({ left: 18, right: 18, top: 18, bottom: 16 })
    .linearGradient({ angle: 135, colors: [[this.t.leafDeep, 0], [this.t.leaf, 1]] })
    .borderRadius(20)
    .margin({ bottom: 16 })
  }

  @Builder
  roomCard(r: StudyRoom) {
    Row({ space: 14 }) {
      Column() {
        Text(this.themeEmoji(r.theme)).fontSize(22)
      }
      .width(44).height(44).borderRadius(13)
      .backgroundColor(this.t.surface2)
      .justifyContent(FlexAlign.Center)

      Column() {
        Row({ space: 6 }) {
          Text(r.name).fontSize(14.5).fontWeight(FontWeight.Medium).fontColor(this.t.ink)
          if (r.hotScore >= 85) {
            Text('火热').fontSize(10).fontColor(this.t.tomato)
              .padding({ left: 6, right: 6, top: 2, bottom: 2 })
              .borderRadius(99)
              .backgroundColor(this.t.tomatoSoft)
              .fontWeight(FontWeight.Medium)
          }
        }
        Text(r.theme + ' · ' + r.onlineCount + ' 人在线 · 热度 ' + r.hotScore)
          .fontSize(11.5).fontColor(this.t.ink3).margin({ top: 3 })
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)

      Text('加入')
        .fontSize(12.5).fontWeight(FontWeight.Medium).fontColor('#FFFFFF')
        .padding({ left: 14, right: 14, top: 7, bottom: 7 })
        .borderRadius(99)
        .backgroundColor(this.t.leaf)
        .onClick(() => { this.joinRoom(r); })

      Text('✕')
        .fontSize(13)
        .fontColor(this.t.ink3)
        .padding({ left: 8, right: 2, top: 4, bottom: 4 })
        .onClick(() => { this.askDeleteRoom(r); })
    }
    .width('100%')
    .padding({ left: 16, right: 16, top: 14, bottom: 14 })
    .backgroundColor(this.t.surface)
    .borderRadius(16)
    .border({ width: 1, color: this.t.line })
  }

  @Builder
  feedRow(f: FeedItem) {
    Row({ space: 10 }) {
      Column() {
        Text(f.icon).fontSize(15).fontColor(this.t.leafDeep)
      }
      .width(30).height(30).borderRadius(9)
      .backgroundColor(this.t.leafSoft)
      .justifyContent(FlexAlign.Center)

      Text(f.text).fontSize(12.5).fontColor(this.t.ink).lineHeight(19).layoutWeight(1)
      Text(f.time).fontSize(10.5).fontColor(this.t.ink3)
    }
    .width('100%')
    .padding({ left: 14, right: 14, top: 11, bottom: 11 })
    .backgroundColor(this.t.surface)
    .borderRadius(14)
    .border({ width: 1, color: this.t.line })
  }

  // ====== 数据 ======
  mineRooms(): StudyRoom[] {
    const out: StudyRoom[] = [];
    this.rooms.forEach(r => {
      if (r.joined) out.push(r);
    });
    return out;
  }

  otherRooms(): StudyRoom[] {
    const out: StudyRoom[] = [];
    this.rooms.forEach(r => {
      if (!r.joined) out.push(r);
    });
    return out;
  }

  feeds(): FeedItem[] {
    const out: FeedItem[] = [];
    this.rooms.forEach(r => {
      r.events.forEach(e => {
        out.push({ icon: '🌳', text: e, time: '刚刚' });
      });
    });
    if (out.length === 0) {
      out.push({ icon: '🌳', text: '苏叶 完成一个番茄，种下 1 棵树', time: '2 分钟前' });
      out.push({ icon: '🔥', text: '周青 加入了自习室', time: '18 分钟前' });
    }
    return out.slice(0, 6);
  }

  memberViews(r: StudyRoom): MemberView[] {
    const out: MemberView[] = [];
    const names = r.members.length > 0 ? r.members : [r.hostId];
    for (let i = 0; i < names.length && i < 5; i++) {
      const n = names[i];
      const isMe = n === '我' || n === AppState.instance.user?.nickname;
      const m: MemberView = {
        name: isMe ? (AppState.instance.user?.nickname ?? '我') : n,
        status: i % 3 === 2 ? '休息中' : '专注中',
        color: this.memberColors[i % this.memberColors.length],
        me: isMe
      };
      out.push(m);
    }
    return out;
  }

  themeEmoji(t: string): string {
    return t === '共学' ? '📚' : t === '晨读' ? '🌅' : t === '冲刺' ? '🔥' : '🌙';
  }

  // ====== 操作 ======
  joinRoom(r: StudyRoom) {
    const idx = AppState.instance.rooms.findIndex(x => x.id === r.id);
    if (idx < 0) return;
    AppState.instance.rooms[idx].joined = true;
    AppState.instance.rooms[idx].onlineCount += 1;
    const meName = AppState.instance.user?.nickname ?? '我';
    if (AppState.instance.rooms[idx].members.indexOf(meName) < 0) {
      AppState.instance.rooms[idx].members = [...AppState.instance.rooms[idx].members, meName];
    }
    AppState.instance.currentRoomId = r.id;
    AppState.saveRooms();
    this.refreshRooms();
    this.uiTick += 1;
    promptAction.showToast({ message: '已加入「' + r.name + '」', duration: 1500 });
  }

  startFocus(r: StudyRoom) {
    AppState.instance.currentRoomId = r.id;
    AppState.instance.currentRoomMode = 'study';
    router.pushUrl({ url: 'pages/StudyRoomFocus', params: { roomId: r.id } });
  }

  createRoom() {
    if (!this.newName.trim()) {
      promptAction.showToast({ message: '请输入房间名', duration: 1500 });
      return;
    }
    const u = AppState.instance.user;
    const meName = u?.nickname ?? '我';
    const room: StudyRoom = {
      id: genId('r'),
      name: this.newName.trim(),
      theme: this.newTheme,
      hostId: meName,
      members: [meName],
      onlineCount: 1,
      hotScore: 50,
      todayMinutes: 0,
      events: [meName + ' 创建了自习室'],
      joined: true
    };
    AppState.instance.rooms = [room, ...AppState.instance.rooms];
    AppState.instance.currentRoomId = room.id;
    AppState.saveRooms();
    this.refreshRooms();
    this.uiTick += 1;
    this.showCreate = false;
    this.newName = '';
    promptAction.showToast({ message: '自习室「' + room.name + '」已创建', duration: 1500 });
  }

  // ====== 长按删除 ======
  askDeleteRoom(r: StudyRoom) {
    this.pendingRoomId = r.id;
    this.pendingRoomName = r.name;
    this.showRoomDelete = true;
  }

  confirmDeleteRoom() {
    const id = this.pendingRoomId;
    AppState.instance.rooms = AppState.instance.rooms.filter(x => x.id !== id);
    if (AppState.instance.currentRoomId === id) {
      AppState.instance.currentRoomId = '';
    }
    AppState.saveRooms();
    this.refreshRooms();
    this.showRoomDelete = false;
    this.pendingRoomId = '';
    this.pendingRoomName = '';
    this.uiTick += 1;
    promptAction.showToast({ message: '已删除自习室', duration: 1500 });
  }

  @Builder
  roomDeletePanel() {
    Stack() {
      Column()
        .width('100%')
        .height('100%')
        .backgroundColor('rgba(30,40,26,0.42)')
        .onClick(() => { this.showRoomDelete = false; })
      Column() {
        Text('删除自习室？')
          .fontFamily(FONT_DISPLAY)
          .fontSize(17)
          .fontColor(this.t.ink)
        Text('「' + this.pendingRoomName + '」将从列表中移除。')
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
          .onClick(() => { this.showRoomDelete = false; })

          Row() {
            Text('删除').fontSize(14).fontColor('#FFFFFF').fontWeight(FontWeight.Medium)
          }
          .layoutWeight(1).height(44).borderRadius(12)
          .backgroundColor(this.t.tomato)
          .justifyContent(FlexAlign.Center)
          .onClick(() => { this.confirmDeleteRoom(); })
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

  // ====== 创建弹窗 ======
  @Builder
  createPanel() {
    Stack() {
      Column()
        .width('100%').height('100%')
        .backgroundColor('rgba(30,40,26,0.42)')
        .onClick(() => { this.showCreate = false; })
      Column() {
        Text('创建自习室').fontFamily(FONT_DISPLAY).fontSize(17).fontColor(this.t.ink)
          .width('100%').margin({ bottom: 6 })
        Text('起个名字，选个主题，喊上好友一起学')
          .fontSize(11.5).fontColor(this.t.ink3)
          .width('100%').margin({ bottom: 14 })

        TextInput({ placeholder: '自习室名称', text: this.newName })
          .fontSize(14).fontColor(this.t.ink)
          .placeholderColor(this.t.ink3)
          .backgroundColor(this.t.surface2)
          .borderRadius(12)
          .height(46).width('100%')
          .onChange((v: string) => { this.newName = v; })

        Row({ space: 8 }) {
          ForEach(this.themes, (t: string) => {
            Column({ space: 5 }) {
              Text(this.themeEmoji(t)).fontSize(18).fontColor(this.newTheme === t ? this.t.leafDeep : this.t.ink3)
              Text(t).fontSize(11).fontColor(this.newTheme === t ? this.t.leafDeep : this.t.ink3)
            }
            .layoutWeight(1)
            .padding({ top: 10, bottom: 10 })
            .borderRadius(12)
            .backgroundColor(this.newTheme === t ? this.t.leafSoft : this.t.surface2)
            .border(this.newTheme === t ? { width: 1.5, color: this.t.leaf } : { width: 1, color: this.t.line })
            .onClick(() => { this.newTheme = t; })
          }, (t: string) => t)
        }
        .width('100%')
        .margin({ top: 14 })

        Row({ space: 10 }) {
          Row() {
            Text('取消').fontSize(14).fontColor(this.t.ink2)
          }
          .layoutWeight(1).height(44).borderRadius(12)
          .border({ width: 1, color: this.t.line })
          .justifyContent(FlexAlign.Center)
          .onClick(() => { this.showCreate = false; })

          Row() {
            Text('创建').fontSize(14).fontColor('#FFFFFF').fontWeight(FontWeight.Medium)
          }
          .layoutWeight(1).height(44).borderRadius(12)
          .backgroundColor(this.t.leaf)
          .justifyContent(FlexAlign.Center)
          .onClick(() => { this.createRoom(); })
        }
        .width('100%')
        .margin({ top: 16 })
      }
      .width(300)
      .padding(22)
      .backgroundColor(this.t.surface)
      .borderRadius(22)
    }
  }
}
