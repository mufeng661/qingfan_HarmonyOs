# 青番 · ARCHITECTURE

## 1. 分层

```
pages/       页面（@Entry 组件，负责 UI 与交互编排）
components/  复用组件（TabBar 底部导航）
service/     云函数客户端（CloudFnService 通用调用 + Auth/Room/Comment 领域封装）
model/       数据与状态（Types 类型与令牌、AppState 全局状态、Store 持久化、CloudBase 云配置）
widget/      桌面卡片（FormExtensionAbility + ArkUI 渲染）
```

- **page 不直接拼 HTTP**：所有云端调用走 `service/*`。
- **model 不依赖 page**：`AppState` 只依赖 `Store` 与 `Types`。
- **样式统一取 `ThemeDef`**（`themeOf(themeKey)`），页面用 `this.t = themeOf(AppState.instance.themeKey)`。

## 2. 路由与导航

- 启动：`EntryAbility` → `pages/Index`。
- `Index`：`!onboarded` → `Onboarding`；否则 → `Home`（不再强制登录）。
- 底部导航 `TabBar`（`components/TabBar.ets`）：今日 / 自习室 / 统计 / 我的，用 `router.replaceUrl` 切换。
  - 未登录点「统计 / 自习室」→ 提示并跳「我的」。
- 页面跳转：`router.pushUrl`（详情类）/ `replaceUrl`（Tab 与完成页）/ `back`（返回）。
- 登录页从「我的」`pushUrl` 进入，登录成功 `router.back()` 返回。

## 3. 状态与数据流

- **全局状态**：`AppState`（`@Observed` 单例，静态 `instance`）。
- **持久化**：`Store`（Preferences，fail-soft）。业务数据按账号命名空间（`dk(base)` = `base_手机号`）。
- **加载**：
  - `AppState.loadAll()`：App 启动时调用（引导标记、用户、主题、账号、业务数据、房间种子）。
  - `AppState.loadBusinessData()`：**登录/注册成功后**调用，按当前账号重新加载业务数据。
- **本地优先**：待办/专注统计/成长数据均本地存储；退出登录只清内存、不清账号数据。
- **云端**：账号、自习室房间、房间留言走云函数（三端共享）。

```
UI(page) ──调用──▶ service ──HTTP──▶ CloudBase 云函数 studyRoomFunctions ──▶ MySQL
   ▲                                                                          
   └── 读写 ──▶ AppState(内存) ──▶ Store(Preferences，按账号隔离)
```

## 4. 访客 / 登录权限矩阵

| 功能 | 游客 | 登录 |
|---|---|---|
| 今日待办（增删改/排序/完成） | ✅ | ✅ |
| 专注计时（待办模式） | ✅ | ✅ |
| 签到 / 成长体系 | ❌（提示登录） | ✅ |
| AI 助手 / AI 对话 | ❌（提示登录） | ✅ |
| 统计 | ❌ | ✅ |
| 自习室（房间/留言/房间计时） | ❌ | ✅ |

判断：`AppState.isLoggedIn()`（`user.phone !== ''`）。云函数用的稳定标识：`AppState.userKey()`（登录=手机号，游客=`harmony-guest`）。

## 5. 关键机制

- **签到与连续**：`AppState.signInToday()`（写 `signDates`、发经验、`recomputeStreak()`）；`computeStreak()` = 从今天往前连续满足「已签到 且 专注≥10 分钟」；Home/Me 用定时器每 30s 检测跨天刷新。
- **番茄 → 树**：`Me.trees() = floor(累计番茄/10) + bonusTrees`。
- **专注完成**：
  - 待办模式 → 记录统计/经验 → `Complete` 庆祝 → 首页；
  - 自习室模式 → 记录统计/经验 + 本地累计房间时长（并尝试上报 `focus.record`）→ 弹窗「是否继续专注」：是则留在计时页、否则返回自习室。
- **提前退出**：未开始可直接退出；已开始需选中断原因，不计番茄、待办保持未完成。
- **列表刷新**：用 `@State` 数组驱动（`refreshTasks()` / `refreshRooms()`），避免 ArkUI 增量刷新不重绘。

## 6. 组件职责

| 文件 | 职责 |
|---|---|
| `components/TabBar.ets` | 底部 4 标签导航 + 登录拦截 |
| `service/CloudFnService.ets` | 通用云函数调用（拼 body/头、解析响应） |
| `service/CloudAuthService.ets` | 注册 / 登录 |
| `service/CloudRoomService.ets` | 房间增删查改、加入/退出、（预留）上报专注 |
| `service/CloudCommentService.ets` | 房间留言列表 / 发表（支持回复） |
| `model/AppState.ets` | 全局状态、账号隔离读写、签到/连续、番茄→树 |
| `model/Store.ets` | Preferences 封装 + 格式化工具 |
| `model/CloudBase.ets` | 云函数地址与平台标识（不含密钥） |
| `widget/*` | 桌面卡片三种尺寸 |

## 7. 三端架构（互通）

```
        鸿蒙 App            Web(qingfan(web))        小程序
   ArkTS + @kit.NetworkKit   HTML/CSS/JS + fetch    wx.cloud.callFunction
            \                     |                     /
             \                    |                    /
              ▼                   ▼                   ▼
        ┌──────────────────────────────────────────────────┐
        │  CloudBase 云函数 studyRoomFunctions              │
        │  env: cloud1-d5g8q89yd66340db4 (MySQL)           │
        │  actions: auth.* / room.* / comment.*            │
        └──────────────────────────────────────────────────┘
                 rooms_self / room_members_self / comments_self
```

- **统一协议**：`POST { action, userId, platform, ...data }`；Web/鸿蒙登录后带 token，云函数以 token 解析手机号为身份。
- **入口差异**：
  - 鸿蒙：`service/CloudFnService` → HTTP 访问服务地址（`model/CloudBase.ets`）。
  - Web：`api.js` 的 `call()` → `config.js.fnUrl`（免鉴权 HTTP 访问服务）或网关 `/v1/functions`。
  - 小程序：`wx.cloud.callFunction({ name:'studyRoomFunctions', data })`。
- **数据互通**：房间（`rooms_self`）、成员（`room_members_self`）、留言（`comments_self`）三端共享；**房间号 = room.id（UUID）**，跨端可直接加入。
- **端内数据**：待办 / 专注统计 / 成长体系在**各端本地**按账号隔离存储（未上云）；三端各自实现同一套功能。
- **功能一致**：三端功能范围完全一致（见 PRD §6），仅技术栈与页面载体不同。
- **登录页三端一致**：登录=手机号+密码；注册=用户名+手机号+密码+确认密码+验证码（演示码 1234）。

