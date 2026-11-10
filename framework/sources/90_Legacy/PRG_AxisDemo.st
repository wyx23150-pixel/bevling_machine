(* 模块说明：保留的旧单轴低速往返 Demo，当前未周期调用。它不属于新切割机自动工序。 *)
PROGRAM PRG_AxisDemo
VAR
    (* 运动控制功能块：伺服使能、复位、停止及位置反馈。 *)
    fbPower    : MC_Power; (* 旧 Demo 伺服使能功能块，操作对象为 pandao。 *)
    fbReset    : MC_Reset; (* 旧 Demo 轴故障复位功能块。 *)
    fbStop     : MC_Stop; (* 旧 Demo 受控停止功能块，完成后释放停止锁定。 *)
    fbJog      : MC_Jog; (* 保留的点动实例，当前 Demo 正文未调用。 *)
    fbMoveRel  : MC_MoveRelative; (* 保留的相对定位实例，当前正文使用 fbCycle 执行往返。 *)
    fbMoveAbs  : MC_MoveAbsolute; (* 保留的绝对定位实例，当前 Demo 正文未调用。 *)
    fbCycle    : MC_MoveRelative; (* 实际执行单次往返的相对定位实例，每段使用独立 Execute 触发。 *)
    fbReadPos  : MC_ReadActualPosition; (* 读取 pandao 实际位置，写入旧监控变量 rActPos。 *)
    fbReadStat : MC_ReadStatus; (* 保留的轴状态读取实例，当前正文未调用。 *)
    fbReadErr  : MC_ReadAxisError; (* 保留的轴错误读取实例，当前正文未调用。 *)

    (* 启动信号上升沿检测 *)
    rtCycle    : R_TRIG; (* 旧 Demo 启动按钮上升沿检测，按住按钮不会重复往返。 *)

    (* 自动测试循环的内部状态 *)
    fbCycleExec: BOOL; (* 往返定位功能块 Execute 请求，换向前清除后再置位。 *)
    rCycleDist : LREAL; (* 本段相对位移，正向为正、回程为负，单段绝对值限 20 mm。 *)
    iCycle     : INT := 0; (* 旧 Demo 步骤：0 待机，10 正向，20 停留，30 回程，40 停留结束，99 故障。 *)
    tonDwell   : TON; (* 正向与回程到位后的停留计时器。 *)

    (* 运行状态与故障诊断 *)
    eLastErr   : SMC_ERROR; (* 历史保留的错误变量，当前正文未更新，请看轴/功能块实际错误输出。 *)
	xDoReset: BOOL; (* 历史测试保留变量，当前正文未引用。 *)
	xStopRun: BOOL; (* 旧 Demo 停止请求锁存，收到停止或运动错误后置位。 *)
	rRunDec: LREAL; (* 历史测试保留减速度变量，当前正文未引用。 *)
	xStartRun: BOOL; (* 历史测试保留启动变量，当前正文未引用。 *)
	iStep: INT; (* 历史测试保留步骤变量，当前有效步骤为 iCycle。 *)
	fbMoveVel: MC_MoveVelocity; (* 历史速度运动实例，当前正文未调用。 *)
	Axis: INT; (* 历史保留 INT 变量，不是 pandao 运动轴对象，当前正文未引用。 *)
	Execute: BOOL; (* 历史测试保留执行变量，当前正文未引用。 *)
	rRunVel: LREAL; (* 历史测试保留速度变量，当前正文未引用。 *)
	rRunAcc: LREAL; (* 历史测试保留加速度变量，当前正文未引用。 *)
	Velocity: INT; (* 历史测试保留 INT 变量，当前正文未引用。 *)
	Acceleration: INT; (* 历史测试保留 INT 变量，当前正文未引用。 *)
	Deceleration: INT; (* 历史测试保留 INT 变量，当前正文未引用。 *)
	Direction: INT; (* 历史测试保留方向变量，当前正文未引用。 *)
	InVelocity: INT; (* 历史测试保留 INT 变量，当前正文未引用。 *)
	xMoveExec: BOOL; (* 历史测试保留执行变量，当前正文未引用。 *)
END_VAR
PROGRAM PRG_AxisDemo
(* 中文注释显示核对：单次低速 20 mm 往返测试。
   GVL_Motion.xStartCycle 的上升沿启动一次循环。
   单程距离最多 20 mm，速度最多 10 mm/s。 *)
rtCycle(CLK := GVL_Motion.xStartCycle);

fbPower(Axis         := pandao,
        Enable       := GVL_Motion.xEnable,
        bRegulatorOn := TRUE,
        bDriveStart  := TRUE);

fbReset(Axis := pandao, Execute := GVL_Motion.xReset);

IF GVL_Motion.xStop THEN
    xStopRun   := TRUE;
    fbCycleExec := FALSE;
    iCycle      := 0;
END_IF

IF fbPower.Error OR fbCycle.Error OR fbReset.Error OR fbStop.Error THEN
    iCycle      := 99;
    fbCycleExec := FALSE;
    xStopRun    := TRUE;
END_IF

fbStop(Axis         := pandao,
       Execute      := xStopRun,
       Deceleration := MIN(MAX(GVL_Motion.rDec, 10.0), 200.0));

IF xStopRun AND fbStop.Done THEN
    xStopRun := FALSE;
END_IF

tonDwell(IN := (iCycle = 20) OR (iCycle = 40),
         PT := GVL_Motion.tDwell);

CASE iCycle OF
    0:  (* 等待启动：一次上升沿触发一次完整往返。 *)
        fbCycleExec := FALSE;
        IF rtCycle.Q
           AND GVL_Motion.xEnable
           AND fbPower.Status
           AND NOT GVL_Motion.xAxisError
           AND NOT xStopRun
           AND (ABS(GVL_Motion.rStroke) > 0.0) THEN
            rCycleDist := MIN(ABS(GVL_Motion.rStroke), 20.0);
            fbCycleExec := TRUE;
            iCycle := 10;
        END_IF

    10: (* 正向运动：等待轴到达指定位置。 *)
        IF fbCycle.Done THEN
            fbCycleExec := FALSE;
            iCycle := 20;
        ELSIF fbCycle.Error THEN
            fbCycleExec := FALSE;
            iCycle := 99;
            xStopRun := TRUE;
        END_IF

    20: (* 正向到位后停留，再发出反向运动指令。 *)
        IF tonDwell.Q AND NOT xStopRun THEN
            rCycleDist := -MIN(ABS(GVL_Motion.rStroke), 20.0);
            fbCycleExec := TRUE;
            iCycle := 30;
        END_IF

    30: (* 反向返回：等待轴完成回程。 *)
        IF fbCycle.Done THEN
            fbCycleExec := FALSE;
            iCycle := 40;
        ELSIF fbCycle.Error THEN
            fbCycleExec := FALSE;
            iCycle := 99;
            xStopRun := TRUE;
        END_IF

    40: (* 返回起点后停留，本次循环结束。 *)
        IF tonDwell.Q THEN
            iCycle := 0;
        END_IF

    99: (* 故障保持：复位成功且停止完成后，允许回到待机。 *)
        fbCycleExec := FALSE;
        IF GVL_Motion.xReset AND fbReset.Done AND NOT xStopRun THEN
            iCycle := 0;
        END_IF

ELSE
    iCycle := 99;
    fbCycleExec := FALSE;
    xStopRun := TRUE;
END_CASE

fbCycle(Axis         := pandao,
        Execute      := fbCycleExec AND NOT xStopRun,
        Distance     := rCycleDist,
        Velocity     := MIN(MAX(GVL_Motion.rVel, 1.0), 10.0),
        Acceleration := MIN(MAX(GVL_Motion.rAcc, 10.0), 200.0),
        Deceleration := MIN(MAX(GVL_Motion.rDec, 10.0), 200.0));

fbReadPos(Axis := pandao, Enable := TRUE);

GVL_Motion.xPowered    := fbPower.Status;
GVL_Motion.xBusy       := fbCycle.Busy OR fbStop.Busy;
GVL_Motion.xDisabled   := NOT fbPower.Status;
GVL_Motion.xStopping   := fbStop.Busy;
GVL_Motion.xStandStill := fbPower.Status AND NOT GVL_Motion.xBusy;
GVL_Motion.xAxisReady  := GVL_Motion.xStandStill AND NOT GVL_Motion.xAxisError;
GVL_Motion.xAxisError  := fbPower.Error OR fbCycle.Error OR fbReset.Error OR fbStop.Error;
GVL_Motion.xErrorStop  := GVL_Motion.xAxisError;
GVL_Motion.iState      := iCycle;
GVL_Motion.rActPos     := fbReadPos.Position;
