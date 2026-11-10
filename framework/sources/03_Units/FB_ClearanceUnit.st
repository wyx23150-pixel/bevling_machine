(* 模块说明：并行执行 P/Q 两路避让；两路都完成才继续，任一路故障向主流程报告。 *)
FUNCTION_BLOCK FB_ClearanceUnit
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
    udiErrorID : UDINT; (* 错误码；0 表示无错误，设备或流程发生异常时赋值。 *)
    uiLengthStep : UINT; (* 定长支线当前步骤，供监控定位等待点。 *)
    uiTransferStep : UINT; (* 流利条/侧推/侧挡支线当前步骤，供监控定位等待点。 *)
END_VAR
VAR
    fbLength : FB_ClearLength; (* P 支线：D5 升起、D4 移开。 *)
    fbTransfer : FB_ClearTransfer; (* 切割前流利条/侧推/侧挡避让支线。 *)
END_VAR
FUNCTION_BLOCK FB_ClearanceUnit
(* P/Q 两路同一扫描使能；xDone 使用 AND，任一路未完成均不得继续。 *)
fbLength(xExecute:=xExecute,stRecipe:=stRecipe,aCommand:=aCommand,aStatus:=aStatus,udiCounter:=udiCounter);
fbTransfer(xExecute:=xExecute,stRecipe:=stRecipe,aCommand:=aCommand,aStatus:=aStatus,udiCounter:=udiCounter);
xDone := fbLength.xDone AND fbTransfer.xDone;
xError := fbLength.xError OR fbTransfer.xError;
udiErrorID := MAX(fbLength.udiErrorID,fbTransfer.udiErrorID);
uiLengthStep := fbLength.uiStep; uiTransferStep := fbTransfer.uiStep;
