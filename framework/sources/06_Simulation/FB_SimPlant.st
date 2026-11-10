(* 模块说明：仿真来料模型。皮带运行且定长下降时延时产生一次到位，定长升起或关闭模型后清除。 *)
FUNCTION_BLOCK FB_SimPlant
VAR_INPUT
    xEnable : BOOL; (* 本功能使能，电平有效；失能时不接受新的动作请求。 *)
    stSettings : ST_SimulationSettings; (* 软件仿真参数，含来料方式和异常注入。 *)
    aStatus : ARRAY[1..17] OF ST_DeviceStatus; (* 各设备的反馈数组 1..17，供判断忙、完成序号、故障和位置。 *)
END_VAR
VAR_OUTPUT
    xMaterialAtLength : BOOL; (* 定长光电到位状态；自动送料须先离开再到位，并满足 D5 下降。 *)
END_VAR
VAR
    xLatched : BOOL; (* 本轮仿真料到位保持标志；定长升起或模型失能时清除。 *)
    tonMaterial : TON; (* 自动仿真来料延时，仅在运行皮带且定长下降到位时计时。 *)
END_VAR
FUNCTION_BLOCK FB_SimPlant
(* 定长抬起时清除上次来料；自动方式形成一次延时到位，手动方式直接采用人工传感器。 *)
IF NOT xEnable OR NOT F_At(aStatus[5],1.0) THEN xLatched:=FALSE; END_IF
tonMaterial(IN:=xEnable AND stSettings.xAutoMaterial AND aStatus[1].xActive
    AND F_At(aStatus[5],1.0) AND NOT xLatched,PT:=stSettings.tMaterialDelay);
IF tonMaterial.Q THEN xLatched:=TRUE; END_IF
IF stSettings.xAutoMaterial THEN xMaterialAtLength:=xLatched;
ELSE xMaterialAtLength:=xEnable AND F_At(aStatus[5],1.0) AND stSettings.xMaterialSensor;
END_IF
