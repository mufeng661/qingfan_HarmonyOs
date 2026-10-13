import { ThemeDef, themeOf } from '../../model/Types';

let storage: LocalStorage = new LocalStorage();

// ---- 卡片点击 → 拉起应用并直达「今日待办」 ----
// 官方约束：postCardAction 只能在卡片控件的点击事件里调用（本文件挂在根 Stack 的 onClick 上）。
// action 用 router：拉起本应用的 EntryAbility，并把参数经 want.parameters 带过去，
// 由 EntryAbility 决定是冷启动首屏（Index 读 AppStorage）还是热启动 pushUrl。
const PAGE_PARAM: string = 'qfPage';
// 「今日待办」就是首页 Home（页面内即待办列表所在的界面）
const TODO_PAGE: string = 'pages/Home';

interface CardRouterAction {
  action: string;
  abilityName: string;
  params: Record<string, string>;
}

@Entry(storage)
@Component
struct WidgetCard {
  // 卡片数据通过 FormBindingData 下发到 LocalStorage
  // key 与 QfWidgetAbility.buildFormData 一一对应（全量下发，缺 key 会退回这里的默认值）
  @LocalStorageProp('dimension') dimension: string = '2*2';
  @LocalStorageProp('done') done: string = '0';
  @LocalStorageProp('goal') goal: string = '4';
  @LocalStorageProp('min') min: string = '0';
  @LocalStorageProp('streak') streak: string = '0';
  @LocalStorageProp('trees') trees: string = '0';
  @LocalStorageProp('progressPct') progressPct: string = '0';
  @LocalStorageProp('date') dateText: string = '';

  private theme: ThemeDef = themeOf('green');

  // ⚠️ 这里必须用「普通字段」，不能用 `private get theme() { ... }`。
  // ArkTS 自定义组件（@Component struct）里的 get/set 访问器会被编译器**静默丢弃**：
  // 生成的 WidgetCard 类里根本没有 theme 成员，而 initialRender() 首句就是
  // `Column.backgroundColor(this.theme.cardBg)` → 运行时 this.theme 为 undefined →
  // 抛 TypeError、initialRender 中断 → 桌面卡片整块空白（编译期无任何报错/告警）。
  // 排查方式：看 build 产物
  //   entry/build/default/cache/default/default@CompileArkTS/esmodule/debug_widget/.../WidgetCard.ts
  // 生成类成员只有 initialRender / compactLayout / wideLayout / ...
  // 自检脚本：node .workbuddy/check_widget_card.js <生成的 WidgetCard.ts>

  // ---- 2×2 的「吉祥物」状态：随今日进度变化 ----
  // 多邻国的 Duo 会随打卡进度换表情（鼓励/催促），这里用同一思路让卡片"活"起来。
  private moodEmoji(): string {
    const d: number = Number(this.done);
    const g: number = Number(this.goal);
    if (g > 0 && d >= g) {
      return '🎉';
    }
    if (d > 0) {
      return '🍅';
    }
    return '🌱';
  }

  private moodText(): string {
    const d: number = Number(this.done);
    const g: number = Number(this.goal);
    if (g > 0 && d >= g) {
      return '今日目标达成';
    }
    if (d > 0) {
      return '继续加油';
    }
    return '今天还没开始';
  }

  // 整卡点击 → 打开应用的「今日待办」
  private openTodo(): void {
    const action: CardRouterAction = {
      action: 'router',
      abilityName: 'EntryAbility',
      params: { 'qfPage': TODO_PAGE }
    };
    postCardAction(this, action);
  }

  build() {
    Stack() {
      Column()
        .width('100%')
        .height('100%')
        .backgroundColor(this.theme.cardBg)

      // 4×4 规格已不再提供（用户要求：4×4 缩小为 2×4，内容不删）。
      // 桌面可能残留改动前添加的 4×4 卡片，仍按宽卡渲染，避免落到窄卡而丢内容。
      if (this.dimension === '2*4' || this.dimension === '4*2' || this.dimension === '4*4') {
        this.wideLayout()
      } else {
        this.compactLayout()
      }
    }
    .width('100%')
    .height('100%')
    .onClick(() => {
      this.openTodo();
    })
  }

  // ===== 2×2：多邻国（Duolingo）式小组件 =====
  // 参照多邻国的 streak 小组件：一个突出的「吉祥物」+ 一个大号数字 + 一句状态文案，
  // 只讲一件事、扫一眼就懂。此处主指标换成番茄钟的「今日番茄进度」，并补一条细完成度条。
  @Builder
  compactLayout() {
    Column() {
      Row() {
        Text('今日番茄')
          .fontSize(10)
          .fontColor(this.theme.ink2)
        Blank()
        Text('🔥 ' + this.streak)
          .fontSize(10)
          .fontWeight(FontWeight.Medium)
          .fontColor(this.theme.tomato)
      }
      .width('100%')

      Row() {
        Text(this.moodEmoji())
          .fontSize(26)
        Text(this.done)
          .fontSize(36)
          .fontWeight(FontWeight.Bold)
          .fontColor(this.theme.primary)
          .margin({ left: 4 })
        Text('/' + this.goal)
          .fontSize(14)
          .fontColor(this.theme.ink3)
          .margin({ left: 1 })
      }
      .alignItems(VerticalAlign.Bottom)
      .margin({ top: 2 })

      Text(this.moodText())
        .fontSize(10)
        .fontColor(this.theme.ink2)
        .margin({ top: 2 })

      Stack({ alignContent: Alignment.Start }) {
        Row()
          .width('100%')
          .height(5)
          .backgroundColor(this.theme.surface2)
          .borderRadius(3)
        Row()
          .width(this.progressPct + '%')
          .height(5)
          .backgroundColor(this.theme.primary)
          .borderRadius(3)
      }
      .width('100%')
      .margin({ top: 10 })
    }
    .width('100%')
    .height('100%')
    .padding(12)
    .justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Center)
  }

  // ===== 2×4：宽卡 =====
  // 承接原 4×4 的全部信息（标题 / 专注分钟 / 森林 / 番茄进度 / 连续签到 / 完成度 / 行动引导），
  // 一项都不少，只是排成左右两栏以适配扁长比例。
  @Builder
  wideLayout() {
    Row() {
      // 左栏：品牌 + 今日专注时长 + 森林
      Column() {
        Text('🌿 青番')
          .fontSize(12)
          .fontWeight(FontWeight.Bold)
          .fontColor(this.theme.primary)
        Text(this.min + ' 分钟')
          .fontSize(26)
          .fontWeight(FontWeight.Bold)
          .fontColor(this.theme.cardText)
          .margin({ top: 2 })
        Text('🌳 ' + this.trees + ' 棵树')
          .fontSize(10)
          .fontColor(this.theme.ink2)
          .margin({ top: 2 })
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)
      .justifyContent(FlexAlign.Center)

      // 右栏：番茄进度 + 连签 + 完成度 + 日期 / 行动引导
      Column() {
        Row() {
          Text('🍅 ' + this.done + '/' + this.goal)
            .fontSize(13)
            .fontWeight(FontWeight.Medium)
            .fontColor(this.theme.cardText)
          Blank()
          Text('🔥 ' + this.streak + ' 天')
            .fontSize(11)
            .fontColor(this.theme.tomato)
        }
        .width('100%')

        Stack({ alignContent: Alignment.Start }) {
          Row()
            .width('100%')
            .height(6)
            .backgroundColor(this.theme.surface2)
            .borderRadius(3)
          Row()
            .width(this.progressPct + '%')
            .height(6)
            .backgroundColor(this.theme.primary)
            .borderRadius(3)
        }
        .width('100%')
        .margin({ top: 8 })

        Row() {
          Text(this.dateText)
            .fontSize(10)
            .fontColor(this.theme.ink3)
          Blank()
          Text('查看待办 ›')
            .fontSize(11)
            .fontColor(this.theme.primary)
        }
        .width('100%')
        .margin({ top: 8 })
      }
      .layoutWeight(1)
      .margin({ left: 12 })
      .alignItems(HorizontalAlign.Start)
      .justifyContent(FlexAlign.Center)
    }
    .width('100%')
    .height('100%')
    .padding(14)
    .alignItems(VerticalAlign.Center)
  }
}
