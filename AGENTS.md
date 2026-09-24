# 青番 · AI 番茄钟智能助手 · AI 执行规则

本项目是 HarmonyOS（ArkTS / ArkUI）原生应用「青番 AI 番茄钟智能助手」。
AI 写代码前必须先读取上下文文档，不允许只根据一句话直接生成代码。

## 必读文档

- `memory-bank/PRD.md` —— 做什么（功能范围、页面清单、验收标准）
- `memory-bank/DESIGN.md` —— 长什么样（设计令牌、组件、页面结构）
- `memory-bank/TECH_STACK.md` —— 用什么做（平台、构建、云）
- `memory-bank/DATA_MODEL.md` —— 数据与接口（本地模型、云函数 action、云表）
- `memory-bank/ARCHITECTURE.md` —— 怎么分层（页面/组件/模型/服务/卡片、路由、数据流）
- `memory-bank/TASKS.md` —— 任务清单
- `memory-bank/PROGRESS.md` —— 进度记录
- `design/index.html` —— 高保真原型（视觉与交互以它为准）

## 执行规则

- 每次只做 `TASKS.md` 中的一个编号任务，不要顺手做后续任务。
- 不要实现 `TASKS.md` 之外的功能；如任务不合理，先改文档再写代码。
- 页面与交互对齐 `DESIGN.md`；数据字段、接口出入参对齐 `DATA_MODEL.md`；文件职责与数据流对齐 `ARCHITECTURE.md`。
- 新增/改动功能后，同步更新 `PROGRESS.md`（必要时更新 `TASKS.md`）。

## 工程约束（HarmonyOS / ArkTS 严格模式）

- 目标平台：HarmonyOS，`compatibleSdkVersion = 26.0.0`，`runtimeOS = HarmonyOS`，bundleName `com.example.myapplication`。
- 严格模式硬约束（`arkts-no-*`）：对象字面量必须有声明类型；禁止对象展开、动态 `import()`；`build()` 内不要写 `const x = ...` 语句；struct 名不要与导入类型同名。
- 新增页面必须在 `entry/src/main/resources/base/profile/main_pages.json` 注册。
- 样式统一走主题令牌（`ThemeDef`），不要写死颜色（桌面卡片 `WidgetCard` 除外）。
- 列表刷新用 `@State` 数组驱动（ArkUI 按依赖增量刷新，`build` 里读非状态不会重绘）。

## 构建 / 校验

命令行构建（无需打开 IDE）：

```powershell
$env:DEVECO_SDK_HOME="C:\Program Files\Huawei\DevEco Studio\sdk"
$env:HOS_SDK_HOME="C:\Program Files\Huawei\DevEco Studio\sdk"
$env:OHOS_SDK_HOME="C:\Program Files\Huawei\DevEco Studio\sdk"
& "C:\Program Files\Huawei\DevEco Studio\tools\node\node.exe" `
  "C:\Program Files\Huawei\DevEco Studio\tools\hvigor\bin\hvigorw.js" `
  --mode module -p module=entry@default -p product=default -p requiredDeviceType=phone `
  assembleHap --no-daemon
```

产物：`entry/build/default/outputs/default/entry-default-unsigned.hap`。

> 部署到模拟器/真机请用 DevEco Studio 的 Run（命令行无法解密自动签名的加密密码）。

## 禁止事项

- 不要把签名材料（`.sign/`、`*.p12`、`*.jks`、`*.pem`）提交到仓库。
- 不要在客户端硬编码云函数密钥（当前走免鉴权的 HTTP 访问服务地址，不含密钥）。
- 不要绕过类型系统（禁止 `any` 逃逸）。
