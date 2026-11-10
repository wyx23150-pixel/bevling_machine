(* 模块说明：面板两色指示灯的纯输出逻辑。指示灯没有反馈、不参与互锁、不占设备索引，
   所以不做成设备，只在这里按整机状态算出两个灯的电平，由 PLC_PRG 下沉到 GVL_IO_Physical。
   优先级：停止/故障最高（红亮绿灭）→ 自动循环运行中（绿慢闪）→ 其余正常运行（绿常亮）。 *)
FUNCTION_BLOCK FB_Indicator
VAR_INPUT
	xRunState : BOOL; (* 整机运行态锁存；FALSE 表示按过停止或上电还没启动。 *)
	eState : E_MachineState; (* 整机状态；Stopped 与 Fault 一律按停机处理。 *)
	eMode : E_MachineMode; (* 模式旋钮当前选择；只有自动循环真正在跑时绿灯才改为慢闪。 *)
	udiAlarm : UDINT; (* 锁存报警码；非 0 时按故障处理，红亮绿灭。 *)
	tBlinkHalf : TIME := T#500MS; (* 慢闪半周期：500 ms 亮 + 500 ms 灭，即每秒亮灭一次。 *)
END_VAR
VAR_OUTPUT
	xGreen : BOOL; (* 绿灯电气电平，TRUE 为亮。 *)
	xRed : BOOL; (* 红灯电气电平，TRUE 为亮。 *)
	xBlinking : BOOL; (* 绿灯当前处于闪烁状态；仅用于监控，不参与控制。 *)
END_VAR
VAR
	tonBlink : TON; (* 闪烁节拍定时器；到点翻转相位并自复位，形成连续方波。 *)
	xBlinkPhase : BOOL; (* 闪烁相位：TRUE 为亮的那一半。 *)
END_VAR
FUNCTION_BLOCK FB_Indicator
(* 先算闪烁节拍：定时器到点就翻转相位并自复位，得到占空比 50% 的连续方波。
   IN 取 Q 的反相做自复位，Q 每次只保持一个扫描，正好当翻转脉冲用。 *)
tonBlink(IN := NOT tonBlink.Q, PT := tBlinkHalf);
IF tonBlink.Q THEN xBlinkPhase := NOT xBlinkPhase; END_IF

(* 停机判据与状态机保持同一口径：运行态锁存为假、处在故障、或有锁存报警，都算停下。
   红灯优先，任何情况下都不会出现红绿同时亮。 *)
IF (NOT xRunState) OR (eState = E_MachineState.Fault) OR (udiAlarm <> 0) THEN
	xRed := TRUE; xGreen := FALSE; xBlinking := FALSE;
(* 自动循环运行中：绿灯慢闪，表示"正在自动动作"，与手动时有人在场操作区分开。 *)
ELSIF (eMode = E_MachineMode.Automatic) AND (eState = E_MachineState.Automatic) THEN
	xRed := FALSE; xGreen := xBlinkPhase; xBlinking := TRUE;
(* 其余运行状态（手动、初始化中、已就绪待启动）：绿灯常亮。 *)
ELSE
	xRed := FALSE; xGreen := TRUE; xBlinking := FALSE;
END_IF
