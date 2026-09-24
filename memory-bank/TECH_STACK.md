# 青番 · TECH_STACK

## 1. 平台与语言

- 平台：**HarmonyOS**，原生 **ArkTS / ArkUI**（声明式 UI）。
- SDK：`compatibleSdkVersion = 26.0.0`，`targetSdkVersion = 26.0.0`，`runtimeOS = HarmonyOS`。
- 包名：`com.example.myapplication`（`AppScope/app.json5`）。
- 严格模式：开启 ArkTS 严格校验（`arkts-no-untyped-obj-literals`、禁止对象展开/动态 import 等）。

## 2. 工程与构建

- 构建工具：**hvigor**（DevEco Studio 自带）。
- 命令行构建（无需 IDE）：见 `AGENTS.md`「构建 / 校验」。
- 产物：`entry/build/default/outputs/default/entry-default-unsigned.hap`。
- 真机/模拟器部署：用 DevEco Studio 的 Run（自动签名，命令行无法解密加密密码）。

## 3. 目录

```
entry/src/main/ets/
├─ components/      # 复用组件（TabBar）
├─ entryability/    # 应用入口（EntryAbility）
├─ model/           # 模型与状态（Types / AppState / Store / CloudBase）
├─ service/         # 云函数客户端（CloudFn / CloudAuth / CloudRoom / CloudComment）
├─ pages/           # 页面（19 个）
└─ widget/          # 桌面卡片（QfWidgetAbility + WidgetCard）
```

## 4. 本地存储

- `@kit.ArkData` 的 **Preferences**，封装在 `model/Store.ets`（`getStr/getInt/getBool/getObj/getArr` 等，fail-soft）。
- 业务数据按账号隔离：key 形如 `qf_tasks_<手机号>`（游客用 `qf_tasks_guest`）。
- 主题、引导标记等全局项不隔离。

## 5. 网络与云

- 网络：`@kit.NetworkKit` 的 `http`（`http.createHttp().request(...)`）。
- 云：**CloudBase 云函数** `studyRoomFunctions`，通过 **HTTP 访问服务**（免鉴权地址）调用：
  - 地址：`https://cloud1-d5g8q89yd66340db4-1493220082.ap-shanghai.app.tcloudbase.com/studyRoom`
  - 环境：`cloud1-d5g8q89yd66340db4`（ap-shanghai，MySQL）
  - 协议：`POST { action, userId, platform:'harmony', ...data }`，请求头 `x-user-id` / `x-user-platform`。
  - 该地址**公开、不含密钥**，可入库；客户端不持有任何密钥。
- 三端（鸿蒙 / Web / 小程序）**共用同一云函数与同一套账号**，数据互通。

## 6. 云函数能力（action）

| 分类 | action | 用途 |
|---|---|---|
| 账号 | `auth.register` / `auth.login` | 用户名+手机号+密码注册 / 手机号+密码登录，返回 `{ token, user }` |
| 房间 | `room.create` / `room.listMine` / `room.get` / `room.join` / `room.leave` / `room.delete` | 创建 / 我的房间 / 房间详情(含成员) / 加入 / 退出 / 解散 |
| 留言 | `comment.list` / `comment.add` / `comment.like` / `comment.delete` | 列表 / 发表(支持 parentId 回复) / 点赞 / 删除 |

## 7. 桌面卡片

- `FormExtensionAbility`（`widget/QfWidgetAbility.ets`）+ ArkUI 渲染（`widget/pages/WidgetCard.ets`）。
- 尺寸：`2*2 / 2*4 / 4*4`（见 `form_config.json`）。
- 数据经 `formBindingData` 下发（今日番茄、目标、连签、森林、进度）。

## 8. 关键依赖

- `@kit.ArkUI`（router、promptAction、display、animateTo）
- `@kit.ArkData`（preferences）
- `@kit.NetworkKit`（http）
- `@kit.FormKit`（formProvider / FormExtensionAbility）
- `@kit.AbilityKit`（UIAbility、Want）

## 9. 三端技术栈

三端**功能一致**（见 PRD §6「统一功能范围」），仅技术实现不同：

| 端 | 技术 | 身份 | 调用云函数方式 |
|---|---|---|---|
| 鸿蒙 | HarmonyOS ArkTS / ArkUI + hvigor | 登录=手机号，游客=`harmony-guest` | `@kit.NetworkKit` http → HTTP 访问服务 |
| Web | 原生 HTML/CSS/JS（无框架），`qingfan(web)` | 登录=手机号，未登录=设备 UUID | `fetch` → HTTP 访问服务（`config.js.fnUrl`） |
| 小程序 | 微信小程序（`wx.cloud`） | 微信 **OPENID** | `wx.cloud.callFunction({ name:'studyRoomFunctions', data })` |

- 三者共用云函数 `studyRoomFunctions`（env `cloud1-d5g8q89yd66340db4`）与同一套账号（`auth.login`/`auth.register`）。
- Web 侧配置：`config.js`（`envId` / `fnName` / `gatewayBase` / `fnUrl` / 可选 `accessKey`）；`fnUrl` 为免鉴权 HTTP 访问地址（不含密钥）。
- Web 登录后请求会带 `x-user-token`（token 由 `auth.*` 签发），后端优先用 token 解析身份。

