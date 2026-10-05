# SimpleDispel 当前开发状态与后续计划

2026-09-27 工作区更新：Party 和 Raid 均改为左上角左侧外缘的 16 × 28 悬停拖动把手，去掉两种布局原有标题的 22 像素留白和大背景；锁定、解锁不再移动布局，锁定或进入战斗会禁用并停止拖动。Party 按钮、图标和名字条尺寸不变，外框高度为显示名字 70、隐藏名字 56。四个 Lua 5.4 测试套件已通过，包含新增 Options 页面与 Core 的集成 mock 测试。实际客户端的鼠标命中、屏幕边缘约束和战斗行为仍待按 `BETA_TESTING.md` 验证。Party/Raid 独立缩放沿用 `/sd scale <party|raid> <0.60-2.00>`，默认均为 1.00。本节以下保留此前审计记录，其中旧版 Party/Raid 标题栏行为以此更新为准。

当前工作区新增 `Options.lua` 原生 Retail Settings 页面：位于 `Options > AddOns > SimpleDispel`，可由 `/sd` 或 `/sd options` 打开，`/sd help` 继续输出命令帮助。页面覆盖现有锁定、主题、无驱散显示、Party/Raid 缩放与布局、技能、过滤器、重置和诊断功能，并提供英文、zhCN、zhTW 标签；过滤器仍须通过 Reload UI 生效。设置注册、保存值与命令同步、重置后的读取、控件更新框体、缩放范围、战斗延迟、过滤器重载分离和技能 ID 弹窗校验已获 mock 覆盖，真实客户端行为仍待验证。

## 1. 审计结论

- **审计日期：** 2026-08-17
- **审计基准：** 当前 `HEAD`；插件版本 `1.0.0`；Retail `Interface: 120100`
- **当前判断：** Party/Raid 的主要代码路径已经实现，并有离线 mock 测试覆盖结构和初始化逻辑；`1.0.0` 作为首个正式版本发布。安全点击、正式服战斗行为、taint/Forbidden、Raid 性能和职业/专精覆盖仍需持续扩大正式服验收，不应未经实测直接依赖于高层钥匙、开荒或其他重要内容。

本文是面向 review 的状态记录，不把“源码存在”误写成“正式服已验证”。每项能力使用以下状态：

| 状态 | 含义 |
|---|---|
| **代码已实现** | 当前源码包含可执行实现；不等于已通过正式服验收。 |
| **mock 已覆盖** | 离线 mock 测试覆盖了指定结构或分支；不等于真实 WoW API 行为成立。 |
| **正式服待验证** | 代码路径已存在，但需要在 Retail 12.1 实际客户端、战斗或团队环境确认。 |
| **尚未实现/暂不做** | 当前没有实现，或明确不属于本阶段范围。 |

当前没有发现 Lua 源码中的 `TODO`、`FIXME` 或明显空函数/stub；未完成内容主要是正式服验证、功能范围和质量门禁，而不是隐藏的代码占位符。

## 2. 项目目标与明确边界

SimpleDispel 的“一键驱散”是：插件为固定 unit token 创建成员方块；客户端的 Aura Container 显示系统过滤后的效果；玩家点击对应方块；安全按钮对该固定 unit 施放当前配置的友方驱散技能；过程中不需要切换当前目标。

项目不实现：

- 自动选择应该驱散的成员、自动排序驱散优先级或自动施法；
- 读取、比较、推导或通过侧信道恢复 secret aura 数据；
- 战斗日志驱动的自动目标判断、自动点击、输入模拟或外部程序；
- Classic 客户端支持；本项目目标是 Retail 12.1+。

## 3. 12.1 API 安全边界

实现必须遵守以下边界：

- Aura 只通过 `CustomAuraContainerTemplate` 和系统过滤器显示；不枚举、比较或解析受限 aura payload。
- 不使用 `UNIT_AURA` payload、Aura Button 的显示/隐藏/尺寸变化、tooltip、帧数量、声音、耗时或布局变化推导战斗信息。
- 每个安全按钮永久绑定固定 unit token；protected attribute 只在脱战时更新。
- Party/Raid 成员显示和布局变化使用安全状态驱动；战斗中的非安全更新进入脱战队列。
- 范围提示只针对当前实际选中的友方驱散 spell，通过 `C_Spell.IsSpellInRange` 检查现存 unit，约每 0.25 秒刷新；它只改变普通视觉层，不禁用安全点击。
- `IsSpellInRange` 返回 `true` 时保持正常外观，`false` 时显示暗色遮罩、红边和 `×`，`nil` 时保持中性；范围提示不判断 LoS，并允许客户端刷新延迟。
- 驱散技能冷却通过 `C_Spell.GetSpellCooldown` 的非 secret 状态字段显示；实际技能 CD 使用中性暗层和琥珀色 `CD`，普通 GCD 不触发提示，且不读取受限的精确剩余时间。
- 冷却与范围提示共用合成后的视觉层：范围外保留红边和 `×`，冷却标记可同时出现，暗层不重复叠加；两种提示都不隐藏 debuff、不禁用安全点击。
- 若官方 API 不支持某项功能，应停止该项或记录降级，不使用 taint、hook、时序漏洞或污染安全路径绕过限制。

## 4. 当前实际文件结构

| 文件 | 当前职责 |
|---|---|
| `SimpleDispel.toc` | Retail 12.1 manifest、版本、SavedVariables 和加载顺序。 |
| `Core.lua` | 初始化、SavedVariables 迁移、Party/Raid 根框架、布局、事件、斜杠命令和模块协调。 |
| `Options.lua` | Retail Settings 页面、代理设置、重置/重载/诊断按钮、技能 ID 弹窗和 English/zhCN/zhTW 标签。 |
| `DispelSpells.lua` | 各职业候选技能、spellbook/已知技能检测和自动解析。 |
| `SecureButtons.lua` | `SecureActionButtonTemplate`、固定 unit、点击注册、spell attribute 和安全可见性。 |
| `AuraDisplay.lua` | Aura Container、过滤器、单个 aura slot、图标/cooldown/count/duration 初始化和点击传播。 |
| `tests/test.lua` | Core 的 mock runtime 测试。 |
| `tests/secure_button_test.lua` | 安全按钮的 mock API 测试。 |
| `tests/aura_input_test.lua` | Aura Button 初始化和鼠标传播的 mock API 测试。 |
| `tests/settings_mock.lua` | Options.lua 使用的最小 Retail Settings API mock。 |
| `.github/workflows/release.yml` | 校验 TOC 版本、打包 Lua/TOC 并创建 GitHub release。 |

当前不存在计划早期列出的 `Layout.lua`、`Locale.lua`；布局、SavedVariables/命令功能仍集中在 `Core.lua`，Retail Settings 页面由 `Options.lua` 提供。Options 内含三种客户端语言的标签，但尚未拆出独立 locale 模块。

## 5. 已实现能力与证据

| 能力 | 状态 | 代码证据 | review 说明 |
|---|---|---|---|
| Manifest、版本和 SavedVariables | 代码已实现 | `SimpleDispel.toc:1-14` | 当前版本为 `1.8.0`。加载是否无 Lua 错误仍需游戏内确认。 |
| Party 五个固定 slot | 代码已实现；mock 已覆盖 | `Core.lua:305-337`；`tests/test.lua:223-231` | 固定为 `player`、`party1`-`party4`；按钮保持 48 × 62（隐藏名字时 48 × 48），外框高度为 70/56。 |
| Raid 四十个固定 slot | 代码已实现；mock 已覆盖 | `Core.lua:370-408`；`tests/test.lua:223-231` | 固定为 `raid1`-`raid40`，不动态重排。 |
| Party/Raid 安全显示切换 | 代码已实现；mock 已覆盖 | `Core.lua:230-236`、`SecureButtons.lua:53-58`；`tests/test.lua:249-261` | 具体客户端 protected frame 行为仍待验证。 |
| Raid 八列及按人数调整行数 | 代码已实现；mock 已覆盖 | `Core.lua`；`tests/test.lua` | 固定 28 × 28 方格，8 列、最多 5 行；10/20/25/30/40 人分别使用 2/3/4/4/5 行。 |
| Party 成员名称与 Raid tooltip 识别 | 代码已实现；mock 已覆盖 | `Core.lua`；`tests/test.lua` | Party 可直接显示名称；Raid 不常驻显示姓名，普通 unit button tooltip 仅用于识别，不能用于排序或战斗决策。 |
| 每个单位一个 Aura Container | 代码已实现；mock 已覆盖 | `AuraDisplay.lua:104-164`；`Core.lua:241-273`；`tests/test.lua:232` | 当前创建 45 个容器。 |
| 系统过滤 aura、图标、cooldown、层数、可选持续时间 | 代码已实现；仅部分初始化由 mock 覆盖 | `AuraDisplay.lua:8-12,14-84`；`tests/aura_input_test.lua:111-137` | mock 只覆盖部分初始化调用；过滤器实际语义、tooltip、驱散类型边框和真实客户端显示仍待正式服确认。 |
| 驱散范围视觉提示 | 代码已实现；正式服待验证 | `Core.lua`；`C_Spell.IsSpellInRange` | 使用当前实际驱散 spell，约每 0.25 秒刷新；`true` 正常、`false` 暗色遮罩+红边+`×`、`nil` 中性。只提示不禁用点击，不能判断 LoS。 |
| 驱散技能冷却视觉提示 | 代码已实现；正式服待验证 | `Core.lua`；`SecureButtons.lua`；`C_Spell.GetSpellCooldown` | 实际技能 CD 显示中性暗层+琥珀色 `CD`，忽略普通 GCD；debuff 保持可见，点击保持启用，并可与范围外提示同时显示。 |
| Aura 图标左键传播降级路径 | 代码已实现；`SetPropagateMouseClicks` 成功路径 mock 已覆盖 | `AuraDisplay.lua:20-40`；`tests/aura_input_test.lua:122-126` | `SetPassThroughButtons` fallback 未覆盖；能否在真实受保护 Aura Button 上稳定传到安全按钮仍是 P0。 |
| 固定 unit 的安全施法按钮 | 代码已实现；mock 已覆盖 | `SecureButtons.lua:37-57,99-119`；`tests/secure_button_test.lua:96-145` | 只证明属性和注册方式，不证明战斗内施法成功。 |
| 左键按下/抬起及 `useOnKeyDown=false` | 代码已实现；mock 已覆盖 | `SecureButtons.lua:42-50`；`tests/secure_button_test.lua:104-108` | 用于避免依赖账号级 `ActionButtonUseKeyDown`。 |
| 自动候选技能解析 | 代码已实现 | `DispelSpells.lua:8-16,18-107` | 按职业候选顺序检查已知 spell；尚无每职业/专精正式服验证。 |
| 专精、技能和天赋变化触发刷新 | 代码已实现 | `Core.lua:633-670` | 当前只是重新运行职业候选列表，并未实现真正的专精/天赋条件逻辑。 |
| 手动 spell ID override | 代码已实现 | `Core.lua:491-512`；`DispelSpells.lua:80-87` | 已知风险：只确认客户端能取得 spell 信息，不强制确认角色已学会该 spell。 |
| SavedVariables、旧版迁移和 Party/Raid 独立缩放 | 代码已实现；mock 已覆盖 | `Core.lua:78-107,149-183`；`tests/test.lua:219-222,267-301` | schema 当前为 3。 |
| 锁定、解锁、拖动、重置和战斗延迟 | 代码已实现；部分 mock 已覆盖 | `Core.lua`；`tests/test.lua` | Party/Raid 都没有顶部标题留白；两者使用左上角左侧外缘的 16 × 28 悬停把手。正常驱散布局隐藏大背景，锁定或进入战斗会禁用并停止拖动，布局尺寸和位置偏移不因锁定改变。战斗内实际 protected 行为仍需验证。 |
| Retail Settings 页面 | 代码已实现；集成 mock 已通过 | `Options.lua`；`Core.lua`；`tests/test.lua`；`tests/settings_mock.lua` | 位于 `Options > AddOns > SimpleDispel`，`/sd` 和 `/sd options` 可打开；覆盖现有配置、布局重置、过滤器 Reload UI、技能下拉/自定义 ID 验证和诊断输出。与斜杠命令共用处理器和战斗延迟；真实客户端行为仍待验证。 |
| 诊断命令 `/sd status` | 代码已实现 | `Core.lua:438-480` | 可输出版本、Build、模式、容器数、过滤器和技能信息。 |
| 过滤器、缩放、重置和 spell 命令 | 代码已实现；部分 mock 已覆盖 | `Core.lua:482-610`；`tests/test.lua:267-288` | 修改 filter 后需要 `/reload` 重建容器。 |
| Release 打包工作流 | 代码已实现 | `.github/workflows/release.yml:1-77` | 只打包 Lua/TOC 并发布；当前没有 test job。 |

## 6. Mock 测试覆盖与边界

已有测试覆盖：

- `tests/test.lua`：SavedVariables 迁移、45 个按钮和容器的结构、unit-button 设置、网格位置、visibility driver、Party/Raid 高度、缩放/重置、悬停把手、拖动清理和战斗延迟。
- `tests/secure_button_test.lua`：固定 unit、左右键注册、`useOnKeyDown`、spell attribute、范围/冷却合成视觉状态、Party/Raid visibility driver。
- `tests/aura_input_test.lua`：Aura Button 尺寸、图标、cooldown、层数、持续时间、native mouse motion 和点击传播初始化。
- `tests/settings_mock.lua`：为 `tests/test.lua` 中的 Options/Core 集成测试提供 Settings、滑块、下拉框、按钮、弹窗和 Reload UI 的最小 mock；不能验证真实控件的排版、鼠标输入和三种语言的实际显示。

这些测试使用自建 API mock，不能证明真实客户端会接受 protected action，不能证明目标不变、点击图标一定成功，也不能发现真实 taint、`ADDON_ACTION_FORBIDDEN`、secret-value/forbidden-frame、战斗 roster 行为或 40 个容器的性能问题。`tests/test.lua` 还替换了 `SecureButtons`、`AuraDisplay` 和 `Spells`，因此不等于端到端集成测试。

2026-09-27 已在 Lua 5.4 环境执行四个测试套件并全部通过。仓库不提供解释器，项目源码不依赖 Ace3 或其他第三方 addon 库。当前 release workflow 会在打包前运行这四个测试套件；此前审计中未执行测试的环境结论不再代表当前工作区。

## 7. 正式服待验证项（P0/P1 验收门禁）

以下事项不能从源码或 mock 推断为已完成：

- `/reload` 和登录时无 Lua 错误，Aura Container 在目标 Retail 12.1 Build 上可用。
- Party 中点击空白区域、Aura 图标中心和图标边缘，均只对被点击的固定 unit 施放技能。
- 点击前后当前目标保持不变；射程外、死亡、冷却或无可驱散效果时只产生正常施法失败。
- Aura 出现、消失、倒计时、层数、tooltip、过滤器结果和图标点击传播符合预期。
- Party 外框在显示/隐藏名字时分别为 70/56，按钮、图标和名字条尺寸保持不变；10/20/25/30/40 人 Raid 均显示为 28 × 28、8 列、最多 5 行的固定网格。两种布局都没有顶部标题留白，解锁时左上角左侧外缘显示 16 × 28 悬停把手，锁定或战斗时禁用并停止拖动。
- 范围提示按当前实际驱散 spell 约每 0.25 秒刷新；`true`、`false`、`nil` 的视觉状态正确，提示不禁用点击，也不把 LoS 当作范围判断。
- 驱散实际 CD 期间 debuff 继续显示，方块出现中性暗层和琥珀色 `CD`；普通 GCD 不触发，CD 结束后恢复，且与范围外红边/`×` 正确共存。
- 战斗中加入、离开、掉线、死亡、复活、换队和 roster 变化不产生 protected/forbidden 错误；脱战后延迟更新能够恢复。
- 没有 `ADDON_ACTION_FORBIDDEN`、secret-value、forbidden-frame、blocked-action 或 taint 记录。
- 10/20/25/30/40 人团队均能正确显示固定 `raidN` 对应成员，不误点其他成员。
- 40 个 Aura Container 在至少 30 分钟真实团队场景中没有明显卡顿、异常内存增长或不可接受的帧创建/布局开销。
- 每个声明支持的职业、专精和实际天赋组合至少完成一次真实可驱散效果测试；未测试组合不得写成已支持。

正式服测试应记录客户端 Build、职业/专精、场景、过滤器、spell、完整 `/sd status`、Lua 错误、taint 和实际点击结果。`BETA_TESTING.md` 是执行步骤和回报模板，不是已经通过的测试结果。

## 8. 尚未实现、已知风险与暂不做

### 尚未实现或仍需代码工作

- 真正按专精/天赋条件筛选和验证候选驱散技能；当前仅按职业候选表和 spellbook 已知状态选择。
- 简体中文、繁体中文和英文的 locale 系统；当前没有 `Locale.lua`，命令文本主要直接写在 `Core.lua`。
- 可配置方块大小、间距、每行数量、横向/纵向增长方向。
- 不依赖真实 aura 的布局测试模式。
- Native Retail Settings 页面已覆盖当前 MVP 设置并通过集成 mock；仍需真实客户端验收，超出当前页面范围的自定义 GUI 暂不做。
- 独立的 PR 测试 workflow；当前四个 mock 套件已在 release workflow 的打包前执行。

### 已知风险

- `/sd spell <spellID>` 不强制验证角色已学会该 spell；误设未知或不可用技能可能导致按钮不可施法。
- 每个单位只显示一个系统过滤后的 `dispel` slot；过滤器具体结果由客户端决定，插件不解析 aura。
- Native Retail Settings 页面和三种语言标签尚未完成真实客户端验证；离线测试不能验证实际排版、输入或 taint 行为。
- Party 名字显示设置或 Raid roster 在战斗中变化时，外框尺寸可能暂时保持旧值，计划在脱战后更新。
- Raid 使用固定 `raid1`-`raid40` 顺序和 8 列、最多 5 行的 28 × 28 方格；普通 unit-button tooltip 只用于识别，不保证按姓名、职业或职责排序。
- 范围视觉状态约每 0.25 秒刷新，可能因客户端延迟暂时滞后；`nil` 表示未知，提示不能判断 LoS；即使范围外也保留点击能力。
- 45 个 Aura Container 的真实性能和 taint 尚无证据。

### 明确暂不做

- 自动驱散优先级、自动选择成员、自动施法或输入模拟。
- 敌方净化/偷取、宁神/安抚、声音、黑白名单、副本数据库和 Classic 支持。

## 9. 重新排序的后续里程碑

### P0：正式服安全点击门禁

**工作：** 使用 Retail 12.1 实际客户端完成单人、五人和至少一个团队规模的低风险测试；重点验证 Party/Raid 布局、Native Settings 页面、28 × 28 Raid 网格、空白方块、Aura 图标、正确 unit、当前目标、范围视觉状态、战斗状态和错误日志。

**验收标准：**

- 每次点击只对显示方块固定绑定的 unit 施法；当前目标不改变；
- Aura 显示/消失和图标点击传播在战斗中稳定；
- 范围提示对当前实际驱散 spell 的 `true`、`false`、`nil` 状态表现正确，且不阻止范围外点击；LoS 不被误判为范围状态；
- roster 变化和脱战延迟更新可恢复；
- 无 Lua、`ADDON_ACTION_FORBIDDEN`、secret/forbidden、blocked-action 或 taint 问题；
- 记录完整测试结果，而不是只更新 checklist 状态。

若遇到 API 硬限制，停止该路径并记录降级方案；不得通过 secret 数据推导、taint 或侧信道绕过。

### P1：职业覆盖与 Raid 可靠性

**工作：** 逐职业/专精/天赋验证候选技能和手动 override；完成 10/20/25/30/40 人 roster、8 列最多 5 行 Raid 网格、死亡/掉线/加入/离开、范围提示、Raid 点击绑定及性能测试。

**验收标准：**

- README 只列出已经真实测试的职业/专精；
- 自动选择和手动选择的行为、未学会技能风险有明确结果；
- 各团队规模在战斗内外均无错误，30 分钟观察无明显卡顿或异常内存增长；
- `/reload` 后 Party/Raid 位置、缩放和模式切换保持正确。

### P2：易用性、本地化与工程质量

**工作：** 在 P0/P1 稳定后继续验证 Native Settings 页面、English/zhCN/zhTW 标签、尺寸、间距、行数、增长方向和测试模式；28 × 28、8 列最多 5 行作为当前默认布局保持稳定；为 mock 测试加入可执行的 CI job，并保持 release workflow 的版本校验。

**验收标准：**

- 新设置有 SavedVariables 迁移策略、命令/文档和 mock 覆盖；
- Native Settings 页面在英文、简体中文及繁体中文客户端均不会破坏显示或安全施法属性；
- CI 能在干净环境执行全部 mock 测试；
- 若未来需要超出 Retail Settings 的自定义 GUI，必须先明确扩大范围。

## 10. 稳定版门槛

`v0.1.0`（或后续稳定版）至少必须满足：

1. 插件在 Retail 12.1 目标 Build 正常加载，`/reload` 无错误；
2. Party 五人布局、固定 unit 和系统过滤 aura 正确显示；
3. 当前角色的友方驱散技能能可靠自动识别，或有明确可用的手动选择；
4. 战斗中一次玩家点击能对正确成员施法，且不改变当前目标；
5. Aura 图标点击和方块边缘点击行为一致；
6. 无 Lua、taint、secret-value、forbidden-frame、blocked-action 或 protected-action 错误；
7. 至少完成一次真实五人副本，并完成必要的 Raid/性能门禁；
8. README、CHANGELOG 和支持职业列表与实际验证结果一致。

项目已以 `1.0.0` 进入正式版本线；以上尚未完成的验收门槛继续作为后续版本的强化目标和风险提示。

## 11. 相关文档状态

- `README.md`：当前用户说明和正式版风险提示；其中“已支持”仍应以正式服验证结果为准。
- `BETA_TESTING.md`：Party/Raid 的执行步骤、检查项和回报模板，不代表测试已经通过。
- `STAGE1_TESTING.md`：**历史原型文档**，仍描述只有 `player`/`party1` 和 `SELF`/`P1` 的阶段 1 版本，不应作为当前 `1.0.0` 的功能说明。
- `CHANGELOG.md`：版本变更记录，不是正式服验收记录。

后续每次完成正式服测试、发现 API 限制或改变范围时，应同时更新本文件的状态、证据和验收结果。
