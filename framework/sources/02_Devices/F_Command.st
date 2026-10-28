(* 模块说明：组装设备命令，不执行运动。由设备管理器和对应设备功能块实际处理。 *)
FUNCTION F_Command : ST_DeviceCommand
VAR_INPUT
    eAction : E_DeviceAction; (* 动作类型：无请求、定位、连续运行、点动或停止，见 E_DeviceAction。 *)
    udiID : UDINT; (* 本次命令序号，0 无效；发起新定位时换新序号。 *)
    lrTarget : LREAL; (* 目标工程位置；气缸使用约定的 0/1 端点，连续运行和点动不使用该位置。 *)
    lrVelocity : LREAL; (* 请求速度，单位随设备工程单位定义；尚未完成实机标定。 *)
END_VAR

(* 只复制字段形成结构体，不等待动作、不直接访问物理设备。 *)
F_Command.eAction := eAction;
F_Command.udiID := udiID;
F_Command.lrTarget := lrTarget;
F_Command.lrVelocity := lrVelocity;
