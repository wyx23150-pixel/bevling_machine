"""为现有 ST 源码补充中文注释；不改动任何可执行语句或变量定义。"""
import re


MODULES = {
    'E_MachineMode': '操作模式。手动与自动分别提出动作请求，共用设备执行和互锁。',
    'E_MachineState': '整机运行状态。停止或报警复位后须重新初始化，启动命令不会跳过初始化。',
    'E_AutoStep': '自动主流程步骤。正常循环从送料等料开始，切割完成后执行三路收尾。',
    'E_DeviceAction': '统一设备动作类型。未请求或停止时取消动作；定位完成依据本次命令序号判断。',
    'E_DeviceKind': '设备适配类型，由设备管理器选择轴、电机、气缸或阀的执行入口。',
    'ST_DeviceCommand': '上层发给单个设备的请求。定位每次换新序号；连续运行和点动期间保持请求。',
    'ST_DeviceStatus': '单个设备的执行反馈。收到命令与完成命令是两个状态，不能只看忙标志判断完成。',
    'ST_DeviceConfig': '设备类型、行程范围和仿真参数。当前工程单位与时间均为仿真示例，尚未完成实机标定。',
    'ST_ManualCommand': '手动按钮接口。点动和运行按住有效，定位使用上升沿；手动请求同样经过互锁。',
    'ST_OperatorCommand': '本地面板或上位机的整机操作命令。初始化、启动、报警复位按上升沿处理，停止为电平有效。',
    'ST_Recipe': '加工配方。初始化和自动启动时校验并复制到运行配方，避免运行中参数变化影响当前工序。',
    'ST_SimulationSettings': '软件仿真输入和异常注入。设备索引为 1..17，与 GVL_DeviceIds 一致。',
    'ST_MachineStatus': '提供给监控和上位机的整机状态。可从主步骤、支线步骤、报警和互锁阻挡编号定位等待原因。',
    'GVL_DeviceIds': '设备数组索引常量。D1..D8 对应索引 1..8，D6 保留；G1..G9 对应索引 9..17。',
    'GVL_Interface': '操作与监控入口。面板写 stPanel，手动写 aManual；整机每周期更新状态，外部不要修改反馈。',
    'GVL_Parameters': '仿真开关和待执行配方。参数生效时机见 ST_Recipe；关闭仿真当前报 3001，未接入真实设备。',
    'GVL_Simulation': '仿真调试入口。可模拟来料、动作卡住、设备故障和安全许可丢失。',
    'GVL_IO': '逻辑 I/O 预留接口，尚未绑定物理地址。数字输出数组当前每周期清零；G2 需求仅用于观察。',
    'GVL_Modbus': 'Modbus 收发缓冲区，索引从 0 开始，尚未绑定网络寄存器。实际地址和字序需另行配置。',
    'F_NextID': '生成本次动作的非零序号。计数到最大值后回到 1，用于排除上一步残留的完成反馈。',
    'F_Command': '组装设备命令，不执行运动。由设备管理器和对应设备功能块实际处理。',
    'F_Done': '只有设备完成序号等于本次命令序号、无忙且无故障，才返回动作完成。',
    'F_At': '检查设备可用、无忙无故障且位置误差小于 0.01。它检查位置，不检查本次命令序号。',
    'FB_Axis': '定位轴适配入口。当前调用内部仿真；真实轴的 MC 功能块、回原点和限位尚未接入。',
    'FB_Motor': '连续电机适配入口，供皮带 D1 和盘刀 D3 使用。当前仅仿真运行状态。',
    'FB_Cylinder': '气缸适配入口。当前用 0/1 位置模拟两端到位；真实电磁阀和到位传感器尚未映射。',
    'FB_Valve': '阀适配入口，供喷油 G5 和吹气 G6 使用。当前用运行状态表示开启，未映射输出。',
    'FB_DeviceManager': '统一设备执行入口。首次建立类型和初始位置，每扫描周期按类型调用设备功能块并收集反馈。',
    'FB_ClearLength': '切割前避让支线 P：D5 定长升起，再将 D4 移到避让位置。每步等待本次序号完成。',
    'FB_ClearTransfer': '切割前避让支线 Q：G4 流利条下降、G3 解除侧推、G2 侧挡下降。',
    'FB_ClearanceUnit': '并行执行 P/Q 两路避让；两路都完成才继续，任一路故障向主流程报告。',
    'FB_ReturnKnife': '收尾支线 A：G5 喷油到设定时间，再令 D2 回刀。喷油仅在第一步保持请求。',
    'FB_Unload': '收尾支线 B：机械手移料。后退、下降、最终回位是三个独立动作，全部完成后才允许下一轮送料。',
    'FB_ResetLength': '收尾支线 C：D4 回检测位置、D5 下降到位、确认下降位置；随后具备来料检测条件。',
    'FB_Initialize': '软件仿真的初始姿态整理流程。接实机前应按机械结构设计真实回原点与初始化动作。',
    'FB_PostCut': '切割后先 G9 抬刀，再 G1 抬压；之后同时执行回刀、机械手移料、定长复位，三路全完成才结束。',
    'FB_AutoCycle': '自动主状态机。只组织工序并提出请求，设备执行由整机统一调用；送料等料允许长期等待。',
    'FB_ManualControl': '将手动按钮转为统一设备请求。点动松开即取消；定位请求保持到本次动作完成；D6 不调度。',
    'FB_Interlocks': '对手动、初始化和自动请求统一执行软件互锁。禁止动作时改为停止，并报告最后一个被阻挡设备。',
    'FB_AlarmManager': '锁存首次非零报警。只有复位有效且当前没有新报警时清除；同一扫描有新报警时仍会锁存。',
    'F_RecipeValid': '检查框架允许的料型、速度、行程和位置顺序。通过仅表示符合示例边界，不代表实机参数已经确认。',
    'FB_Machine': '整机调度中心：命令选择、模式和报警管理、初始化/手动/自动调度、统一互锁、设备执行及状态发布。',
    'FB_IOMap': '物理 I/O 映射预留。当前数字输出全为 FALSE；G2 按料型形成三个未映射的继电器需求。',
    'FB_ModbusInterface': '上位机命令解析与状态打包。命令序号防重复，新启用时先建立序号基线；无实际网络读写。',
    'FB_SimDevice': '设备仿真模型：定位按固定时间插值、连续运行保持状态、点动按时间增量累计位置。',
    'FB_SimPlant': '仿真来料模型。皮带运行且定长下降时延时产生一次到位，定长升起或关闭模型后清除。',
    'PLC_PRG': '周期入口，当前仅在 ETHERCAT1 任务调用一次。顺序为通信解析、整机调度、反馈发布、逻辑 I/O 映射。',
    'GVL_Motion': '旧单轴 Demo 的操作和监控变量。新切割机框架不使用这些变量；旧 Demo 当前未挂周期任务。',
    'PRG_AxisDemo': '保留的旧单轴低速往返 Demo，当前未周期调用。它不属于新切割机自动工序。',
}

# 同名接口的通用说明；有对象或作用域差异时在 OVERRIDES 中明确覆盖。
VARIABLES = {
    'eAction': '动作类型：无请求、定位、连续运行、点动或停止，见 E_DeviceAction。',
    'udiID': '本次命令序号，0 无效；发起新定位时换新序号。',
    'lrTarget': '目标工程位置；气缸使用约定的 0/1 端点，连续运行和点动不使用该位置。',
    'lrVelocity': '请求速度，单位随设备工程单位定义；尚未完成实机标定。',
    'xReady': '设备已使能且无故障，允许接收命令；不表示动作已经完成。',
    'xBusy': '当前动作正在执行，定位完成或停止后清除。',
    'xActive': '连续运行已建立或点动正在进行；定位动作完成后不保持该标志。',
    'xError': '本设备或本子流程发生故障；具体原因见对应错误码。',
    'udiErrorID': '错误码；0 表示无错误，设备或流程发生异常时赋值。',
    'udiAcceptedID': '设备已接收的命令序号，用于区别尚未接收与正在执行。',
    'udiCompletedID': '设备已完成的命令序号；应与本次 udiID 匹配后再切换步骤。',
    'lrPosition': '实际或仿真反馈位置；气缸 0/1 的方向见设备编号说明。',
    'eKind': '设备类型，决定调用哪一种设备适配功能块。',
    'lrInitialPosition': '首次进入仿真时的初始位置，不是实机回原点结果。',
    'lrMinPosition': '示例软行程下限，单位随机构定义。',
    'lrMaxPosition': '示例软行程上限，单位随机构定义。',
    'lrMaxVelocity': '允许请求的最大速度，用于仿真命令范围检查。',
    'tSimAction': '仿真单次定位/建立运行状态所需时间，不代表实际机械动作时间。',
    'xJogPositive': '手动正向点动，按住有效，释放后取消；只支持定位轴。',
    'xJogNegative': '手动反向点动，按住有效；与正向同时按下会被拒绝。',
    'xMove': '手动定位按钮，上升沿锁存目标，动作保持到本次序号完成。',
    'xRun': '连续运行请求，电平有效；撤销时本流程取消请求。',
    'eMode': '操作模式：Manual=手动，Automatic=自动。',
    'xInitialize': '初始化请求，上升沿有效；只允许从停止且许可满足时进入。',
    'xStart': '自动启动请求，上升沿有效；须先初始化到 Ready。',
    'xStop': '普通停止，TRUE 持续有效；取消动作并清除初始化，不能替代硬件急停。',
    'xResetAlarm': '报警复位请求，上升沿有效；原因清除后复位，不会自动重新启动。',
    'xContinuous': 'TRUE 连续循环；FALSE 在当前完整循环结束后回到就绪。',
    'uiMaterialModel': '料型选择，仅支持 300/400/600，对应 G2 三个继电器；不是位移。',
    'lrCutHome': 'D2 回刀起点；切割终点为该位置加 lrCutLength。',
    'lrCutLength': 'D2 本次切割行程，示例默认 20；到达指定终点才结束切割。',
    'lrCutVelocity': 'D2 切割进给速度；示例参数，接实机前确认工程单位。',
    'lrPositionVelocity': '其余定位动作的公共请求速度，当前为仿真示例。',
    'lrBeltVelocity': 'D1 皮带运行速度请求，当前未换算到实际驱动器单位。',
    'lrSpindleVelocity': 'D3 盘刀运行速度请求，当前不是已标定的实际转速。',
    'lrLengthPosition': 'D4 定长检测工作位置；到位后再令 D5 下降。',
    'lrLengthClear': 'D4 切割前避让位置；移动前须 D5 升起。',
    'lrRotateAngle': 'D8 平台旋转目标角度，示例范围为正负 360，实机角度单位待标定。',
    'lrGripperFront': 'D7 机械手前进取料位置。',
    'lrGripperPull': 'D7 夹紧后拉料目标位置。',
    'lrGripperBack': 'D7 松开后的抬升后退位置；到位后先下降，再最终回位。',
    'lrGripperHome': 'D7 机械手下降后最终回位的位置。',
    'tSpray': '收尾支线 A 的喷油保持时间；该步结束后撤销喷油请求。',
    'tStepTimeout': '单动作步骤超时时间；正常送料等料阶段不套用此超时。',
    'xSafetyOK': '安全许可接口或仿真许可，TRUE 允许；不等同于安全级急停回路。',
    'xAutoMaterial': 'TRUE 由仿真模型自动产生到位；FALSE 使用人工料到位输入。',
    'xMaterialSensor': '手动模拟的光电到位信号，仅在 xAutoMaterial=FALSE 时使用。',
    'tMaterialDelay': '满足皮带运行及定长下降条件后，仿真来料的延时时间。',
    'axStall': '设备卡住注入，索引 1..17；保持忙且不完成，用于观察等待/超时。',
    'axFault': '设备故障注入，索引 1..17；先清除注入，再执行报警复位。',
    'eState': '整机状态，见 E_MachineState；调试时先确认是否已初始化及处于正确模式。',
    'eAutoStep': '自动主流程步骤；送料、避让、切割、收尾等状态见 E_AutoStep。',
    'xSimulation': 'TRUE 使用内部仿真；当前 FALSE 报未实现 3001，不会接管真实运动。',
    'xRealBackendAvailable': '真实设备适配是否已具备；当前框架固定 FALSE。',
    'xInitialized': '初始化完成标志；停止、运行中切换模式或故障会清除。',
    'xMaterialAtLength': '定长光电到位状态；自动送料须先离开再到位，并满足 D5 下降。',
    'xCycleComplete': '一个扫描周期的整循环完成脉冲，可用于计数或上位机提示。',
    'udiCycleCount': '已完成的自动整循环计数；包括机械手移料等三路收尾。',
    'udiAlarm': '整机锁存报警码；0 无报警，1001 安全许可，3001 实机未接入，10000+索引为设备故障。',
    'uiBlockedDevice': '本扫描最后一个被互锁阻挡的设备索引；0 表示无阻挡，可结合设备状态排查。',
    'uiManualReject': '本扫描最后一个被拒绝的手动设备索引；0 无拒绝，检查相反按钮或动作类型。',
    'uiClearLengthStep': '避让支线 P 的当前步骤：10 升起 D5，20 移开 D4，1000 完成。',
    'uiClearTransferStep': '避让支线 Q 当前步骤：10 降 G4，20 松 G3，30 降 G2，1000 完成。',
    'uiPostStep': '收尾总步骤：10 抬刀，20 抬压，30 等待三路完成，1000 结束。',
    'uiReturnKnifeStep': '收尾支线 A：10 喷油，20 D2 回刀，1000 完成。',
    'uiUnloadStep': '机械手移料支线 B 步骤，10..110 每步加 10，1000 完成；详见 FB_Unload。',
    'uiResetLengthStep': '收尾支线 C：10 D4 定位，20 D5 下降，30 确认下降，1000 完成。',
    'uiInitializeStep': '初始化步骤：10 整理刀/压/夹爪，20 避让，30 初始定位，40 定长下降，1000 完成。',
    'uiActiveMaterialModel': '已采纳的运行料型，取自运行配方；可能与尚未生效的参数区不同。',
    'wRemoteAckSequence': '整机已处理的上位机命令序号；应结合 uiRemoteResult 判断是否接受。',
    'uiRemoteResult': '远程处理结果：0 接受，1 未授权，3 状态不允许，5 配方不合法；接受不代表动作完成。',
    'D1_Belt': 'D1 送料皮带电机，设备数组索引 1。',
    'D2_CutFeed': 'D2 切割走刀/回刀轴，设备数组索引 2。',
    'D3_Spindle': 'D3 盘刀旋转电机，设备数组索引 3。',
    'D4_LengthMove': 'D4 定长平移轴，设备数组索引 4。',
    'D5_LengthLift': 'D5 定长升降，0 升起避让，1 下降检测，索引 5。',
    'D7_GripperMove': 'D7 机械手平移，索引 7；索引 6 为保留设备 D6。',
    'D8_Rotate': 'D8 平台旋转轴，设备数组索引 8。',
    'G1_Press': 'G1 下压气缸，0 抬起，1 下压，索引 9。',
    'G2_SideStop': 'G2 侧挡升降，0 提升，1 下降；按料型选择继电器，索引 10。',
    'G3_Push': 'G3 推动气缸，0 放开，1 侧推，索引 11。',
    'G4_RollerLift': 'G4 流利条升降，0 下降，1 提升，索引 12。',
    'G5_Spray': 'G5 喷油阀，连续运行请求表示打开，索引 13。',
    'G6_Air': 'G6 吹气阀，切割开始打开、切割结束关闭，索引 14。',
    'G7_GripperLift': 'G7 机械手升降，0 下降，1 提升，索引 15。',
    'G8_GripperClamp': 'G8 机械手夹爪，0 打开，1 夹紧，索引 16。',
    'G9_KnifeLift': 'G9 盘刀升降，0 提升，1 下降，索引 17。',
    'stPanel': '本地操作面板命令，见 ST_OperatorCommand。',
    'aManual': '各设备手动请求，索引 1..17；进入手动后先释放所有按钮再允许动作。',
    'stStatus': '本模块对外发布的状态；字段含义见其数据类型。',
    'aDeviceStatus': '设备管理器汇总反馈，索引 1..17；供工序判断及在线监控。',
    'stRecipe': '待校验配方或上层传入的运行配方，字段含义见 ST_Recipe。',
    'stSettings': '软件仿真参数，含来料方式和异常注入。',
    'axDigitalInputs': '预留数字输入位，索引 0..31；当前未映射到真实输入。',
    'axDigitalOutputs': '预留数字输出位，索引 0..31；当前由 FB_IOMap 每周期清 FALSE。',
    'axG2RelayDemand': 'G2 三路逻辑继电器需求：1=300 料型，2=400，3=600；未映射物理输出。',
    'awRx': '上位机接收字缓冲区 0..31；0 版本，1 序号，2 命令，3 模式，4 连续选择。',
    'awTx': '发布字缓冲区 0..127；包含确认、状态、报警、计数和位置，详见程序内索引注释。',
    'udiCounter': '全机共享的动作序号计数器，通过引用传递；由 F_NextID 分配，0 不使用。',
    'xEnable': '本功能使能，电平有效；失能时不接受新的动作请求。',
    'xReset': '故障复位许可；仿真设备仅在故障注入已撤销时清除错误。',
    'xStall': '仿真卡住输入；TRUE 暂停位置推进且不发完成，保留忙状态。',
    'xInjectFault': '仿真设备故障输入；TRUE 锁存错误码 9001。',
    'stConfig': '设备类型、初始位置、软限位与仿真动作时间。',
    'stCommand': '当前单设备命令，含动作类型、序号、目标和速度。',
    'xBooted': '本功能块首次初始化完成标志，防止每扫描重写初值。',
    'xAction': '仿真定时动作进行中；定位和建立连续运行状态使用，点动另行处理。',
    'udiLastID': '上次已接受序号，同一序号保持期间不重复启动动作。',
    'lrStart': '本次仿真定位的起始位置，用于按时间插值。',
    'lrJogDelta': '点动相邻扫描的时间差，单位秒；速度乘该值取得本扫描位移。',
    'tLastJog': '上扫描点动计时值，用于计算本扫描时间增量。',
    'tonAction': '仿真定位或建立连续运行状态的定时器。',
    'tonJog': '点动累计计时器，用于计算位置增量，设定计时上限 24 小时。',
    'fbSimulation': '内部设备仿真实例，真实设备适配尚未接入。',
    'stSim': '软件仿真设置；设备管理器按设备索引读取卡住与故障注入。',
    'aCommand': '统一设备请求数组 1..17；子流程写请求，设备管理器执行。',
    'aStatus': '各设备的反馈数组 1..17，供判断忙、完成序号、故障和位置。',
    'aConfig': '设备配置数组，首扫描按固定编号设置类型和初始姿态。',
    'aAxis': '定位轴功能块实例数组，只有设备类型为 Axis 的元素被调用。',
    'aMotor': '连续电机功能块实例数组，供 D1、D3 使用。',
    'aCylinder': '气缸功能块实例数组，按 G 编号驱动对应仿真实例。',
    'aValve': '阀功能块实例数组，供 G5 喷油及 G6 吹气使用。',
    'i': '本扫描数组遍历索引；含义及范围以当前 FOR 循环为准。',
    'xExecute': '子流程执行许可；须保持到完成，清 FALSE 复位该流程步骤和错误。',
    'xDone': '本子流程完成标志；执行许可撤销后复位。',
    'uiStep': '当前子步骤：0 待机，10/20/... 执行动作，1000 完成；切勿在线强制跳步。',
    'uiPrevStep': '上扫描步骤，用于判断本扫描是否刚进入新步骤。',
    'udiToken': '本步骤专用动作序号；同一步中的设备共用该号，以排除旧完成信号。',
    'xEntry': '本扫描为新步骤入口；用于分配新序号并复位步骤超时计时。',
    'tonStep': '步骤超时定时器；进入新步骤时复位，超时错误码由模块及当前步号组成。',
    'tonSpray': '通用子流程模板的喷油定时器，只有 FB_ReturnKnife 用其完成条件。',
    'uiLengthStep': '定长支线当前步骤，供监控定位等待点。',
    'uiTransferStep': '流利条/侧推/侧挡支线当前步骤，供监控定位等待点。',
    'fbLength': '定长相关子流程实例，具体动作见本模块调用的数据类型。',
    'fbTransfer': '切割前流利条/侧推/侧挡避让支线。',
    'uiKnifeStep': '收尾回刀支线 A 当前步骤：喷油、回刀或完成。',
    'fbKnife': '收尾支线 A：喷油后回刀。',
    'fbUnload': '收尾支线 B：机械手移料，含后退、下降、最终回位。',
    'eStep': '自动主工序当前状态，见 E_AutoStep。',
    'ePrevStep': '上扫描主工序状态，用于产生步骤入口标志。',
    'udiSpindleToken': '盘刀运行命令序号，切割过程中保持该号，避免重复重启盘刀命令。',
    'xSawSensorClear': '本轮送料已观察到光电离开；须先有该标志再接受新到位，防止残留信号触发。',
    'fbClear': '切割前两路并行避让流程。',
    'fbPost': '切割后抬刀、抬压及三路收尾流程。',
    'uiRejectDevice': '本扫描最后一个手动拒绝设备索引；0 无，常见原因是冲突按钮或不支持该动作。',
    'aPrev': '上扫描手动按钮快照；即使禁用仍更新，防止按住按钮切模式后被误作新上升沿。',
    'aPending': '手动定位的锁存请求，直到本次命令完成；点动或运行优先时清除。',
    'aRunID': '各设备按住运行/点动时保持的序号，按钮释放后归零。',
    'xPermit': '整机当前允许发出动作的总许可；仍需继续满足各设备互锁。',
    'aRequest': '初始化/手动/自动产生的原始请求，每周期先清空，再交互锁筛选。',
    'xAllowed': '当前遍历设备的最终互锁允许结果。',
    'xMotion': '当前请求是否为点动或离开当前位置的定位，决定是否检查机构避让。',
    'xKnifeUp': 'G9 刀具处于提升端且设备无忙无故障。',
    'xPressUp': 'G1 下压机构处于抬起端且设备无忙无故障。',
    'xClampOpen': 'G8 夹爪处于打开端且设备无忙无故障。',
    'xLatched': '本轮仿真料到位保持标志；定长升起或模型失能时清除。',
    'tonMaterial': '自动仿真来料延时，仅在运行皮带且定长下降到位时计时。',
    'udiIncoming': '当前扫描的新报警码；0 表示当前未提出报警。',
    'udiLatched': '已锁存的首个非零报警码；后续报警不覆盖，满足复位条件后清零。',
    'xRequest': '解析到一帧合法新命令时给整机的单扫描请求。',
    'wRequestSequence': '解析出的新命令序号，供整机处理后原样确认。',
    'uiParseResult': '帧格式检查结果：0 合法，2 版本/模式/命令码不合法，非法帧不下发。',
    'aSnapshot': '新命令帧快照，读取后再次核对序号，降低写入过程中读取半帧的风险。',
    'wLastSeen': '已观察过的帧序号，包含非法帧；相同序号不会重复处理。',
    'xWasEnabled': '上扫描通信使能状态；首次使能只记录序号，不执行缓冲区旧命令。',
    'stRemote': '通信解析得到的远程整机命令；须本地面板授权才可使用。',
    'xRemoteRequest': '远程新命令有效脉冲；无新帧时仅保留模式与连续选择。',
    'wRemoteSequence': '本次远程新命令序号，整机处理后写入确认状态。',
    'xRealSafetyOK': '真实安全许可预留接口；当前仿真模式使用 stSim.xSafetyOK。',
    'xRealMaterial': '真实定长光电预留输入；当前仿真模式由 FB_SimPlant 提供。',
    'aSelectedCommand': '通过统一互锁后的最终设备请求，交设备管理器执行。',
    'stActiveRecipe': '本次初始化/自动启动时采纳的配方快照，运行中不直接跟随参数区变化。',
    'stEmpty': '默认全零设备命令，每周期用它清空原始请求，未被重新提出的动作自动取消。',
    'fbDevices': '统一设备管理器，每周期调用一次，汇总各设备反馈。',
    'fbManual': '手动请求转换功能块，须处于手动并已释放全部按钮才使能。',
    'fbAuto': '自动主流程功能块，仅在整机 Automatic 状态运行。',
    'fbInitialize': '初始化功能块，仅在整机 Initializing 状态执行。',
    'fbInterlocks': '所有模式共用的软件互锁，输出最终允许的请求。',
    'fbPlant': '仿真整机来料模型；当前流程读取其上一扫描的到位反馈。',
    'fbAlarm': '整机首报警锁存功能块。',
    'rtInitialize': '初始化按钮上升沿检测。',
    'rtStart': '自动启动按钮上升沿检测。',
    'rtReset': '报警复位按钮上升沿检测。',
    'udiFault': '本扫描整理出的报警原因；设备错误使用 10000+设备索引。',
    'xMaterial': '当前实际采用的来料信号，仿真与实机预留输入二选一。',
    'xRemoteAccepted': '本扫描远程命令已获授权，用于回传状态拒绝或配方错误。',
    'xResetDevices': '本扫描设备复位脉冲，需复位上升沿、安全许可和仿真模式均满足。',
    'xLastSimulation': '上扫描仿真开关；切换模式时清除初始化并停止。',
    'xManualReleased': '所有手动按钮都已释放，用于避免带着按住命令进入手动。',
    'xManualArmed': '本次进入手动后已观察到全部按钮释放；离开手动即清除。',
    'eActiveMode': '当前初始化/运行时采纳的操作模式，用于检测运行中切换模式。',
    'axOutputs': '预留物理数字输出数组 0..31，当前实现每周期强制清 FALSE。',
    'fbCommunication': '通信命令解析和状态打包实例；打包的是上一扫描已发布的整机反馈。',
    'fbMachine': '整机调度实例，包含初始化、手动、自动、互锁、报警和设备管理。',
    'fbIO': '逻辑 I/O 映射实例，当前只形成诊断需求，不驱动真实输出。',
}

OVERRIDES = {
    ('ST_MachineStatus', 'xReady'): '整机已经初始化并处于 Ready 状态，可接受自动启动；手动状态下不置该位。',
    ('FB_Machine', 'stCommand'): '本周期选择并合并后的整机命令；本地停止始终优先于远程。',
    ('FB_ModbusInterface', 'stCommand'): '从合法接收帧转换得到的整机命令；初始化/启动/停止/复位为本扫描脉冲。',
    ('FB_AutoCycle', 'xRun'): '自动工序运行许可，整机 Automatic 时保持 TRUE；撤销立即复位主流程。',
    ('ST_ManualCommand', 'xRun'): '手动连续运行按钮，按住有效、松开停止，仅支持 D1/D3/G5/G6。',
    ('FB_AutoCycle', 'xDone'): '整循环完成的单扫描脉冲；机械手等三路收尾全部结束后才产生。',
    ('FB_ManualControl', 'xEnable'): '手动模式且按钮释放联锁已满足时允许；未使能也同步按钮快照。',
    ('FB_ModbusInterface', 'xEnable'): '通信解析许可；首次使能只记录现有序号，防止重放旧命令。',
    ('GVL_Modbus', 'xEnable'): '启用 Modbus 缓冲区解析，默认 FALSE；不代表网络映射已经配置。',
    ('GVL_Parameters', 'stRecipe'): '待执行配方：初始化和自动启动时校验并取快照，运行中修改不会立即生效。',
    ('GVL_IO', 'xMaterialAtLength'): '真实光电到位预留输入，当前未映射物理输入，仿真时不采用此值。',
    ('FB_SimDevice', 'lrTarget'): '本次已接受定位命令的目标位置快照，用于时间插值。',
    ('F_At', 'lrTarget'): '要检查的目标位置；误差小于 0.01 且设备就绪、无忙无错时返回 TRUE。',
    ('FB_ManualControl', 'lrVelocity'): '本扫描限幅后的手动速度，取绝对值限幅 0.1..100；反向点动时变为负值。',
    ('FB_ClearanceUnit', 'fbLength'): 'P 支线：D5 升起、D4 移开。',
    ('FB_PostCut', 'fbLength'): 'C 支线：D4 回检测位置、D5 下降、确认下降到位。',
    ('FB_IOMap', 'aCommand'): '最终设备命令预留输入，当前映射实现未使用该数组。',
    ('FB_PostCut', 'udiErrorID'): '非法总步骤为 4700，超时为 4700+总步号；支线故障则向上传递支线错误码。',
    ('FB_AutoCycle', 'udiErrorID'): '非法主步骤为 4800，主步超时为 4800+枚举值；支线错误则向上传递。',
}
for _name, _base in [('FB_ClearLength', 4100), ('FB_ClearTransfer', 4200), ('FB_ReturnKnife', 4300), ('FB_Unload', 4400), ('FB_ResetLength', 4500), ('FB_Initialize', 4600)]:
    OVERRIDES[(_name, 'udiErrorID')] = '非法步骤码 %d；动作超时码=%d+uiStep，可据此定位本支线等待点。' % (_base, _base)

ENUMS = {
    'E_MachineMode': {'Manual': '手动点动/单机构调试', 'Automatic': '自动循环工序'},
    'E_MachineState': {'Stopped': '停止，须初始化', 'Initializing': '初始化中', 'Ready': '初始化完成，等待自动启动', 'Manual': '手动控制中', 'Automatic': '自动工序运行中，包含正常等料', 'Fault': '报警锁存，清除原因后复位'},
    'E_AutoStep': {'Idle': '主流程待机', 'FeedWait': '正常送料等料，可长期等待', 'StopFeed': '撤销皮带运行并等待停止', 'Push': 'G3 推动气缸动作', 'Clearance': '并行避让 P/Q，全完成后继续', 'Rotate': 'D8 平台旋转到配方角度', 'PressDown': 'G1 下压到位', 'KnifeDown': 'G9 盘刀下降到位', 'SpindleOn': 'D3 盘刀运行状态建立', 'Cutting': 'D2 走刀和 G6 吹气，等待指定行程到位', 'StopCut': '停止盘刀和吹气', 'PostCut': '抬刀、抬压、并行三路收尾', 'Complete': '整循环完成，连续模式回送料', 'Fault': '自动流程错误，退出执行后复位'},
    'E_DeviceAction': {'None': '无动作请求，取消当前动作', 'Position': '定位到指定目标，等待本次序号完成', 'Run': '保持连续运行请求', 'Jog': '保持点动，速度正负决定方向', 'Stop': '取消动作，停止运行'},
    'E_DeviceKind': {'Unused': '保留，不调度', 'Axis': '定位轴', 'Motor': '连续电机', 'Cylinder': '两端动作气缸', 'Valve': '开关阀'},
}


LEGACY_VARIABLES = {
    'fbPower': '旧 Demo 伺服使能功能块，操作对象为 Axis_1。',
    'fbReset': '旧 Demo 轴故障复位功能块。',
    'fbStop': '旧 Demo 受控停止功能块，完成后释放停止锁定。',
    'fbJog': '保留的点动实例，当前 Demo 正文未调用。',
    'fbMoveRel': '保留的相对定位实例，当前正文使用 fbCycle 执行往返。',
    'fbMoveAbs': '保留的绝对定位实例，当前 Demo 正文未调用。',
    'fbCycle': '实际执行单次往返的相对定位实例，每段使用独立 Execute 触发。',
    'fbReadPos': '读取 Axis_1 实际位置，写入旧监控变量 rActPos。',
    'fbReadStat': '保留的轴状态读取实例，当前正文未调用。',
    'fbReadErr': '保留的轴错误读取实例，当前正文未调用。',
    'rtCycle': '旧 Demo 启动按钮上升沿检测，按住按钮不会重复往返。',
    'fbCycleExec': '往返定位功能块 Execute 请求，换向前清除后再置位。',
    'rCycleDist': '本段相对位移，正向为正、回程为负，单段绝对值限 20 mm。',
    'iCycle': '旧 Demo 步骤：0 待机，10 正向，20 停留，30 回程，40 停留结束，99 故障。',
    'tonDwell': '正向与回程到位后的停留计时器。',
    'eLastErr': '历史保留的错误变量，当前正文未更新，请看轴/功能块实际错误输出。',
    'xStopRun': '旧 Demo 停止请求锁存，收到停止或运动错误后置位。',
    'xDoReset': '历史测试保留变量，当前正文未引用。',
    'rRunDec': '历史测试保留减速度变量，当前正文未引用。',
    'xStartRun': '历史测试保留启动变量，当前正文未引用。',
    'iStep': '历史测试保留步骤变量，当前有效步骤为 iCycle。',
    'fbMoveVel': '历史速度运动实例，当前正文未调用。',
    'Axis': '历史保留 INT 变量，不是 Axis_1 运动轴对象，当前正文未引用。',
    'Execute': '历史测试保留执行变量，当前正文未引用。',
    'rRunVel': '历史测试保留速度变量，当前正文未引用。',
    'rRunAcc': '历史测试保留加速度变量，当前正文未引用。',
    'Velocity': '历史测试保留 INT 变量，当前正文未引用。',
    'Acceleration': '历史测试保留 INT 变量，当前正文未引用。',
    'Deceleration': '历史测试保留 INT 变量，当前正文未引用。',
    'Direction': '历史测试保留方向变量，当前正文未引用。',
    'InVelocity': '历史测试保留 INT 变量，当前正文未引用。',
    'xMoveExec': '历史测试保留执行变量，当前正文未引用。',
}

MOTION_VARIABLES = {
    'xEnable': '旧 Demo 的 Axis_1 伺服使能请求，TRUE 上使能，FALSE 关闭。',
    'xReset': '旧 Demo 轴故障复位请求，接 MC_Reset.Execute。',
    'xStop': '旧 Demo 停止请求；停止完成后释放锁定，再决定是否重新启动。',
    'xJogFwd': '历史正向点动入口，当前旧 Demo 正文未接入。',
    'xJogRev': '历史反向点动入口，当前旧 Demo 正文未接入。',
    'xMoveRel': '历史相对定位入口，当前旧 Demo 正文未接入。',
    'xMoveAbs': '历史绝对定位入口，当前旧 Demo 正文未接入。',
    'xStartCycle': '旧 Demo 单次往返启动，上升沿有效；当前 Demo 未周期调用。',
    'rRelDist': '历史单次相对距离 mm，当前往返正文不采用该参数。',
    'rTargetPos': '历史绝对目标位置 mm，当前往返正文不采用该参数。',
    'rJogVel': '历史点动速度 mm/s，当前往返正文不采用该参数。',
    'rVel': '旧 Demo 往返速度 mm/s，正文限幅为 1..10。',
    'rAcc': '旧 Demo 加速度 mm/s²，正文限幅为 10..200。',
    'rDec': '旧 Demo 减速度 mm/s²，正文限幅为 10..200。',
    'rStroke': '旧 Demo 请求的单程距离 mm，正文使用绝对值并限制最大 20。',
    'tDwell': '旧 Demo 每个行程端点停留时间。',
    'xPowered': 'MC_Power.Status，伺服已使能反馈。',
    'xAxisReady': '旧 Demo 中由已使能、非忙、无错误组合得到的可用标志。',
    'xBusy': '往返功能块或停止功能块正忙。',
    'xDisabled': '旧 Demo 根据未使能得到的显示状态。',
    'xStandStill': '旧 Demo 根据已使能且非忙得到的显示状态，不是独立轴状态读取。',
    'xStopping': '停止功能块正在执行。',
    'xErrorStop': '旧 Demo 综合错误显示，与 xAxisError 同步。',
    'xAxisError': '使能、往返、复位或停止功能块任一报错。',
    'iAxisErrorID': '历史错误码显示变量，当前正文未更新，需读取实际功能块 ErrorID。',
    'rActPos': 'MC_ReadActualPosition 返回的 Axis_1 实际位置，单位 mm。',
    'iState': '旧 Demo 当前 iCycle 步骤镜像，便于在线监控。',
}

TRANSLATIONS = {
    'Reset on acceptance; the regular call below starts the new timer.': '接收新序号时先复位计时器，随后由每扫描调用开始本次计时。',
    'The real hardware adapter is intentionally not commissioned.': '真实设备适配尚未接入；关闭仿真时返回 3001，避免误认为已具备实机控制。',
    'D5 is modeled as a positioning lift; 0/1 are simulation up/down points.': 'D5 暂按定位升降建模：0=升起避让，1=下降检测，非实际机械坐标。',
    'Unmapped interface. No AT %Q / %I bindings in this framework.': '当前均为普通逻辑变量，没有 AT %Q / %I 物理地址绑定。',
    'Buffers only; the existing MODBUS_TCP driver is not bound yet.': '仅预留收发缓冲区，尚未绑定工程中的 MODBUS_TCP 网络映射。',
    'Simulation examples only: these are NOT commissioned machine settings.': '以下默认值仅供软件仿真，不能直接作为已确认的生产参数。',
    'Physical writes remain unimplemented. Logical relay demand is diagnostic.': '物理输出尚未实现；G2 三路继电器需求只用于逻辑观察。',
    'Mode and continuous selection persist between remote command frames.': '远程两帧之间保留模式与连续选择，动作按钮仍按新命令脉冲处理。',
    'Local stop always overrides remote control.': '本地停止始终优先，远程命令不能屏蔽本地停止。',
    'Reset injected/device errors before clearing the machine latch next scan.': '复位时先按仍有效的故障注入判断原因，再清设备错误和整机锁存；原因未撤销不能复位。',
    'Synchronize while disabled: held buttons never acquire a fresh move edge.': '禁用时仍同步按钮快照，避免按住定位按钮切入手动后产生虚假的新上升沿。',
    'Baseline on enable, so reconnect never replays a stale command.': '首次启用仅记录当前序号，避免重新连接时执行缓冲区遗留命令。',
    'Positions at [32..48]: signed INT, 0.1 engineering-unit scaling.': 'awTx[32..48]：设备 1..17 位置，按 0.1 工程单位缩放，解读为有符号 INT。',
    'One cyclic owner in ETHERCAT1. All lower device FBs are called each scan.': '本程序只在 ETHERCAT1 中周期调用一次；内部功能块沿本调用链每扫描执行。',
    '================= Commands (HMI / online write) =================': '旧 Demo 操作命令：仅供单轴测试，新整机流程不使用。',
    '================= Motion parameters =================': '旧 Demo 运动参数：实际采用及限幅见各参数同行说明。',
    '================= Status =================': '旧 Demo 运行反馈：仅在旧程序被调用时更新。',
    'P010 length up': 'P010 定长 D5 升起避让；确认本次动作完成后再允许 D4 平移。',
    'P020 move length clear': 'P020 定长 D4 移到配方避让位置，等待本次序号完成。',
    'Q010 roller down': 'Q010 流利条 G4 下降。',
    'Q020 release side push': 'Q020 推动气缸 G3 放开。',
    'Q030 lower selected side stop': 'Q030 侧挡 G2 下降；继电器选择由当前料型决定。',
    'A010 spray before return': 'A010 G5 喷油并等待 tSpray；喷油建立后才开始计时。',
    'A020 return cut axis': 'A020 结束喷油请求，D2 回到 lrCutHome，等待到位。',
    'B010 side stop up': 'B010 侧挡 G2 提升。',
    'B020 rollers up': 'B020 流利条 G4 提升。',
    'B030 gripper lift up': 'B030 机械手 G7 提升。',
    'B040 gripper open': 'B040 夹爪 G8 打开，准备前进取料。',
    'B050 gripper forward': 'B050 机械手 D7 前进到取料位置 lrGripperFront。',
    'B060 gripper clamp': 'B060 夹爪 G8 夹紧，确认后才拉料。',
    'B070 pull product': 'B070 机械手 D7 拉料到 lrGripperPull。',
    'B080 gripper open': 'B080 夹爪 G8 打开，释放移走的料。',
    'B090 retreat while raised': 'B090 保持机械手抬升，D7 后退至 lrGripperBack；此时不是最终回位。',
    'B100 lower gripper': 'B100 后退到位后，G7 下降。',
    'B110 final return while lowered': 'B110 下降到位后，D7 再回 lrGripperHome；本支线结束前不允许送料。',
    'C010 length to detection position': 'C010 定长 D4 回到配方检测位置 lrLengthPosition。',
    'C020 lower length sensor': 'C020 D4 到位后，定长 D5 下降。',
    'C030 verify down, detection permission follows physical position': 'C030 确认 D5 下降端到位，后续送料才具备光电检测条件。',
    'SIMULATION initialization: lift knife, press; open gripper': '仿真初始化 10：同时抬起 G9、抬起 G1、打开 G8，三项都完成才继续。',
    'Prepare clear positions': '仿真初始化 20：D5 升起、G2 提升、G3 释放、G4 提升、G7 下降，全部完成再定位。',
    'Move to simulation initial coordinates': '仿真初始化 30：D2/D4/D7/D8 移至示例初始坐标，全部完成才继续。',
    'Length down for detection': '仿真初始化 40：D5 下降，准备进入来料检测。',
}

AUTO_STEPS = {
    'Idle': '待机转入送料；没有直接跳到切割。',
    'FeedWait': 'D1 送料并正常等料；光电须先离开再到位，且 D5 必须在下降端。',
    'StopFeed': '本步不再给 D1 运行请求，整机周期清空请求后等待皮带非运行、非忙。',
    'Push': 'G3 侧推到位；只认本次 udiToken 对应的完成。',
    'Clearance': '并行调用定长避让 P 和输送机构避让 Q，两路都完成后旋转平台。',
    'Rotate': 'D8 旋转到 lrRotateAngle，必须在 G1 下压之前完成。',
    'PressDown': 'G1 下压到位。',
    'KnifeDown': 'G9 盘刀下降到位。',
    'SpindleOn': 'D3 盘刀开始旋转，完成序号匹配且运行反馈成立后允许走刀。',
    'Cutting': '保持 D3 运行，G6 吹气，D2 走到回刀起点加切割长度；以 D2 到位作为切割完成。',
    'StopCut': '撤销 D3/G6 运行请求，等待盘刀停止且吹气关闭后收尾。',
    'PostCut': '先抬刀再抬压，随后三支线同步执行；全部结束才完成本轮。',
    'Complete': '只在进入本步时输出一次完成脉冲；连续模式返回送料，单循环由整机回到 Ready。',
    'Fault': '保留流程错误状态；整机退出自动后才复位此流程。',
}

# 每个锚点均是原有语句；只在它前面插入解释，不改动语句自身。
ANCHORS = {
    'PLC_PRG': [
        ('fbCommunication(', '1. 解析上位机新命令并打包上一扫描状态，供本扫描整机处理。'),
        ('fbMachine(', '2. 整机选择操作来源，调度工序，通过互锁后统一调用设备。'),
        ('GVL_Interface.stStatus:=', '3. 将整机反馈发布到监控接口，建议调试时从这里查看主步骤和支线步骤。'),
        ('fbIO(', '4. 形成逻辑输出需求；此版本尚未映射真实 I/O。'),
    ],
    'FB_Machine': [
        ('stCommand:=stPanel;', '一、选择命令来源：本地默认优先；远程须授权，本地停止始终有效。'),
        ('rtInitialize(CLK', '二、提取初始化/启动/复位上升沿；采样仿真或真实预留输入。'),
        ('udiFault:=0;', '三、整理当前报警原因并清空本扫描请求；未被子流程重新提出的动作自动取消。'),
        ('IF (stStatus.eState=E_MachineState.Automatic) OR', '四、运行中切模式、停止或故障会撤销初始化，不能直接接续上一次工序。'),
        ('xResetDevices:=', '五、复位设备和首报警锁存；必须先撤销故障原因，复位不自动启动。'),
        ('IF rtInitialize.Q', '六、仅停止态接受初始化；配方通过检查后取快照。'),
        ('IF stStatus.eState=E_MachineState.Ready THEN', '七、初始化完成后才能启动自动；手动进入后还需全部按钮释放。'),
        ('xManualReleased:=TRUE;', '八、手动进入联锁：观察到一次全部按钮释放后，才开放点动/定位操作。'),
        ('fbInitialize(xExecute', '九、每扫描调用各模式功能块，失能的流程同时复位；共享请求只由当前模式提出。'),
        ('IF fbInitialize.xDone', '十、汇总流程完成和流程错误，单循环完成后回到 Ready。'),
        ('xPermit:=', '十一、总许可与机构互锁筛选请求，再调用设备管理器；流程判断使用此前的反馈。'),
        ('stStatus.eMode:=', '十二、集中发布状态；机械手/定长/回刀卡在哪一步，可从对应 ui...Step 追踪。'),
    ],
    'FB_AutoCycle': [
        ('xDone := FALSE;', '完成标志每扫描先清零；本流程在许可撤销后复位，不保留中断点续跑。'),
        ('xEntry :=', '进入新步骤才换新动作序号，同一步持续保持请求，防止反复启动。'),
        ('tonStep(IN', '送料等料不计步骤超时；其余执行步按运行配方监控。'),
        ('fbClear(xExecute', '子功能块必须每扫描调用，包括失能时复位；上方状态判断看到的是此前反馈。'),
        ('IF fbClear.xError', '任一支线错误向主流程上报；所有设备请求还须经过整机统一互锁。'),
    ],
    'FB_PostCut': [
        ('xEntry :=', '每个总步骤分配新序号；等待三路期间保留总步骤超时。'),
        ('fbKnife(xExecute', '三路只在总步骤 30 同时使能，并且每扫描调用；等待三路全完成才退出。'),
    ],
    'FB_ClearanceUnit': [('fbLength(xExecute', 'P/Q 两路同一扫描使能；xDone 使用 AND，任一路未完成均不得继续。')],
    'FB_ManualControl': [
        ('uiRejectDevice:=0;', '每扫描重新判断按钮冲突；无合法请求的设备由整机统一撤销动作。'),
        ('        ELSIF aManual[i].xJogPositive', '点动电平控制，只支持 D2/D4/D5/D7/D8；速度符号决定方向，松开后不保持点动。'),
        ('        ELSIF aManual[i].xRun', '连续运行电平控制，仅允许皮带、盘刀、喷油和吹气。'),
        ('            IF aManual[i].xMove AND NOT', '定位仅在按钮上升沿锁存目标和序号，然后持续等待本次完成。'),
    ],
    'FB_Interlocks': [
        ('uiBlockedDevice:=0;', '以下为普通程序互锁；实际急停、门锁、失气等安全功能须由最终硬件方案实现。'),
        ('        4:', 'D4 平移之前，D5 定长升降必须已经升起。'),
        ('        8:', 'D8 平台旋转之前，盘刀和下压抬起、G3 侧推解除。'),
        ('        9:', 'G1 下压时，平台不得旋转，盘刀抬起且 D2 在回刀起点。'),
        ('        17:', 'G9 下刀时，下压到位、旋转停止、定长升起、流利条下降、侧挡下降。'),
        ('        2:', 'D2 正向切割需下压和盘刀下降到位且盘刀运行；回刀需盘刀抬起。'),
        ('        7:', 'D7 机械手分点动、拉料、抬升平移与下降回位分别校验，保持后退/下降/回位顺序。'),
        ('    IF NOT xAllowed', '互锁不满足则用 Stop 覆盖该设备请求；记录最后一个被阻挡编号，便于排查。'),
    ],
    'FB_DeviceManager': [
        ('IF NOT xBooted', '只在首扫描建立设备类型和初始位置；D6 保留，G4 初始在提升端，其余位置取配置默认。'),
        ('FOR i := 1 TO 17 DO\n    CASE', '每周期按设备类型只选择一种执行入口，再将反馈回填同一编号。'),
    ],
    'FB_SimDevice': [
        ('IF NOT xBooted', '首次读取初始位置；以后位置由仿真动作累计，不在每周期重新归零。'),
        ('IF NOT stStatus.xReady', '无许可、无请求或明确 Stop 时取消当前动作并清接收/完成序号。'),
        ('ELSIF (stCommand.udiID', '只接收不同于上次的非零序号；接收时检查速度与目标行程范围。'),
        ('tonAction(IN := xAction', '固定时间仿真定位，不依据实际速度/加速度建模；卡住注入时保持忙且不完成。'),
        ('tonJog(IN :=', '点动按相邻扫描的时间差累计位置，达到示例软行程边界后限幅。'),
    ],
    'FB_SimPlant': [('IF NOT xEnable', '定长抬起时清除上次来料；自动方式形成一次延时到位，手动方式直接采用人工传感器。')],
    'FB_ModbusInterface': [
        ('xRequest:=FALSE;', '每扫描清除动作脉冲；模式和连续选择保留，避免两帧之间丢失模式。'),
        ('    aSnapshot:=awRx;', '接收索引：0=版本1，1=非零新序号，2=命令1初始化/2启动/3停止/4复位，3=模式0手动/1自动，4=连续。发送端应先写参数，最后更新序号。'),
        ('            CASE aSnapshot[2]', '仅合法新帧发出一次请求；收到确认还要继续观察整机状态，确认不代表运动完成。'),
        ('FOR i:=0 TO 127', '发布缓冲区每扫描清零后重填；数组索引不是实际 Modbus 4xxxx 地址。'),
        ('awTx[0]:=1;', '0=协议版本；1=整机已处理序号；2=处理结果。'),
        ('awTx[3]:=', '3=整机状态；4=自动主步骤，枚举值见 00_Types。'),
        ('awTx[5]:=', '5/6=报警码低字/高字；7/8=循环计数低字/高字，网络侧须约定同样字序。'),
        ('awTx[9]:=', '9=仿真；10=已初始化；11=来料到位；12=当前运行料型。'),
        ('awTx[13]:=', '13=解析器已观察序号；14=格式结果，0 合法、2 非法。'),
    ],
    'FB_IOMap': [('IF aStatus[10]', '仅当 G2 下降反馈大于 0.5 时，按运行料型选择一条需求；未绑定物理继电器。')],
    'F_NextID': [('IF udiCounter', '最大值之后回到 1，跳过无效序号 0；同一机台所有流程共享该计数器。')],
    'F_Command': [('F_Command.eAction', '只复制字段形成结构体，不等待动作、不直接访问物理设备。')],
    'F_Done': [('F_Done :=', '完成必须匹配本次请求；历史 Done 或仅 Busy=FALSE 都不足以作为本步完成条件。')],
    'F_At': [('F_At :=', '位置容差为 0.01 工程单位；这里不做新命令序号校验，用于姿态/互锁判断。')],
    'F_RecipeValid': [('F_RecipeValid :=', '示例边界：切长 0..500、速度 0..100、角度正负360，并要求机械手回位<后退<前进<拉料。边界是否适合实机仍需标定。')],
    'FB_AlarmManager': [('IF xReset', '只有没有当前报警原因才清锁存；当前代码保留第一个非零报警，后续报警不覆盖。')],
}


# 2026-10-21：实体面板拥有模式，远程类型只保留启停。
MODULES.update({
    'ST_PanelInputs': '实体旋钮与按钮的逻辑输入；映射层先处理常开/常闭和极性，不在此处指定物理地址。仿真使用相同格式。',
    'ST_RemoteCommand': '上位机可选启停请求，不含模式、初始化、复位或连续选择字段。参数通过独立配方接口下发。',
    'ST_OperatorCommand': '由本地实体面板解码形成的整机命令。模式取自旋钮，初始化/启动/复位取按钮，停止为电平有效。',
    'FB_PanelInput': '每扫描先读取实体面板或仿真面板，形成唯一的本地命令来源。上位机不能修改此处的模式。',
    'GVL_Interface': '监控与调试接口。stPanel 每周期由面板解码覆盖，不是上位机命令入口；手动请求保留待物理按钮映射。',
    'FB_ModbusInterface': 'Modbus 协议 v2：只解析可选的远程启动/停止，发布整机状态。模式只读；参数映射另行配置。',
    'PLC_PRG': '周期入口：先解码实体面板，再解析通信、调度整机、发布反馈和映射逻辑输出，仅在 ETHERCAT1 调用一次。',
})
VARIABLES.update({
    'xAutoMode': '模式旋钮的标准化逻辑值：TRUE 自动，FALSE 手动；不是上位机设定值。',
    'stPanelInputs': '实体面板的模式旋钮、初始化、启动、停止、复位逻辑信号；急停走独立安全许可。',
    'xAllowRemoteStartStop': '本地工程配置授权远程启停，默认 FALSE；不授予改模式、初始化或复位权限，也不映射给上位机写。',
    'xRemoteStartStopAllowed': '当前是否允许上位机启停，供只读状态发布；与物理手动/自动模式独立。',
    'xStartRequest': '本次启动事件=本地启动按钮上升沿或已接受的远程启动帧；两种事件分别处理以免相互吞掉。',
    'stSelected': '本扫描选中的实体/仿真面板输入快照。',
    'stReal': '从物理 I/O 映射得到的标准化面板输入，当前未分配端子地址。',
    'fbPanel': '实体/仿真面板解码实例，须先于通信和整机调度调用。',
    'awRx': 'v2 接收字：0=版本2，1=序号，2=命令2启动/3停止；3/4 保留且必须为0，不接受模式写入。',
    'eMode': '本地模式旋钮的当前选择：Manual 手动，Automatic 自动；上位机仅可读取。',
    'uiRemoteResult': '远程处理结果：0 接受，1 未授权，2 不支持命令，3 状态/本地停止不允许，5 配方不合法。',
})
OVERRIDES.update({
    ('FB_PanelInput', 'stSim'): '仿真用面板输入，代替尚未连接的实体旋钮和按钮。',
    ('FB_PanelInput', 'stCommand'): '由本地面板生成的命令，模式仅由 xAutoMode 形成。',
    ('FB_Machine', 'stPanel'): '本地实体面板解码结果；模式、初始化、复位始终以它为准。',
    ('FB_Machine', 'stRemote'): '上位机可选的启停请求，不包含模式或初始化/复位字段。',
    ('FB_ModbusInterface', 'stCommand'): '合法新帧产生的单扫描远程启停请求，没有模式字段。',
    ('GVL_Interface', 'stPanel'): '本地面板解码结果，只读观察；每周期覆盖，操作请使用实体或仿真面板输入。',
    ('GVL_Simulation', 'stPanelInputs'): '仿真旋钮/按钮输入；xAutoMode 选择模式，其余按钮按住/释放模拟物理信号。',
    ('GVL_Parameters', 'xContinuous'): '本地工程配置的单循环/连续选择；上位机启停帧不修改此设置，默认单循环。',
})
TRANSLATIONS.update({
    'Logical signals are normalized at the I/O boundary; no physical addresses are assigned here.': '这里只处理已归一化的逻辑信号；端子、常开/常闭和必要的输入滤波在实际 I/O 映射时确定。',
    'Physical panel owns mode, initialization, reset and local stop.': '模式、初始化、复位来自实体面板；远程只可追加经过授权的启停，不能替换整份本地命令。',
    'Local start uses an edge; each accepted remote frame is already a one-scan request.': '本地启动取按钮上升沿，远程启动取新帧脉冲，分别形成事件；本地停止仍优先。',
})
ANCHORS['PLC_PRG'].insert(0, ('fbPanel(', '先解码实体/仿真面板；模式旋钮为唯一模式来源，随后发布到只读监控接口。'))
ANCHORS['FB_PanelInput'] = [('stCommand.eMode:=', '默认手动，只有本地旋钮明确选择自动才转自动；急停反馈不混入普通停止按钮。')]
ANCHORS['FB_ModbusInterface'] = [
    ('xRequest:=FALSE;', '每扫描清除远程启停脉冲；模式、初始化、复位不属于远程命令。'),
    ('    aSnapshot:=awRx;', 'v2：0=版本2，1=新序号，2=命令2启动/3停止，3/4 必须0；旧版或带模式的帧被拒绝。'),
    ('            CASE aSnapshot[2]', '合法新帧只产生启停请求，实际接受还须整机检查本地授权、旋钮模式及状态。'),
    ('FOR i:=0 TO 127', '发布缓冲区是只读反馈，实际寄存器地址与参数下发映射尚未接入。'),
    ('awTx[0]:=2;', '0=协议版本2；1=整机处理序号；2=处理结果。'),
    ('awTx[3]:=', '3=整机状态；4=自动主步骤。'),
    ('awTx[5]:=', '5/6=报警低字/高字；7/8=循环计数低字/高字。'),
    ('awTx[9]:=', '9=仿真；10=已初始化；11=料到位；12=运行料型。'),
    ('awTx[13]:=', '13=解析器观察序号；14=格式结果0合法/2非法；15=实体旋钮模式0手动/1自动；16=远程启停授权。'),
]


def translate_comments(text):
    def replace(match):
        original = match.group(1).strip()
        note = TRANSLATIONS.get(original)
        return '(* ' + note + ' *)' if note else match.group(0)
    return re.sub(r'\(\*([\s\S]*?)\*\)', replace, text)


def annotate_implementation(name, text):
    if not text.strip():
        return ''
    text = translate_comments(text)
    for anchor, note in ANCHORS.get(name, []):
        if anchor not in text:
            raise ValueError('缺少实现注释锚点：%s / %s' % (name, anchor))
        offset = text.index(anchor)
        line_start = text.rfind('\n', 0, offset) + 1
        indent = re.match(r'[ \t]*', text[line_start:]).group(0)
        prefix = indent + '(* ' + note + ' *)\n'
        if not text[:line_start].endswith(prefix):
            text = text[:line_start] + prefix + text[line_start:]
    if name == 'FB_AutoCycle':
        for step, note in AUTO_STEPS.items():
            anchor = 'E_AutoStep.' + step + ':'
            prefix = '(* ' + note + ' *)\n'
            if prefix + anchor not in text:
                text = text.replace(anchor, prefix + anchor, 1)
    elif name == 'FB_PostCut':
        notes = {0: '待机，执行许可有效后进入抬刀。', 10: '先 G9 盘刀提升，等待本次序号完成。', 20: '再 G1 下压提升，等待本次序号完成。', 30: '等待回刀、机械手移料、定长复位三路全部完成。', 1000: '三路收尾结束，保持完成反馈直到执行许可撤销。'}
        for step, note in notes.items():
            text = re.sub(r'^(\s*' + str(step) + r':)(?! \(\*)', lambda m: m[1] + ' (* ' + note + ' *)', text, count=1, flags=re.M)
    if name in {'FB_ClearLength', 'FB_ClearTransfer', 'FB_ReturnKnife', 'FB_Unload', 'FB_ResetLength', 'FB_Initialize'}:
        prefix = '(* 执行许可撤销即复位；步骤入口换新序号，每步等待本次动作完成，超时码=模块基码+步号。 *)\n'
        if not text.startswith(prefix):
            text = prefix + text
        text = text.replace('0: uiStep := 10;', '0: (* 待机；许可有效时进入首个动作。 *) uiStep := 10;')
        text = text.replace('1000: ;', '1000: (* 本支线完成，保持至 xExecute 撤销。 *) ;')
    return text.rstrip() + '\n'


def annotate_declaration(name, text):
    """注释写在声明同行，便于变量表直接显示；保留既有中文注释。"""
    lines = []
    in_variables = False
    for line in translate_comments(text).splitlines():
        stripped = line.strip()
        if re.match(r'^(VAR(?:_INPUT|_OUTPUT|_IN_OUT|_GLOBAL)?(?:\s+CONSTANT)?|STRUCT)$', stripped):
            in_variables = True
        elif stripped in ('END_VAR', 'END_STRUCT'):
            in_variables = False
        match = re.match(r'^(\s*)([A-Za-z_]\w*)\s*:(?!=)(.*?;)(.*)$', line) if in_variables else None
        if match:
            variable = match.group(2)
            note = OVERRIDES.get((name, variable), VARIABLES.get(variable))
            if name == 'PRG_AxisDemo':
                note = LEGACY_VARIABLES.get(variable, note)
            elif name == 'GVL_Motion':
                note = MOTION_VARIABLES.get(variable, note)
            if not note:
                raise ValueError('缺少变量注释：%s.%s' % (name, variable))
            tail = match.group(4).strip()
            # Replace old inline prose only; never remove executable text.
            if tail and not re.fullmatch(r'\(\*.*?\*\)', tail):
                raise ValueError('声明行尾包含非注释内容：%s' % line)
            line = line[:match.start(4)].rstrip() + ' (* ' + note + ' *)'
        elif name in ENUMS:
            member = re.match(r'^\s*([A-Za-z_]\w*)\s*:=\s*\d+\s*,?\s*$', line)
            if member:
                line += ' (* ' + ENUMS[name][member.group(1)] + ' *)'
        lines.append(line)
    header = '(* 模块说明：' + MODULES[name] + ' *)'
    if not text.startswith(header):
        lines.insert(0, header)
    return '\n'.join(lines).rstrip() + '\n'


def annotate_object(name, declaration, implementation=''):
    return annotate_declaration(name, declaration), annotate_implementation(name, implementation)
