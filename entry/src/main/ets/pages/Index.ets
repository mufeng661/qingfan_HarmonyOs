import { router } from '@kit.ArkUI';
import { AppState } from '../model/AppState';
import { themeOf } from '../model/Types';

// 桌面卡片点击（router 事件）时由 EntryAbility 写入的目标页，读完即清
const LAUNCH_TARGET_KEY = 'qfLaunchTarget';

// 启动入口：根据 onboarded / loggedIn 状态分发页面
@Entry
@Component
struct Index {
  @State ready: boolean = false;
  @State goTo: string = '';

  aboutToAppear(): void {
    AppState.loadAll().then(() => {
      this.ready = true;
      // 桌面卡片点进来时优先直达目标页（一次性消费，避免下次启动误用）
      const target: string = AppStorage.get<string>(LAUNCH_TARGET_KEY) ?? '';
      AppStorage.delete(LAUNCH_TARGET_KEY);
      if (!AppState.instance.onboarded) {
        this.goTo = 'pages/Onboarding';
      } else if (target.length > 0) {
        this.goTo = target;
      } else {
        this.goTo = 'pages/Home';
      }
      // 短暂展示品牌页过渡
      setTimeout(() => {
        router.replaceUrl({ url: this.goTo });
      }, 400);
    });
  }

  build() {
    Stack() {
      Column() {
        Text('🌿')
          .fontSize(96)
        Text('青番')
          .fontSize(36)
          .fontWeight(FontWeight.Bold)
          .fontColor(themeOf(AppState.instance.themeKey).primary)
          .margin({ top: 16 })
        Text('把专注，种成一片番茄园')
          .fontSize(14)
          .fontColor('#666666')
          .margin({ top: 8 })
      }
      .width('100%')
      .height('100%')
      .justifyContent(FlexAlign.Center)
      .alignItems(HorizontalAlign.Center)
      .backgroundColor(themeOf(AppState.instance.themeKey).bg)
    }
    .width('100%')
    .height('100%')
  }
}