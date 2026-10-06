import { router } from '@kit.ArkUI';
import { promptAction } from '@kit.ArkUI';
import { pasteboard } from '@kit.BasicServicesKit';
import { AppState } from '../model/AppState';
import { themeOf, ThemeDef, FONT_DISPLAY } from '../model/Types';
import { TabBar } from '../components/TabBar';
import { CloudRoomService, Room, RoomMember } from '../service/CloudRoomService';
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
  @State refreshing: boolean = false;
  // 创建
  @State showCreate: boolean = false;
  @State newName: string = '';
  @State newPwd: string = '';
  @State usePwd: boolean = false;
  @State newDailyMin: string = '30';
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
  @State dissolveLeft: number = 0;
  private dissolveTimer: number = -1;
  // 当前所在房间的成员
  @State roomMembers: RoomMember[] = [];
  @State showKickMember: boolean = false;
  @State kickMemberId: string = '';
  @State kickMemberName: string = '';
  // 退出
  @State showLeave: boolean = false;
  @State pendingLeaveId: string = '';
  @State pendingLeaveName: string = '';
  private t: ThemeDef = themeOf(AppState.instance.themeKey);

  aboutToAppear() {
    this.loadRooms();
    // 来自分享邀请：预填房间号并打开加入弹窗（密码仍需用户输入）
    const params = router.getParams() as Record<string, Object>;
    if (params && params['join']) {
      this.joinCode = String(params['join']);
      this.showJoin = true;
    }
  }

  aboutToDisappear() {
    this.stopDissolveCountdown();
  }

  onPageShow() {
    this.loadRooms();
  }

  onRefresh() {
    this.refreshing = true;
    this.loadRooms();
    if (this.showBoard && this.boardRoomId.length > 0) {
      this.loadMessages();
    }
    setTimeout(() => {
      this.refreshing = false;
      promptAction.showToast({ message: '已刷新', duration: 1200 });
    }, 600);
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
        r.id = String(r.id);
        fixed.push(r);
      }
      this.rooms = fixed;
      this.roomError = '';
      if (fixed.length > 0) {
        try {
          const detail = await CloudRoomService.get(this.userId(), fixed[0].id);
          this.roomMembers = detail.members ? detail.members : [];
          fixed[0].role = detail.role;
          fixed[0].my_focus_minutes = detail.my_focus_minutes;
          fixed[0].member_count = detail.member_count;
        } catch (e) {
          this.roomMembers = [];
        }
      } else {
        this.roomMembers = [];
      }
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
    const dmParsed = parseInt(this.newDailyMin, 10);
    const dailyMin = Number.isFinite(dmParsed) && dmParsed >= 0 ? dmParsed : 30;
    try {
      const room = await CloudRoomService.create(this.userId(), name, this.usePwd ? this.newPwd : '', dailyMin);
      this.showCreate = false;
      this.newName = '';
      this.newPwd = '';
      this.usePwd = false;
      this.newDailyMin = '30';
      await this.loadRooms();
      const copied = await this.copyRoomId(room.id, true);
      promptAction.showToast({
        message: copied ? '自习室已创建，房间号已复制' : ('自习室已创建，房间号 ' + room.id),
        duration: 1800
      });
    } catch (e) {
      const msg = (e as Error).message;
      promptAction.showToast({ message: msg && msg.length > 0 ? msg : '创建失败，请稍后重试', duration: 2200 });
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
      const msg = (e as Error).message;
      promptAction.showToast({ message: msg && msg.length > 0 ? msg : '房间不存在、密码错误或加入失败', duration: 2200 });
    } finally {
      this.joining = false;
    }
  }

  askDeleteRoom(r: Room) {
    this.pendingRoomId = r.id;
    this.pendingRoomName = r.name;
    this.showRoomDelete = true;
    this.startDissolveCountdown();
  }

  // 解散需等待 10s 才能点确定
  startDissolveCountdown() {
    this.stopDissolveCountdown();
    this.dissolveLeft = 10;
    this.dissolveTimer = setInterval(() => {
      if (this.dissolveLeft > 0) {
        this.dissolveLeft -= 1;
      }
      if (this.dissolveLeft <= 0) {
        this.dissolveLeft = 0;
        this.stopDissolveCountdown();
      }
    }, 1000);
  }

  stopDissolveCountdown() {
    if (this.dissolveTimer !== -1) {
      clearInterval(this.dissolveTimer);
      this.dissolveTimer = -1;
    }
  }

  cancelDeleteRoom() {
    this.showRoomDelete = false;
    this.stopDissolveCountdown();
    this.dissolveLeft = 0;
  }

  shareText(r: Room): string {
    const me = AppState.instance.user?.nickname ?? '好友';
    const code = r.join_code !== undefined && r.join_code.length > 0 ? r.join_code : r.id;
    return '青番自习室邀请：' + me + ' 邀请你进入「' + r.name + '」自习室，加入码 ' + code + '（房间号 ' + r.id + '），一起专注吧！';
  }

  async shareRoom(r: Room): Promise<void> {
    try {
      const data = pasteboard.createData(pasteboard.MIMETYPE_TEXT_PLAIN, this.shareText(r));
      await pasteboard.getSystemPasteboard().setData(data);
      promptAction.showToast({ message: '分享文案已复制，发给好友即可邀请', duration: 1800 });
    } catch (e) {
      promptAction.showToast({ message: '复制失败，请重试', duration: 1500 });
    }
  }

  memberName(m: RoomMember): string {
    const uid = this.userId();
    if (m.user_id === uid) {
      return AppState.instance.user?.nickname ?? '我';
    }
    if (m.nickname !== undefined && m.nickname.length > 0) {
      return m.nickname;
    }
    return '用户 …' + String(m.user_id).slice(-6);
  }

  joinCodeOf(r: Room): string {
    if (r.join_code !== undefined && r.join_code.length > 0) return r.join_code;
    return r.id;
  }

  focusingCount(): number {
    let n = 0;
    for (let i = 0; i < this.roomMembers.length; i++) {
      if (this.roomMembers[i].focusing === 1) n += 1;
    }
    return n;
  }

  myRank(): number {
    const uid = this.userId();
    for (let i = 0; i < this.roomMembers.length; i++) {
      if (this.roomMembers[i].user_id === uid) return i + 1;
    }
    return 0;
  }

  async copyText(text: string): Promise<void> {
    if (!text) return;
    try {
      const data = pasteboard.createData(pasteboard.MIMETYPE_TEXT_PLAIN, text);
      await pasteboard.getSystemPasteboard().setData(data);
      promptAction.showToast({ message: '已复制', duration: 1200 });
    } catch (e) {
      promptAction.showToast({ message: '复制失败，请重试', duration: 1200 });
    }
  }

  askKickMember(m: RoomMember) {
    if (m.user_id === this.userId()) return;
    if (m.role === 'owner') return;
    this.kickMemberId = m.user_id;
    this.kickMemberName = this.memberName(m);
    this.showKickMember = true;
  }

  async confirmKickMember(): Promise<void> {
    const target = this.kickMemberId;
    const roomId = this.rooms.length > 0 ? this.rooms[0].id : '';
    this.showKickMember = false;
    if (!target || roomId.length === 0) return;
    try {
      await CloudRoomService.kick(this.userId(), roomId, target);
      promptAction.showToast({ message: '已将该成员移出自习室', duration: 1500 });
      await this.loadRooms();
    } catch (e) {
      promptAction.showToast({ message: '移除失败，请稍后重试', duration: 1500 });
    }
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
    this.stopDissolveCountdown();
    this.dissolveLeft = 0;
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

  async copyRoomId(id: string, silent: boolean = false): Promise<boolean> {
    if (!id) return false;
    try {
      const data = pasteboard.createData(pasteboard.MIMETYPE_TEXT_PLAIN, id);
      await pasteboard.getSystemPasteboard().setData(data);
      if (!silent) {
        promptAction.showToast({ message: '房间号已复制', duration: 1500 });
      }
      return true;
    } catch (e) {
      if (!silent) {
        promptAction.showToast({ message: '复制失败，请重试', duration: 1500 });
      }
      return false;
    }
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
      const msg = (e as Error).message;
      this.msgError = msg && msg.length > 0 ? msg : '留言发送失败，请稍后重试';
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

            if (this.rooms.length === 0) {
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
          }
          .width('100%')
          .padding({ left: 22, right: 22, top: 20, bottom: 16 })

          Refresh({ refreshing: $$this.refreshing }) {
            Scroll() {
              Column() {
                if (this.roomError.length > 0) {
                  Text(this.roomError)
                    .fontSize(12).fontColor(this.t.tomato)
                    .width('100%').margin({ bottom: 12 })
                }
                if (this.rooms.length === 0) {
                  this.entryCards()
                } else {
                  this.roomHome(this.rooms[0])
                }
                Column().height(20)
              }
              .width('100%')
              .padding({ left: 22, right: 22, top: 4 })
            }
            .scrollBar(BarState.Off)
            .edgeEffect(EdgeEffect.Spring)
          }
          .layoutWeight(1)
          .onRefreshing(() => { this.onRefresh(); })

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
      if (this.showKickMember) {
        this.kickMemberPanel()
      }
      if (this.showLeave) {
        this.leavePanel()
      }
    }
  }

  // ====== 无房间：加入 / 创建 卡片 ======
  @Builder
  entryCards() {
    Column({ space: 14 }) {
      this.entryCard('join', '🔑', '加入自习室', '输入好友分享的房间号，一起专注')
      this.entryCard('create', '🏠', '创建自习室', '新建一个自习室，邀请好友加入')
    }
    .width('100%')
    .margin({ top: 16 })
  }

  @Builder
  entryCard(kind: string, icon: string, title: string, desc: string) {
    Column() {
      Column() {
        Text(icon).fontSize(30)
      }
      .width(64).height(64).borderRadius(20)
      .backgroundColor(this.t.leafSoft)
      .justifyContent(FlexAlign.Center)
      Text(title).fontFamily(FONT_DISPLAY).fontSize(17).fontColor(this.t.ink).margin({ top: 14 })
      Text(desc).fontSize(12).fontColor(this.t.ink3).margin({ top: 6 })
    }
    .width('100%')
    .padding({ top: 30, bottom: 30 })
    .backgroundColor(this.t.surface)
    .borderRadius(18)
    .border({ width: 1, color: this.t.line })
    .alignItems(HorizontalAlign.Center)
    .onClick(() => {
      if (kind === 'join') {
        this.showJoin = true;
      } else {
        this.showCreate = true;
      }
    })
  }

  // ====== 有房间：房间信息 + 成员专注卡片 ======
  @Builder
  roomHome(r: Room) {
    Column() {
      Row() {
        Column() {
          Text(r.name)
            .fontSize(20).fontWeight(FontWeight.Bold).fontColor(this.t.ink)
            .maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
          Row({ space: 6 }) {
            Text('加入码').fontSize(11).fontColor(this.t.ink3)
            Text(this.joinCodeOf(r)).fontSize(13.5).fontWeight(FontWeight.Medium).fontColor(this.t.ink2)
            Text('📋').fontSize(12).fontColor(this.t.leaf)
          }
          .margin({ top: 4 })
          .onClick(() => { this.copyText(this.joinCodeOf(r)); })
          Text((r.member_count || 0) + ' 人')
            .fontSize(11).fontColor(this.t.ink3)
            .padding({ left: 8, right: 8, top: 2, bottom: 2 })
            .borderRadius(99).backgroundColor(this.t.surface2)
            .margin({ top: 8 })
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start)

        Column() {
          Text(this.focusingCount() + '')
            .fontSize(24).fontWeight(FontWeight.Bold).fontColor(this.t.tomato)
          Text('正在专注中').fontSize(10.5).fontColor(this.t.ink3)
          Text(this.myRank() + '')
            .fontSize(20).fontWeight(FontWeight.Bold).fontColor(this.t.tomato).margin({ top: 8 })
          Text('当前排名').fontSize(10.5).fontColor(this.t.ink3)
        }
        .alignItems(HorizontalAlign.End)
      }
      .width('100%')

      Row({ space: 10 }) {
        Text('📖 留言')
          .fontSize(12.5).fontColor(this.t.leafDeep).fontWeight(FontWeight.Medium)
          .padding({ left: 12, right: 12, top: 7, bottom: 7 })
          .borderRadius(99).backgroundColor(this.t.leafSoft)
          .onClick(() => { this.openBoard(r); })
        Text('↗ 分享')
          .fontSize(12.5).fontColor(this.t.ink2)
          .padding({ left: 12, right: 12, top: 7, bottom: 7 })
          .borderRadius(99).border({ width: 1, color: this.t.line })
          .onClick(() => { this.shareRoom(r); })
      }
      .width('100%')
      .margin({ top: 14 })

      if ((r.daily_min || 0) > 0) {
        Text('每日最低专注 ' + r.daily_min + ' 分钟 · 未达标当日会被移出')
          .fontSize(11).fontColor(this.t.ink3).width('100%').margin({ top: 10 })
      }

      Row() {
        Text('成员排行')
          .fontFamily(FONT_DISPLAY).fontSize(15).fontColor(this.t.ink)
          .layoutWeight(1)
        if (r.role === 'owner') {
          Text('长按成员可移出').fontSize(10.5).fontColor(this.t.ink3)
        }
      }
      .width('100%').margin({ top: 18, bottom: 10 })

      if (this.roomMembers.length === 0) {
        Text('暂无成员')
          .fontSize(12.5).fontColor(this.t.ink3)
          .width('100%').padding({ top: 12, bottom: 12 })
      } else {
        Column({ space: 10 }) {
          ForEach(this.roomMembers, (m: RoomMember, i: number) => {
            this.memberCard(m, i)
          }, (m: RoomMember) => m.user_id)
        }
        .width('100%')
      }

      Row() {
        Text(r.role === 'owner' ? '解散自习室' : '退出自习室')
          .fontSize(13.5).fontColor(this.t.tomato)
      }
      .width('100%').height(46).borderRadius(14)
      .border({ width: 1, color: this.t.line })
      .justifyContent(FlexAlign.Center)
      .margin({ top: 18 })
      .onClick(() => {
        if (r.role === 'owner') {
          this.askDeleteRoom(r);
        } else {
          this.askLeaveRoom(r);
        }
      })
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  memberCard(m: RoomMember, i: number) {
    Row() {
      Column() {
        Text((i + 1) + '')
          .fontSize(12).fontWeight(FontWeight.Bold).fontColor('#FFFFFF')
      }
      .width(24).height(24).borderRadius(12)
      .backgroundColor(i === 0 ? this.t.gold : i === 1 ? this.t.ink2 : i === 2 ? this.t.tomato : this.t.line)
      .justifyContent(FlexAlign.Center)

      Column() {
        Row({ space: 6 }) {
          Text(this.memberName(m))
            .fontSize(14).fontWeight(FontWeight.Medium).fontColor(this.t.ink)
            .maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
          if (m.role === 'owner') {
            Text('房主').fontSize(10).fontColor(this.t.gold)
              .padding({ left: 6, right: 6, top: 2, bottom: 2 })
              .borderRadius(99).backgroundColor(this.t.goldSoft)
          }
        }
        Text('今日已专注 ' + (m.today_minutes || 0) + ' 分钟')
          .fontSize(11.5).fontColor(this.t.ink3).margin({ top: 3 })
        Row({ space: 6 }) {
          Text('连续专注 ' + (m.streak_days || 0) + ' 天')
            .fontSize(10).fontColor(this.t.tomato)
            .padding({ left: 7, right: 7, top: 2, bottom: 2 })
            .borderRadius(99).backgroundColor(this.t.tomatoSoft)
          Text('共专注 ' + (m.total_days || 0) + ' 天')
            .fontSize(10).fontColor(this.t.gold)
            .padding({ left: 7, right: 7, top: 2, bottom: 2 })
            .borderRadius(99).backgroundColor(this.t.goldSoft)
        }
        .margin({ top: 6 })
      }
      .layoutWeight(1)
      .margin({ left: 10 })
      .alignItems(HorizontalAlign.Start)

      Column() {
        Text((m.focus_minutes || 0) + '')
          .fontSize(20).fontWeight(FontWeight.Bold).fontColor(this.t.ink2)
        Text('分钟').fontSize(10).fontColor(this.t.ink3)
      }
      .alignItems(HorizontalAlign.End)
    }
    .width('100%')
    .padding(14)
    .backgroundColor(this.t.surface)
    .borderRadius(14)
    .border({ width: 1, color: this.t.line })
    .gesture(LongPressGesture().onAction(() => { this.askKickMember(m); }))
  }

  @Builder
  roomSwipeAction(r: Room) {
    Row() {
      Row() {
        Text(r.role === 'owner' ? '解散' : '退出')
          .fontSize(13).fontColor('#FFFFFF').fontWeight(FontWeight.Medium)
      }
      .width(72).height('100%')
      .justifyContent(FlexAlign.Center)
      .borderRadius(16)
      .backgroundColor(this.t.tomato)
      .onClick(() => {
        if (r.role === 'owner') {
          this.askDeleteRoom(r);
        } else {
          this.askLeaveRoom(r);
        }
      })
    }
    .height('100%')
    .padding({ left: 10 })
  }

  @Builder
  roomCard(r: Room) {
    Column() {
      Row() {
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
        .layoutWeight(1)

        Text('↗')
          .fontSize(16).fontColor(this.t.ink3)
          .padding({ left: 8 })
          .onClick(() => { this.shareRoom(r); })
        Text('💬')
          .fontSize(16)
          .padding({ left: 8 })
          .onClick(() => { this.openBoard(r); })
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)
      .onClick(() => { this.startFocus(r); })

      Row() {
        Text('房间号 ' + r.id)
          .fontSize(11).fontColor(this.t.ink3)
          .layoutWeight(1)
        Text('📋')
          .fontSize(12).fontColor(this.t.leaf)
          .padding({ left: 5, right: 5, top: 1, bottom: 1 })
          .borderRadius(6).backgroundColor(this.t.leafSoft)
      }
      .width('100%').margin({ top: 6 })
      .onClick(() => { this.copyRoomId(r.id); })

      Text('我的专注 ' + (r.my_focus_minutes || 0) + ' 分 · ' + (r.member_count || 0) + ' 人 · ' + this.formatTime(r.created_at))
        .fontSize(11).fontColor(this.t.ink3).margin({ top: 4 })
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
      .margin({ top: 12 })
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

        Row() {
          Text('每日最低专注').fontSize(13).fontColor(this.t.ink).layoutWeight(1)
          TextInput({ placeholder: '30', text: this.newDailyMin })
            .type(InputType.Number)
            .fontSize(14).fontColor(this.t.ink).placeholderColor(this.t.ink3)
            .backgroundColor(this.t.surface2).borderRadius(10)
            .width(90).height(40).textAlign(TextAlign.End)
            .onChange((v: string) => { this.newDailyMin = v; })
          Text('分钟').fontSize(12).fontColor(this.t.ink3).margin({ left: 6 })
        }
        .width('100%').margin({ top: 14 })

        Text('未达标当日会被移出自习室；填 0 表示不设限')
          .fontSize(10.5).fontColor(this.t.ink3).width('100%').margin({ top: 6 })

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
        Text('输入好友分享的房间号（6 位数字）')
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

  // ====== 留言弹窗 ======
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
            Text('留言').fontFamily(FONT_DISPLAY).fontSize(17).fontColor(this.t.ink)
            Text(this.boardRoomName).fontSize(11.5).fontColor(this.t.ink3)
              .maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
              .margin({ top: 2 })
            Row({ space: 6 }) {
              Text('房间号 ' + this.boardRoomId)
                .fontSize(11).fontColor(this.t.ink3)
              Text('复制')
                .fontSize(10).fontColor(this.t.leaf)
                .padding({ left: 6, right: 6, top: 1, bottom: 1 })
                .borderRadius(6).backgroundColor(this.t.leafSoft)
            }
            .margin({ top: 4 })
            .onClick(() => { this.copyRoomId(this.boardRoomId); })
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

  @Builder
  kickMemberPanel() {
    Stack() {
      Column()
        .width('100%').height('100%')
        .backgroundColor('rgba(30,40,26,0.42)')
        .onClick(() => { this.showKickMember = false; })
      Column() {
        Text('移出成员').fontFamily(FONT_DISPLAY).fontSize(17).fontColor(this.t.ink)
        Text('确定将「' + this.kickMemberName + '」移出自习室吗？')
          .fontSize(12.5).fontColor(this.t.ink2).lineHeight(20)
          .textAlign(TextAlign.Center).margin({ top: 8, bottom: 16 })
        Row({ space: 10 }) {
          Row() {
            Text('取消').fontSize(14).fontColor(this.t.ink2)
          }
          .layoutWeight(1).height(44).borderRadius(12)
          .border({ width: 1, color: this.t.line })
          .justifyContent(FlexAlign.Center)
          .onClick(() => { this.showKickMember = false; })

          Row() {
            Text('移出').fontSize(14).fontColor('#FFFFFF').fontWeight(FontWeight.Medium)
          }
          .layoutWeight(1).height(44).borderRadius(12)
          .backgroundColor(this.t.tomato)
          .justifyContent(FlexAlign.Center)
          .onClick(() => { this.confirmKickMember(); })
        }
        .width('100%')
      }
      .width(290).padding(22).backgroundColor(this.t.surface).borderRadius(22)
      .alignItems(HorizontalAlign.Center)
    }
  }

  // ====== 解散弹窗 ======
  @Builder
  roomDeletePanel() {
    Stack() {
      Column()
        .width('100%').height('100%')
        .backgroundColor('rgba(30,40,26,0.42)')
        .onClick(() => { this.cancelDeleteRoom(); })
      Column() {
        Text('解散自习室？').fontFamily(FONT_DISPLAY).fontSize(17).fontColor(this.t.ink)
        Text('「' + this.pendingRoomName + '」及其留言将不可见，成员会被移出。')
          .fontSize(12.5).fontColor(this.t.ink2).lineHeight(20)
          .textAlign(TextAlign.Center).margin({ top: 8 })
        Row({ space: 10 }) {
          Row() {
            Text('取消').fontSize(14).fontColor(this.t.ink2)
          }
          .layoutWeight(1).height(44).borderRadius(12)
          .border({ width: 1, color: this.t.line })
          .justifyContent(FlexAlign.Center)
          .onClick(() => { this.cancelDeleteRoom(); })

          Row() {
            Text(this.dissolveLeft > 0 ? ('解散（' + this.dissolveLeft + 's）') : '解散')
              .fontSize(14).fontColor('#FFFFFF').fontWeight(FontWeight.Medium)
          }
          .layoutWeight(1).height(44).borderRadius(12)
          .backgroundColor(this.dissolveLeft > 0 ? this.t.line : this.t.tomato)
          .justifyContent(FlexAlign.Center)
          .onClick(() => {
            if (this.dissolveLeft <= 0) {
              this.confirmDeleteRoom();
            }
          })
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
