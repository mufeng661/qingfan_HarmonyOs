import { router } from '@kit.ArkUI';
import { promptAction } from '@kit.ArkUI';
import { AppState } from '../model/AppState';
import { themeOf, ThemeDef, FONT_DISPLAY } from '../model/Types';
import { TabBar } from '../components/TabBar';
import { CloudRoomService, Room } from '../service/CloudRoomService';
import { CloudCommentService, RoomComment } from '../service/CloudCommentService';

interface BoardItem {
  id: number;
  parentId: number | null;
  nickname: string;
  content: string;
  created_at: number;
  replyToName: string;
  depth: number;
}

@Entry
@Component
struct StudyRoomPage {
  @State uiTick: number = 0;
  @State rooms: Room[] = [];
  @State roomError: string = '';
  @State loading: boolean = false;
  // 创建
  @State showCreate: boolean = false;
  @State newName: string = '';
  @State newPwd: string = '';
  @State usePwd: boolean = false;
  @State creating: boolean = false;
  // 加入
  @State showJoin: boolean = false;
  @State joinCode: string = '';
  @State joinPwd: string = '';
  @State joining: boolean = false;
  // 留言
  @State showBoard: boolean = false;
  @State boardRoomId: string = '';
  @State boardRoomName: string = '';
  @State messages: RoomComment[] = [];
  @State msgInput: string = '';
  @State msgSending: boolean = false;
  @State msgError: string = '';
  @State replyToId: number = 0;
  @State replyToName: string = '';
  // 解散
  @State showRoomDelete: boolean = false;
  @State pendingRoomId: string = '';
  @State pendingRoomName: string = '';
  // 退出
  @State showLeave: boolean = false;
  @State pendingLeaveId: string = '';
  @State pendingLeaveName: string = '';
  private t: ThemeDef = themeOf(AppState.instance.themeKey);

  aboutToAppear() {
    this.loadRooms();
  }

  private userId(): string {
    return AppState.userKey();
  }

  async loadRooms(): Promise<void> {
    this.loading = true;
    try {
      const list = await CloudRoomService.listMine(this.userId());
      const fixed: Room[] = [];
      for (let i = 0; i < list.length; i++) {
        const r = list[i];
        try {
          const detail = await CloudRoomService.get(this.userId(), r.id);
          r.member_count = detail.member_count;
          r.role = detail.role;
          r.need_password = detail.need_password;
        } catch (e) {
          // 单个房间取详情失败时保留列表值
        }
        fixed.push(r);
      }
      this.rooms = fixed;
      this.roomError = '';
    } catch (e) {
      this.roomError = '自习室加载失败，请检查网络后重试';
    } finally {
      this.loading = false;
    }
  }

  async createRoom(): Promise<void> {
    const name = this.newName.trim();
    if (!name) {
      promptAction.showToast({ message: '请输入房间名称', duration: 1500 });
      return;
    }
    if (this.usePwd && !this.newPwd) {
      promptAction.showToast({ message: '请输入房间密码或关闭密码', duration: 1500 });
      return;
    }
    if (this.creating) return;
    this.creating = true;
    try {
      await CloudRoomService.create(this.userId(), name, this.usePwd ? this.newPwd : '');
      this.showCreate = false;
      this.newName = '';
      this.newPwd = '';
      this.usePwd = false;
      await this.loadRooms();
      promptAction.showToast({ message: '自习室已创建', duration: 1500 });
    } catch (e) {
      promptAction.showToast({ message: '创建失败，请稍后重试', duration: 1500 });
    } finally {
      this.creating = false;
    }
  }

  async joinByCode(): Promise<void> {
    const code = this.joinCode.trim();
    if (!code) {
      promptAction.showToast({ message: '请输入房间号', duration: 1500 });
      return;
    }
    if (this.joining) return;
    this.joining = true;
    try {
      await CloudRoomService.join(this.userId(), code, this.joinPwd);
      this.showJoin = false;
      this.joinCode = '';
      this.joinPwd = '';
      await this.loadRooms();
      promptAction.showToast({ message: '已加入房间', duration: 1500 });
    } catch (e) {
      promptAction.showToast({ message: '房间不存在、密码错误或加入失败', duration: 1500 });
    } finally {
      this.joining = false;
    }
  }

  askDeleteRoom(r: Room) {
    this.pendingRoomId = r.id;
    this.pendingRoomName = r.name;
    this.showRoomDelete = true;
  }

  askLeaveRoom(r: Room) {
    this.pendingLeaveId = r.id;
    this.pendingLeaveName = r.name;
    this.showLeave = true;
  }

  async confirmLeaveRoom(): Promise<void> {
    const id = this.pendingLeaveId;
    this.showLeave = false;
    this.pendingLeaveId = '';
    this.pendingLeaveName = '';
    if (!id) return;
    try {
      await CloudRoomService.leave(this.userId(), id);
      await this.loadRooms();
      promptAction.showToast({ message: '已退出自习室', duration: 1500 });
    } catch (e) {
      promptAction.showToast({ message: '退出失败，请稍后重试', duration: 1500 });
    }
  }

  async confirmDeleteRoom(): Promise<void> {
    const id = this.pendingRoomId;
    this.showRoomDelete = false;
    this.pendingRoomId = '';
    this.pendingRoomName = '';
    if (!id) return;
    try {
      await CloudRoomService.remove(this.userId(), id);
      await this.loadRooms();
      promptAction.showToast({ message: '已解散自习室', duration: 1500 });
    } catch (e) {
      promptAction.showToast({ message: '操作失败，请稍后重试', duration: 1500 });
    }
  }

  startFocus(r: Room) {
    AppState.instance.currentRoomId = r.id;
    AppState.instance.currentRoomMode = 'study';
    router.pushUrl({ url: 'pages/Focus', params: { roomId: r.id, roomName: r.name } });
  }

  openBoard(r: Room) {
    this.boardRoomId = r.id;
    this.boardRoomName = r.name;
    this.showBoard = true;
    this.messages = [];
    this.msgError = '';
    this.cancelReply();
    this.loadMessages();
  }

  async loadMessages(): Promise<void> {
    if (!this.boardRoomId) return;
    try {
      this.messages = await CloudCommentService.list(this.userId(), this.boardRoomId, 1, 50);
      this.msgError = '';
    } catch (e) {
      this.msgError = '留言加载失败，请检查网络后重试';
    }
  }

  async sendMessage(): Promise<void> {
    const text = this.msgInput.trim();
    if (!text) {
      promptAction.showToast({ message: '请输入留言内容', duration: 1500 });
      return;
    }
    if (this.msgSending) return;
    this.msgSending = true;
    const nick = AppState.instance.user?.nickname ?? '访客';
    try {
      await CloudCommentService.create(this.userId(), this.boardRoomId, nick, text, this.replyToId);
      this.msgInput = '';
      this.cancelReply();
      await this.loadMessages();
      this.msgError = '';
      promptAction.showToast({ message: '留言成功', duration: 1500 });
    } catch (e) {
      this.msgError = '留言发送失败，请稍后重试';
    } finally {
      this.msgSending = false;
    }
  }

  formatTime(ts: number): string {
    const d = new Date(ts);
    const mm = (d.getMonth() + 1).toString().padStart(2, '0');
    const dd = d.getDate().toString().padStart(2, '0');
    const hh = d.getHours().toString().padStart(2, '0');
    const mi = d.getMinutes().toString().padStart(2, '0');
    return mm + '-' + dd + ' ' + hh + ':' + mi;
  }

  setReply(id: number, name: string) {
    this.replyToId = id;
    this.replyToName = name;
  }

  cancelReply() {
    this.replyToId = 0;
    this.replyToName = '';
  }

  private walkBoard(list: BoardItem[], depth: number, out: BoardItem[], childrenOf: Map<number, BoardItem[]>) {
    list.sort((a, b) => a.created_at - b.created_at);
    for (let i = 0; i < list.length; i++) {
      const it = list[i];
      it.depth = depth;
      out.push(it);
      const kids = childrenOf.get(it.id);
      if (kids) {
        this.walkBoard(kids, depth + 1, out, childrenOf);
      }
    }
  }

  // 把扁平留言按 parent_id 组树，再按「根倒序、子正序」拍平并带 depth（与 Web 端一致）
  buildBoard(): BoardItem[] {
    const byId: Map<number, BoardItem> = new Map<number, BoardItem>();
    for (let i = 0; i < this.messages.length; i++) {
      const c = this.messages[i];
      const it: BoardItem = {
        id: c.id,
        parentId: c.parent_id,
        nickname: c.nickname,
        content: c.content,
        created_at: c.created_at,
        replyToName: c.reply_to_name ? c.reply_to_name : '',
        depth: 0
      };
      byId.set(c.id, it);
    }
    const roots: BoardItem[] = [];
    const childrenOf: Map<number, BoardItem[]> = new Map<number, BoardItem[]>();
    for (let i = 0; i < this.messages.length; i++) {
      const c = this.messages[i];
      const it = byId.get(c.id);
      if (it === undefined) continue;
      const pid = c.parent_id;
      if (pid !== null && byId.has(pid)) {
        const arr = childrenOf.get(pid);
        if (arr) {
          arr.push(it);
        } else {
          childrenOf.set(pid, [it]);
        }
      } else {
        roots.push(it);
      }
    }
    roots.sort((a, b) => b.created_at - a.created_at);
    const out: BoardItem[] = [];
    for (let i = 0; i < roots.length; i++) {
      this.walkBoard([roots[i]], 0, out, childrenOf);
    }
    return out;
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
          Row() {
            Column() {
              Text('自习室').fontFamily(FONT_DISPLAY).fontSize(24).fontColor(this.t.ink)
              Text('和好友一起，专注不孤单').fontSize(12).fontColor(this.t.ink2).margin({ top: 3 })
            }
            .alignItems(HorizontalAlign.Start)
            .layoutWeight(1)

            Row({ space: 8 }) {
              Row({ space: 5 }) {
                Text('🔑').fontSize(12)
                Text('加入').fontSize(12.5).fontColor(this.t.leafDeep).fontWeight(FontWeight.Medium)
              }
              .padding({ left: 12, right: 12, top: 7, bottom: 7 })
              .borderRadius(99)
              .backgroundColor(this.t.leafSoft)
              .onClick(() => { this.showJoin = true; })

              Row({ space: 5 }) {
                Text('＋').fontSize(13).fontColor('#FFFFFF')
                Text('创建').fontSize(12.5).fontColor('#FFFFFF').fontWeight(FontWeight.Medium)
              }
              .padding({ left: 13, right: 13, top: 7, bottom: 7 })
              .borderRadius(99)
              .backgroundColor(this.t.leaf)
              .onClick(() => { this.showCreate = true; })
            }
          }
          .width('100%')
          .padding({ left: 22, right: 22, top: 20, bottom: 16 })

          Scroll() {
            Column() {
              if (this.roomError.length > 0) {
                Text(this.roomError)
                  .fontSize(12).fontColor(this.t.tomato)
                  .width('100%').margin({ bottom: 12 })
              }

              Text('我的自习室')
                .fontFamily(FONT_DISPLAY).fontSize(16).fontColor(this.t.ink)
                .width('100%').margin({ bottom: 12 })

              if (this.rooms.length === 0) {
                Column() {
                  Text('🏠').fontSize(48)
                  Text(this.loading ? '加载中…' : '还没有自习室')
                    .fontSize(14).fontColor(this.t.ink2).margin({ top: 12 })
                  Text('点右上角「创建」新建，或「加入」输入房间号')
                    .fontSize(12).fontColor(this.t.ink3).margin({ top: 6 })
                }
                .width('100%')
                .padding({ top: 50, bottom: 50 })
                .alignItems(HorizontalAlign.Center)
              } else {
                Column({ space: 10 }) {
                  ForEach(this.rooms, (r: Room) => {
                    this.roomCard(r)
                  }, (r: Room) => r.id)
                }
                .width('100%')
              }

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
      if (this.showJoin) {
        this.joinPanel()
      }
      if (this.showBoard) {
        this.roomBoardPanel()
      }
      if (this.showRoomDelete) {
        this.roomDeletePanel()
      }
      if (this.showLeave) {
        this.leavePanel()
      }
    }
  }

  @Builder
  roomCard(r: Room) {
    Column() {
      Row() {
        Column() {
          Row({ space: 6 }) {
            Text(r.name)
              .fontSize(15).fontWeight(FontWeight.Medium).fontColor(this.t.ink)
              .maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
            if (r.role === 'owner') {
              Text('房主').fontSize(10).fontColor(this.t.gold)
                .padding({ left: 6, right: 6, top: 2, bottom: 2 })
                .borderRadius(99).backgroundColor(this.t.goldSoft)
            }
            if (r.need_password) {
              Text('有密码').fontSize(10).fontColor(this.t.tomato)
                .padding({ left: 6, right: 6, top: 2, bottom: 2 })
                .borderRadius(99).backgroundColor(this.t.tomatoSoft)
            }
          }
          .width('100%')

          Text('房间号 ' + r.id)
            .fontSize(10.5).fontColor(this.t.ink3)
            .maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
            .width('100%').margin({ top: 4 })

          Text((r.member_count || 0) + ' 人 · ' + this.formatTime(r.created_at))
            .fontSize(11).fontColor(this.t.ink3).margin({ top: 2 })
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start)

        Row({ space: 10 }) {
          Text('💬')
            .fontSize(16)
            .padding(4)
            .onClick(() => { this.openBoard(r); })
          if (r.role === 'owner') {
            Text('✕')
              .fontSize(14).fontColor(this.t.ink3)
              .padding(4)
              .onClick(() => { this.askDeleteRoom(r); })
          } else {
            Text('退出')
              .fontSize(12).fontColor(this.t.tomato)
              .padding(4)
              .onClick(() => { this.askLeaveRoom(r); })
          }
        }
      }
      .width('100%')

      Row() {
        Text('开始自习')
          .fontSize(12.5).fontWeight(FontWeight.Medium).fontColor(this.t.leafDeep)
          .padding({ left: 14, right: 14, top: 7, bottom: 7 })
          .borderRadius(99)
          .backgroundColor(this.t.leafSoft)
          .onClick(() => { this.startFocus(r); })
      }
      .width('100%')
      .margin({ top: 10 })
    }
    .width('100%')
    .padding(14)
    .backgroundColor(this.t.surface)
    .borderRadius(16)
    .border({ width: 1, color: this.t.line })
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
        Text('起个名字，喊上好友一起学')
          .fontSize(11.5).fontColor(this.t.ink3).width('100%').margin({ bottom: 14 })

        TextInput({ placeholder: '房间名称', text: this.newName })
          .fontSize(15).fontColor(this.t.ink).placeholderColor(this.t.ink3)
          .backgroundColor(this.t.surface2).borderRadius(12)
          .height(46).width('100%')
          .onChange((v: string) => { this.newName = v; })

        Row() {
          Text('设置密码').fontSize(13).fontColor(this.t.ink).layoutWeight(1)
          Toggle({ type: ToggleType.Switch, isOn: this.usePwd })
            .selectedColor(this.t.leaf)
            .onChange((v: boolean) => { this.usePwd = v; })
        }
        .width('100%').margin({ top: 14 })

        if (this.usePwd) {
          TextInput({ placeholder: '房间密码', text: this.newPwd })
            .type(InputType.Password)
            .fontSize(15).fontColor(this.t.ink).placeholderColor(this.t.ink3)
            .backgroundColor(this.t.surface2).borderRadius(12)
            .height(46).width('100%').margin({ top: 10 })
            .onChange((v: string) => { this.newPwd = v; })
        }

        Row({ space: 10 }) {
          Row() {
            Text('取消').fontSize(14).fontColor(this.t.ink2)
          }
          .layoutWeight(1).height(44).borderRadius(12)
          .border({ width: 1, color: this.t.line })
          .justifyContent(FlexAlign.Center)
          .onClick(() => { this.showCreate = false; })

          Row() {
            Text(this.creating ? '创建中…' : '创建')
              .fontSize(14).fontColor('#FFFFFF').fontWeight(FontWeight.Medium)
          }
          .layoutWeight(1).height(44).borderRadius(12)
          .backgroundColor(this.t.leaf)
          .justifyContent(FlexAlign.Center)
          .onClick(() => { this.createRoom(); })
        }
        .width('100%').margin({ top: 16 })
      }
      .width(300).padding(22)
      .backgroundColor(this.t.surface).borderRadius(22)
    }
  }

  // ====== 加入弹窗 ======
  @Builder
  joinPanel() {
    Stack() {
      Column()
        .width('100%').height('100%')
        .backgroundColor('rgba(30,40,26,0.42)')
        .onClick(() => { this.showJoin = false; })
      Column() {
        Text('加入自习室').fontFamily(FONT_DISPLAY).fontSize(17).fontColor(this.t.ink)
          .width('100%').margin({ bottom: 6 })
        Text('输入好友分享的房间号（一串字符）')
          .fontSize(11.5).fontColor(this.t.ink3).width('100%').margin({ bottom: 14 })

        TextInput({ placeholder: '房间号', text: this.joinCode })
          .fontSize(14).fontColor(this.t.ink).placeholderColor(this.t.ink3)
          .backgroundColor(this.t.surface2).borderRadius(12)
          .height(46).width('100%')
          .onChange((v: string) => { this.joinCode = v; })

        TextInput({ placeholder: '房间密码（没有可不填）', text: this.joinPwd })
          .type(InputType.Password)
          .fontSize(14).fontColor(this.t.ink).placeholderColor(this.t.ink3)
          .backgroundColor(this.t.surface2).borderRadius(12)
          .height(46).width('100%').margin({ top: 10 })
          .onChange((v: string) => { this.joinPwd = v; })

        Row({ space: 10 }) {
          Row() {
            Text('取消').fontSize(14).fontColor(this.t.ink2)
          }
          .layoutWeight(1).height(44).borderRadius(12)
          .border({ width: 1, color: this.t.line })
          .justifyContent(FlexAlign.Center)
          .onClick(() => { this.showJoin = false; })

          Row() {
            Text(this.joining ? '加入中…' : '加入')
              .fontSize(14).fontColor('#FFFFFF').fontWeight(FontWeight.Medium)
          }
          .layoutWeight(1).height(44).borderRadius(12)
          .backgroundColor(this.t.leaf)
          .justifyContent(FlexAlign.Center)
          .onClick(() => { this.joinByCode(); })
        }
        .width('100%').margin({ top: 16 })
      }
      .width(300).padding(22)
      .backgroundColor(this.t.surface).borderRadius(22)
    }
  }

  // ====== 房间留言弹窗 ======
  @Builder
  roomBoardPanel() {
    Stack() {
      Column()
        .width('100%').height('100%')
        .backgroundColor('rgba(30,40,26,0.42)')
        .onClick(() => { this.showBoard = false; })
      Column() {
        Row() {
          Column() {
            Text('房间留言').fontFamily(FONT_DISPLAY).fontSize(17).fontColor(this.t.ink)
            Text(this.boardRoomName).fontSize(11.5).fontColor(this.t.ink3)
              .maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
              .margin({ top: 2 })
          }
          .alignItems(HorizontalAlign.Start)
          .layoutWeight(1)

          Text('✕')
            .fontSize(18).fontColor(this.t.ink3)
            .padding({ left: 8, right: 4 })
            .onClick(() => { this.showBoard = false; })
        }
        .width('100%').margin({ bottom: 12 })

        Scroll() {
          this.boardContent()
        }
        .constraintSize({ maxHeight: 380 })
        .scrollBar(BarState.Off)
      }
      .width('88%').padding(20)
      .backgroundColor(this.t.surface).borderRadius(22)
    }
  }

  @Builder
  boardContent() {
    Column() {
      if (this.replyToName.length > 0) {
        Row() {
          Text('回复 @' + this.replyToName)
            .fontSize(11.5).fontColor(this.t.leafDeep).layoutWeight(1)
            .maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
          Text('取消').fontSize(11.5).fontColor(this.t.ink3)
            .onClick(() => { this.cancelReply(); })
        }
        .width('100%')
        .padding({ left: 10, right: 10, top: 6, bottom: 6 })
        .backgroundColor(this.t.leafSoft)
        .borderRadius(8)
        .margin({ bottom: 8 })
      }
      Row({ space: 8 }) {
        TextInput({ placeholder: '写一句留言…', text: this.msgInput })
          .fontSize(13).fontColor(this.t.ink).placeholderColor(this.t.ink3)
          .backgroundColor(this.t.surface2).borderRadius(10)
          .height(40).layoutWeight(1)
          .onChange((v: string) => { this.msgInput = v; })
        Text(this.msgSending ? '发送中…' : '发送')
          .fontSize(13).fontColor('#FFFFFF').fontWeight(FontWeight.Medium)
          .padding({ left: 16, right: 16, top: 10, bottom: 10 })
          .borderRadius(10).backgroundColor(this.t.leaf)
          .onClick(() => { this.sendMessage(); })
      }
      .width('100%')

      if (this.msgError.length > 0) {
        Text(this.msgError).fontSize(11).fontColor(this.t.tomato)
          .width('100%').margin({ top: 8 })
      }

      if (this.messages.length === 0) {
        Text('还没有留言，来说点什么吧')
          .fontSize(12).fontColor(this.t.ink3)
          .width('100%').textAlign(TextAlign.Center).margin({ top: 18, bottom: 6 })
      } else {
        Column({ space: 10 }) {
          ForEach(this.buildBoard(), (m: BoardItem) => {
            Row({ space: 8 }) {
              Column() {
                Text(m.nickname.length > 0 ? m.nickname.slice(0, 1) : '客')
                  .fontSize(13).fontWeight(FontWeight.Medium).fontColor('#FFFFFF')
              }
              .width(28).height(28).borderRadius(14)
              .backgroundColor(this.t.leaf)
              .justifyContent(FlexAlign.Center)

              Column() {
                Row() {
                  Text(m.nickname)
                    .fontSize(12.5).fontWeight(FontWeight.Medium).fontColor(this.t.ink)
                    .layoutWeight(1)
                  Text(this.formatTime(m.created_at))
                    .fontSize(10.5).fontColor(this.t.ink3)
                }
                .width('100%')

                Text((m.replyToName.length > 0 ? ('回复 @' + m.replyToName + '：') : '') + m.content)
                  .fontSize(13).fontColor(this.t.ink).lineHeight(19)
                  .width('100%').margin({ top: 3 })

                Text('回复')
                  .fontSize(10.5).fontColor(this.t.leafDeep)
                  .margin({ top: 4 })
                  .onClick(() => { this.setReply(m.id, m.nickname); })
              }
              .layoutWeight(1)
              .alignItems(HorizontalAlign.Start)
            }
            .width('100%')
            .alignItems(VerticalAlign.Top)
            .padding({ left: m.depth * 16 })
          }, (m: BoardItem) => m.id + '')
        }
        .width('100%').margin({ top: 14 })
      }
    }
    .width('100%')
  }

  // ====== 解散弹窗 ======
  @Builder
  roomDeletePanel() {
    Stack() {
      Column()
        .width('100%').height('100%')
        .backgroundColor('rgba(30,40,26,0.42)')
        .onClick(() => { this.showRoomDelete = false; })
      Column() {
        Text('解散自习室？').fontFamily(FONT_DISPLAY).fontSize(17).fontColor(this.t.ink)
        Text('「' + this.pendingRoomName + '」及其留言将不可见。')
          .fontSize(12.5).fontColor(this.t.ink2).lineHeight(20)
          .textAlign(TextAlign.Center).margin({ top: 8 })
        Row({ space: 10 }) {
          Row() {
            Text('取消').fontSize(14).fontColor(this.t.ink2)
          }
          .layoutWeight(1).height(44).borderRadius(12)
          .border({ width: 1, color: this.t.line })
          .justifyContent(FlexAlign.Center)
          .onClick(() => { this.showRoomDelete = false; })

          Row() {
            Text('解散').fontSize(14).fontColor('#FFFFFF').fontWeight(FontWeight.Medium)
          }
          .layoutWeight(1).height(44).borderRadius(12)
          .backgroundColor(this.t.tomato)
          .justifyContent(FlexAlign.Center)
          .onClick(() => { this.confirmDeleteRoom(); })
        }
        .width('100%').margin({ top: 18 })
      }
      .width(290).padding(22)
      .backgroundColor(this.t.surface).borderRadius(22)
      .alignItems(HorizontalAlign.Center)
    }
  }

  // ====== 退出弹窗 ======
  @Builder
  leavePanel() {
    Stack() {
      Column()
        .width('100%').height('100%')
        .backgroundColor('rgba(30,40,26,0.42)')
        .onClick(() => { this.showLeave = false; })
      Column() {
        Text('退出自习室？').fontFamily(FONT_DISPLAY).fontSize(17).fontColor(this.t.ink)
        Text('「' + this.pendingLeaveName + '」退出后可在「加入」中重新进入。')
          .fontSize(12.5).fontColor(this.t.ink2).lineHeight(20)
          .textAlign(TextAlign.Center).margin({ top: 8 })
        Row({ space: 10 }) {
          Row() {
            Text('取消').fontSize(14).fontColor(this.t.ink2)
          }
          .layoutWeight(1).height(44).borderRadius(12)
          .border({ width: 1, color: this.t.line })
          .justifyContent(FlexAlign.Center)
          .onClick(() => { this.showLeave = false; })

          Row() {
            Text('退出').fontSize(14).fontColor('#FFFFFF').fontWeight(FontWeight.Medium)
          }
          .layoutWeight(1).height(44).borderRadius(12)
          .backgroundColor(this.t.tomato)
          .justifyContent(FlexAlign.Center)
          .onClick(() => { this.confirmLeaveRoom(); })
        }
        .width('100%').margin({ top: 18 })
      }
      .width(290).padding(22)
      .backgroundColor(this.t.surface).borderRadius(22)
      .alignItems(HorizontalAlign.Center)
    }
  }

  // ====== 未登录 ======
  @Builder
  lockedView() {
    Column() {
      Text('🔒').fontSize(56)
      Text('登录后使用自习室')
        .fontFamily(FONT_DISPLAY).fontSize(20).fontColor(this.t.ink).margin({ top: 12 })
      Text('登录后可创建/加入自习室，与好友一起专注')
        .fontSize(13).fontColor(this.t.ink2)
        .textAlign(TextAlign.Center).width(260).margin({ top: 8 })
      Row() {
        Text('去登录').fontSize(14).fontColor('#FFFFFF').fontWeight(FontWeight.Medium)
      }
      .padding({ left: 24, right: 24, top: 11, bottom: 11 })
      .borderRadius(99).backgroundColor(this.t.leaf).margin({ top: 18 })
      .onClick(() => { router.pushUrl({ url: 'pages/Login' }); })
    }
    .width('100%').layoutWeight(1).padding({ left: 22, right: 22 })
    .justifyContent(FlexAlign.Center).alignItems(HorizontalAlign.Center)
  }
}
