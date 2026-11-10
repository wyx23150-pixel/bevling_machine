FUNCTION_BLOCK FB_RealCylinder
(* 模块说明：真实气缸适配层。读取两端到位传感器判定姿态，按统一设备命令驱动单电控阀，
   回写与 FB_SimDevice 完全一致的接收/完成序号，使上层流程与互锁无需区分真假气缸。
   某个端点传感器损坏时用 xExtendByRetract 退让：只看缩回信号，全部消失并稳定后视为伸出到位。 *)
VAR_INPUT
	xUseReal : BOOL; (* TRUE 表示本编号由真实气缸接管；FALSE 时阀保持失电且不响应任何命令。 *)
	xEnable : BOOL; (* 设备级使能，来自整机许可；FALSE 时阀失电并清序号。 *)
	xReset : BOOL; (* 故障复位上升沿；清锁存错误并允许重新建立姿态。 *)
	xSensorRetract : BOOL; (* 缩回到位传感器原始电平，TRUE 表示该端有信号。 *)
	xSensorExtend : BOOL; (* 伸出到位传感器原始电平，TRUE 表示该端有信号。 *)
	xSensorRetract2 : BOOL; (* 第二组（右压板）缩回到位原始电平；仅 xUseSecond 为 TRUE 时参与判定。 *)
	xSensorExtend2 : BOOL; (* 第二组（右压板）伸出到位原始电平；仅 xUseSecond 为 TRUE 时参与判定。 *)
	xUseSecond : BOOL := FALSE; (* TRUE 表示由两个同步执行器组成：两组传感器必须同时到位才算该端到位。 *)
	xExtendByRetract : BOOL := FALSE; (* 退让模式：伸出端传感器不可用时置 TRUE，改用「所有缩回信号都消失」推断伸出到位；默认 FALSE 仍按两端判定。 *)
	tExtendConfirm : TIME := T#1S; (* 仅退让模式有效：缩回信号消失并持续该时间才确认伸出到位，避免气缸刚起步就误判为已伸出。 *)
	xInvertSensors : BOOL; (* TRUE 表示两个传感器接线为低电平有效，本层统一取反，不动上层。 *)
	xInvertValve : BOOL; (* TRUE 表示阀为低电平使能；默认 FALSE，即高电平使能。 *)
	xFaultHold : BOOL := FALSE; (* 整机故障保持：TRUE 时阀立即失电并撤销保位，直到复位。 *)
	tSensorTimeout : TIME := T#3S; (* 两端均无信号达到该时间判为传感器丢失，报 3004；双执行器时也包含两侧不同步。 *)
	tTravelTimeout : TIME := T#10S; (* 命令发出后未到位达到该时间判为动作超时，报 3005。 *)
	stConfig : ST_DeviceConfig; (* 行程范围，语义与仿真侧一致；气缸只使用 0/1 两端。 *)
	stCommand : ST_DeviceCommand; (* 上层统一设备命令，气缸只响应 Position 的 0/1 目标。 *)
END_VAR
VAR_OUTPUT
	stStatus : ST_DeviceStatus; (* 与 FB_SimDevice 语义一致；lrPosition 取 0.0 缩回、1.0 伸出。 *)
	xValve : BOOL; (* 阀电气输出电平，已含 xInvertValve；直接接物理输出点。 *)
	xValve2 : BOOL; (* 第二个执行器的阀电气输出电平；xUseSecond 为 FALSE 时恒为 FALSE。 *)
END_VAR
VAR
	rtReset : R_TRIG; (* 复位上升沿。 *)
	tonNoSensor : TON; (* 两端均无信号的持续计时。 *)
	tonExtendConfirm : TON; (* 退让模式下「缩回信号全部消失」的持续计时，到时才确认伸出到位。 *)
	tonTravel : TON; (* 命令发出后等待到位的计时。 *)
	udiLastID : UDINT; (* 上次已接受的命令序号。 *)
	xSenseRetract : BOOL; (* 取反处理后的缩回信号：双执行器时为两侧 AND，TRUE 表示两侧都缩回到位。 *)
	xRetractAny : BOOL; (* 取反处理后的缩回信号：双执行器时为两侧 OR，TRUE 表示至少一侧仍停在缩回位。退让模式用它判「两侧都离开」。 *)
	xSenseExtend : BOOL; (* 取反处理后的伸出信号。 *)
	xPositionKnown : BOOL; (* 姿态是否已由传感器确立；未确立时 xReady 必须为 FALSE，防止上层把未知当成已缩回。 *)
	lrLastKnown : LREAL; (* 最后一次确立的姿态；传感器全灭时保持该值。 *)
	xCmdValid : BOOL; (* 当前存在有效的保位命令，阀按此持续输出。 *)
	xCmdExtend : BOOL; (* 有效命令期望的端点：TRUE 伸出，FALSE 缩回。 *)
	xTravelling : BOOL; (* 尚未确认到达目标端点。 *)
END_VAR
FUNCTION_BLOCK FB_RealCylinder
rtReset(CLK := xReset);

(* ===== 1. 复位：只清错误与序号，姿态仍由传感器决定 ===== *)
IF xUseReal AND rtReset.Q THEN
	stStatus.xError := FALSE; stStatus.udiErrorID := 0;
	xCmdValid := FALSE; xTravelling := FALSE; udiLastID := 0;
	stStatus.udiAcceptedID := 0; stStatus.udiCompletedID := 0;
	tonNoSensor(IN := FALSE);
	tonTravel(IN := FALSE);
END_IF

(* ===== 2. 传感器取反与姿态判定 ===== *)
xSenseRetract := xSensorRetract XOR xInvertSensors;
xSenseExtend := xSensorExtend XOR xInvertSensors;

(* 双执行器：两组必须同时到位才算该端到位。
   左侧在上、右侧在下时两个都为 FALSE，自然落进下面的“两端都无信号”分支：
   保持上次姿态，持续 tSensorTimeout 才报 3004，与单缸中间态同一套处理。
   同时另算一个 OR 合成量给退让模式用：AND 取反只能得到「至少一侧离开」，
   而退让模式要的是「两侧都离开」，所以必须在合并之前留一份单侧信号。 *)
xRetractAny := xSenseRetract;
IF xUseSecond THEN
	xRetractAny := xRetractAny OR (xSensorRetract2 XOR xInvertSensors);
	xSenseRetract := xSenseRetract AND (xSensorRetract2 XOR xInvertSensors);
	xSenseExtend := xSenseExtend AND (xSensorExtend2 XOR xInvertSensors);
END_IF

(* 退让模式：伸出端传感器不可用，只认缩回信号。
   判定 = 左右两侧都没有缩回信号（都离开缩回位）并持续 tExtendConfirm；
   必须延时确认：缩回信号在气缸刚起步就掉，不延时会在压板还没压下去时就报已伸出，
   上层的压紧判定和自动流程会提前放行。延时期间保持上次姿态。 *)
tonExtendConfirm(IN := xUseReal AND xExtendByRetract AND NOT xRetractAny, PT := tExtendConfirm);
IF xExtendByRetract THEN
	xSenseExtend := tonExtendConfirm.Q;
END_IF

(* 退让模式下「两端都无信号」正是伸出到位的正常表现，不能再按传感器丢失报 3004，所以此模式关闭该计时。 *)
tonNoSensor(IN := xUseReal AND NOT xExtendByRetract AND NOT xSenseRetract AND NOT xSenseExtend, PT := tSensorTimeout);

IF xSenseRetract AND xSenseExtend THEN
	(* 两端同时有信号：传感器短路、磁环位置错或机械卡在中间，姿态不可信 *)
	xPositionKnown := FALSE;
	stStatus.lrPosition := lrLastKnown;
	stStatus.xError := TRUE; stStatus.udiErrorID := 3003;
ELSIF xSenseExtend THEN
	xPositionKnown := TRUE; lrLastKnown := 1.0; stStatus.lrPosition := 1.0;
ELSIF xSenseRetract THEN
	xPositionKnown := TRUE; lrLastKnown := 0.0; stStatus.lrPosition := 0.0;
ELSE
	(* 两端都没有信号：保持最后姿态；从未确立过则 xReady 一直为 FALSE *)
	stStatus.lrPosition := lrLastKnown;
	IF tonNoSensor.Q AND NOT stStatus.xError THEN
		xPositionKnown := FALSE;
		stStatus.xError := TRUE; stStatus.udiErrorID := 3004;
	END_IF
END_IF

(* ===== 3. 命令接收与保位判定 ===== *)
IF NOT xUseReal THEN
	(* 未接管：不驱动阀，也不发布就绪，避免被上层当成可用设备 *)
	xCmdValid := FALSE; xTravelling := FALSE; udiLastID := 0;
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
			IF (stCommand.lrTarget < stConfig.lrMinPosition - 0.01)
				OR (stCommand.lrTarget > stConfig.lrMaxPosition + 0.01) THEN
				stStatus.xError := TRUE; stStatus.udiErrorID := 2001;
				xCmdValid := FALSE;
			ELSE
				xCmdExtend := stCommand.lrTarget > 0.5;
				xCmdValid := TRUE;
				xTravelling := TRUE;
				stStatus.xBusy := TRUE;
			END_IF
		E_DeviceAction.Stop, E_DeviceAction.None:
			xCmdValid := FALSE; xTravelling := FALSE;
			stStatus.udiAcceptedID := 0; stStatus.udiCompletedID := 0;
			udiLastID := 0;
		ELSE
			(* 气缸没有连续运行、点动和回零，明确报错而不是静默不动 *)
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

	(* 到位判定：姿态已知且与命令期望的端点一致即算完成 *)
	IF xCmdValid AND xPositionKnown THEN
		IF (xCmdExtend AND (stStatus.lrPosition > 0.5))
			OR ((NOT xCmdExtend) AND (stStatus.lrPosition < 0.5)) THEN
			IF xTravelling THEN stStatus.udiCompletedID := udiLastID; END_IF
			xTravelling := FALSE;
			stStatus.xBusy := FALSE;
		END_IF
	END_IF
END_IF

(* ===== 4. 到位超时 ===== *)
tonTravel(IN := xUseReal AND xTravelling AND xCmdValid, PT := tTravelTimeout);
IF tonTravel.Q AND NOT stStatus.xError THEN
	stStatus.xError := TRUE; stStatus.udiErrorID := 3005;
	stStatus.xBusy := FALSE;
	xTravelling := FALSE;
END_IF

(* ===== 5. 阀输出：按保位命令持续输出，不是只在动作过程中输出 ===== *)
xValve := FALSE;
xValve2 := FALSE;
IF xCmdValid AND xUseReal AND NOT stStatus.xError AND NOT xFaultHold THEN
	xValve := xCmdExtend;
	IF xUseSecond THEN xValve2 := xCmdExtend; END_IF
END_IF
IF xInvertValve THEN xValve := NOT xValve; END_IF
IF xInvertValve AND xUseSecond THEN xValve2 := NOT xValve2; END_IF

(* ===== 6. 收尾 ===== *)
stStatus.xReady := stStatus.xReady AND xUseReal AND NOT stStatus.xError;
stStatus.xActive := xCmdValid;
(* 气缸没有回零动作，用“姿态已确立”代替，供整机统计已接管设备是否可信 *)
stStatus.xHomed := xUseReal AND xPositionKnown;
