(* 模块说明：设备类型、行程范围和仿真参数。当前工程单位与时间均为仿真示例，尚未完成实机标定。 *)
TYPE ST_DeviceConfig :
STRUCT
eKind : E_DeviceKind; (* 设备类型，决定调用哪一种设备适配功能块。 *)
lrInitialPosition : LREAL; (* 首次进入仿真时的初始位置，不是实机回原点结果。 *)
lrMinPosition : LREAL := -1000.0; (* 示例软行程下限，单位随机构定义。 *)
lrMaxPosition : LREAL := 1000.0; (* 示例软行程上限，单位随机构定义。 *)
lrMaxVelocity : LREAL := 100.0; (* 允许请求的最大速度，用于仿真命令范围检查。 *)
tSimAction : TIME := T#500MS; (* 仿真单次定位/建立运行状态所需时间，不代表实际机械动作时间。 *)
END_STRUCT
END_TYPE

