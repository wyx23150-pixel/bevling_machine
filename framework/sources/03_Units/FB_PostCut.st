(* 模块说明：切割后先 G9 抬刀，再 G1 抬压；之后同时执行回刀、机械手移料、定长复位，三路全完成才结束。 *)
FUNCTION_BLOCK FB_PostCut
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
    udiErrorID : UDINT; (* 非法总步骤为 4700，超时为 4700+总步号；支线故障则向上传递支线错误码。 *)
    uiStep : UINT; (* 当前子步骤：0 待机，10/20/... 执行动作，1000 完成；切勿在线强制跳步。 *)
    uiKnifeStep : UINT; (* 收尾回刀支线 A 当前步骤：喷油、回刀或完成。 *)
    uiUnloadStep : UINT; (* 机械手移料支线 B 步骤，10..110 每步加 10，1000 完成；详见 FB_Unload。 *)
    uiLengthStep : UINT; (* 定长支线当前步骤，供监控定位等待点。 *)
END_VAR
VAR
    fbKnife : FB_ReturnKnife; (* 收尾支线 A：喷油后回刀。 *)
    fbUnload : FB_Unload; (* 收尾支线 B：机械手移料，含后退、下降、最终回位。 *)
    fbLength : FB_ResetLength; (* C 支线：D4 回检测位置、D5 下降、确认下降到位。 *)
    uiPrevStep : UINT := 65535; (* 上扫描步骤，用于判断本扫描是否刚进入新步骤。 *)
    udiToken : UDINT; (* 本步骤专用动作序号；同一步中的设备共用该号，以排除旧完成信号。 *)
    xEntry : BOOL; (* 本扫描为新步骤入口；用于分配新序号并复位步骤超时计时。 *)
    tonStep : TON; (* 步骤超时定时器；进入新步骤时复位，超时错误码由模块及当前步号组成。 *)
END_VAR
FUNCTION_BLOCK FB_PostCut
IF NOT xExecute THEN uiStep := 0; xError := FALSE; udiErrorID := 0; END_IF
(* 每个总步骤分配新序号；等待三路期间保留总步骤超时。 *)
xEntry := uiStep <> uiPrevStep;
IF xEntry THEN udiToken := F_NextID(udiCounter); END_IF
uiPrevStep := uiStep;
tonStep(IN:=xExecute AND NOT xEntry AND (uiStep>0) AND (uiStep<1000),PT:=stRecipe.tStepTimeout);
IF xExecute AND NOT xError THEN
    CASE uiStep OF
    0: (* 待机，执行许可有效后进入抬刀。 *) uiStep := 10;
    10: (* 先 G9 盘刀提升；同时保持 G1 下压，刀没抬起来之前不能松压板。 *)
        aCommand[9] := F_Command(E_DeviceAction.Position,udiToken,1.0,stRecipe.lrPositionVelocity);
        aCommand[17] := F_Command(E_DeviceAction.Position,udiToken,0.0,stRecipe.lrPositionVelocity);
        IF F_Done(aStatus[17],udiToken) THEN uiStep := 20; END_IF
    20: (* 再 G1 下压提升，等待本次序号完成。 *)
        aCommand[9] := F_Command(E_DeviceAction.Position,udiToken,0.0,stRecipe.lrPositionVelocity);
        IF F_Done(aStatus[9],udiToken) THEN uiStep := 30; END_IF
    30: (* 等待回刀、机械手移料、定长复位三路全部完成。 *)
        IF fbKnife.xDone AND fbUnload.xDone AND fbLength.xDone THEN uiStep := 1000; END_IF
    1000: (* 三路收尾结束，保持完成反馈直到执行许可撤销。 *) ;
    ELSE xError := TRUE; udiErrorID := 4700;
    END_CASE
    IF tonStep.Q THEN xError := TRUE; udiErrorID := 4700+UINT_TO_UDINT(uiStep); END_IF
END_IF
(* 三路只在总步骤 30 同时使能，并且每扫描调用；等待三路全完成才退出。 *)
fbKnife(xExecute:=xExecute AND (uiStep=30),stRecipe:=stRecipe,aCommand:=aCommand,aStatus:=aStatus,udiCounter:=udiCounter);
fbUnload(xExecute:=xExecute AND (uiStep=30),stRecipe:=stRecipe,aCommand:=aCommand,aStatus:=aStatus,udiCounter:=udiCounter);
fbLength(xExecute:=xExecute AND (uiStep=30),stRecipe:=stRecipe,aCommand:=aCommand,aStatus:=aStatus,udiCounter:=udiCounter);
IF fbKnife.xError OR fbUnload.xError OR fbLength.xError THEN
    xError:=TRUE; udiErrorID:=MAX(fbKnife.udiErrorID,MAX(fbUnload.udiErrorID,fbLength.udiErrorID));
END_IF
xDone := xExecute AND (uiStep=1000) AND NOT xError;
uiKnifeStep:=fbKnife.uiStep; uiUnloadStep:=fbUnload.uiStep; uiLengthStep:=fbLength.uiStep;
