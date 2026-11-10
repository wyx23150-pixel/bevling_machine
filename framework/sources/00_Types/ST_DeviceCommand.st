(* 模块说明：上层发给单个设备的请求。定位每次换新序号；连续运行和点动期间保持请求。 *)
TYPE ST_DeviceCommand :
STRUCT
eAction : E_DeviceAction; (* 动作类型：无请求、定位、连续运行、点动或停止，见 E_DeviceAction。 *)
udiID : UDINT; (* 本次命令序号，0 无效；发起新定位时换新序号。 *)
lrTarget : LREAL; (* 目标工程位置；气缸使用约定的 0/1 端点，连续运行和点动不使用该位置。 *)
lrVelocity : LREAL; (* 请求速度，单位随设备工程单位定义；尚未完成实机标定。 *)
END_STRUCT
END_TYPE
