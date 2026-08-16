# SimpleDispel 阶段 1 游戏内验证

此文档用于验证 12.1 Aura Container 与安全点击原型。当前版本只显示 `player` 和 `party1` 两个测试方块。

## 安装

1. 将仓库目录复制或链接为：
   `_retail_/Interface/AddOns/SimpleDispel`
2. 确认目录内直接存在 `SimpleDispel.toc`，不能再多套一层目录。
3. 启动游戏，在角色选择界面启用 SimpleDispel。
4. 建议启用 Lua 错误：`/console scriptErrors 1`
5. 输入 `/reload`。

## 首次检查

登录后应在屏幕中下方看到 `SELF` 和 `P1` 两个方块，并在聊天框看到加载信息。

运行：

```text
/sd status
```

记录以下内容：

- `auraContainer=yes`
- 当前过滤器应为 `HARMFUL|RAID`
- 自动识别到的技能名称和 spell ID
- 是否出现 `last aura error`

如果没有自动识别驱散技能，将鼠标放到法术书中的驱散技能上取得 spell ID，然后运行：

```text
/sd spell 你的技能ID
```

恢复自动选择：

```text
/sd spell auto
```

## 安全点击测试

1. 与一名队友组队，让他成为 `party1`。
2. 保持一个无关的敌人或友方为当前目标。
3. 让自己或队友获得当前驱散技能能够解除的效果。
4. 在战斗中点击对应的 `SELF` 或 `P1` 方块。
5. 确认驱散施放到方块对应成员，且当前目标没有变化。
6. 测试射程外、技能冷却、成员死亡时是否只是正常施法失败。

## Aura 显示测试

默认过滤器：

```text
/sd filter mine
/reload
```

它使用 `HARMFUL|RAID`，预期只显示当前玩家可处理的有害效果。

另外两种过滤器仅用于比较 12.1 客户端实际行为：

```text
/sd filter group
/reload
```

```text
/sd filter all
/reload
```

- `group` 使用 `HARMFUL|RAID_PLAYER_DISPELLABLE`。
- `all` 使用 `HARMFUL|DISPELLABLE`。
- 每次只测试一种；完成后恢复 `mine`。

不要通过 Aura Button 的显示、隐藏或数量推导 aura 数据。本测试只观察玩家在屏幕上实际看到的结果。

## 错误检查

重点记录：

- Lua 错误完整堆栈。
- `ADDON_ACTION_FORBIDDEN`。
- 点击方块没有施法或施法对象错误。
- aura 图标显示但吞掉点击。
- 进入战斗后才出现的 secret/forbidden 错误。

可选启用 taint 日志：

```text
/console taintLog 2
/reload
```

测试结束后可以关闭：

```text
/console taintLog 0
```

## 回报模板

```text
客户端版本与 Build：
地区与语言：
职业/专精：
自动识别技能：
过滤器：

AuraContainer：通过 / 失败
SELF 点击：通过 / 失败
P1 点击：通过 / 失败
当前目标保持不变：是 / 否
战斗中错误：无 / 有

Lua 错误或补充说明：
```
