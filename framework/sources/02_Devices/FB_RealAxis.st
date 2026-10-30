(* 模块说明：真实轴适配层。把统一设备命令翻译成 SoftMotion 动作，并回写与仿真完全一致的接收/完成序号。 *)
FUNCTION_BLOCK FB_RealAxis
VAR_IN_OUT
	Axis : AXIS_REF_SM3; (* 轴节点引用，编译期强制绑定；未接轴无法通过编译，不存在空指针。 *)
END_VAR
VAR_INPUT
	xUseReal : BOOL; (* TRUE 表示本编号由本功能块接管；FALSE 时驱动器保持去使能且不响应任何命令。 *)
	xEnable : BOOL; (* 设备级使能，来自整机许可；FALSE 时主动停止并清序号。 *)
	xReset : BOOL; (* 故障复位，上升沿清锁存错误与 MC 错误。 *)
	stConfig : ST_DeviceConfig; (* 行程、速度、加减速与绝对定位许可。 *)
	stCommand : ST_DeviceCommand; (* 上层统一设备命令，含义与仿真侧完全一致。 *)
	stReal : ST_RealDeviceSettings; (* 相对验证距离、速度与旁路设置。 *)
END_VAR
VAR_OUTPUT
	stStatus : ST_DeviceStatus; (* 与 FB_SimDevice 语义一致，上层无需区分真假设备。 *)
	uiVerifyPhase : UINT; (* 相对验证相位：0 空闲、1 正向、2 停留、3 反向、4 完成、90 中止。 *)
	lrVerifyMeasured : LREAL; (* 本次往返正向段的实测位移，取自轴反馈。 *)
	lrVerifyRatio : LREAL; (* 实测除以指令；只能证明指令与反馈自洽，不能证明单位就是毫米。 *)
END_VAR
VAR
	fbPower : MC_Power; (* 伺服使能，接管期间保持上电。 *)
	fbReset : MC_Reset; (* 清 MC 错误。 *)
	fbStop : MC_Stop; (* 受控停止，停止请求需保持到 Done。 *)
	fbMoveAbs : MC_MoveAbsolute; (* 绝对定位，仅在 xAbsoluteAllowed 为 TRUE 时使用。 *)
	fbMoveRel : MC_MoveRelative; (* 相对定位，验证模式的两段行程使用。 *)
	fbMoveVel : MC_MoveVelocity; (* 连续运行与点动共用，两者相位互斥；方向必须显式给出。 *)
	fbHoming : CmpHCMotion.MC_Homing; (* 上位机回零：由 PLC 自己按轴配置的回零方式走，不依赖驱动器支持 DS402 回零。 *)
	fbReadPos : MC_ReadActualPosition; (* 实际位置反馈。 *)
	fbReadStatus : MC_ReadStatus; (* 轴状态，用于判断故障停止。 *)
	fbReadErr : MC_ReadAxisError; (* 轴错误码，供在线排查。 *)
	rtReset : R_TRIG; (* 复位上升沿。 *)
	tonEnable : TON; (* 命令已接收但轴未使能的 3 秒超时。 *)
	tonDwell : TON; (* 验证往返之间的停留，保证 Execute 拉低形成新上升沿。 *)
	tonHome : TON; (* 回零超时；找不到原点时按 2004 暴露，避免无限等待。 *)
	udiLastID : UDINT; (* 上次已接受序号，用于识别新命令。 *)
	udiActiveID : UDINT; (* 正在执行的序号，完成时回写。 *)
	xPending : BOOL; (* 已接收但尚未启动，等待轴使能。 *)
	xStopLatch : BOOL; (* 停止请求锁存，保持到 MC_Stop 完成。 *)
	xStopReq : BOOL; (* 本扫描停止请求。 *)
	xMoveAbsReq : BOOL; (* 本扫描绝对定位请求。 *)
	xMoveRelReq : BOOL; (* 本扫描相对定位请求。 *)
	xMoveVelReq : BOOL; (* 本扫描速度模式请求，连续运行与点动共用。 *)
	xHomeReq : BOOL; (* 本扫描回零请求，保持到 Done。 *)
	xHomed : BOOL; (* 本次上电后已成功回零；成功后允许绝对定位，断电或重新下载后清零。 *)
	uiPhase : UINT; (* 动作相位：0 空闲、10 等待使能、20 绝对、30/31/32 验证三段、40 连续、50 点动、60 回零、90 中止。 *)
	lrVerifyStart : LREAL; (* 验证正向段起点位置。 *)
	lrRelDistance : LREAL; (* 本次相对定位距离，正负决定方向。 *)
	lrRelVelocity : LREAL; (* 本次相对定位速度，取正值。 *)
	lrCmdVelocity : LREAL; (* 连续运行与点动的限幅后速度，带符号。 *)
END_VAR

(* ===== 1. 读取块无条件调用，保证反馈新鲜 ===== *)
fbReadPos(Axis := Axis, Enable := TRUE);
fbReadStatus(Axis := Axis, Enable := TRUE);
fbReadErr(Axis := Axis, Enable := TRUE);
rtReset(CLK := xReset);

stStatus.lrPosition := fbReadPos.Position;
stStatus.xRealActive := xUseReal;

(* ===== 2. 复位：只在接管状态下响应，避免误清其它轴 ===== *)
IF xUseReal AND rtReset.Q THEN
	stStatus.xError := FALSE;
	stStatus.udiErrorID := 0;
	xStopLatch := FALSE;
	xPending := FALSE;
	uiPhase := 0;
	uiVerifyPhase := 0;
	udiLastID := 0;
	udiActiveID := 0;
	stStatus.udiAcceptedID := 0;
	stStatus.udiCompletedID := 0;
	stStatus.xBusy := FALSE;
	stStatus.xActive := FALSE;
END_IF

(* ===== 3. 定时器：用上扫描状态驱动，避免与状态判定循环依赖 ===== *)
tonEnable(IN := xPending AND xUseReal, PT := T#3S);
tonDwell(IN := (uiPhase = 31), PT := stReal.tVerifyDwell);
tonHome(IN := (uiPhase = 60), PT := stReal.tHomeTimeout);

(* ===== 4. 请求默认全部撤销 ===== *)
xStopReq := FALSE;
xMoveAbsReq := FALSE;
xMoveRelReq := FALSE;
xMoveVelReq := FALSE;
xHomeReq := FALSE;
lrRelDistance := 0.0;
lrRelVelocity := 0.0;
lrCmdVelocity := 0.0;

(* ===== 5. 主状态判定 ===== *)
IF NOT xUseReal THEN
	(* 未接管：不产生任何运动请求，驱动器由 MC_Power 去使能。 *)
	xPending := FALSE; xStopLatch := FALSE;
	uiPhase := 0; uiVerifyPhase := 0;
	udiLastID := 0; udiActiveID := 0;
	stStatus.xReady := FALSE;
	stStatus.xBusy := FALSE; stStatus.xActive := FALSE;
	stStatus.udiAcceptedID := 0; stStatus.udiCompletedID := 0;
	stStatus.xError := FALSE; stStatus.udiErrorID := 0;
ELSE
	(* --- 5.1 接收新序号：新序号就是新命令，不用边沿检测 --- *)
	IF (stCommand.udiID <> 0) AND (stCommand.udiID <> udiLastID)
		AND xEnable AND NOT stStatus.xError THEN
		udiLastID := stCommand.udiID;
		udiActiveID := udiLastID;
		stStatus.udiAcceptedID := udiActiveID;
		stStatus.udiCompletedID := 0;
		stStatus.xBusy := TRUE; stStatus.xActive := FALSE;
		uiVerifyPhase := 0;
		xPending := TRUE;
		uiPhase := 10;
		xStopLatch := FALSE;
	END_IF

	(* --- 5.2 停止请求锁存：保持到 MC_Stop 完成，不能提前撤 Execute --- *)
	IF (stCommand.eAction = E_DeviceAction.Stop) OR (NOT xEnable) THEN
		(* 只在真的有动作时才锁存，避免 Stop 常驻时每扫描重复触发 MC_Stop。 *)
		IF xPending OR (uiPhase <> 0) THEN xStopLatch := TRUE; END_IF
	ELSIF (stCommand.eAction = E_DeviceAction.None) AND (uiPhase <> 0) THEN
		xStopLatch := TRUE;
	END_IF
	IF fbStop.Done THEN xStopLatch := FALSE; END_IF

	IF xStopLatch THEN
		xStopReq := TRUE;
		xPending := FALSE;
		uiPhase := 0; uiVerifyPhase := 0;
		udiLastID := 0; udiActiveID := 0;
		stStatus.udiAcceptedID := 0; stStatus.udiCompletedID := 0;
		stStatus.xBusy := FALSE; stStatus.xActive := FALSE;
	ELSIF xPending THEN
		(* --- 5.3 等轴使能；就绪后按动作类型进入相位，3 秒未使能报 2003 --- *)
		IF fbPower.Status THEN
			xPending := FALSE;
			CASE stCommand.eAction OF
			E_DeviceAction.Position:
				(* 已回零优先走绝对定位：相对验证只是未回零时的临时替代，回零成功后不再需要。 *)
				IF xHomed OR stConfig.xAbsoluteAllowed THEN
					uiPhase := 20;
				ELSIF stReal.xRelativeVerify THEN
					lrVerifyStart := fbReadPos.Position;
					uiPhase := 30; uiVerifyPhase := 1;
				ELSE
					(* 未回零不允许绝对定位：报 2002 且不置完成位，由上层按步号超时暴露。 *)
					stStatus.xError := TRUE; stStatus.udiErrorID := 2002;
					uiPhase := 0; uiVerifyPhase := 0;
				END_IF
			E_DeviceAction.Run:
				uiPhase := 40;
			E_DeviceAction.Jog:
				uiPhase := 50;
			E_DeviceAction.Home:
				uiPhase := 60;
			ELSE
				uiPhase := 0;
			END_CASE
		ELSIF tonEnable.Q THEN
			xPending := FALSE; uiPhase := 0;
			stStatus.xError := TRUE; stStatus.udiErrorID := 2003;
			stStatus.xBusy := FALSE;
		END_IF
	END_IF

	(* --- 5.4 按相位生成限幅后的运动参数 --- *)
	CASE uiPhase OF
	30:
		lrRelDistance := LIMIT(0.0, stReal.lrVerifyDistance, 20.0);
		lrRelVelocity := LIMIT(0.01, stReal.lrVerifyVelocity, stConfig.lrMaxVelocity);
	32:
		lrRelDistance := -LIMIT(0.0, stReal.lrVerifyDistance, 20.0);
		lrRelVelocity := LIMIT(0.01, stReal.lrVerifyVelocity, stConfig.lrMaxVelocity);
	40:
		(* 连续运行：按设备配置限幅，不使用验证低速。 *)
		lrCmdVelocity := LIMIT(-stConfig.lrMaxVelocity, stCommand.lrVelocity, stConfig.lrMaxVelocity);
	50:
		(* 点动：额外用验证速度作为上限，防止手动全速冲出去。 *)
		lrCmdVelocity := LIMIT(0.01, ABS(stCommand.lrVelocity),
			MIN(stConfig.lrMaxVelocity, stReal.lrVerifyVelocity));
		IF stCommand.lrVelocity < 0.0 THEN lrCmdVelocity := -lrCmdVelocity; END_IF
	END_CASE

	xMoveAbsReq := (uiPhase = 20);
	xMoveRelReq := (uiPhase = 30) OR (uiPhase = 32);
	xMoveVelReq := (uiPhase = 40) OR (uiPhase = 50);
	xHomeReq := (uiPhase = 60);
END_IF

(* ===== 6. MC 块无条件调用：漏调用会报 SMC_FB_WASNT_CALLED_DURING_MOTION ===== *)
fbPower(Axis := Axis, Enable := xUseReal AND xEnable,
	bRegulatorOn := xUseReal AND xEnable, bDriveStart := xUseReal AND xEnable);
fbReset(Axis := Axis, Execute := xUseReal AND rtReset.Q);
fbStop(Axis := Axis, Execute := xStopReq, Deceleration := stConfig.lrMaxDeceleration);
fbMoveRel(Axis := Axis, Execute := xMoveRelReq, Distance := lrRelDistance,
	Velocity := lrRelVelocity, Acceleration := stConfig.lrMaxAcceleration,
	Deceleration := stConfig.lrMaxDeceleration);
fbMoveAbs(Axis := Axis, Execute := xMoveAbsReq, Position := stCommand.lrTarget,
	Velocity := LIMIT(0.01, ABS(stCommand.lrVelocity), stConfig.lrMaxVelocity),
	Acceleration := stConfig.lrMaxAcceleration, Deceleration := stConfig.lrMaxDeceleration);
fbMoveVel(Axis := Axis, Execute := xMoveVelReq,
	Velocity := ABS(lrCmdVelocity),
	Direction := SEL(lrCmdVelocity < 0.0, MC_Direction.positive, MC_Direction.negative),
	Acceleration := stConfig.lrMaxAcceleration,
	Deceleration := stConfig.lrMaxDeceleration);
(* 回零走 MC_Homing（上位机回零）：回零方式、开始方向、零点信号、快慢速全部来自轴配置，
   本块只给 Axis 和 Execute。驱动器不支持 DS402 回零，用 MC_Home 会一直卡在 Homing 状态不动。 *)
fbHoming(Axis := Axis, Execute := xHomeReq);

(* ===== 7. 完成判定与序号回写 ===== *)
IF xUseReal THEN
	CASE uiPhase OF
	20:
		IF fbMoveAbs.Done THEN
			stStatus.udiCompletedID := udiActiveID;
			stStatus.xBusy := FALSE; stStatus.xActive := FALSE;
			uiPhase := 0;
		ELSIF fbMoveAbs.CommandAborted THEN
			stStatus.xBusy := FALSE; uiPhase := 0;
		END_IF
	30:
		IF fbMoveRel.Done THEN
			lrVerifyMeasured := fbReadPos.Position - lrVerifyStart;
			uiPhase := 31; uiVerifyPhase := 2;
		ELSIF fbMoveRel.CommandAborted THEN
			uiPhase := 90; uiVerifyPhase := 90;
			stStatus.xError := TRUE; stStatus.udiErrorID := 2005;
			stStatus.xBusy := FALSE;
		END_IF
	31:
		IF tonDwell.Q THEN
			uiPhase := 32; uiVerifyPhase := 3;
		END_IF
	32:
		IF fbMoveRel.Done THEN
			IF stReal.lrVerifyDistance > 0.001 THEN
				lrVerifyRatio := lrVerifyMeasured / stReal.lrVerifyDistance;
			END_IF
			uiPhase := 0; uiVerifyPhase := 4;
			stStatus.udiCompletedID := udiActiveID;
			stStatus.xBusy := FALSE; stStatus.xActive := FALSE;
		ELSIF fbMoveRel.CommandAborted THEN
			uiPhase := 90; uiVerifyPhase := 90;
			stStatus.xError := TRUE; stStatus.udiErrorID := 2005;
			stStatus.xBusy := FALSE;
		END_IF
	40:
		(* 连续运行：建立速度后回写完成位，但保持相位直到命令改变。 *)
		IF fbMoveVel.InVelocity THEN
			stStatus.xActive := TRUE;
			stStatus.xBusy := FALSE;
			stStatus.udiCompletedID := udiActiveID;
		END_IF
	50:
		(* 点动：与仿真一致，不置完成位，靠松开后的 None/Stop 停止。 *)
		stStatus.xActive := fbMoveVel.InVelocity;
		stStatus.xBusy := TRUE;
	60:
		(* 回零：Done 后置 xHomed 并放行绝对定位；超时报 2004 且不置完成位，避免上层误判已到位。 *)
		IF fbHoming.Done THEN
			xHomed := TRUE;
			stStatus.udiCompletedID := udiActiveID;
			stStatus.xBusy := FALSE; stStatus.xActive := FALSE;
			uiPhase := 0;
		ELSIF fbHoming.CommandAborted THEN
			(* 被其它运动块打断：只清忙标志退出相位，既不置完成位也不置故障，由上层按步号超时暴露。 *)
			stStatus.xBusy := FALSE; uiPhase := 0;
		ELSIF tonHome.Q THEN
			xHomed := FALSE;
			stStatus.xError := TRUE; stStatus.udiErrorID := 2004;
			stStatus.xBusy := FALSE; uiPhase := 0;
		END_IF
	END_CASE

	(* --- MC 错误汇总：只锁存第一条，40000 为前缀，低 16 位保留原码便于查手册 --- *)
	IF NOT stStatus.xError THEN
		IF fbPower.Error THEN
			stStatus.xError := TRUE; stStatus.udiErrorID := UDINT#40000 + TO_UDINT(fbPower.ErrorID);
		ELSIF fbReset.Error THEN
			stStatus.xError := TRUE; stStatus.udiErrorID := UDINT#40000 + TO_UDINT(fbReset.ErrorID);
		ELSIF fbStop.Error THEN
			stStatus.xError := TRUE; stStatus.udiErrorID := UDINT#40000 + TO_UDINT(fbStop.ErrorID);
		ELSIF fbMoveRel.Error THEN
			stStatus.xError := TRUE; stStatus.udiErrorID := UDINT#40000 + TO_UDINT(fbMoveRel.ErrorID);
		ELSIF fbMoveAbs.Error THEN
			stStatus.xError := TRUE; stStatus.udiErrorID := UDINT#40000 + TO_UDINT(fbMoveAbs.ErrorID);
		ELSIF fbMoveVel.Error THEN
			stStatus.xError := TRUE; stStatus.udiErrorID := UDINT#40000 + TO_UDINT(fbMoveVel.ErrorID);
		ELSIF fbHoming.Error THEN
			stStatus.xError := TRUE; stStatus.udiErrorID := UDINT#40000 + TO_UDINT(fbHoming.ErrorID);
		END_IF
	END_IF
END_IF

(* ===== 8. 就绪与故障收尾 ===== *)
stStatus.xReady := xUseReal AND xEnable AND NOT stStatus.xError;
stStatus.xHomed := xUseReal AND xHomed;
IF stStatus.xError THEN
	stStatus.xBusy := FALSE;
	stStatus.xActive := FALSE;
END_IF
