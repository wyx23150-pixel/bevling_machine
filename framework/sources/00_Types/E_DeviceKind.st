(* 模块说明：设备适配类型，由设备管理器选择轴、电机、气缸或阀的执行入口。 *)
{attribute 'qualified_only'}
TYPE E_DeviceKind :
(
    Unused := 0, (* 保留，不调度 *)
    Axis := 1, (* 定位轴 *)
    Motor := 2, (* 连续电机 *)
    Cylinder := 3, (* 两端动作气缸 *)
    Valve := 4 (* 开关阀 *)
);
END_TYPE
