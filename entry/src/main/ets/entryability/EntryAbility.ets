import { AbilityConstant, ConfigurationConstant, UIAbility, Want } from '@kit.AbilityKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { window } from '@kit.ArkUI';
import { BusinessError } from '@kit.BasicServicesKit';

const DOMAIN = 0x0000;
// 桌面卡片点击（postCardAction 的 router 事件）带来的目标页参数，见 widget/pages/WidgetCard.ets
const PAGE_PARAM = 'qfPage';
const PAGE_PREFIX = 'pages/';
// 冷启动时窗口还没创建，先把目标页放这里，交给 pages/Index 决定首屏
const LAUNCH_TARGET_KEY = 'qfLaunchTarget';

interface CardParams {
  qfPage?: string;
}

export default class EntryAbility extends UIAbility {
  private mainWindowStage: window.WindowStage | null = null;

  onCreate(want: Want, launchParam: AbilityConstant.LaunchParam): void {
    try {
      this.context.getApplicationContext().setColorMode(ConfigurationConstant.ColorMode.COLOR_MODE_NOT_SET);
    } catch (err) {
      hilog.error(DOMAIN, 'testTag', 'Failed to set colorMode. Cause: %{public}s', JSON.stringify(err));
    }
    // 冷启动：窗口尚未创建，先把目标页记到 AppStorage，由 Index 决定首屏跳哪儿
    const page: string = EntryAbility.launchPageOf(want);
    if (page.length > 0) {
      AppStorage.setOrCreate<string>(LAUNCH_TARGET_KEY, page);
      hilog.info(DOMAIN, 'testTag', 'cold launch target: %{public}s', page);
    }
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onCreate');
  }

  onDestroy(): void {
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onDestroy');
  }

  onWindowStageCreate(windowStage: window.WindowStage): void {
    // Main window is created, set main page for this ability
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onWindowStageCreate');

    this.mainWindowStage = windowStage;
    windowStage.loadContent('pages/Index', (err) => {
      if (err.code) {
        hilog.error(DOMAIN, 'testTag', 'Failed to load the content. Cause: %{public}s', JSON.stringify(err));
        return;
      }
      hilog.info(DOMAIN, 'testTag', 'Succeeded in loading the content.');
    });
  }

  onWindowStageDestroy(): void {
    // Main window is destroyed, release UI related resources
    this.mainWindowStage = null;
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onWindowStageDestroy');
  }

  // 应用已在运行时点桌面卡片：不会走 onCreate，走这里，直接把当前窗口路由到目标页
  onNewWant(want: Want, launchParam: AbilityConstant.LaunchParam): void {
    const page: string = EntryAbility.launchPageOf(want);
    if (page.length === 0) {
      return;
    }
    hilog.info(DOMAIN, 'testTag', 'onNewWant target: %{public}s', page);
    this.routeTo(page);
  }

  onForeground(): void {
    // Ability has brought to foreground
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onForeground');
  }

  onBackground(): void {
    // Ability has back to background
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onBackground');
  }

  private routeTo(page: string): void {
    const stage: window.WindowStage | null = this.mainWindowStage;
    if (stage === null) {
      // 窗口还未就绪（竞态，极少见）：退回给 Index 处理
      AppStorage.setOrCreate<string>(LAUNCH_TARGET_KEY, page);
      return;
    }
    try {
      const uiRouter = stage.getMainWindowSync().getUIContext().getRouter();
      try {
        const top = uiRouter.getState();
        if (top.path === page) {
          return; // 已经停在目标页，不必再压一层
        }
      } catch (err) {
        // 路由栈未就绪时 getState 会抛错，忽略后继续 push
        hilog.warn(DOMAIN, 'testTag', 'router.getState failed, continue to push');
      }
      uiRouter.pushUrl({ url: page }).catch((err: BusinessError) => {
        hilog.error(DOMAIN, 'testTag', 'pushUrl failed, code: %{public}d', err.code);
      });
    } catch (err) {
      hilog.error(DOMAIN, 'testTag', 'routeTo failed. Cause: %{public}s', JSON.stringify(err));
    }
  }

  // 从 want 里取出卡片带过来的目标页，只放行应用内页面（pages/ 前缀）
  private static launchPageOf(want: Want): string {
    const params: Record<string, Object> | undefined = want.parameters;
    if (params === undefined) {
      return '';
    }
    // 形态一：参数被平铺在 want.parameters 顶层
    const flat: Object | undefined = params[PAGE_PARAM];
    if (typeof flat === 'string') {
      const page: string = EntryAbility.safePage(flat as string);
      if (page.length > 0) {
        return page;
      }
    }
    // 形态二：系统把 postCardAction 的 params 收纳到 want.parameters.params 下（字符串或对象）
    const raw: Object | undefined = params['params'];
    if (raw !== undefined) {
      const text: string = typeof raw === 'string' ? (raw as string) : JSON.stringify(raw);
      return EntryAbility.pageFromJson(text);
    }
    return '';
  }

  private static pageFromJson(text: string): string {
    try {
      const obj = JSON.parse(text) as CardParams;
      return EntryAbility.safePage(obj.qfPage);
    } catch (err) {
      hilog.warn(DOMAIN, 'testTag', 'card params is not valid json');
      return '';
    }
  }

  private static safePage(page: string | undefined): string {
    if (page === undefined) {
      return '';
    }
    if (page.indexOf(PAGE_PREFIX) === 0) {
      return page;
    }
    return '';
  }
}
