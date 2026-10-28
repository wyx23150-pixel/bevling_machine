(* 模块说明：定位轴适配入口。当前调用内部仿真；真实轴的 MC 功能块、回原点和限位尚未接入。 *)
FUNCTION_BLOCK FB_Axis
VAR_INPUT
    xSimulation : BOOL; (* TRUE 使用内部仿真；当前 FALSE 报未实现 3001，不会接管真实运动。 *)
    xEnable : BOOL; (* 本功能使能，电平有效；失能时不接受新的动作请求。 *)
    xReset : BOOL; (* 故障复位许可；仿真设备仅在故障注入已撤销时清除错误。 *)
    xStall : BOOL; (* 仿真卡住输入；TRUE 暂停位置推进且不发完成，保留忙状态。 *)
    xInjectFault : BOOL; (* 仿真设备故障输入；TRUE 锁存错误码 9001。 *)
    stConfig : ST_DeviceConfig; (* 设备类型、初始位置、软限位与仿真动作时间。 *)
    stCommand : ST_DeviceCommand; (* 当前单设备命令，含动作类型、序号、目标和速度。 *)
END_VAR
VAR_OUTPUT
    stStatus : ST_DeviceStatus; (* 本模块对外发布的状态；字段含义见其数据类型。 *)
END_VAR
VAR
    fbSimulation : FB_SimDevice; (* 内部设备仿真实例，真实设备适配尚未接入。 *)
END_VAR

(* 真实设备适配尚未接入；关闭仿真时返回 3001，避免误认为已具备实机控制。 *)
fbSimulation(xEnable := xEnable AND xSimulation, xReset := xReset,
    xStall := xStall, xInjectFault := xInjectFault,
    stConfig := stConfig, stCommand := stCommand);
stStatus := fbSimulation.stStatus;
IF NOT xSimulation THEN
    stStatus.xReady := FALSE; stStatus.xBusy := FALSE; stStatus.xActive := FALSE;
    stStatus.xError := TRUE; stStatus.udiErrorID := 3001;
END_IF
