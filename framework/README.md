# 切割机框架使用说明

版本：2026-10-28，按流程图 v0.3 搭建，控制权限调整为实体面板决定模式；D2/D4 已接入真实伺服轴，其余设备仍走仿真。

## 控制来源

- 手动/自动模式只取自实体旋钮；初始化、启动、停止、报警复位来自独立实体按钮。
- `GVL_IO.stPanelInputs` 是预留的面板逻辑输入。端子、常开/常闭、极性和滤波须按实际接线配置，目前没有分配地址。
- `FB_PanelInput` 每周期先解码面板，`GVL_Interface.stPanel` 为监控结果，不是上位机写入入口。
- 仿真使用 `GVL_Simulation.stPanelInputs`，与实体面板字段相同。
- 上位机主要下发配方、读取状态。可选远程启停由本地工程配置 `GVL_Parameters.xAllowRemoteStartStop` 授权，默认 FALSE；此授权不提供给上位机写入。
- 即使授权，远程启动也须实体旋钮为自动、整机 Ready、本地停止未按下。远程不能切模式、初始化或复位。
- 急停反馈走独立安全许可 `xSafetyOK`；实际安全回路尚未接线，不作为普通 Modbus 命令处理。
- 连续/单循环取自本地工程配置 `GVL_Parameters.xContinuous`，远程启停帧不修改该项。

当前 Modbus 仅有逻辑缓冲区解析；参数寄存器、网络地址、按钮端子和手动点动按钮的物理映射仍待接入。

## 当前范围

框架已写入 `../beveling.project`。默认使用内部设备仿真，不会自行启动生产循环。
轴、普通电机、气缸、阀共用统一的命令与状态接口；设备类型有各自的 FB 入口。
所有框架设备均由同一条 `PLC_PRG` 调用链执行。

- 原任务中的 `PLC_PRG` 调用保持在 `ETHERCAT1` 下，不增加第二个调用。
- 原试轴程序保存为 `90_Legacy/PRG_AxisDemo`，没有周期调用。
- `GVL_Motion` 仅供旧 Demo 使用，新入口不引用它。
- 实机适配（仅 D2/D4）、真实 I/O 地址、硬件安全回路接口和 Modbus 网络映射尚未全部接入。
- `GVL_Parameters.xSimulation = FALSE` 会报未实现错误 3001，不会转入真实设备控制。**混跑时它必须保持 TRUE**：真实设备靠 `GVL_RealDevice.stSettings.axRealDevice[1..17]` 逐台接管，详见下一节。
- `GVL_IO.axDigitalOutputs` 为未映射的普通 BOOL 数组，当前每周期置 FALSE。

2026-10-15 框架逻辑版本的原生编译：0 错误、2 条警告（原有 CmpLog 日志库未加载、MainTask 未定义 POU）。
2026-10-28 接入 D2/D4 真实轴后重做 clean + build：同样 0 错误、同样 2 条警告，无新增告警。
已通过一次负向编译探针确认错误可以正确返回；探针已移除并重新编译、保存。
56 个代码对象的工程回读与本地源码一致。未登录、下载或运行物理 PLC，尚未执行循环运行验证，**真实轴也尚未上电试动**。
设备仿真为软件模型。位置动作默认在约 500 ms 完成，用于检查流程等待，不代表真实速度、加速度或机械响应。
默认位置、速度、时间是仿真示例，不是已调试的生产参数。

## 工程结构

| 文件夹 | 主要对象 | 职责 |
|---|---|---|
| `00_Types` | `E_MachineState`、`E_AutoStep`、`ST_Recipe` 等 | 状态枚举、命令、反馈和参数类型 |
| `01_Data` | `GVL_Interface`、`GVL_Parameters`、`GVL_IO` 等 | 面板接口、参数、逻辑 I/O 和通信数据 |
| `02_Devices` | `FB_Axis`、`FB_Motor`、`FB_Cylinder`、`FB_Valve`、`FB_DeviceManager` | 设备接口及命令执行 |
| `03_Units` | `FB_Initialize`、`FB_ClearanceUnit`、`FB_PostCut` 等 | 初始化、两路移开、三路收尾 |
| `04_Machine` | `FB_PanelInput`、`FB_Machine`、`FB_AutoCycle`、`FB_ManualControl`、`FB_Interlocks` 等 | 面板解码、模式调度、工序、互锁和报警 |
| `05_Communication` | `FB_ModbusInterface` | 缓冲区解析、序号确认和状态发布 |
| `06_Simulation` | `FB_SimDevice`、`FB_SimPlant` | 模拟位置、动作完成、来料及异常 |
| `90_Legacy` | `PRG_AxisDemo` | 原单轴 Demo，未调用 |

`sources/` 是对应的可审阅 ST 文本，`manifest.json` 保存对象类型、路径、声明和实现。
当前导出共 56 个代码对象（2026-10-28 新增 `ST_RealDeviceSettings`、`GVL_RealDevice`、`F_SafetyBypassActive`、`FB_RealAxis`）。
`build_sources.py` 仅生成本地源文件，不会自行修改 IDE 或连接 PLC。
`comments_zh.py` 为生成结果补充模块、变量和工序的中文说明，重新生成时会保留这些注释。
工程由 MCP 的创建对象、设置代码工具导入。
若在 IDE 里修改程序，应先导出或同步到这些文本，再考虑重新生成，避免覆盖人工修改。

## 中文注释阅读与调试顺序

2026-10-16 为 49 个代码对象补充中文说明，覆盖 475 处变量/结构字段声明、状态枚举和关键执行条件。
本次仅修改注释，变量名、默认参数、动作条件及任务调用关系保持原样；未重新执行编译或运行测试。
已直接核对编辑器接口中的 78 段声明/正文，中文字符与源码一致；生成脚本重新生成 49 个对象后内容也一致。

1. 从 `PLC_PRG` 查看调用顺序，再读 `FB_Machine` 中命令来源、模式、报警、互锁与设备执行分段。
2. 在线观察先看 `GVL_Interface.stStatus.eState`、`udiAlarm`、`xInitialized`，确认整机所处状态。
3. 自动等待点看 `eAutoStep`，再看对应 `ui...Step` 支线步骤；每个动作旁已标明机构名称和转步条件。
4. 动作不完成时，看 `uiBlockedDevice` 及 `aDeviceStatus[设备索引]` 的忙、故障、位置和命令序号。
5. `udiAcceptedID` 是设备已接收序号，`udiCompletedID` 是已完成序号；应与当前步骤的 `udiToken` 配合判断。
6. 旧程序中的保留变量会注明“未引用”或“未更新”，避免把历史变量误当成有效调试入口。
7. 真实轴问题先看 `GVL_RealDevice.stSettings` 的开关状态，再看 `FB_RealAxis` 的 `uiVerifyPhase` 与 `aDeviceStatus[2]/[4].udiErrorID`；4xxxx 说明是 MC 层报错，低 16 位就是原码。

## 状态与操作入口

整机状态 `GVL_Interface.stStatus.eState`：

| 值 | 状态 | 含义 |
|---|---|---|
| 0 | Stopped | 未初始化，或普通停止后 |
| 10 | Initializing | 初始化流程 |
| 20 | Ready | 初始化完成，自动模式下等待启动 |
| 30 | Manual | 手动模式，可接收手动请求 |
| 40 | Automatic | 自动运行，包含送料等料阶段 |
| 90 | Fault | 报警锁存，须清除原因并复位 |

将来在软件仿真运行环境中操作时：

1. 确认 `GVL_Parameters.xSimulation = TRUE`。
2. 设置 `GVL_Simulation.stPanelInputs.xAutoMode` 模拟旋钮：FALSE 手动，TRUE 自动。
3. 将 `GVL_Simulation.stPanelInputs.xInitialize` 置 TRUE 后清 FALSE，模拟独立初始化按钮。
4. 等待 `stStatus.xInitialized = TRUE`。自动模式下此时为 Ready；手动模式会进入 Manual。
   **手动模式不需要初始化**：旋钮切到手动且停止按钮未按下，就从 Stopped 直接进 Manual，开机后可以先动轴再决定是否初始化。
5. 自动模式下将 `GVL_Simulation.stPanelInputs.xStart` 置 TRUE 后清 FALSE，模拟启动按钮。
6. `GVL_Parameters.xContinuous = FALSE` 为单循环，TRUE 为连续；运行时清 FALSE，在本循环结束后停止。
7. `GVL_Simulation.stPanelInputs.xStop = TRUE` 模拟普通停止，取消动作及工序；释放后须重新初始化并启动。
8. 运行中切换手动/自动会停止，须在新模式重新初始化。
9. 报警原因清除后，给 `GVL_Simulation.stPanelInputs.xResetAlarm` 上升沿模拟复位按钮；复位只回到 Stopped。

软件中的安全许可是仿真/接口状态，不能替代真实急停与安全回路。
初始化第 25 步已接真实轴回零（`MC_Homing`），其余步骤仍按仿真机构位置组合执行；机构实际摆位参数仍需逐台标定。

## 手动控制

输入位于 `GVL_Interface.aManual[设备索引]`，反馈位于 `aDeviceStatus[设备索引]`。
进入手动后先释放全部手动按钮，再允许动作，避免切模式时接续旧的按住命令。

- 轴：按住 `xJogPositive` 或 `xJogNegative` 点动，松开停止；速度取 `lrVelocity`，真实设备再被 `lrVerifyVelocity` 限幅（默认 2.0，写更大也无效）。
  `FB_ManualControl` 每扫描先撤销该设备请求再按按钮重写，所以松开即撤销，不会残留上一扫描的点动。
- 轴或气缸：设置 `lrTarget`，给 `xMove` 上升沿，发出一次定位/动作请求。
- 真实轴回零：给 `xHome` 上升沿，发出一次 `Home` 请求并保持到本次回零完成；只支持 D2/D4。
  回零成功后 `aDeviceStatus[i].xHomed = TRUE`，绝对定位才被放行。走的是 `CmpHCMotion.MC_Homing`（上位机回零），
  回零方式、开始方向、零点信号、快慢速、回零坐标全部取自**轴配置**，PLC 侧只给 `Axis` 和 `Execute`；
  超过 `tHomeTimeout`（默认 30 s）报 2004。
- 连续电机或阀：`xRun` 按住运行，松开停止。
- 气缸的仿真目标通常是 0 / 1。具体方向见编号表。
- 相反点动同时有效、点动和定位同时有效等冲突会被拒绝；查看 `stStatus.uiManualReject`。
- **手动模式当前不做机构互锁**（`FB_Interlocks` 收到 `xManualMode` 为 TRUE 时整段跳过），单轴可以独立动作；`stStatus.uiBlockedDevice` 在手动下恒为 0。
  互锁只约束自动流程，主要内容：定长平移前先抬起；平台旋转前刀具和下压抬起、侧推解除；下刀前下压到位且相关机构移开；走刀前刀具和下压到位、盘刀运行；机械手按抬升/夹紧/后退/下降/回位关系执行。
  这些是框架中的软件条件，仍须结合最终机械结构补充和验证。手动下的硬干涉（D5 挡 D4 行程、平台旋转扫刀等）后续按调试情况逐条补回。

## 设备索引

| 索引 | 编号 | 设备 / 仿真位置 |
|---|---|---|
| 1 | D1 | 皮带电机 |
| 2 | D2 | 切割走刀 / 回刀轴 |
| 3 | D3 | 盘刀旋转电机 |
| 4 | D4 | 定长平移轴 |
| 5 | D5 | 定长升降；仿真 0=上升避让，1=下降检测 |
| 6 | D6 | 保留，当前工序不用 |
| 7 | D7 | 机械手平移轴 |
| 8 | D8 | 平台旋转轴 |
| 9 | G1 | 下压；0=抬起，1=下压 |
| 10 | G2 | 侧挡；0=抬起，1=下降，按料型选择继电器 |
| 11 | G3 | 推动气缸；0=解除侧推，1=动作 |
| 12 | G4 | 流利条；0=下降，1=提升 |
| 13 | G5 | 喷油阀 |
| 14 | G6 | 吹气阀 |
| 15 | G7 | 机械手升降；0=下降，1=提升 |
| 16 | G8 | 机械手夹爪；0=打开，1=夹紧 |
| 17 | G9 | 盘刀升降；0=提升，1=下降 |

`GVL_DeviceIds` 提供对应常量。G2 的三个逻辑继电器需求在 `GVL_IO.axG2RelayDemand[1..3]`，对应 300、400、600 料型，当前均未绑定实际输出。

## 真实轴接管（D2 / D4）

混跑设计：整机基准仍是仿真，真实设备按编号逐台接管。**`xSimulation` 不要改成 FALSE**，否则 `FB_Machine` 会立刻报 3001 并进 Fault，连手动都进不去。

| 项 | 内容 |
|---|---|
| D2 切割走刀 | `Axis_1`，汇川 SV660N，`InoSV660N` 从站 |
| D4 定长平移 | `ASDA_E3_1`，台达 ASDA-B3-E，`ASDA_B3_E_CoE_Drive` 从站 |
| 其余 15 台 | 继续 `FB_SimDevice` / `FB_Axis` / `FB_Motor` / `FB_Cylinder` / `FB_Valve` |
| 设置入口 | `GVL_RealDevice.stSettings`（类型 `ST_RealDeviceSettings`） |
| 适配功能块 | `FB_RealAxis`，每个真实轴一个实例，在 `FB_DeviceManager` 中无条件调用 |

开关与默认值（全部默认 FALSE，行为与纯仿真逐语句一致）：

| 字段 | 默认 | 作用 |
|---|---|---|
| `axRealDevice[1..17]` | 全 FALSE | 逐台接管。本版本只认 2 和 4，其它编号置 TRUE 会在该设备状态上报 3002 |
| `xRelativeVerify` | FALSE | 相对验证模式：**未回零**的真实轴把定位命令解释为「+d → 停留 → −d」往返；回零成功后自动改走绝对定位，本开关不再生效 |
| `xInterlockBypass` | FALSE | **预留字段**：手动模式已默认不做机构互锁，本开关当前不影响任何判定；后续给手动按需补互锁时再用 |
| `xSafetyBypass` + `xSafetyBypassConfirm` | 全 FALSE | 两级安全旁路，必须同时为 TRUE 才生效（`F_SafetyBypassActive`） |
| `xUseRealMaterial` | FALSE | TRUE 才用真实定长光电，默认仍由 `FB_SimPlant` 产生来料 |
| `lrVerifyDistance` / `Velocity` / `Acceleration` / `Deceleration` | 1.0 / 2.0 / 50.0 / 50.0 | 验证用的低速小加速度；速度同时作为真实设备的手动速度上限 |
| `tVerifyDwell` | 500 ms | 往返之间的停留，保证 Execute 拉低至少一个扫描 |
| `lrVerifyMeasuredByHand` | 0.0 | 人工用百分表量到的实际位移，用于核对轴单位 |
| `lrHomePosition` | 0.0 | **预留**：`MC_Homing` 没有 Position 入口，回零坐标改由轴配置决定，本字段当前不下发 |
| `tHomeTimeout` | 30 s | 单轴回零超时，超时报 2004 |

`FB_RealAxis` 的错误码（与原有 2xxx / 4xxxx 不冲突）：

| 码 | 含义 |
|---|---|
| 2001 | 速度非法或目标超软限位（沿用仿真语义） |
| 2002 | 真实轴未回零且未开相对验证，拒绝绝对定位；正常流程不会出现，回零成功即自动放行 |
| 2003 | 命令已接收但轴 3 秒未使能 |
| 2004 | 回零超时（`tHomeTimeout`），常见原因是原点开关没接到、回零方式选错或回零方向反了 |
| 2005 | 相对验证往返中途被中止 |
| 3002 | 该编号被请求接管但本版本未支持 |
| 40000 + MC 错误码 | 任一 MC 功能块报错，低 16 位保留原码便于查手册 |

### 回零（2026-10-30 接入，D4 已实测通过）

`FB_Initialize` 第 30 步对 D2/D4 发的是**绝对定位**（`lrCutHome` / `lrLengthPosition`），所以回零是初始化的前置条件。做法是**把回零并进初始化流程**，不必再手动先回零：

| 步骤 | 内容 |
|---|---|
| 10 | G9 抬刀、G1 抬压、G8 开夹爪 |
| 20 | D5 升起、G2 提升、G3 释放、G4 提升、G7 下降 |
| **25** | **D2 / D4 执行 `MC_Homing`**（新增） |
| 30 | D2/D4/D7/D8 绝对定位到配方坐标 |
| 40 | D5 下降 |

`FB_RealAxis` 的实现只有一行调用：

```st
fbHoming(Axis := Axis, Execute := xHomeReq);
```

**这里用的是 Inovance 的 `MC_Homing`（上位机回零），不是 PLCopen 的 `MC_Home`（驱动器回零）。** 两者不能混用：

| | `MC_Home` | `MC_Homing` |
|---|---|---|
| 谁在找原点 | 驱动器自己按 DS402 0x6098 方式找 | PLC 按轴配置一步步走 |
| 前提 | 驱动器必须支持 DS402 回零 | 驱动器只要能接受速度指令 |
| 本机 | **不支持**，会一直卡在 Homing 不动 | 正确选择 |

接口（`CmpHCMotion.MC_Homing`，已在库浏览器「输入/输出」页确认）：

| 名称 | 类型 | 方向 | 说明 |
|---|---|---|---|
| `Axis` | `AXIS_REF_SM3` | IN_OUT | 轴引用 |
| `Execute` | `BOOL` | IN | 上升沿启动 |
| `Done` | `BOOL` | OUT | 已到达终点位置 |
| `Busy` | `BOOL` | OUT | 功能块执行中 |
| `CommandAborted` | `BOOL` | OUT | 被其它功能块打断 |
| `Error` | `BOOL` | OUT | 出错 |
| `ErrorID` | `SMC_ERROR` | OUT | 错误码 |

- **只有 `Axis` 和 `Execute` 两个入口**，没有速度/方向/回零方式/原点开关之类的参数。回零方式、开始方向、原点输入检测方向、零点信号（Z 相）、正负限位模式、快慢速全部来自轴配置的「原点参数设置」页。
- `MC_Homing` **没有 `Position` 入口**，所以 `ST_RealDeviceSettings.lrHomePosition` 现在不参与下发，回零后的坐标由轴配置里的回零坐标决定。该字段保留但已降级为预留。
- 库引用：`CmpHCMotion, 1.1.8.0 (Inovance)` 必须加进**应用**的库管理器。工程里原本只有设备描述自带的引用，应用层 `MC_Homing` 会报「没有定义标识符」；而且它带命名空间，要写 `CmpHCMotion.MC_Homing`。
- `fbHoming.Done` → `xHomed := TRUE`，此后 `Position` 命令自动走绝对定位，不再看 `xRelativeVerify`；
- `fbHoming.Error` → `40000 + MC 错误码`；超时 → 2004，且**不置完成位**，避免上层误判已到位；
- `xHomed` 是普通变量，**断电和完整下载都会清零**，必须重新回零。增量编码器断电后位置本就不可信，这是刻意的保守设计。

`xRelativeVerify` 仍然保留，但语义收窄为「**未回零时**的临时替代」：把 Position 解释为「+`lrVerifyDistance` → 停留 → −`lrVerifyDistance`」，走完仍回写同一个 udiToken，上层 `F_Done` 语义不变。该模式下 `FB_Machine` 拒绝进自动（`uiRemoteResult = 4`），因为绝对位置是「假」的。

`lrVerifyRatio = 实测/指令` 只能证明「指令与反馈自洽」，**不能证明 1 个单位 = 1 mm**。轴单位若被错设成「转」，比值仍是 1.0 却实际走了 10 mm。真实比例必须用外部量具：命令走 1.000，用百分表读实际位移。

### 首轮调试顺序（每步都能独立验证）

1. `axRealDevice[2] := TRUE`，旁路全关 → 应出现 **1001**，`fbRealD2` 完全不动。这步不过，后面一律不做。
2. 打开 `xSafetyBypass` + `xSafetyBypassConfirm` → `xSafetyBypassed = TRUE`、`uiSafetySource = 2`，1001 清除，伺服使能。
3. 手动模式（**不需要初始化**，旋钮切手动即进 Manual）→ D4 负向点动 1 s（2 mm/s）→ 位置单调变化约 2 mm，无 MC 错误；再正向点动回原位。
   **历史陷阱一**：2026-10-29 之前这一步会失败——`fbMoveVel` 未指定 `Direction`，默认 `MC_Direction.current` 遇到负速度时方向不反转、速度失控（实测 D4 冲了 229 mm），且 `fbMoveVel.Error` 始终 FALSE。现已改为 `Velocity := ABS(...)` + `SEL` 显式方向。若再次出现「同向」或「超速」，先查这一处。
   **历史陷阱二**：`FB_ManualControl` 原先只在有按钮时写请求，松开后 `aRequest[i]` 残留 `Jog`，而 `FB_RealAxis` 第 50 相位靠 `None`/`Stop` 才停止，于是松手不停。现已改为每扫描先撤销再按按钮重写。若出现「松手还在动」，先查这一处。
   **历史陷阱三**：此时若 `uiBlockedDevice` 非 0、`aSelectedCommand[i].eAction` 被改成 `Stop`，说明被 `FB_Interlocks` 挡了，不是轴的问题。见下方互锁说明。
4. **回零**：给 `GVL_Interface.aManual[4].xHome` 一个上升沿 → `aDeviceStatus[4].xHomed` 变 TRUE、`stStatus.xRealAxesHomed` 变 TRUE。
   若 30 s 后报 2004，按「原点开关 → 回零方式 → 回零方向」的顺序查，别改 PLC 代码。
   **D4 已于 2026-10-30 15:26 实测通过**：回零后 `Axis.fActPosition = -0.0014`、`xHomed = TRUE`、`udiAlarm = 0`。D2 尚未用程序触发，所以 `xRealAxesHomed` 仍是 FALSE（它要求所有已接管的真实轴都回零）。
   **历史陷阱四**：2026-10-30 首次实机触发时轴完全不动、也不报错，`udiCounter` 加了 1（序号分配过）但 `udiLastID` 又回到 0。原因是 `FB_ManualControl` 的 `xHome` 分支抄了点动分支的写法，在分支开头就 `aPending[i].eAction := None`。点动是**电平动作**，每扫描重写 `aCommand` 即可；回零/定位是**保持型动作**，靠 `aPending` 锁存，每扫描重发直到 `F_Done`。提前清掉后 `Home` 只活一个扫描周期：第 N 扫描设备进相位 60，第 N+1 扫描收到 `None` → `FB_RealAxis` 5.2 段 `eAction = None AND uiPhase <> 0` → `xStopLatch := TRUE`、发 `MC_Stop`，`MC_Home.Execute` 只保持一周期就被打断。现已把清 `aPending` 移到「编号不支持」的 `ELSE` 分支。
   排查要点：**先看 `aPending[4].eAction` 是否在回零期间一直保持 `Home`、`uiPhase` 是否稳定在 60**，再看轴动不动。若 `uiPhase` 在 0 和 60 之间来回跳，就是这个坑。
   **历史陷阱五**：修完陷阱四后轴仍然不动、且 `fbHome.Busy` 一直 TRUE 不退。根因是发的是 `MC_Home`（驱动器回零），而两轴的回零方式都配成了「上位机回零」——驱动器不支持 DS402 回零，收到 Homing 模式后既不动作也不报错，PLC 侧就一直等。已改为 `CmpHCMotion.MC_Homing`。**判断方法：看轴配置「原点参数设置」页顶部的「回原方式」——写「上位机回零（回原指令：MC_Homing）」就必须用 MC_Homing。**
5. 百分表核对 1.000 指令的实际位移，误差 < 0.05 mm；差 10 倍说明轴单位/齿轮比配错。
6. 接 `ASDA_E3_1` 到 D4，重复 3~5。**这一步之前必须先确认台达从站能进 OP**。
7. 执行初始化 → `uiInitializeStep` 走 10→20→**25（回零）**→30→40→1000，回 Ready。
8. 最后 17 台一起跑自动（D2/D4 真实，其余仿真），确认一个完整循环三路收尾全部完成。

> **第 7、8 步已于 2026-10-30 17:0x 实测通过**（零代码改动，用的是 15:24 下载的版本）。
>
> **初始化**：步骤序列 10→20→25→30→40→1000 全部走到。步骤 25 里 D2 `xHomed` 由 FALSE 变 TRUE、位置 −125.08123 → 0；D4 保持 TRUE、位置 ≈0 —— 两轴 `MC_Homing` 都成功。步骤 30 里 D4 走满 100 mm 实测约 10.8 s（10 mm/s + 50 mm/s² 预估 10.4 s，吻合），末端读到 99.99996。终态 `eState = Ready(20)`、`udiAlarm = 0`。
>
> **自动循环**：连跑两轮，`udiCycleCount` 0→1→2，每轮都回 Ready，全程无报警、无步骤超时、`uiBlockedDevice` 恒 0。步骤序列 Idle → FeedWait(10) → StopFeed(20) → Push(30) → Clearance(40) → Rotate(50) → PressDown(60) → KnifeDown(70) → SpindleOn(80) → Cutting(90) → StopCut(100) → PostCut(110) → Complete(120)。
>
> **两轴交替**（本轮验证目标）：同一循环内 D4 与 D2 交替动四次，无同时运动 —— D4 100→0（Clearance P020）→ D2 0→20（Cutting）→ D2 20→0（PostCut A020）→ D4 0→100（PostCut C010）。3 变量 / 100 ms 高频采样实测位置：t=0 D2=0、D4≈0；t=2.8 s D2=7.84；t=5.6 s D2=20.0、D4=12.68；t=8.4 s D2≈0、D4=41.82；t=11.6 s D4=77.38；t=14.9 s D4=99.99998；t=18.5 s 回 Idle。终点 D2 = 4.77e−06、D4 = 99.99998，都精确停在各自目标位。
>
> **采样工具注意**：`monitor_variables` 是按变量顺序**串行**逐个读的，12 变量 / 55 s 时实际间隔退化到约 11 s，抓不到步骤跳转。后续测试控制在 **4 个变量以内**。另外同批次内 `eAutoStep` 比位置变量早读约 2~3 s，比对波形时要把这个偏移算进去。
>
> **接工件前必须注意**：`Cutting` 步 D2 正向的互锁要求 G1 下压到位 + G9 盘刀下降到位 + D3 `xActive`。D3 是仿真电机，收 `Run` 后 `xActive` 会置 TRUE，互锁过得去，但**物理盘刀实际不转**。本轮 D2 是空载电机所以无风险；一旦装料，这一点必须先解决。

> **2026-10-30 起手动模式不做机构互锁**，所以手动点动 D4 / D2 不会再被挡（`uiBlockedDevice` 在手动下恒为 0）。下面这段是历史记录，仅适用于自动流程，或将来给手动按需补回互锁时。
> 历史：`FB_Interlocks` 曾要求 D4 移动时 D5 在升起端（0.0），而初始化第 40 步把 D5 置到 1.0，所以初始化后手动动 D4 一定被挡（`uiBlockedDevice = 4`）；D2 正向还要求 G1 下压 + G9 下刀 + D3 盘刀运行三个条件同时成立。**任何情况下都不绕过 `xPermit` 和安全许可**。
>
> （自动流程适用）为什么「电机能转、初始化能跑、偏偏点动不动」：`FB_Interlocks` 只对 `xMotion` 检查机构互锁，而 `xMotion` 的定义是 `Jog` **或**「`Position` 且目标与当前位置差 > 0.01」。所以 `Run`（调试驱动电机）永远不检查，初始化里的 `Position` 因目标≈当前位置也常常不检查，只有点动必定检查。点动不动时先看 `stStatus.uiBlockedDevice` 和 `aSelectedCommand[i].eAction` 是否被改成了 `Stop`。
>
> 机构互锁现在只约束自动流程：`FB_Interlocks` 收到 `xManualMode` 为 TRUE 时整段跳过 CASE。自动流程里 D4 仍要求 D5 升起（`FB_ClearLength` 会先升 D5 再移 D4），D2 正向仍要求 G1 下压 + G9 下刀 + D3 盘刀运行。`xInterlockBypass` 已降级为预留字段，当前不影响任何判定。

## 自动工序

`GVL_Interface.stStatus.eAutoStep` 使用 `E_AutoStep`，数值可供上位机显示：

| 值 | 步骤 |
|---|---|
| 0 | Idle |
| 10 | FeedWait：送料，等定长光电新的到位变化 |
| 20 | StopFeed：停止输送 |
| 30 | Push：推动气缸动作 |
| 40 | Clearance：两路移开，全部完成后继续 |
| 50 | Rotate：平台旋转 D8 |
| 60 | PressDown：下压 G1 |
| 70 | KnifeDown：盘刀下降 G9 |
| 80 | SpindleOn：盘刀旋转 D3 |
| 90 | Cutting：走刀 D2 + 吹气 G6；指定切割长度到位后结束 |
| 100 | StopCut：盘刀和吹气停止 |
| 110 | PostCut：先 G9 提升，再 G1 提升，随后三路收尾 |
| 120 | Complete：三路均完成，本循环结束 |
| 900 | Fault |

两路移开：定长上升 D5 → 定长移开 D4；另一支线为流利条下降 G4 → 解除侧推 G3 → 侧挡下降 G2。

三路收尾：

- A：喷油 G5 → 回刀 D2。当前以 `tSpray` 模拟喷油时长，具体关闭时机仍须确认。
- B：侧挡提升 → 流利条提升 → 机械手提升 → 打开 → 前进 → 夹紧 → 拉动 → 打开 → 后退 → 下降 → 再回位。
- C：定长回指定位置 D4 → 下降 D5 → 确认下降到位，具备光电检测条件。

各子流程的 `uiStep` 使用 10、20、30…，1000 表示该支线完成。
对应当前子步已发布在 `stStatus.uiClearLengthStep`、`uiClearTransferStep`、`uiPostStep`、`uiReturnKnifeStep`、`uiUnloadStep`、`uiResetLengthStep`。
每个步骤分配新的命令序号，只等待匹配本次序号的完成反馈。
动作步骤默认超时 30 秒；正常 FeedWait 可一直等料。送料要求光电先离开再到位，避免上次残留到位信号直接触发切割。

## 仿真与异常注入

`GVL_Simulation.stSettings`：

- `xAutoMaterial=TRUE`：皮带运行、定长下降到位后，约 `tMaterialDelay` 产生一次料到位。
- `xAutoMaterial=FALSE`：由 `xMaterialSensor` 人工模拟料到位。
- `axStall[i]=TRUE`：设备不返回完成，用于检查步骤等待和超时。
- `axFault[i]=TRUE`：设备故障锁存；清 FALSE 后再复位报警。
- `xSafetyOK=FALSE`：模拟安全许可丢失；恢复 TRUE 后仍须复位、初始化、启动。

## Modbus 接口预留

这里只建立 PLC 数据接口，`GVL_Modbus.xEnable` 默认 FALSE；没有改变现有 MODBUS_TCP 设备参数，也没有绑定寄存器地址。
下表为缓冲区索引，不是 40001 地址；网络侧实际起始地址和字序须以后统一。

| awRx 索引 | 含义 |
|---|---|
| 0 | 协议版本，固定 2；旧 v1 帧被拒绝 |
| 1 | 命令序号，非零；写完参数后最后写入序号 |
| 2 | 仅允许 2=启动、3=普通停止 |
| 3 / 4 | 保留且必须为 0，不接受模式或连续选择 |

只有本地工程配置 `GVL_Parameters.xAllowRemoteStartStop=TRUE` 才接受上位机启停；模式、初始化、复位以面板为准，本地停止始终优先。
刚启用通信时会记录当前序号而不执行旧命令，后续新序号才处理。
配方待执行区为 `GVL_Parameters.stRecipe`；初始化/启动时校验并取快照，运行中不采用中途修改。配方字段尚未映射为 Modbus 寄存器，当前缓冲区解析不代表参数通信已完成。

| awTx 索引 | 含义 |
|---|---|
| 0 | 协议版本 2 |
| 1 / 2 | 整机处理后的命令序号 / 处理结果 |
| 3 / 4 | 整机状态 / 自动步骤 |
| 5 / 6 | 报警码低字 / 高字 |
| 7 / 8 | 循环计数低字 / 高字 |
| 9 / 10 / 11 / 12 | 仿真标志 / 已初始化 / 料到位 / 当前料型 |
| 13 / 14 | 解析器观察到的序号 / 格式检查结果 |
| 15 / 16 | 实体旋钮模式：0 手动 / 1 自动；远程启停授权 |
| 17 / 18 | 真实设备接管掩码（第 i 位=设备 i 走真实轴）；安全来源 0 仿真 / 1 真实 / 2 调试旁路 |
| 19 / 20 | 是否处于相对验证模式；初始化拒绝原因（回零已并入初始化，当前恒为 0，字段预留） |
| 32..48 | 17 个设备的位置，有符号 INT，缩放 0.1 工程单位 |

命令处理结果：0=接受，1=未授权远程启停，2=不支持命令，3=模式/状态/本地停止不允许，4=相对验证模式禁止启动自动，5=配方不合法。
**上位机不能只看 9 号字（xSimulation）**：混跑时它恒为 TRUE，必须结合 17 号掩码判断哪些编号已接实机。
格式检查结果 2 表示帧格式、版本、模式或命令码无效，未发给整机执行。
命令接受不表示动作完成；应继续读取整机状态、工序和报警。

## 中文注释与文本编码

外部 `.st`、Python、文档统一保存为 UTF-8，项目根目录的 `.editorconfig` 已声明该约定。
`.project` 由 InoProShop 管理，不能作为普通文本文件转换编码。
本机 SP11 的 MCP 写入接口需要先把 UTF-8 字节形式的文字转换成真正的 Unicode，再写入编辑器。
2026-10-16 已在独立工程副本核对新建 GVL、声明区及程序正文的中文，保存、关闭、重开后的字符值一致。
这项修正不会自动恢复历史乱码注释；恢复时应使用原始中文文本。

**2026-10-28 补充：写入方向会静默产生乱码，回读方向是正常的。**
用 MCP 的 `set_pou_code` 传中文时，内容是以 `"""..."""` 字面量嵌进 IronPython 源码执行的，没有编码声明，中文会被按字节写成 mojibake：工程里存的不再是汉字，而是「UTF-8 字节按 Latin-1 逐字符摊开」的结果（`模` 变成码点 0xE6/0xA8/0xA1 三个字符），IDE 里显示为 `å¤æ¥` 之类。`set_pou_code` 本身报成功，编译也通过，只有打开编辑器才看得出来。

排查时最大的坑：`.text` 回读出来是**如实反映**工程内容的（内容乱码，回读就乱码），但直接 `print` 到 UTF-8 控制台会把这些码点输出成原始字节，控制台又按 UTF-8 解回来，**看起来完全正常**。所以不要靠 `print` 判断，要看码点：

- 正确汉字：码点在 0x4E00–0x9FFF（`模` = 27169）
- mojibake：码点在 0x80–0xFF（`模` 的乱码形态 = 230/168/161）

正确的写入方式：不要用 `set_pou_code` 传非 ASCII 内容，改用 `eval_python` 调 `obj.textual_declaration.replace(unicode_text)`，并确保传进去的是真 unicode。修复已有乱码的办法是把它 `encode('latin-1').decode('utf-8')` 还原后重新 `replace()`，全程在 IDE 内完成，不经过传输层。

## 后续接实机前要补齐

已完成（2026-10-28）：D2/D4 真实轴适配、逐台接管开关、两级安全旁路、相对验证模式、真实设备状态与掩码发布。

已完成（2026-10-30）：D2/D4 上位机回零 `CmpHCMotion.MC_Homing`（手动 `xHome` 按钮 + 初始化第 25 步）、手动模式免初始化直进、手动模式不做机构互锁。

仍需补齐：回零方式与原点开关的**实机标定**（当前沿用轴配置里的调试值）；轴对象里的工程单位、软限位、CSP 模式、站地址；台达 ASDA-B3 的编码器分辨率与每转位移（**与汇川 SV660N 不同，必须各自标定**）；其余 15 台的真实 I/O 接线；D8 角度、D2 切割长度、D4/D7 各位置、各动作时间和速度；G2 三种料型与实际继电器对应关系；喷油关闭规则；安全回路、失气/断电行为及受控停止；Modbus 寄存器映射、连接监视及断线策略。

> `framework/sources/*.st` 本次是由 IDE 回读导出的，`build_sources.py` / `comments_zh.py` **未同步**。若之后重新运行生成器，会覆盖本次人工改动；请先把改动回写生成器，或改完继续用 IDE 导出覆盖 `sources/`。

原工程完整备份：`../before-machine-framework-20261015.projectarchive`。
本次改造前备份：`../beveling-before-realaxis-20261028.project`。
`baseline-20261015.json` 保存导入前的旧程序文本。
