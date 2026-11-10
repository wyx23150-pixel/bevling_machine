FUNCTION_BLOCK FB_RealSensor
(* 模块说明：真实传感器（光电/接近开关）只读适配层。本块不驱动任何输出，只把原始电平
   去抖后发布成「到位」状态，使上层（自动送料判断、互锁、诊断）与仿真设备使用同一套接口。
   按料型/来料判断的是「有没有件」而不是「走到哪个位置」，所以姿态只有 0.0 / 1.0 两端：
   1.0 = 有料（光电被遮挡），0.0 = 无料。连续位置对传感器没有意义。 *)
VAR_INPUT
	xUseReal : BOOL; (* TRUE 表示本编号由真实传感器接管；FALSE 时不读物理点，也不发布就绪。 *)
	xEnable : BOOL; (* 设备级使能，来自整机许可；FALSE 时状态复位为无料且不发布就绪。 *)
	xReset : BOOL; (* 故障复位上升沿；清锁存错误。 *)
	xSensorRaw : BOOL; (* 传感器原始电平，TRUE 表示被遮挡（有料）。 *)
	xInvertSensor : BOOL; (* TRUE 表示接线为低电平有效（遮挡时读 FALSE），本层统一取反，不动上层。 *)
	tDebounce : TIME := T#20MS; (* 去抖时间：光电受粉尘、振动、反光影响会抖，短于该时间的跳变忽略。 *)
	tStuckTimeout : TIME := T#0MS; (* 常亮/常灭监视；0 表示不监视。料走完仍长时间有信号通常代表传感器卡死或反光。 *)
	stConfig : ST_DeviceConfig; (* 与其它设备一致的配置结构；传感器只用 lrInitialPosition 作初值，不使用行程字段。 *)
	stCommand : ST_DeviceCommand; (* 上层统一设备命令；传感器只响应被读请求，Position 目标被忽略。 *)
END_VAR
VAR_OUTPUT
	stStatus : ST_DeviceStatus; (* 与仿真侧语义一致；lrPosition 取 1.0 有料、0.0 无料。 *)
	xDetected : BOOL; (* 去抖后的最终信号，TRUE=有料。流程与互锁直接取用这个而不是原始点。 *)
	xRaw : BOOL; (* 取反处理后的原始电平（未去抖），供在线排查接线极性与抖动。 *)
END_VAR
VAR
	rtReset : R_TRIG; (* 复位上升沿。 *)
	tonDebounce : TON; (* 由 FALSE 变 TRUE 的去抖计时，到时才认「有料」。 *)
	tonClear : TON; (* 由 TRUE 变 FALSE 的去抖计时，到时才认「无料」。 *)
	tonStuck : TON; (* 长时间保持同一状态计时，用于常亮/常灭监视。 *)
	xStuckWindowClear : BOOL; (* 本扫描检测到电平跳变：清掉常亮/常灭计时窗口，重新开始计时。 *)
	xStable : BOOL; (* 去抖后的稳定值。 *)
	xLastRaw : BOOL; (* 上扫描取反后的原始电平，用于判断是否发生跳变并重置去抖计时。 *)
	xBooted : BOOL; (* 首次扫描标志，上电时直接用当前电平作初值，不等待去抖。 *)
END_VAR
FUNCTION_BLOCK FB_RealSensor
rtReset(CLK := xReset);

(* ===== 1. 复位：只清错误，状态仍由传感器决定 ===== *)
IF xUseReal AND rtReset.Q THEN
	stStatus.xError := FALSE; stStatus.udiErrorID := 0;
	tonStuck(IN := FALSE);
END_IF

(* ===== 2. 极性处理：接线反了只改 xInvertSensor 一个参数，上层不受影响 ===== *)
xRaw := xSensorRaw XOR xInvertSensor;

(* ===== 3. 去抖：跳变后必须稳定 tDebounce 才改 xStable ===== *)
(* 用两个单稳计时而不是一个沿检测，是为了让"抖动期间保持上次稳定值"这件事显式可见：
   信号连续抖动时两个计时都不会到时，xStable 保持在最后一个稳定值上。 *)
xStuckWindowClear := (NOT xBooted) OR (xRaw <> xLastRaw);
IF xStuckWindowClear THEN
	tonDebounce(IN := FALSE);
	tonClear(IN := FALSE);
	IF NOT xBooted THEN
		(* 上电直接用当前电平作初值，避免开机 20ms 内把有料当无料 *)
		xStable := xRaw;
		xBooted := TRUE;
	END_IF
	xLastRaw := xRaw;
END_IF

IF xUseReal THEN
	IF xRaw THEN
		tonDebounce(IN := TRUE, PT := tDebounce);
		tonClear(IN := FALSE);
		IF tonDebounce.Q THEN xStable := TRUE; END_IF
	ELSE
		tonClear(IN := TRUE, PT := tDebounce);
		tonDebounce(IN := FALSE);
		IF tonClear.Q THEN xStable := FALSE; END_IF
	END_IF
END_IF

xDetected := xStable;

(* ===== 4. 常亮/常灭监视：料已走完却一直有信号，或本该有料却一直没有，都报出来 =====
   只监视"信号纹丝不动"这个可观测事实，不猜业务含义；阈值由 tStuckTimeout 给，0 表示关闭。 *)
tonStuck(IN := xUseReal AND (tStuckTimeout > T#0MS) AND NOT xStuckWindowClear, PT := tStuckTimeout);
IF tonStuck.Q AND NOT stStatus.xError THEN
	stStatus.xError := TRUE;
	(* 3006：持续有信号（常亮/反光/卡死）；3007：持续无信号（断线/被挡/未接通） *)
	IF xDetected THEN stStatus.udiErrorID := 3006;
	ELSE stStatus.udiErrorID := 3007; END_IF
END_IF

(* ===== 5. 状态发布：传感器没有动作请求，只要接管且使能就算就绪 ===== *)
stStatus.lrPosition := SEL(xDetected, 0.0, 1.0);
stStatus.xReady := xUseReal AND xEnable AND NOT stStatus.xError;
stStatus.xActive := xUseReal AND xDetected;
stStatus.xBusy := FALSE;
(* 传感器没有回零概念，用"已接管且状态可信"代替 *)
stStatus.xHomed := xUseReal AND xBooted;
stStatus.xRealActive := xUseReal;
