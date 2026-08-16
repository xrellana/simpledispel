# SimpleDispel 0.10.0-beta.3 Party/Raid 实测

这个版本具备五人小队和最多 40 人团队的基本路径，但尚未经过 WoW 12.1 正式服完整战斗验证。第一次建议使用普通/英雄地下城、随机团队或不重要的普通团队，不要直接用于高层钥匙或开荒关键场次。

## 1. 安装与启动

1. 把插件目录放到 `_retail_/Interface/AddOns/SimpleDispel`。
2. 确认 `SimpleDispel.toc` 就在该目录内，没有多套一层文件夹。
3. 在角色选择界面启用 SimpleDispel。
4. 首次测试前输入 `/console scriptErrors 1`，然后 `/reload`。

单人时应看到 `YOU`；小队中出现 `P1`–`P4`。进入 Raid 后小队横条会安全隐藏，改为编号 `1`–`40` 的 8×5 团队网格，只有实际存在的 `raidN` 按钮显示。

在脱战状态使用 `/sd unlock`，拖动当前可见布局的标题栏定位，最后输入 `/sd lock`。小队和团队的位置分别保存。

## 2. 测试前检查

输入：

```text
/sd status
```

正常结果应包含：

- `addon=0.10.0-beta.3`
- 单人/小队时 `mode=party`，团队中 `mode=raid`
- `auraContainer=yes`
- `containers=45`
- `buttons=5+40`
- `filter=HARMFUL|RAID`
- `spell=技能名称 (spellID)`

如果显示 `spell=none`，先确认当前职业或专精确实有友方驱散。若自动识别漏掉已学会技能，可从法术书取得 spell ID，脱战输入：

```text
/sd spell <spellID>
```

恢复自动选择：`/sd spell auto`。

## 3. Party 测试

保持怪物为当前目标，等待自己或队友出现你能处理的 debuff：

1. 对应的 `YOU`/`P1`–`P4` 方块应出现 debuff 图标。
2. 点击图标所在方块，应对该固定成员施放驱散。
3. 当前怪物目标不应改变。
4. debuff 消失后图标应自行消失。
5. 战斗中队员死亡、掉线或离队不应产生 protected/forbidden 错误。

## 4. Raid 测试

先加入团队并保持脱战，确认团队网格出现，然后测试：

1. 10/20/30/40 人规模下，只显示实际存在的编号格。
2. 某个团员获得可驱散效果时，对应 `raidN` 格显示图标。
3. 点击图标中心和方块边缘都能驱散同一固定团员。
4. 玩家自己在 `raid1`–`raid40` 中只出现一次，不额外显示 `YOU`。
5. 战斗中换队、掉线、死亡或有人加入/离开时，没有安全动作错误。
6. 连续战斗 30 分钟观察是否出现明显卡顿或持续内存增长。
7. 离开团队后应自动恢复五人横条；重新进团后团队位置和缩放仍保留。

团队格使用固定 raid index，不尝试读取受保护身份后重新排序。编号与 Blizzard 当前团队 roster 的 `raidN` 一致。

## 5. 快速区分故障

- 图标出现，点击边缘能驱散，但点击图标本身不行：Aura Button 吞点击。
- 没有图标，但盲点对应方块可以驱散：安全施法正常，Aura 过滤或显示路径异常。
- 图标和盲点都不能驱散：检查 `/sd status` 的技能、施法距离、冷却和 Lua 错误。
- 点击某编号却驱散另一人：立即停止使用并报告，这是最高优先级单位绑定错误。

## 6. 第一优先级错误

遇到以下任一情况就停止依赖该版本并记录完整错误：

- `ADDON_ACTION_FORBIDDEN`
- secret-value 或 forbidden-frame 错误
- 点击 Pn/raidN 却驱散到另一名成员
- 点击改变当前目标
- 进战后按钮失效，出战后仍不能恢复
- 团队模式出现明显持续卡顿

回报模板：

```text
/sd status 的全部输出：
职业/专精：
Party 或 Raid（人数）：
副本/团本与触发 debuff：
图标显示：正常 / 未显示 / 显示错误
点击图标：成功 / 失败
当前目标保持：是 / 否
性能：正常 / 卡顿
完整 Lua 错误：
```

## 7. 命令速查

```text
/sd unlock                  解锁两个布局
/sd lock                    锁定两个布局
/sd scale 0.60-2.00         调整当前布局缩放
/sd scale party 1.00        明确调整小队缩放
/sd scale raid 0.80         明确调整团队缩放
/sd reset                   重置当前布局
/sd reset party|raid|all    重置指定布局
/sd status                  输出诊断信息
```

过滤器默认保持 `mine`。`group` 和 `all` 仅用于排查显示问题，修改后需要 `/reload`：

```text
/sd filter mine
/reload
```
