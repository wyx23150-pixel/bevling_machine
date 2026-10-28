(* 模块说明：统一设备执行入口。首次建立类型和初始位置，每扫描周期按类型调用设备功能块并收集反馈。 *)
FUNCTION_BLOCK FB_DeviceManager
VAR_INPUT
    xEnable : BOOL; (* 本功能使能，电平有效；失能时不接受新的动作请求。 *)
    xSimulation : BOOL; (* TRUE 使用内部仿真；当前 FALSE 报未实现 3001，不会接管真实运动。 *)
    xReset : BOOL; (* 故障复位许可；仿真设备仅在故障注入已撤销时清除错误。 *)
    stSim : ST_SimulationSettings; (* 软件仿真设置；设备管理器按设备索引读取卡住与故障注入。 *)
    aCommand : ARRAY[1..17] OF ST_DeviceCommand; (* 统一设备请求数组 1..17；子流程写请求，设备管理器执行。 *)
END_VAR
VAR_OUTPUT
    aStatus : ARRAY[1..17] OF ST_DeviceStatus; (* 各设备的反馈数组 1..17，供判断忙、完成序号、故障和位置。 *)
END_VAR
VAR
    aConfig : ARRAY[1..17] OF ST_DeviceConfig; (* 设备配置数组，首扫描按固定编号设置类型和初始姿态。 *)
    aAxis : ARRAY[1..17] OF FB_Axis; (* 定位轴功能块实例数组，只有设备类型为 Axis 的元素被调用。 *)
    aMotor : ARRAY[1..17] OF FB_Motor; (* 连续电机功能块实例数组，供 D1、D3 使用。 *)
    aCylinder : ARRAY[1..17] OF FB_Cylinder; (* 气缸功能块实例数组，按 G 编号驱动对应仿真实例。 *)
    aValve : ARRAY[1..17] OF FB_Valve; (* 阀功能块实例数组，供 G5 喷油及 G6 吹气使用。 *)
    xBooted : BOOL; (* 本功能块首次初始化完成标志，防止每扫描重写初值。 *)
    i : INT; (* 本扫描数组遍历索引；含义及范围以当前 FOR 循环为准。 *)
END_VAR

(* 只在首扫描建立设备类型和初始位置；D6 保留，G4 初始在提升端，其余位置取配置默认。 *)
IF NOT xBooted THEN
    aConfig[1].eKind := E_DeviceKind.Motor;
    aConfig[2].eKind := E_DeviceKind.Axis;
    aConfig[3].eKind := E_DeviceKind.Motor;
    aConfig[4].eKind := E_DeviceKind.Axis;
    (* D5 暂按定位升降建模：0=升起避让，1=下降检测，非实际机械坐标。 *)
    aConfig[5].eKind := E_DeviceKind.Axis;
    aConfig[7].eKind := E_DeviceKind.Axis;
    aConfig[8].eKind := E_DeviceKind.Axis;
    FOR i := 9 TO 17 DO aConfig[i].eKind := E_DeviceKind.Cylinder; END_FOR
    aConfig[13].eKind := E_DeviceKind.Valve;
    aConfig[14].eKind := E_DeviceKind.Valve;
    aConfig[12].lrInitialPosition := 1.0;
    FOR i := 1 TO 17 DO
        IF aConfig[i].eKind = E_DeviceKind.Cylinder THEN
            aConfig[i].lrMinPosition := 0.0; aConfig[i].lrMaxPosition := 1.0;
        END_IF
    END_FOR
    xBooted := TRUE;
END_IF
(* 每周期按设备类型只选择一种执行入口，再将反馈回填同一编号。 *)
FOR i := 1 TO 17 DO
    CASE aConfig[i].eKind OF
    E_DeviceKind.Axis:
        aAxis[i](xSimulation:=xSimulation,xEnable:=xEnable,xReset:=xReset,
            xStall:=stSim.axStall[i],xInjectFault:=stSim.axFault[i],stConfig:=aConfig[i],stCommand:=aCommand[i]);
        aStatus[i] := aAxis[i].stStatus;
    E_DeviceKind.Motor:
        aMotor[i](xSimulation:=xSimulation,xEnable:=xEnable,xReset:=xReset,
            xStall:=stSim.axStall[i],xInjectFault:=stSim.axFault[i],stConfig:=aConfig[i],stCommand:=aCommand[i]);
        aStatus[i] := aMotor[i].stStatus;
    E_DeviceKind.Cylinder:
        aCylinder[i](xSimulation:=xSimulation,xEnable:=xEnable,xReset:=xReset,
            xStall:=stSim.axStall[i],xInjectFault:=stSim.axFault[i],stConfig:=aConfig[i],stCommand:=aCommand[i]);
        aStatus[i] := aCylinder[i].stStatus;
    E_DeviceKind.Valve:
        aValve[i](xSimulation:=xSimulation,xEnable:=xEnable,xReset:=xReset,
            xStall:=stSim.axStall[i],xInjectFault:=stSim.axFault[i],stConfig:=aConfig[i],stCommand:=aCommand[i]);
        aStatus[i] := aValve[i].stStatus;
    END_CASE
END_FOR
