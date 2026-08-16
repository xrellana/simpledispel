# Changelog

## 0.10.0-beta.4 — 2026-08-16

- 小队按钮由 `P1`–`P4` 改为直接显示实际队员名字。
- 小队 debuff 图标底部预留姓名栏，图标出现时仍可识别成员。
- 名字只直接交给 FontString 显示，不读取、截断、比较或参与战斗决策。
- Raid 保持紧凑的 `1`–`40` 固定编号网格。

## 0.10.0-beta.3 — 2026-08-16

- 修复安全按钮只注册 `LeftButtonUp`，在默认按下施法 CVar 下不执行动作的问题。
- 同时注册 LeftButton 按下与抬起事件，并用 `useOnKeyDown=false` 明确只在抬起时施法一次。
- 新增 SecureActionButton 点击注册、固定单位和施法属性专项测试。

## 0.10.0-beta.2 — 2026-08-16

- 修复 Aura 图标覆盖安全按钮时，点击图标不能触发驱散的问题。
- 在 Aura Button 初始化窗口内启用原生鼠标点击传播，保留图标、倒计时和 tooltip。
- 保留 `SetPassThroughButtons("LeftButton")` 作为客户端兼容降级路径。

## 0.10.0-beta.1 — 2026-08-16

- 新增独立 Raid 模式，预创建固定 `raid1`–`raid40` 安全按钮。
- 新增 8×5 团队网格，Raid 中自动安全切换，小队布局自动隐藏。
- 小队与团队分别保存位置和缩放。
- `/sd scale` 和 `/sd reset` 新增 `party`、`raid`、`all` 参数。
- 团队按钮使用 32 像素图标和原生冷却转圈，省略外置持续时间文字以避免网格重叠。
- SavedVariables schema 升级到 3，并迁移原五人版位置与缩放。
- 新增 45 按钮模拟运行时测试。

## 0.9.0-beta.1 — 2026-08-16

- 五人小队 MVP：`player` 与 `party1`–`party4`。
- 新增拖动、锁定、缩放、重置和设置持久化。
- 新增可安装 beta ZIP 与副本实测清单。

## 0.1.0-alpha.1 — 2026-08-16

- 建立 `player`/`party1` 安全点击与 Aura Container 技术验证原型。
