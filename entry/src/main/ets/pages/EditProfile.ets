import { router } from '@kit.ArkUI';
import { promptAction } from '@kit.ArkUI';
import { AppState } from '../model/AppState';
import { themeOf, ThemeDef } from '../model/Types';

const AVATARS = ['🌿', '🌸', '🌻', '🍀', '🌙', '🌞', '🍃', '🌾', '🦊', '🐱'];

@Entry
@Component
struct EditProfile {
  @State nickname: string = '';
  @State bio: string = '';
  @State avatar: string = '🌿';
  private t: ThemeDef = themeOf(AppState.instance.themeKey);

  aboutToAppear() {
    const u = AppState.instance.user;
    if (u) {
      this.nickname = u.nickname;
      this.bio = u.bio;
      this.avatar = u.avatarSeed;
    }
  }

  save() {
    const u = AppState.instance.user;
    if (!u) return;
    if (!this.nickname.trim()) {
      promptAction.showToast({ message: '昵称不能为空', duration: 1500 });
      return;
    }
    u.nickname = this.nickname.trim();
    u.bio = this.bio.trim();
    u.avatarSeed = this.avatar;
    AppState.saveUser();
    promptAction.showToast({ message: '已保存', duration: 1200 });
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
            .onClick(() => { this.avatar = a; })
        })
      }
      .width('100%')
      .justifyContent(FlexAlign.Center)
      .padding({ left: 16, right: 16, top: 8 })

      Column() {
        Text('昵称').fontSize(13).fontColor(this.t.ink2).width('100%')
        TextInput({ placeholder: '你的昵称', text: this.nickname })
          .fontSize(16).fontColor(this.t.ink).placeholderColor(this.t.ink3)
          .backgroundColor(this.t.surface2).borderRadius(10)
          .height(48).width('100%').margin({ top: 6 })
          .onChange((v: string) => { this.nickname = v; })

        Text('个性签名').fontSize(13).fontColor(this.t.ink2).margin({ top: 14 }).width('100%')
        TextInput({ placeholder: '一句话介绍一下自己', text: this.bio })
          .fontSize(15).fontColor(this.t.ink).placeholderColor(this.t.ink3)
          .backgroundColor(this.t.surface2).borderRadius(10)
          .height(48).width('100%').margin({ top: 6 })
          .onChange((v: string) => { this.bio = v; })
      }
      .width('100%')
      .padding(16)
      .backgroundColor(this.t.surface)
      .borderRadius(16)
      .border({ width: 1, color: this.t.line })
      .margin({ left: 16, right: 16, top: 20 })

      Blank().layoutWeight(1)
    }
    .width('100%')
    .height('100%')
    .backgroundColor(this.t.bg)
  }
}
