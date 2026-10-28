(* 模块说明：切割前避让支线 P：D5 定长升起，再将 D4 移到避让位置。每步等待本次序号完成。 *)
FUNCTION_BLOCK FB_ClearLength
VAR_INPUT
    xExecute : BOOL; (* 子流程执行许可；须保持到完成，清 FALSE 复位该流程步骤和错误。 *)
    stRecipe : ST_Recipe; (* 待校验配方或上层传入的运行配方，字段含义见 ST_Recipe。 *)
END_VAR
VAR_IN_OUT
    aCommand : ARRAY[1..17] OF ST_DeviceCommand; (* 统一设备请求数组 1..17；子流程写请求，设备管理器执行。 *)
    aStatus : ARRAY[1..17] OF ST_DeviceStatus; (* 各设备的反馈数组 1..17，供判断忙、完成序号、故障和位置。 *)
    udiCounter : UDINT; (* 全机共享的动作序号计数器，通过引用传递；由 F_NextID 分配，0 不使用。 *)
END_VAR
VAR_OUTPUT
    xDone : BOOL; (* 本子流程完成标志；执行许可撤销后复位。 *)
    xError : BOOL; (* 本设备或本子流程发生故障；具体原因见对应错误码。 *)
    udiErrorID : UDINT; (* 非法步骤码 4100；动作超时码=4100+uiStep，可据此定位本支线等待点。 *)
    uiStep : UINT; (* 当前子步骤：0 待机，10/20/... 执行动作，1000 完成；切勿在线强制跳步。 *)
END_VAR
VAR
    uiPrevStep : UINT := 65535; (* 上扫描步骤，用于判断本扫描是否刚进入新步骤。 *)
    udiToken : UDINT; (* 本步骤专用动作序号；同一步中的设备共用该号，以排除旧完成信号。 *)
    xEntry : BOOL; (* 本扫描为新步骤入口；用于分配新序号并复位步骤超时计时。 *)
    tonStep : TON; (* 步骤超时定时器；进入新步骤时复位，超时错误码由模块及当前步号组成。 *)
    tonSpray : TON; (* 通用子流程模板的喷油定时器，只有 FB_ReturnKnife 用其完成条件。 *)
END_VAR

(* 执行许可撤销即复位；步骤入口换新序号，每步等待本次动作完成，超时码=模块基码+步号。 *)
IF NOT xExecute THEN uiStep := 0; xError := FALSE; udiErrorID := 0; END_IF;
xEntry := uiStep <> uiPrevStep;
IF xEntry THEN udiToken := F_NextID(udiCounter); END_IF;
uiPrevStep := uiStep;
tonStep(IN := xExecute AND (uiStep > 0) AND (uiStep < 1000) AND NOT xEntry, PT := stRecipe.tStepTimeout);
tonSpray(IN := xExecute AND (uiStep = 10) AND aStatus[13].xActive, PT := stRecipe.tSpray);
IF xExecute AND NOT xError THEN
CASE uiStep OF
0: (* 待机；许可有效时进入首个动作。 *) uiStep := 10;
10: (* P010 定长 D5 升起避让；确认本次动作完成后再允许 D4 平移。 *)
aCommand[5] := F_Command(E_DeviceAction.Position, udiToken, 0.0, stRecipe.lrPositionVelocity);
IF F_Done(aStatus[5], udiToken) THEN uiStep := 20; END_IF;
20: (* P020 定长 D4 移到配方避让位置，等待本次序号完成。 *)
aCommand[4] := F_Command(E_DeviceAction.Position, udiToken, stRecipe.lrLengthClear, stRecipe.lrPositionVelocity);
IF F_Done(aStatus[4], udiToken) THEN uiStep := 1000; END_IF;
1000: (* 本支线完成，保持至 xExecute 撤销。 *) ;
ELSE xError := TRUE; udiErrorID := 4100;
END_CASE;
IF tonStep.Q THEN xError := TRUE; udiErrorID := 4100 + UINT_TO_UDINT(uiStep); END_IF;
END_IF;
xDone := xExecute AND (uiStep = 1000) AND NOT xError;
