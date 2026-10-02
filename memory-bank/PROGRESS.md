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

### 2026-09-30

- 修复云函数 `room.create` 失败：线上 `rooms_self` 实为 `id`(bigint 自增 PK) + `room_no`(varchar 唯一非空) 双列结构，旧代码只写 `id`、漏写 `room_no`，触发 `Field 'room_no' doesn't have a default value` / `Duplicate entry '' for key 'uk_rooms_room_no'`。改为**生成唯一 6 位 `room_no` 写入**，并让 `room.get` / `room.listMine` / `room.join` 以 `room_no` 作为 `id` 下发（房间号语义由 UUID 改为 6 位数字）。
- 修复 `room.listMine` 的 `member_count` 恒为 1：`.in("room_id", …)` 只选 `room_id` 时，同房间多行内容完全相同被整行去重；改为 `select("room_id,user_id")` 后计数正确（App 端 `room.get` 兜底可移除，暂留无害）。
- 云函数 `studyRoomFunctions` 源码纳入本地管理（`index/cloudbase/auth/token/password/utils` + `schema.sql`）；确认该环境（`cloud1-d5g8q89yd66340db4`）当前账号**已可访问与部署**。
- 部署要点：`tcb fn code update` 需在函数目录内执行（否则按 `functionRootPath`=当前目录打包），`--deployMode zip` 在含依赖时超 1.5MB 上限，改用**不含 `node_modules` 的源码包**走 ZIP base64（云端按 `InstallDependency` 安装依赖）。
- 联调通过：`room.create → room.get → room.join → comment.add → comment.list → room.listMine → room.delete` 全链路正常，中文名/留言入库与回读无误；联调数据已清理。
- 自习室房间号支持复制：房间卡片与留言弹窗均加复制入口（`@kit.BasicServicesKit` 剪贴板 + Toast）；创建成功后自动复制房间号；加入弹窗文案改为「6 位数字」。
- 自习室房间卡片重排：文字（房间名/房间号/人数/开始自习）左对齐、图标（💬 标题行右、📋 房间号行右）右对齐；删除/退出由卡片按钮改为**列表左滑**（`List + ListItem.swipeAction`，露出「解散 / 退出」后走二次确认弹窗）。

### 2026-10-01

- **AI 接入真实大模型（B 方案）**：云函数新增 `ai.chat` / `ai.insight`（`ai.js`，OpenAI 兼容 `/chat/completions`，Node 内置 `https`；密钥只存云函数环境变量 `AI_BASE_URL` / `AI_API_KEY` / `AI_MODEL`，客户端零密钥）。
- 前端新增 `service/CloudAiService.ets`（组装真实上下文：昵称/今日专注/番茄/连续/打断原因/待办），`CloudFnService.call` 支持自定义 `readTimeout`（AI 用 60s）。
- `AIChat`（对话 + 建议卡）、`Stats`（AI 洞察）、`Home`（AI 建议卡）接入真实模型，**未登录或调用失败时回退本地文案**；删除原先写死的假洞察/假建议。
- 已在云函数配置 AI 环境变量（DeepSeek：`AI_BASE_URL`/`AI_MODEL=deepseek-chat`/`AI_API_KEY`/`AI_TIMEOUT_MS`）、函数超时提到 **60s** 并部署；联调通过：`ai.chat` 与 `ai.insight` 均返回真实模型回复（含用户数据上下文），未登录返回 `NO_USER`。
- **AI 用量治理**：新增 `ai_usage_self` 表（`user_id`+北京时间日期唯一，列名 `used` 避开 rdb 的 `count` 聚合冲突），云函数 `ai.js` 加**每人每日配额**（`AI_DAILY_LIMIT`，默认 50）+ **频率限制**（`AI_MIN_INTERVAL_MS`，默认 8s），超限返回 `AI_QUOTA_EXCEEDED` / `AI_RATE_LIMIT`；前端 `AIChat` 直接提示，`Stats`/`Home` 静默回退。DB 异常 fail-open。已部署并实测通过。
- **AI 聊天记录**：`AIChat` 对话（问 + 答）本地持久化（`Store`，按账号 `qf_ai_chat_<userKey>`，保留最近 200 条），进入页面自动恢复；顶栏「🗑」可一键**清空记录**（`promptAction.showDialog` 二次确认）。
- **AI 计划 → 待办联动**：`ai.chat` 支持 `wantPlan`（用户消息含「计划/规划/安排/清单/制定」等触发），云函数要求模型在回复末尾输出 ```json``` 计划块并解析为 `todos`（title/durationMin/difficulty）；`AIChat` 收到后**自动写入待办列表**并提示「已添加 N 个待办」，建议卡新增「制定今日计划」。

### Web / 小程序端（`qingfan(web)` 及同构小程序）

- **功能与鸿蒙端一致**：引导、登录注册、今日待办、专注计时、成长（我的）、统计、自习室、主题、AI 助手。
- 自习室已实现：`index.html`（我的自习室/自习动态/留言板/好友的自习室）、`login.html`、`create.html`、`join.html`、`room.html`（成员 + 交流/回复/点赞/删除/分页）。
- 登录/注册与鸿蒙同一套账号（`auth.login` / `auth.register`），token 存 localStorage。
- 小程序：与 Web 同构（`wx.cloud.callFunction`），身份为微信 OPENID。
- 三端共用云函数 `studyRoomFunctions` 与同一套账号，房间/留言互通。

## 已知问题 / 依赖后端

- 云函数无 `focus.record` 与成员 `nickname/focus_minutes`，故成员真实昵称/真实时长排行暂不可得。
- （已解决 09-30）`room.create` 的 `room_no` 唯一约束冲突、`room.listMine` 的 `member_count` 恒为 1、该环境不可访问。
