# 青番 · 鸿蒙端（ArkTS / ArkUI）长期项目记忆

> 只记「跨会话必须遵守」的规则与约定。每日流水见 `YYYY-MM-DD.md`。

## ⚠️ ArkTS / ArkUI 踩坑红线（写了就出事，编译期不报错）

- **`@Component struct` 里禁止 `get` / `set` 访问器。**
  ArkTS 编译器会**静默丢弃**它们（生成类里没有该成员），运行期读到的就是 `undefined`，
  典型后果：`build()` 首个属性访问就抛异常 → **整个页面/卡片空白**，且**编译 BUILD SUCCESSFUL、零告警**。
  正解：改成普通字段并就地初始化（`private theme: ThemeDef = themeOf('green');`），
  或改成普通方法并在 `build()` 里加 `()` 调用。
  排查方式：看 `entry/build/default/cache/default/default@CompileArkTS/esmodule/<debug|debug_widget>/...` 下的生成 `.ts`，
  确认类成员清单里有你用到的字段。项目自带自检脚本：`.workbuddy/check_widget_card.js`。
- `build()` 内限制（官方）：不允许声明局部变量、不允许 `switch`、不允许三元/表达式，
  只能调用 `@Builder` 方法（普通方法的**返回值**可以作为组件参数）。
- `@Entry` 组件 `build()` 必须恰好一个根节点，且必须是容器组件。

## 桌面卡片（FR-10，`entry/src/main/ets/widget/`）

- 三处文件：`QfWidgetAbility.ets`（FormExtensionAbility 供数）、`widget/pages/WidgetCard.ets`（ArkTS 卡片页）、
  `resources/base/profile/form_config.json`（`uiSyntax: arkts`）。
- **卡片尺寸规格 = 2*2 / 2*4 两种**（2026-10-13 起 4*4 下架，改为并入 2*4，内容不删）。
  三处必须同步：`form_config.supportDimensions`、`WidgetCard.build()` 的分支、`pages/WidgetPicker.ets` 的 `sizes` 预览。
  改一处不改另两处，会出现「应用内能选但系统卡片页没有」这类不一致。
- 布局约定：2×2 = 多邻国（Duolingo）式极简卡（大号「吉祥物」emoji + 大数字 + 一句状态文案 + 细完成度条，
  吉祥物随进度切换 🌱→🍅→🎉）；2×4 = 宽卡，左右两栏，承载原 4×4 的全部信息。
- 卡片页面板尺寸参考：2×2 ≈ 155×155 vp，2×4 ≈ 329×155 vp，4×4 ≈ 329×329 vp。
- 数据通路**单向**：`onAddForm/onUpdateForm` → `formBindingData.createFormBindingData(payload)`
  → 系统注入卡片 LocalStorage → 卡片页 `@LocalStorageProp` 读取。卡片页**不能**自己改数据、不能联网、不能起定时器。
- **`@Entry(storage)` 必须绑定一个 `new LocalStorage()`**，否则 `@LocalStorageProp` 拿不到数据。
- **尺寸参数是 `FormDimension` 枚举数字**（`Dimension_1_2=1 / 2_2=2 / 2_4=3 / 4_4=4`），
  key 是 `ohos.extra.param.key.form_dimension`。**不是** `'2*2'` 这种字符串。
  `WidgetPicker.addToDesktop()` 用 `formProvider.openFormManager(want)` 时也传数字。
- `onUpdateForm(formId)` **不携带尺寸**，必须自己记住「formId → 尺寸」：
  内存 `Map` + Preferences 持久化（进程被回收后靠它恢复，否则 2×4 卡片半小时后会变回 2×2）。
- 供数**全量下发**所有 key：某个尺寸少发一个 key，卡片页只能退回声明处的默认值，会出现「2×4 显示 0 分钟」这类假数据。
- 下架某个尺寸后，`dimNameOf` 仍要保留它的分支：桌面残留的旧卡片，尺寸已持久化在 Preferences 里，
  刷新时会照实传回来；分支删了就会掉进默认窄卡、内容丢失（本次 4×4 即按此处理）。
- `onAddForm` 必须**同步**返回 `FormBindingData`；持久化等异步动作只能 fire-and-forget。
- **卡片点击跳转统一走 `postCardAction`**（官方约束：只能在卡片控件的点击事件里调用）。
  做法：整卡根容器 `Stack.onClick` → `{ action: 'router', abilityName: 'EntryAbility', params: { qfPage: 'pages/Home' } }`。
  两条落地路径必须都在 `EntryAbility` 里处理：冷启动 `onCreate` → 写 `AppStorage('qfLaunchTarget')` →
  `pages/Index` 决定首屏（**读后即 `AppStorage.delete`**，否则下次冷启动会误跳）；热启动 `onNewWant` →
  `windowStage.getMainWindowSync().getUIContext().getRouter().pushUrl()`（`getState().path` 已是目标页则跳过，避免重复压栈）。
  `form_config.json` **不能出现 `isDynamic: false`**：那会变静态卡片，`onClick` + `postCardAction` 全部失效（只能用 `FormLink`）。
  静态校验脚本：`.workbuddy/check_card_click.js`（直接从源码抽方法执行 + 跨文件常量一致性）。

## 应用图标（分层图标 layered icon，2026-10-13 换为「奶油底 + 番茄」）

- **两处必须同款**：`AppScope/resources/base/media/` 的 `background.png + foreground.png + layered_image.json`
  （`AppScope/app.json5` 的 `app.icon`）与 `entry/src/main/resources/base/media/` 的同名三件
  （`module.json5` 里 EntryAbility 的 `icon`）。改一处不改另一处会出现「桌面图标 / 应用信息里的图标不一致」。
  另有 `entry/.../media/startIcon.png`（144×144）= 启动页图标，跟 `color.json` 的 `start_window_background`（`#FFFFFF` / 深色 `#000000`）搭配。
- 规范：均为 **1024×1024 PNG**；**背景层实色铺满、不得含透明像素、不得自行裁圆角、不得加透明内边距**；
  前景层除核心图形外 100% 透明。系统按层套遮罩与动效。
- 当前形态：奶油底 `#EFE8D6` + 扁平番茄（主体 `#D9486B`、高光 `#EE7C98`、叶 `#7FC24D`、茎 `#6BAF42`）。
  前景内容（茎尖→番茄底）占画布 **~77%**。**图形源 = Web 端 `qingfan(web)/favicon.svg`**（三端共用同一份矢量）。
- 改图标**不要去 P 图、也不要自绘**：改图形要先改 Web 端 `favicon.svg`，再跑 `.workbuddy/make_app_icon.py` 重生成
  （无头 Chrome 按 `viewBox="2 2 60 60"` 栅格化 favicon 的番茄 → 按 `CONTENT_H`/`CONTENT_CY` 摆到画布）。
  预览图脚本 `.workbuddy/make_app_icon_preview.py`。旧图标备份在 `.workbuddy/icon_backup_2026-10-13/`。
- **小图取形别信像素**：44px 截图的边缘有 1~1.5px 抗锯齿，会把轮廓极值处的宽度撑大，硬算得「圆角矩形」（n≈3.1），
  与肉眼不符。判断图形要用**同尺度并排对比图**。真实教训是：用户那张截图其实就是 Web 端 favicon 的模糊截图
  （主体逐行宽度序列 0.54/0.77/0.85/1.00… 完全一致），**正解是复用已有矢量，而不是重画一遍**。
- 构建期会把 `media` 下的大图压到 **512×512**（1024→512），属正常；源文件仍按规范给 1024。

## 构建 / 验证

- 构建：`export DEVECO_SDK_HOME="C:\Program Files\Huawei\DevEco Studio\sdk"` 后
  `"C:/Program Files/Huawei/DevEco Studio/tools/node/node.exe" "C:/Program Files/Huawei/DevEco Studio/tools/hvigor/bin/hvigorw.js" --mode module -p module=entry@default -p product=default -p requiredDeviceType=phone assembleHap --no-daemon > log 2>&1`
  （重定向到文件再 grep，规避 PowerShell 管道退出码问题）；日志里找 `BUILD SUCCESSFUL`。
- 产物：`entry/build/default/outputs/default/entry-default-signed.hap`。
- 卡片类问题**只能靠看生成产物 + 真机验证**，构建成功不代表卡片能渲染。
