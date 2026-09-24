# 青番 · PROGRESS

## 概览

- 阶段：功能开发完成，已接入 CloudBase（三端互通），命令行构建通过。
- 构建：`hvigorw assembleHap --no-daemon` → `BUILD SUCCESSFUL`。
- 产物：`entry/build/default/outputs/default/entry-default-unsigned.hap`。

## 进度记录

### 2026-09-19

- 引导页改为横向滑动轮播（Swiper + 动画 + 可点圆点）。
- 登录页补叶子背景装饰、Logo 摇摆动画；后续加入注册。
- 修复 `Focus` 倒计时未启动的 bug；切换时长重置计时基准。
- `WidgetPicker` 按原型重写为整屏预览；修复切换尺寸错位。
- 次级页（ThemePicker/Badges/Notify/EditProfile/AIAssistant）统一主题令牌（原写死浅色，深色主题穿帮）。

### 2026-09-20 ~ 09-21

- 首页待办：`List + onItemDragStart/onItemDrop` 实现长按拖动排序；`@State tasks` 驱动刷新。
- 专注背景改为「天空 / 晨雾 / 夕阳」，色块显示对应颜色；新增开始/暂停。
- 待办支持添加时长（预设 + 自定义）。
- 签到规则：文案与实际奖励一致；点击即时刷新；连续 = 签到且专注≥10min；森林 = 每 10 番茄 1 棵树；提前退出记录原因。
- 新增新手引导（启动引导回放 + 首页高亮气泡）。
- 桌面小组件：修复 4×4 溢出、删除图标网格、修复切换尺寸错位；「添加到桌面」改走 `formProvider.openFormManager`。
- 项目推送到 GitHub：`https://github.com/mufeng661/qingfan_HarmonyOs`。

### 2026-09-22 ~ 09-23

- 接入 CloudBase：写入 `.opencode.json`（MCP）、安装 `@cloudbase/cli`、登录并设置环境。
- 访客模式：游客可用待办+计时；AI/统计/自习室需登录；自习室曾设「专注满 25 分钟」后取消。
- 自习室改为对接三端共用云函数 `studyRoomFunctions`：房间列表/创建/按房间号加入/退出/解散、房间留言+回复、房间内计时、房间成员弹窗。
- 登录/注册改走云函数 `auth.login`/`auth.register`（与 Web/小程序同一套账号）。
- 业务数据按手机号隔离存储；退出登录保留账号数据，登录后 `loadBusinessData()` 恢复（番茄/时长/已加入自习室）。
- 底部导航删除「排行」标签（排行移入自习室计时界面的「房间成员」）。
- 房间成员排行展示专注时长（本人本机累计；`focus.record` 上报已预留，云函数未支持时自动忽略）。

### Web / 小程序端（`qingfan(web)` 及同构小程序）

- **功能与鸿蒙端一致**：引导、登录注册、今日待办、专注计时、成长（我的）、统计、自习室、主题、AI 助手。
- 自习室已实现：`index.html`（我的自习室/自习动态/留言板/好友的自习室）、`login.html`、`create.html`、`join.html`、`room.html`（成员 + 交流/回复/点赞/删除/分页）。
- 登录/注册与鸿蒙同一套账号（`auth.login` / `auth.register`），token 存 localStorage。
- 小程序：与 Web 同构（`wx.cloud.callFunction`），身份为微信 OPENID。
- 三端共用云函数 `studyRoomFunctions` 与同一套账号，房间/留言互通。

## 已知问题 / 依赖后端

- 云函数 `room.listMine` 的 `member_count` 恒为 1（App 用 `room.get` 兜底修正）。
- 云函数无 `focus.record` 与成员 `nickname/focus_minutes`，故成员真实昵称/真实时长排行暂不可得。
- 该云函数环境（`cloud1-d5g8q89yd66340db4`）不属于当前登录账号，App 侧无法改其表/函数。
