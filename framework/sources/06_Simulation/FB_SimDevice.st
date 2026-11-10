(* 模块说明：设备仿真模型：定位按固定时间插值、连续运行保持状态、点动按时间增量累计位置。 *)
FUNCTION_BLOCK FB_SimDevice
VAR_INPUT
    xEnable : BOOL; (* 本功能使能，电平有效；失能时不接受新的动作请求。 *)
    xReset : BOOL; (* 故障复位许可；仿真设备仅在故障注入已撤销时清除错误。 *)
    xStall : BOOL; (* 仿真卡住输入；TRUE 暂停位置推进且不发完成，保留忙状态。 *)
    xInjectFault : BOOL; (* 仿真设备故障输入；TRUE 锁存错误码 9001。 *)
    stConfig : ST_DeviceConfig; (* 设备类型、初始位置、软限位与仿真动作时间。 *)
    stCommand : ST_DeviceCommand; (* 当前单设备命令，含动作类型、序号、目标和速度。 *)
END_VAR
VAR_OUTPUT
    stStatus : ST_DeviceStatus; (* 本模块对外发布的状态；字段含义见其数据类型。 *)
END_VAR
VAR
    xBooted : BOOL; (* 本功能块首次初始化完成标志，防止每扫描重写初值。 *)
    xAction : BOOL; (* 仿真定时动作进行中；定位和建立连续运行状态使用，点动另行处理。 *)
    udiLastID : UDINT; (* 上次已接受序号，同一序号保持期间不重复启动动作。 *)
    lrStart : LREAL; (* 本次仿真定位的起始位置，用于按时间插值。 *)
    lrTarget : LREAL; (* 本次已接受定位命令的目标位置快照，用于时间插值。 *)
    lrJogDelta : LREAL; (* 点动相邻扫描的时间差，单位秒；速度乘该值取得本扫描位移。 *)
    tLastJog : TIME; (* 上扫描点动计时值，用于计算本扫描时间增量。 *)
    tonAction : TON; (* 仿真定位或建立连续运行状态的定时器。 *)
    tonJog : TON; (* 点动累计计时器，用于计算位置增量，设定计时上限 24 小时。 *)
END_VAR
FUNCTION_BLOCK FB_SimDevice
(* 首次读取初始位置；以后位置由仿真动作累计，不在每周期重新归零。 *)
IF NOT xBooted THEN
    stStatus.lrPosition := stConfig.lrInitialPosition;
    xBooted := TRUE;
END_IF
IF xReset AND NOT xInjectFault THEN
    stStatus.xError := FALSE; stStatus.udiErrorID := 0;
END_IF
IF xInjectFault THEN 
	stStatus.xError := TRUE;
	stStatus.udiErrorID := 9001;
END_IF
stStatus.xReady := xEnable AND NOT stStatus.xError AND (stConfig.eKind <> E_DeviceKind.Unused);

(* 无许可、无请求或明确 Stop 时取消当前动作并清接收/完成序号。 *)
IF NOT stStatus.xReady OR (stCommand.eAction = E_DeviceAction.None)
   OR (stCommand.eAction = E_DeviceAction.Stop) THEN
    xAction := FALSE; udiLastID := 0;
    stStatus.xBusy := FALSE; stStatus.xActive := FALSE;
    stStatus.udiAcceptedID := 0; stStatus.udiCompletedID := 0;
(* 只接收不同于上次的非零序号；接收时检查速度与目标行程范围。 *)
ELSIF (stCommand.udiID <> 0) AND (stCommand.udiID <> udiLastID) THEN
    udiLastID := stCommand.udiID;
    stStatus.udiAcceptedID := udiLastID; stStatus.udiCompletedID := 0;
    lrStart := stStatus.lrPosition; lrTarget := stCommand.lrTarget;
    IF (ABS(stCommand.lrVelocity) > stConfig.lrMaxVelocity)
       OR ((stCommand.eAction = E_DeviceAction.Position) AND
           ((lrTarget < stConfig.lrMinPosition) OR (lrTarget > stConfig.lrMaxPosition))) THEN
        stStatus.xError := TRUE; stStatus.udiErrorID := 2001; xAction := FALSE;
    ELSE
        xAction := stCommand.eAction <> E_DeviceAction.Jog;
        stStatus.xBusy := TRUE; stStatus.xActive := FALSE;
    END_IF
    (* 接收新序号时先复位计时器，随后由每扫描调用开始本次计时。 *)
    tonAction(IN := FALSE);
END_IF
(* 固定时间仿真定位，不依据实际速度/加速度建模；卡住注入时保持忙且不完成。 *)
tonAction(IN := xAction AND stStatus.xReady, PT := stConfig.tSimAction);
IF xAction AND NOT xStall AND stStatus.xReady THEN
    IF stCommand.eAction = E_DeviceAction.Position THEN
        stStatus.lrPosition := lrStart + (lrTarget-lrStart) *
            MIN(1.0, TIME_TO_LREAL(tonAction.ET) / MAX(1.0, TIME_TO_LREAL(stConfig.tSimAction)));
    END_IF
    IF tonAction.Q THEN
        IF stCommand.eAction = E_DeviceAction.Position THEN stStatus.lrPosition := lrTarget; END_IF
        stStatus.xBusy := FALSE;
        stStatus.xActive := stCommand.eAction = E_DeviceAction.Run;
        stStatus.udiCompletedID := udiLastID;
        xAction := FALSE;
    END_IF
END_IF
(* 点动按相邻扫描的时间差累计位置，达到示例软行程边界后限幅。 *)
tonJog(IN := stStatus.xReady AND (stCommand.eAction = E_DeviceAction.Jog), PT := T#24H);
IF tonJog.IN THEN
    lrJogDelta := TIME_TO_LREAL(tonJog.ET-tLastJog) / 1000.0;
    IF NOT xStall THEN
        stStatus.lrPosition := LIMIT(stConfig.lrMinPosition,
            stStatus.lrPosition+stCommand.lrVelocity*lrJogDelta, stConfig.lrMaxPosition);
    END_IF
    stStatus.xBusy := TRUE; stStatus.xActive := TRUE;
    tLastJog := tonJog.ET;
ELSE tLastJog := T#0MS;
END_IF
IF stStatus.xError THEN
    stStatus.xReady := FALSE; stStatus.xBusy := FALSE; stStatus.xActive := FALSE;
END_IF
