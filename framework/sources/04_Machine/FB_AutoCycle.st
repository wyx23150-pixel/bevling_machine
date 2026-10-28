(* 模块说明：自动主状态机。只组织工序并提出请求，设备执行由整机统一调用；送料等料允许长期等待。 *)
FUNCTION_BLOCK FB_AutoCycle
VAR_INPUT
    xRun : BOOL; (* 自动工序运行许可，整机 Automatic 时保持 TRUE；撤销立即复位主流程。 *)
    xContinuous : BOOL; (* TRUE 连续循环；FALSE 在当前完整循环结束后回到就绪。 *)
    xMaterialAtLength : BOOL; (* 定长光电到位状态；自动送料须先离开再到位，并满足 D5 下降。 *)
    stRecipe : ST_Recipe; (* 待校验配方或上层传入的运行配方，字段含义见 ST_Recipe。 *)
END_VAR
VAR_IN_OUT
    aCommand : ARRAY[1..17] OF ST_DeviceCommand; (* 统一设备请求数组 1..17；子流程写请求，设备管理器执行。 *)
    aStatus : ARRAY[1..17] OF ST_DeviceStatus; (* 各设备的反馈数组 1..17，供判断忙、完成序号、故障和位置。 *)
    udiCounter : UDINT; (* 全机共享的动作序号计数器，通过引用传递；由 F_NextID 分配，0 不使用。 *)
END_VAR
VAR_OUTPUT
    eStep : E_AutoStep; (* 自动主工序当前状态，见 E_AutoStep。 *)
    xDone : BOOL; (* 整循环完成的单扫描脉冲；机械手等三路收尾全部结束后才产生。 *)
    xError : BOOL; (* 本设备或本子流程发生故障；具体原因见对应错误码。 *)
    udiErrorID : UDINT; (* 非法主步骤为 4800，主步超时为 4800+枚举值；支线错误则向上传递。 *)
    uiClearLengthStep : UINT; (* 避让支线 P 的当前步骤：10 升起 D5，20 移开 D4，1000 完成。 *)
    uiClearTransferStep : UINT; (* 避让支线 Q 当前步骤：10 降 G4，20 松 G3，30 降 G2，1000 完成。 *)
    uiPostStep : UINT; (* 收尾总步骤：10 抬刀，20 抬压，30 等待三路完成，1000 结束。 *)
    uiReturnKnifeStep : UINT; (* 收尾支线 A：10 喷油，20 D2 回刀，1000 完成。 *)
    uiUnloadStep : UINT; (* 机械手移料支线 B 步骤，10..110 每步加 10，1000 完成；详见 FB_Unload。 *)
    uiResetLengthStep : UINT; (* 收尾支线 C：10 D4 定位，20 D5 下降，30 确认下降，1000 完成。 *)
END_VAR
VAR
    ePrevStep : E_AutoStep := E_AutoStep.Fault; (* 上扫描主工序状态，用于产生步骤入口标志。 *)
    udiToken : UDINT; (* 本步骤专用动作序号；同一步中的设备共用该号，以排除旧完成信号。 *)
    udiSpindleToken : UDINT; (* 盘刀运行命令序号，切割过程中保持该号，避免重复重启盘刀命令。 *)
    xEntry : BOOL; (* 本扫描为新步骤入口；用于分配新序号并复位步骤超时计时。 *)
    xSawSensorClear : BOOL; (* 本轮送料已观察到光电离开；须先有该标志再接受新到位，防止残留信号触发。 *)
    tonStep : TON; (* 步骤超时定时器；进入新步骤时复位，超时错误码由模块及当前步号组成。 *)
    fbClear : FB_ClearanceUnit; (* 切割前两路并行避让流程。 *)
    fbPost : FB_PostCut; (* 切割后抬刀、抬压及三路收尾流程。 *)
END_VAR

(* 完成标志每扫描先清零；本流程在许可撤销后复位，不保留中断点续跑。 *)
xDone := FALSE;
IF NOT xRun THEN eStep:=E_AutoStep.Idle; xError:=FALSE; udiErrorID:=0; xSawSensorClear:=FALSE; END_IF
(* 进入新步骤才换新动作序号，同一步持续保持请求，防止反复启动。 *)
xEntry := eStep <> ePrevStep;
IF xEntry THEN udiToken := F_NextID(udiCounter); END_IF
ePrevStep := eStep;
(* 送料等料不计步骤超时；其余执行步按运行配方监控。 *)
tonStep(IN:=xRun AND NOT xEntry AND (eStep<>E_AutoStep.Idle)
    AND (eStep<>E_AutoStep.FeedWait) AND (eStep<>E_AutoStep.Complete)
    AND (eStep<>E_AutoStep.Fault),PT:=stRecipe.tStepTimeout);
IF xRun AND NOT xError THEN
CASE eStep OF
(* 待机转入送料；没有直接跳到切割。 *)
E_AutoStep.Idle: eStep:=E_AutoStep.FeedWait;
(* D1 送料并正常等料；光电须先离开再到位，且 D5 必须在下降端。 *)
E_AutoStep.FeedWait:
    IF xEntry THEN xSawSensorClear:=FALSE; END_IF
    IF NOT xMaterialAtLength THEN xSawSensorClear:=TRUE; END_IF
    aCommand[1]:=F_Command(E_DeviceAction.Run,udiToken,0.0,stRecipe.lrBeltVelocity);
    IF xSawSensorClear AND xMaterialAtLength AND F_At(aStatus[5],1.0) THEN eStep:=E_AutoStep.StopFeed; END_IF
(* 本步不再给 D1 运行请求，整机周期清空请求后等待皮带非运行、非忙。 *)
E_AutoStep.StopFeed:
    IF NOT aStatus[1].xActive AND NOT aStatus[1].xBusy THEN eStep:=E_AutoStep.Push; END_IF
(* G3 侧推到位；只认本次 udiToken 对应的完成。 *)
E_AutoStep.Push:
    aCommand[11]:=F_Command(E_DeviceAction.Position,udiToken,1.0,stRecipe.lrPositionVelocity);
    IF F_Done(aStatus[11],udiToken) THEN eStep:=E_AutoStep.Clearance; END_IF
(* 并行调用定长避让 P 和输送机构避让 Q，两路都完成后旋转平台。 *)
E_AutoStep.Clearance:
    IF fbClear.xDone THEN eStep:=E_AutoStep.Rotate; END_IF
(* D8 旋转到 lrRotateAngle，必须在 G1 下压之前完成。 *)
E_AutoStep.Rotate:
    aCommand[8]:=F_Command(E_DeviceAction.Position,udiToken,stRecipe.lrRotateAngle,stRecipe.lrPositionVelocity);
    IF F_Done(aStatus[8],udiToken) THEN eStep:=E_AutoStep.PressDown; END_IF
(* G1 下压到位。 *)
E_AutoStep.PressDown:
    aCommand[9]:=F_Command(E_DeviceAction.Position,udiToken,1.0,stRecipe.lrPositionVelocity);
    IF F_Done(aStatus[9],udiToken) THEN eStep:=E_AutoStep.KnifeDown; END_IF
(* G9 盘刀下降到位。 *)
E_AutoStep.KnifeDown:
    aCommand[17]:=F_Command(E_DeviceAction.Position,udiToken,1.0,stRecipe.lrPositionVelocity);
    IF F_Done(aStatus[17],udiToken) THEN eStep:=E_AutoStep.SpindleOn; END_IF
(* D3 盘刀开始旋转，完成序号匹配且运行反馈成立后允许走刀。 *)
E_AutoStep.SpindleOn:
    udiSpindleToken:=udiToken;
    aCommand[3]:=F_Command(E_DeviceAction.Run,udiSpindleToken,0.0,stRecipe.lrSpindleVelocity);
    IF F_Done(aStatus[3],udiSpindleToken) AND aStatus[3].xActive THEN eStep:=E_AutoStep.Cutting; END_IF
(* 保持 D3 运行，G6 吹气，D2 走到回刀起点加切割长度；以 D2 到位作为切割完成。 *)
E_AutoStep.Cutting:
    aCommand[3]:=F_Command(E_DeviceAction.Run,udiSpindleToken,0.0,stRecipe.lrSpindleVelocity);
    aCommand[14]:=F_Command(E_DeviceAction.Run,udiToken,0.0,0.0);
    aCommand[2]:=F_Command(E_DeviceAction.Position,udiToken,stRecipe.lrCutHome+stRecipe.lrCutLength,stRecipe.lrCutVelocity);
    IF F_Done(aStatus[2],udiToken) THEN eStep:=E_AutoStep.StopCut; END_IF
(* 撤销 D3/G6 运行请求，等待盘刀停止且吹气关闭后收尾。 *)
E_AutoStep.StopCut:
    IF NOT aStatus[3].xActive AND NOT aStatus[3].xBusy AND NOT aStatus[14].xActive THEN eStep:=E_AutoStep.PostCut; END_IF
(* 先抬刀再抬压，随后三支线同步执行；全部结束才完成本轮。 *)
E_AutoStep.PostCut:
    IF fbPost.xDone THEN eStep:=E_AutoStep.Complete; END_IF
(* 只在进入本步时输出一次完成脉冲；连续模式返回送料，单循环由整机回到 Ready。 *)
E_AutoStep.Complete:
    xDone:=xEntry;
    IF xContinuous THEN eStep:=E_AutoStep.FeedWait; END_IF
(* 保留流程错误状态；整机退出自动后才复位此流程。 *)
E_AutoStep.Fault: xError:=TRUE;
ELSE xError:=TRUE; udiErrorID:=4800;
END_CASE
IF tonStep.Q THEN xError:=TRUE; udiErrorID:=4800+TO_UDINT(eStep); END_IF
END_IF
(* 子功能块必须每扫描调用，包括失能时复位；上方状态判断看到的是此前反馈。 *)
fbClear(xExecute:=xRun AND (eStep=E_AutoStep.Clearance),stRecipe:=stRecipe,aCommand:=aCommand,aStatus:=aStatus,udiCounter:=udiCounter);
fbPost(xExecute:=xRun AND (eStep=E_AutoStep.PostCut),stRecipe:=stRecipe,aCommand:=aCommand,aStatus:=aStatus,udiCounter:=udiCounter);
(* 任一支线错误向主流程上报；所有设备请求还须经过整机统一互锁。 *)
IF fbClear.xError OR fbPost.xError THEN xError:=TRUE; udiErrorID:=MAX(fbClear.udiErrorID,fbPost.udiErrorID); END_IF
IF xError THEN eStep:=E_AutoStep.Fault; END_IF
uiClearLengthStep:=fbClear.uiLengthStep; uiClearTransferStep:=fbClear.uiTransferStep;
uiPostStep:=fbPost.uiStep; uiReturnKnifeStep:=fbPost.uiKnifeStep;
uiUnloadStep:=fbPost.uiUnloadStep; uiResetLengthStep:=fbPost.uiLengthStep;
