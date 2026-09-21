import { router } from '@kit.ArkUI';
import { promptAction } from '@kit.ArkUI';
import { AppState } from '../model/AppState';
import { themeOf, UserProfile, ThemeDef, FONT_DISPLAY, Account } from '../model/Types';
import { genId } from '../model/Store';

@Entry
@Component
struct Login {
  @State mode: string = 'login';
  @State phone: string = '138 0000 8888';
  @State code: string = '123456';
  @State username: string = '';
  @State password: string = '';
  @State confirmPwd: string = '';
  @State sending: boolean = false;
  @State countdown: number = 0;
  @State loading: boolean = false;
  @State sway: boolean = false;
  private timerId: number = -1;
  private swayTimerId: number = -1;
  private t: ThemeDef = themeOf(AppState.instance.themeKey);

  aboutToAppear() {
    this.swayTimerId = setInterval(() => {
      this.getUIContext().animateTo({ duration: 1500, curve: Curve.EaseInOut }, () => {
        this.sway = !this.sway;
      });
    }, 1500);
  }

  private isPhoneValid(): boolean {
    const digits = this.phone.replace(/\s/g, '');
    return /^1[3-9]\d{9}$/.test(digits);
  }

  private startCountdown() {
    if (!this.isPhoneValid()) {
      promptAction.showToast({ message: '请输入正确的手机号', duration: 1500 });
      return;
    }
    this.sending = true;
    this.countdown = 60;
    if (this.timerId !== -1) clearInterval(this.timerId);
    this.timerId = setInterval(() => {
      this.countdown -= 1;
      if (this.countdown <= 0) {
        clearInterval(this.timerId);
        this.timerId = -1;
        this.sending = false;
      }
    }, 1000);
    promptAction.showToast({ message: '验证码已发送（演示码 1234）', duration: 1500 });
  }

  aboutToDisappear() {
    if (this.timerId !== -1) clearInterval(this.timerId);
    if (this.swayTimerId !== -1) clearInterval(this.swayTimerId);
  }

  private async doLogin() {
    if (!this.isPhoneValid()) {
      promptAction.showToast({ message: '请输入正确的手机号', duration: 1500 });
      return;
    }
    const phone = this.phone.replace(/\s/g, '');
    const acc = AppState.instance.account;
    if (acc === null || acc.phone !== phone || acc.pwdHash !== AppState.hashPwd(this.password)) {
      promptAction.showToast({ message: '手机号或密码错误', duration: 1500 });
      return;
    }
    const nick: string = acc.nickname;
    this.loading = true;
    setTimeout(async () => {
      const u: UserProfile = {
        id: genId('u'),
        phone: phone,
        nickname: nick,
        avatarSeed: nick.slice(0, 1),
        bio: '把专注，种成一片森林',
        level: 1,
        exp: 0,
        nextLevelExp: 3000,
        streak: 0,
        lastSignDate: '',
        signDates: [],
        theme: AppState.instance.themeKey,
        notifyEnabled: true
      };
      AppState.instance.user = u;
      await AppState.saveUser();
      this.loading = false;
      router.back();
    }, 400);
  }

  private async doRegister() {
    const name = this.username.trim();
    if (name.length < 2) {
      promptAction.showToast({ message: '请输入用户名（至少 2 个字符）', duration: 1500 });
      return;
    }
    if (!this.isPhoneValid()) {
      promptAction.showToast({ message: '请输入正确的手机号', duration: 1500 });
      return;
    }
    if (this.password.length < 6) {
      promptAction.showToast({ message: '密码至少 6 位', duration: 1500 });
      return;
    }
    if (this.password !== this.confirmPwd) {
      promptAction.showToast({ message: '两次输入的密码不一致', duration: 1500 });
      return;
    }
    if (this.code !== '1234') {
      promptAction.showToast({ message: '验证码错误，演示码为 1234', duration: 1500 });
      return;
    }
    const phone = this.phone.replace(/\s/g, '');
    const pwdHash = AppState.hashPwd(this.password);
    this.loading = true;
    setTimeout(async () => {
      const acc: Account = { phone: phone, pwdHash: pwdHash, nickname: name };
      AppState.instance.account = acc;
      await AppState.saveAccount();
      const u: UserProfile = {
        id: genId('u'),
        phone: phone,
        nickname: name,
        avatarSeed: name.slice(0, 1),
        bio: '把专注，种成一片森林',
        level: 1,
        exp: 0,
        nextLevelExp: 3000,
        streak: 0,
        lastSignDate: '',
        signDates: [],
        theme: AppState.instance.themeKey,
        notifyEnabled: true
      };
      AppState.instance.user = u;
      await AppState.saveUser();
      this.loading = false;
      promptAction.showToast({ message: '注册成功', duration: 1200 });
      router.back();
    }, 500);
  }

  build() {
    Stack({ alignContent: Alignment.TopEnd }) {
      // 背景叶子装饰
      Shape() {
        Path()
          .commands('M40 260C60 140 160 60 300 30c-20 120-120 190-240 220Z')
          .fill(this.t.leaf)
        Path()
          .commands('M80 280c10-80 60-140 130-170')
          .fill(Color.Transparent)
          .stroke(this.t.leafDeep)
          .strokeWidth(2)
      }
      .viewPort({ x: 0, y: 0, width: 400, height: 300 })
      .width(300)
      .height(225)
      .opacity(0.10)
      .offset({ x: 60, y: -40 })

      Column() {
        // 上半：品牌
        Column() {
          Text('🍅')
            .fontSize(64)
            .rotate({ angle: this.sway ? 3 : -3 })
          Text('青番')
            .fontFamily(FONT_DISPLAY)
            .fontSize(30)
            .fontColor(this.t.ink)
            .letterSpacing(1.4)
            .margin({ top: 6 })
          Text('QINGFAN · AI POMODORO')
            .fontSize(11)
            .fontColor(this.t.ink3)
            .letterSpacing(3.7)
            .margin({ top: 6 })
        }
        .layoutWeight(1)
        .justifyContent(FlexAlign.Center)
        .alignItems(HorizontalAlign.Center)

        // 下半：登录 / 注册
        Column() {
          Row() {
            this.modeTab('登录', 'login')
            this.modeTab('注册', 'register')
          }
          .width('100%')
          .padding(4)
          .borderRadius(14)
          .backgroundColor(this.t.surface2)
          .margin({ bottom: 16 })

          if (this.mode === 'login') {
            this.loginForm()
          } else {
            this.registerForm()
          }

          Text('登录即代表同意《用户协议》与《隐私政策》')
            .fontSize(11)
            .fontColor(this.t.ink3)
            .textAlign(TextAlign.Center)
            .width('100%')
            .margin({ top: 14 })
        }
        .width('100%')
        .padding({ left: 34, right: 34, bottom: 40 })
      }
      .width('100%')
      .height('100%')
    }
    .width('100%')
    .height('100%')
    .linearGradient({ angle: 180, colors: [[this.t.brandGrad1, 0], [this.t.brandGrad2, 1]] })
  }

  @Builder
  modeTab(label: string, key: string) {
    Row() {
      Text(label)
        .fontSize(13.5)
        .fontWeight(this.mode === key ? FontWeight.Bold : FontWeight.Normal)
        .fontColor(this.mode === key ? this.t.leafDeep : this.t.ink2)
    }
    .layoutWeight(1)
    .height(40)
    .borderRadius(11)
    .backgroundColor(this.mode === key ? this.t.surface : Color.Transparent)
    .justifyContent(FlexAlign.Center)
    .onClick(() => { this.mode = key; })
  }

  @Builder
  inputRow(placeholder: string, value: string, isPwd: boolean, onChange: (v: string) => void) {
    Row() {
      TextInput({ placeholder: placeholder, text: value })
        .type(isPwd ? InputType.Password : InputType.Normal)
        .fontSize(15)
        .fontColor(this.t.ink)
        .placeholderColor(this.t.ink3)
        .backgroundColor(Color.Transparent)
        .layoutWeight(1)
        .maxLength(isPwd ? 20 : 20)
        .onChange((v: string) => { onChange(v); })
    }
    .width('100%')
    .height(50)
    .padding({ left: 16, right: 16 })
    .backgroundColor(this.t.surface)
    .borderRadius(14)
    .border({ width: 1, color: this.t.line })
    .margin({ top: 12 })
  }

  @Builder
  loginForm() {
    Column() {
      Row() {
        Text('+86')
          .fontSize(13)
          .fontColor(this.t.ink3)
          .width(22)
        TextInput({ placeholder: '手机号', text: this.phone })
          .fontSize(15)
          .fontColor(this.t.ink)
          .placeholderColor(this.t.ink3)
          .backgroundColor(Color.Transparent)
          .letterSpacing(1)
          .layoutWeight(1)
          .maxLength(20)
          .onChange((v: string) => { this.phone = v; })
      }
      .width('100%')
      .height(50)
      .padding({ left: 16, right: 16 })
      .backgroundColor(this.t.surface)
      .borderRadius(14)
      .border({ width: 1, color: this.t.line })

      Row() {
        TextInput({ placeholder: '密码', text: this.password })
          .type(InputType.Password)
          .fontSize(15)
          .fontColor(this.t.ink)
          .placeholderColor(this.t.ink3)
          .backgroundColor(Color.Transparent)
          .layoutWeight(1)
          .maxLength(20)
          .onChange((v: string) => { this.password = v; })
      }
      .width('100%')
      .height(50)
      .padding({ left: 16, right: 16 })
      .backgroundColor(this.t.surface)
      .borderRadius(14)
      .border({ width: 1, color: this.t.line })
      .margin({ top: 12 })

      Row() {
        Text(this.loading ? '登录中…' : '登录')
          .fontSize(15)
          .fontWeight(FontWeight.Bold)
          .fontColor('#FFFFFF')
          .letterSpacing(4)
      }
      .width('100%')
      .height(50)
      .borderRadius(14)
      .backgroundColor(this.t.leaf)
      .shadow({ radius: 24, color: 'rgba(110,155,87,0.32)', offsetY: 10 })
      .justifyContent(FlexAlign.Center)
      .margin({ top: 18 })
      .onClick(() => { this.doLogin(); })

      Text('演示账号：13800008888 · 密码 123456')
        .fontSize(11)
        .fontColor(this.t.ink3)
        .textAlign(TextAlign.Center)
        .width('100%')
        .margin({ top: 8 })
    }
    .width('100%')
  }

  @Builder
  registerForm() {
    Column() {
      this.inputRow('用户名', this.username, false, (v: string) => { this.username = v; })

      Row() {
        Text('+86')
          .fontSize(13)
          .fontColor(this.t.ink3)
          .width(22)
        TextInput({ placeholder: '手机号', text: this.phone })
          .fontSize(15)
          .fontColor(this.t.ink)
          .placeholderColor(this.t.ink3)
          .backgroundColor(Color.Transparent)
          .letterSpacing(1)
          .layoutWeight(1)
          .maxLength(20)
          .onChange((v: string) => { this.phone = v; })
      }
      .width('100%')
      .height(50)
      .padding({ left: 16, right: 16 })
      .backgroundColor(this.t.surface)
      .borderRadius(14)
      .border({ width: 1, color: this.t.line })
      .margin({ top: 12 })

      this.inputRow('密码（至少 6 位）', this.password, true, (v: string) => { this.password = v; })
      this.inputRow('确认密码', this.confirmPwd, true, (v: string) => { this.confirmPwd = v; })

      Row() {
        TextInput({ placeholder: '验证码', text: this.code })
          .fontSize(15)
          .fontColor(this.t.ink)
          .placeholderColor(this.t.ink3)
          .backgroundColor(Color.Transparent)
          .letterSpacing(3)
          .layoutWeight(1)
          .maxLength(6)
          .onChange((v: string) => { this.code = v; })
        Text(this.sending ? '已发送' : '获取验证码')
          .fontSize(12)
          .fontColor(this.sending ? this.t.ink3 : this.t.leafDeep)
          .onClick(() => { if (!this.sending) this.startCountdown(); })
      }
      .width('100%')
      .height(50)
      .padding({ left: 16, right: 16 })
      .backgroundColor(this.t.surface)
      .borderRadius(14)
      .border({ width: 1, color: this.t.line })
      .margin({ top: 12 })

      Row() {
        Text(this.loading ? '注册中…' : '注册')
          .fontSize(15)
          .fontWeight(FontWeight.Bold)
          .fontColor('#FFFFFF')
          .letterSpacing(4)
      }
      .width('100%')
      .height(50)
      .borderRadius(14)
      .backgroundColor(this.t.leaf)
      .shadow({ radius: 24, color: 'rgba(110,155,87,0.32)', offsetY: 10 })
      .justifyContent(FlexAlign.Center)
      .margin({ top: 18 })
      .onClick(() => { this.doRegister(); })

      Text('演示验证码：1234')
        .fontSize(11)
        .fontColor(this.t.ink3)
        .textAlign(TextAlign.Center)
        .width('100%')
        .margin({ top: 8 })
    }
    .width('100%')
  }
}
