(* 模块说明：软件仿真输入和异常注入。设备索引为 1..17，与 GVL_DeviceIds 一致。 *)
TYPE ST_SimulationSettings :
STRUCT
xSafetyOK : BOOL := TRUE; (* 安全许可接口或仿真许可，TRUE 允许；不等同于安全级急停回路。 *)
xAutoMaterial : BOOL := TRUE; (* TRUE 由仿真模型自动产生到位；FALSE 使用人工料到位输入。 *)
xMaterialSensor : BOOL; (* 手动模拟的光电到位信号，仅在 xAutoMaterial=FALSE 时使用。 *)
tMaterialDelay : TIME := T#1S; (* 满足皮带运行及定长下降条件后，仿真来料的延时时间。 *)
axStall : ARRAY[1..17] OF BOOL; (* 设备卡住注入，索引 1..17；保持忙且不完成，用于观察等待/超时。 *)
axFault : ARRAY[1..17] OF BOOL; (* 设备故障注入，索引 1..17；先清除注入，再执行报警复位。 *)
END_STRUCT
END_TYPE
