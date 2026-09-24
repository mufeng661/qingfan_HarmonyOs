import { router, promptAction } from '@kit.ArkUI';
import { AppState } from '../model/AppState';
import { themeOf } from '../model/Types';

// 底部 5 标签导航（对齐原型 TabBar）
export interface TabSpec {
  id: string;
  label: string;
  icon: string;
  url: string;
}

export const TABS: TabSpec[] = [
  { id: 'home', label: '今日', icon: '🌿', url: 'pages/Home' },
  { id: 'study', label: '自习室', icon: '👥', url: 'pages/StudyRoom' },
  { id: 'stats', label: '统计', icon: '📊', url: 'pages/Stats' },
  { id: 'me', label: '我的', icon: '👤', url: 'pages/Me' }
];

@Component
export struct TabBar {
  active: string = 'home';

  build() {
    Row() {
      ForEach(TABS, (t: TabSpec) => {
        Column({ space: 3 }) {
          Text(t.icon)
            .fontSize(22)
          Text(t.label)
            .fontSize(10.5)
            .fontWeight(this.active === t.id ? FontWeight.Medium : FontWeight.Normal)
            .fontColor(this.active === t.id ? themeOf(AppState.instance.themeKey).leafDeep : themeOf(AppState.instance.themeKey).ink3)
        }
        .layoutWeight(1)
        .height('100%')
        .justifyContent(FlexAlign.Center)
        .onClick(() => {
          if (this.active === t.id) {
            return;
          }
          if (t.id === 'stats') {
            if (!AppState.isLoggedIn()) {
              promptAction.showToast({ message: '登录后即可使用，请到「我的」登录', duration: 1800 });
              router.replaceUrl({ url: 'pages/Me' });
              return;
            }
          }
          if (t.id === 'study') {
            if (!AppState.isLoggedIn()) {
              promptAction.showToast({ message: '登录后即可浏览自习室', duration: 1800 });
              router.replaceUrl({ url: 'pages/Me' });
              return;
            }
          }
          router.replaceUrl({ url: t.url });
        })
      }, (t: TabSpec) => t.id)
    }
    .width('100%')
    .height(64)
    .backgroundColor(themeOf(AppState.instance.themeKey).bar)
    .border({ width: { top: 1 }, color: themeOf(AppState.instance.themeKey).line })
  }
}
