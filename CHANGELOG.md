# Changelog

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
