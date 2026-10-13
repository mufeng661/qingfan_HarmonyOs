import { router } from '@kit.ArkUI';
import { promptAction } from '@kit.ArkUI';
import { AppState } from '../model/AppState';
import { themeOf, ThemeDef, MAX_NICK, MAX_BIO, cpLen, cpCut, firstCp } from '../model/Types';

const AVATARS = ['🌿', '🌸', '🌻', '🍀', '🌙', '🌞', '🍃', '🌾', '🦊', '🐱'];

@Entry
@Component
struct EditProfile {
  @State nickname: string = '';
  @State bio: string = '';
  @State avatar: string = '🌿';
  // 用户是否手动挑过头像：没挑过就让头像继续跟随新昵称首字，
  // 挑过则保留 emoji（否则改个昵称会把用户挑的头像冲掉）。
  private avatarTouched: boolean = false;
  private t: ThemeDef = themeOf(AppState.instance.themeKey);

  aboutToAppear() {
    const u = AppState.instance.user;
    if (u) {
      this.nickname = u.nickname;
      this.bio = u.bio;
      this.avatar = u.avatarSeed;
    }
  }

  nickFull(): boolean {
    return cpLen(this.nickname) >= MAX_NICK;
  }

  bioFull(): boolean {
    return cpLen(this.bio) >= MAX_BIO;
  }

  save() {
    const u = AppState.instance.user;
    if (!u) return;
    // 统一按码点截断，避免超长把卡片撑破、也避免 emoji 被劈成半个字符
    const nick = cpCut(this.nickname.trim(), MAX_NICK);
    if (nick.length === 0) {
      promptAction.showToast({ message: '昵称不能为空', duration: 1500 });
      return;
    }
    u.nickname = nick;
    u.bio = cpCut(this.bio.trim(), MAX_BIO);
    u.avatarSeed = this.avatarTouched ? this.avatar : firstCp(nick);
    AppState.saveUser();
    // 广播给已打开的页面（「我的」页）：不然返回后要手动刷新才看得到新昵称
    AppState.notifyProfileChanged();
    promptAction.showToast({ message: '资料已保存', duration: 1200 });
    setTimeout(() => { router.back(); }, 400);
  }

  build() {
    Column() {
      Row() {
        Text('‹').fontSize(28).fontColor(this.t.ink)
          .padding({ left: 8, right: 8 })
          .onClick(() => { router.back(); })
        Text('编辑资料').fontSize(18).fontWeight(FontWeight.Bold).fontColor(this.t.ink)
          .layoutWeight(1).textAlign(TextAlign.Center)
        Text('保存').fontSize(15).fontColor(this.t.leaf)
          .padding({ left: 8, right: 8 })
          .onClick(() => { this.save(); })
      }
      .width('100%')
      .padding({ top: 44, bottom: 16, left: 12, right: 12 })

      Scroll() {
        Column() {
          Column() {
            Text(this.avatar).fontSize(56)
          }
          .width(96).height(96)
          .borderRadius(48)
          .backgroundColor(this.t.leafSoft)
          .justifyContent(FlexAlign.Center)
          .margin({ top: 16 })

          Text('选择头像')
            .fontSize(13).fontColor(this.t.ink2)
            .margin({ top: 16 })

          Row({ space: 10 }) {
            ForEach(AVATARS, (a: string) => {
              Text(a).fontSize(26)
                .border(this.avatar === a ? { width: 2, color: this.t.leaf } : { width: 0 })
                .borderRadius(20)
                .padding(4)
                .onClick(() => {
                  this.avatar = a;
                  this.avatarTouched = true;
                })
            })
          }
          .width('100%')
          .justifyContent(FlexAlign.Center)
          .padding({ left: 16, right: 16, top: 8 })

          Column() {
            // 昵称：必填，带实时字数计数（到上限变红提示）
            Row() {
              Text('昵称').fontSize(13).fontColor(this.t.ink2)
              Blank()
              Text(cpLen(this.nickname) + ' / ' + MAX_NICK)
                .fontSize(11)
                .fontColor(this.nickFull() ? this.t.tomato : this.t.ink3)
            }
            .width('100%')

            TextInput({ placeholder: '你的昵称', text: this.nickname })
              .fontSize(16).fontColor(this.t.ink).placeholderColor(this.t.ink3)
              .backgroundColor(this.t.surface2).borderRadius(10)
              .height(48).width('100%').margin({ top: 6 })
              .maxLength(MAX_NICK)
              .onChange((v: string) => { this.nickname = cpCut(v, MAX_NICK); })

            // 个性签名：可空，带实时字数计数
            Row() {
              Text('个性签名').fontSize(13).fontColor(this.t.ink2)
              Blank()
              Text(cpLen(this.bio) + ' / ' + MAX_BIO)
                .fontSize(11)
                .fontColor(this.bioFull() ? this.t.tomato : this.t.ink3)
            }
            .width('100%').margin({ top: 14 })

            TextInput({ placeholder: '写一句鼓励自己的话', text: this.bio })
              .fontSize(15).fontColor(this.t.ink).placeholderColor(this.t.ink3)
              .backgroundColor(this.t.surface2).borderRadius(10)
              .height(48).width('100%').margin({ top: 6 })
              .maxLength(MAX_BIO)
              .onChange((v: string) => { this.bio = cpCut(v, MAX_BIO); })
          }
          .width('100%')
          .padding(16)
          .backgroundColor(this.t.surface)
          .borderRadius(16)
          .border({ width: 1, color: this.t.line })
          .margin({ left: 16, right: 16, top: 20 })
        }
        .width('100%')
      }
      .layoutWeight(1)
      .scrollBar(BarState.Off)
      .align(Alignment.Top)
    }
    .width('100%')
    .height('100%')
    .backgroundColor(this.t.bg)
  }
}
