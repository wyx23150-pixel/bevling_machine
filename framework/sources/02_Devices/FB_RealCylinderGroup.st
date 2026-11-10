FUNCTION_BLOCK FB_RealCylinderGroup
(* 模块说明：按料型选通的真实气缸组适配层（G2 侧挡用，300/450/600 三缸共用设备索引 10）。
   同一时刻只允许一个气缸下降，其余两个强制提升；回写与 FB_SimDevice 完全一致的接收/完成序号，
   使上层流程与互锁无需区分单缸、多缸或仿真。
   命令目标 lrTarget：0 = 三缸全部提升；300 / 450 / 600 = 对应料型气缸下降，其余两个提升。
   lrTarget 在 0..1 之间时按单缸旧语义映射：>0.5 视为「降到当前料型」，<=0.5 视为三缸全部提升。 *)
VAR_INPUT
	xUseReal : BOOL; (* TRUE 表示本编号由真实气缸组接管；FALSE 时三个阀全部失电且不响应任何命令。 *)
	xEnable : BOOL; (* 设备级使能，来自整机许可；FALSE 时阀失电并清序号。 *)
	xReset : BOOL; (* 故障复位上升沿；清锁存错误与序号。 *)
	xFaultHold : BOOL; (* 整机故障保持：TRUE 时三个阀立即失电，直到复位。 *)
	uiMaterialModel : UINT; (* 当前运行料型 300/450/600；旧语义 lrTarget>0.5 时降到本料型。 *)
	xSensorRetract1 : BOOL; (* 1 号缸（300）提升到位传感器原始电平，TRUE 表示该端有信号。 *)
	xSensorExtend1 : BOOL; (* 1 号缸（300）下降到位传感器原始电平。 *)
	xSensorRetract2 : BOOL; (* 2 号缸（450）提升到位传感器原始电平。 *)
	xSensorExtend2 : BOOL; (* 2 号缸（450）下降到位传感器原始电平。 *)
	xSensorRetract3 : BOOL; (* 3 号缸（600）提升到位传感器原始电平。 *)
	xSensorExtend3 : BOOL; (* 3 号缸（600）下降到位传感器原始电平。 *)
	xInvertSensors : BOOL; (* TRUE 表示六个传感器均为低电平有效，本层统一取反，不动上层。 *)
	xInvertValve : BOOL; (* TRUE 表示三个阀均为低电平使能；默认 FALSE，即高电平使能。 *)
	tSensorTimeout : TIME := T#3S; (* 六个传感器全部无信号达到该时间判为整组丢失，报 3004。 *)
	tTravelTimeout : TIME := T#10S; (* 命令发出后目标姿态未达成达到该时间判为动作超时，报 3005。 *)
	stConfig : ST_DeviceConfig; (* 行程范围，语义与仿真侧一致；组内气缸只使用 0/1 两端。 *)
	stCommand : ST_DeviceCommand; (* 上层统一设备命令，本层只响应 Position 的 0/300/450/600 目标。 *)
END_VAR
VAR_OUTPUT
	stStatus : ST_DeviceStatus; (* 与 FB_SimDevice 语义一致；目标缸下降到位 1.0，三缸全提 0.0，中间保持上次值。 *)
	aValve : ARRAY[1..3] OF BOOL; (* 三个阀的电气电平（已含 xInvertValve），直接接物理输出点；索引 1=300，2=450，3=600。 *)
	uiActiveBand : UINT; (* 当前实际下降的料型带号；0 表示三个缸都在提升位。 *)
END_VAR
VAR
	rtReset : R_TRIG; (* 复位上升沿。 *)
	tonNoSensor : TON; (* 六个传感器全部无信号的持续计时。 *)
	tonTravel : TON; (* 命令发出后等待到位的计时。 *)
	udiLastID : UDINT; (* 上次已接受的命令序号。 *)
	aRetract : ARRAY[1..3] OF BOOL; (* 取反处理后的三路提升信号。 *)
	aExtend : ARRAY[1..3] OF BOOL; (* 取反处理后的三路下降信号。 *)
	xAllRetract : BOOL; (* 三个缸都确认在提升位。 *)
	xPositionKnown : BOOL; (* 三缸姿态是否都已由传感器确立；未确立时 xReady 必须为 FALSE，防止上层把未知当成已提升。 *)
	xCmdValid : BOOL; (* 当前存在有效的保位命令，阀按此持续输出。 *)
	uiTargetBand : UINT; (* 有效命令期望下降的料型带号；0 表示三缸全部提升。 *)
	xTravelling : BOOL; (* 尚未确认到达命令要求的姿态。 *)
	i : INT; (* 本扫描数组遍历索引；含义及范围以当前 FOR 循环为准。 *)
END_VAR
FUNCTION_BLOCK FB_RealCylinderGroup
rtReset(CLK := xReset);

(* ===== 1. 复位：只清错误与序号，姿态仍由传感器决定 ===== *)
IF xUseReal AND rtReset.Q THEN
	stStatus.xError := FALSE; stStatus.udiErrorID := 0;
	xCmdValid := FALSE; xTravelling := FALSE; udiLastID := 0; uiTargetBand := 0;
	stStatus.udiAcceptedID := 0; stStatus.udiCompletedID := 0;
	tonNoSensor(IN := FALSE);
	tonTravel(IN := FALSE);
END_IF

(* ===== 2. 传感器取反与逐缸姿态判定 ===== *)
aRetract[1] := xSensorRetract1 XOR xInvertSensors;
aExtend[1] := xSensorExtend1 XOR xInvertSensors;
aRetract[2] := xSensorRetract2 XOR xInvertSensors;
aExtend[2] := xSensorExtend2 XOR xInvertSensors;
aRetract[3] := xSensorRetract3 XOR xInvertSensors;
aExtend[3] := xSensorExtend3 XOR xInvertSensors;

(* 单缸两端同时有信号：传感器短路、磁环位置错或机械卡在中间，该缸姿态不可信，按 3003 暴露。
   逐缸判定而不是整组判定：只要有一个缸自相矛盾，整组位置就不可信。 *)
FOR i := 1 TO 3 DO
	IF aRetract[i] AND aExtend[i] THEN
		stStatus.xError := TRUE; stStatus.udiErrorID := 3003;
	END_IF
END_FOR

(* 三缸姿态是否都已确立：每个缸必须恰好一端有效，中间态或两端全无都算未确立。 *)
xAllRetract := aRetract[1] AND aRetract[2] AND aRetract[3];
xPositionKnown := TRUE;
FOR i := 1 TO 3 DO
	IF (NOT aRetract[i]) AND (NOT aExtend[i]) THEN xPositionKnown := FALSE; END_IF
END_FOR
IF stStatus.xError THEN xPositionKnown := FALSE; END_IF

(* 六个传感器全部无信号并持续 tSensorTimeout：判整组传感器丢失，报 3004。
   单缸丢失不在这里报，由 xPositionKnown 为 FALSE 阻断就绪，交给超时暴露，避免一缸调试刷整组报警。 *)
tonNoSensor(IN := xUseReal AND NOT aRetract[1] AND NOT aExtend[1]
	AND NOT aRetract[2] AND NOT aExtend[2]
	AND NOT aRetract[3] AND NOT aExtend[3], PT := tSensorTimeout);
IF tonNoSensor.Q AND NOT stStatus.xError THEN
	stStatus.xError := TRUE; stStatus.udiErrorID := 3004;
END_IF

(* ===== 3. 命令接收与保位判定 ===== *)
IF NOT xUseReal THEN
	(* 未接管：不驱动阀，也不发布就绪，避免被上层当成可用设备 *)
	xCmdValid := FALSE; xTravelling := FALSE; udiLastID := 0; uiTargetBand := 0;
	stStatus.xReady := FALSE; stStatus.xBusy := FALSE; stStatus.xActive := FALSE;
	stStatus.udiAcceptedID := 0; stStatus.udiCompletedID := 0;
ELSIF NOT xEnable OR stStatus.xError OR xFaultHold THEN
	(* 故障或整机故障保持时阀失电，不带错误继续动作 *)
	xCmdValid := FALSE; xTravelling := FALSE;
	stStatus.xReady := FALSE; stStatus.xBusy := FALSE; stStatus.xActive := FALSE;
ELSE
	stStatus.xReady := xEnable AND xPositionKnown;

	(* 新序号即新命令；姿态未确立时不接受，防止朝未知状态动作 *)
	IF (stCommand.udiID <> 0) AND (stCommand.udiID <> udiLastID)
		AND xEnable AND xPositionKnown AND NOT stStatus.xBusy THEN
		udiLastID := stCommand.udiID;
		stStatus.udiAcceptedID := udiLastID; stStatus.udiCompletedID := 0;
		CASE stCommand.eAction OF
		E_DeviceAction.Position:
			IF (stCommand.lrTarget > 0.5) AND (stCommand.lrTarget <= 1.0) THEN
				(* 单缸旧语义：1 = 降到当前料型；料型非法时报 2001，不猜一个缸去动作 *)
				IF (uiMaterialModel = 300) OR (uiMaterialModel = 450) OR (uiMaterialModel = 600) THEN
					uiTargetBand := uiMaterialModel;
				ELSE
					stStatus.xError := TRUE; stStatus.udiErrorID := 2001;
				END_IF
			ELSIF ABS(stCommand.lrTarget) < 0.01 THEN
				uiTargetBand := 0;
			ELSIF (ABS(stCommand.lrTarget - 300.0) < 0.01) THEN
				uiTargetBand := 300;
			ELSIF (ABS(stCommand.lrTarget - 450.0) < 0.01) THEN
				uiTargetBand := 450;
			ELSIF (ABS(stCommand.lrTarget - 600.0) < 0.01) THEN
				uiTargetBand := 600;
			ELSE
				(* 只支持 0 / 300 / 450 / 600，其它目标明确报错而不是静默不动 *)
				stStatus.xError := TRUE; stStatus.udiErrorID := 2001;
			END_IF
			IF NOT stStatus.xError THEN
				xCmdValid := TRUE;
				xTravelling := TRUE;
				stStatus.xBusy := TRUE;
			ELSE
				xCmdValid := FALSE;
			END_IF
		E_DeviceAction.Stop, E_DeviceAction.None:
			xCmdValid := FALSE; xTravelling := FALSE; uiTargetBand := 0;
			stStatus.udiAcceptedID := 0; stStatus.udiCompletedID := 0;
			udiLastID := 0;
		ELSE
			(* 气缸组没有连续运行、点动和回零，明确报错而不是静默不动 *)
			stStatus.xError := TRUE; stStatus.udiErrorID := 2001;
			xCmdValid := FALSE;
		END_CASE
	END_IF

	(* 命令被撤销或失能：立即取消保位，阀随之失电 *)
	IF (stCommand.eAction = E_DeviceAction.Stop) OR (stCommand.eAction = E_DeviceAction.None)
		OR NOT xEnable THEN
		xCmdValid := FALSE; xTravelling := FALSE;
		stStatus.xBusy := FALSE;
	END_IF

	(* 到位判定：目标缸下降到位，并且另外两个缸都在提升位，才算本次命令完成。
	   中间态（目标缸还没下去、或另一缸还没起来）都视为未完成，由超时兜底。 *)
	IF xCmdValid AND xPositionKnown THEN
		CASE uiTargetBand OF
		0:
			IF xAllRetract THEN
				IF xTravelling THEN stStatus.udiCompletedID := udiLastID; END_IF
				xTravelling := FALSE;
				stStatus.xBusy := FALSE;
			END_IF
		300:
			IF aExtend[1] AND aRetract[2] AND aRetract[3] THEN
				IF xTravelling THEN stStatus.udiCompletedID := udiLastID; END_IF
				xTravelling := FALSE;
				stStatus.xBusy := FALSE;
			END_IF
		450:
			IF aExtend[2] AND aRetract[1] AND aRetract[3] THEN
				IF xTravelling THEN stStatus.udiCompletedID := udiLastID; END_IF
				xTravelling := FALSE;
				stStatus.xBusy := FALSE;
			END_IF
		600:
			IF aExtend[3] AND aRetract[1] AND aRetract[2] THEN
				IF xTravelling THEN stStatus.udiCompletedID := udiLastID; END_IF
				xTravelling := FALSE;
				stStatus.xBusy := FALSE;
			END_IF
		END_CASE
	END_IF
END_IF

(* ===== 4. 位置反馈：只有确切在位才更新，中间态保持上次值 ===== *)
IF uiTargetBand = 0 THEN
	IF xAllRetract THEN stStatus.lrPosition := 0.0; END_IF
ELSIF uiTargetBand = 300 THEN
	IF aExtend[1] THEN stStatus.lrPosition := 1.0; END_IF
ELSIF uiTargetBand = 450 THEN
	IF aExtend[2] THEN stStatus.lrPosition := 1.0; END_IF
ELSIF uiTargetBand = 600 THEN
	IF aExtend[3] THEN stStatus.lrPosition := 1.0; END_IF
END_IF

(* 实际下降的料型：命令目标有效且该缸确实到位才报带号，避免阀已得电但没下去时谎报挡料就位 *)
uiActiveBand := 0;
IF (uiTargetBand = 300) AND aExtend[1] THEN uiActiveBand := 300; END_IF
IF (uiTargetBand = 450) AND aExtend[2] THEN uiActiveBand := 450; END_IF
IF (uiTargetBand = 600) AND aExtend[3] THEN uiActiveBand := 600; END_IF

(* ===== 5. 到位超时 ===== *)
tonTravel(IN := xUseReal AND xTravelling AND xCmdValid, PT := tTravelTimeout);
IF tonTravel.Q AND NOT stStatus.xError THEN
	stStatus.xError := TRUE; stStatus.udiErrorID := 3005;
	stStatus.xBusy := FALSE;
	xTravelling := FALSE;
END_IF

(* ===== 6. 阀输出：按保位命令持续输出，不是只在动作过程中输出；任何时刻最多一个缸下降 ===== *)
aValve[1] := FALSE; aValve[2] := FALSE; aValve[3] := FALSE;
IF xCmdValid AND xUseReal AND NOT stStatus.xError AND NOT xFaultHold THEN
	aValve[1] := (uiTargetBand = 300);
	aValve[2] := (uiTargetBand = 450);
	aValve[3] := (uiTargetBand = 600);
END_IF
IF xInvertValve THEN
	aValve[1] := NOT aValve[1]; aValve[2] := NOT aValve[2]; aValve[3] := NOT aValve[3];
END_IF

(* ===== 7. 收尾 ===== *)
stStatus.xReady := stStatus.xReady AND xUseReal AND NOT stStatus.xError;
stStatus.xActive := xCmdValid;
(* 气缸组没有回零动作，用「三缸姿态都已确立」代替，供整机统计已接管设备是否可信 *)
stStatus.xHomed := xUseReal AND xPositionKnown;
