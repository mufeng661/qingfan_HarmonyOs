import { router } from '@kit.ArkUI';
import { AppState } from '../model/AppState';
import { themeOf } from '../model/Types';

// 启动入口：根据 onboarded / loggedIn 状态分发页面
@Entry
@Component
struct Index {
  @State ready: boolean = false;
  @State goTo: string = '';

  aboutToAppear(): void {
    AppState.loadAll().then(() => {
      this.ready = true;
      if (!AppState.instance.onboarded) {
        this.goTo = 'pages/Onboarding';
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
        Text('把专注，种成一片森林')
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