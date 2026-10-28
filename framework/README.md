# 切割机框架使用说明

版本：2026-10-21，按流程图 v0.3 搭建，控制权限调整为实体面板决定模式。

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
- 实机适配、真实 I/O 地址、硬件安全回路接口和 Modbus 网络映射尚未接入。
- `GVL_Parameters.xSimulation = FALSE` 会报未实现错误 3001，不会转入真实设备控制。
- `GVL_IO.axDigitalOutputs` 为未映射的普通 BOOL 数组，当前每周期置 FALSE。

2026-10-15 框架逻辑版本的原生编译：0 错误、2 条警告（原有 CmpLog 日志库未加载、MainTask 未定义 POU）。
已通过一次负向编译探针确认错误可以正确返回；探针已移除并重新编译、保存。
48 个框架对象的工程回读与本地源码一致。未登录、下载或运行物理 PLC，尚未执行循环运行验证。
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
当前导出共 52 个代码对象，新增实体面板输入类型、远程启停类型及面板解码功能块。
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
5. 自动模式下将 `GVL_Simulation.stPanelInputs.xStart` 置 TRUE 后清 FALSE，模拟启动按钮。
6. `GVL_Parameters.xContinuous = FALSE` 为单循环，TRUE 为连续；运行时清 FALSE，在本循环结束后停止。
7. `GVL_Simulation.stPanelInputs.xStop = TRUE` 模拟普通停止，取消动作及工序；释放后须重新初始化并启动。
8. 运行中切换手动/自动会停止，须在新模式重新初始化。
9. 报警原因清除后，给 `GVL_Simulation.stPanelInputs.xResetAlarm` 上升沿模拟复位按钮；复位只回到 Stopped。

软件中的安全许可是仿真/接口状态，不能替代真实急停与安全回路。
当前初始化按仿真机构位置组合执行；接实机前需要改为实际的回原点和机构初始化方案。

## 手动控制

输入位于 `GVL_Interface.aManual[设备索引]`，反馈位于 `aDeviceStatus[设备索引]`。
进入手动后先释放全部手动按钮，再允许动作，避免切模式时接续旧的按住命令。

- 轴：按住 `xJogPositive` 或 `xJogNegative` 点动，松开停止；速度取 `lrVelocity`。
- 轴或气缸：设置 `lrTarget`，给 `xMove` 上升沿，发出一次定位/动作请求。
- 连续电机或阀：`xRun` 按住运行，松开停止。
- 气缸的仿真目标通常是 0 / 1。具体方向见编号表。
- 相反点动同时有效、点动和定位同时有效等冲突会被拒绝；查看 `stStatus.uiManualReject`。
- 手动也经过 `FB_Interlocks`。阻挡设备可查看 `stStatus.uiBlockedDevice`。

主要互锁包括：定长平移前先抬起；平台旋转前刀具和下压抬起、侧推解除；下刀前下压到位且相关机构移开；走刀前刀具和下压到位、盘刀运行；机械手按抬升/夹紧/后退/下降/回位关系执行。
这些是框架中的软件条件，仍须结合最终机械结构补充和验证。

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
| 32..48 | 17 个设备的位置，有符号 INT，缩放 0.1 工程单位 |

命令处理结果：0=接受，1=未授权远程启停，2=不支持命令，3=模式/状态/本地停止不允许，5=配方不合法。
格式检查结果 2 表示帧格式、版本、模式或命令码无效，未发给整机执行。
命令接受不表示动作完成；应继续读取整机状态、工序和报警。

## 中文注释与文本编码

外部 `.st`、Python、文档统一保存为 UTF-8，项目根目录的 `.editorconfig` 已声明该约定。
`.project` 由 InoProShop 管理，不能作为普通文本文件转换编码。
本机 SP11 的 MCP 写入接口需要先把 UTF-8 字节形式的文字转换成真正的 Unicode，再写入编辑器。
2026-10-16 已在独立工程副本核对新建 GVL、声明区及程序正文的中文，保存、关闭、重开后的字符值一致。
这项修正不会自动恢复历史乱码注释；恢复时应使用原始中文文本。

## 后续接实机前要补齐

真实轴和 I/O 接线、工程单位、限位和原点、D8 角度、D2 切割长度、D4/D7 各位置、各动作时间和速度；G2 三种料型与实际继电器对应关系；喷油关闭规则；安全回路、失气/断电行为及受控停止；Modbus 寄存器映射、连接监视及断线策略。

原工程完整备份：`../before-machine-framework-20261015.projectarchive`。
`baseline-20261015.json` 保存导入前的旧程序文本。
