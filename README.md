# SimpleDispel

一个面向 World of Warcraft 正式服 12.1+ 的轻量点击驱散插件。

当前版本：`0.10.0-beta.4`。它预创建 5 个小队按钮和 `raid1`–`raid40` 共 40 个团队按钮，点击对应方块会直接对该固定单位施放角色当前学会的友方驱散，不改变当前目标。插件只让游戏自身的 Aura Container 显示系统过滤后的一个可驱散效果，不读取或分析受保护的 aura 数据。

- 单人/小队：`YOU` 与四名队员名字组成五人横条；名字栏在 debuff 图标出现时仍然保留。
- 团队：进入 Raid 后安全切换到 8×5 网格，编号对应 `raid1`–`raid40`。
- 不存在的成员按钮通过安全状态驱动隐藏。
- 小队与团队分别保存位置和缩放。

## 使用

将整个目录复制为：

```text
World of Warcraft/_retail_/Interface/AddOns/SimpleDispel
```

进入游戏后拖动标题栏调整位置，再输入：

```text
/sd lock
```

常用命令：

```text
/sd status
/sd lock
/sd unlock
/sd scale 1.0
/sd scale raid 0.8
/sd reset [party|raid|all]
/sd spell auto
/sd spell <spellID>
```

`/sd scale 0.8` 调整当前可见布局；也可以用 `/sd scale party 1.0` 或 `/sd scale raid 0.8` 明确指定。团队框架只能在已进入团队且脱战时拖动。

进地下城或团队前请查看 [BETA_TESTING.md](BETA_TESTING.md)。完整范围、阶段计划以及 12.1 API 硬限制的停止规则见 [DEVELOPMENT_PLAN.md](DEVELOPMENT_PLAN.md)，版本变化见 [CHANGELOG.md](CHANGELOG.md)。

## 已知限制

- 团队格按固定 `raid1`–`raid40` 编号排列，不根据职业、职责、名字或 debuff 自动重排。
- 一次只显示游戏过滤后返回的一个可驱散效果。
- 40 个 Aura Container 已通过创建路径模拟测试，但仍需要 12.1 正式服团队战斗验证性能、点击穿透和 taint。
- 当前版本不是自动驱散，也不会自动选择最优成员；每次驱散都需要玩家点击对应方块。
