(* 模块说明：检查设备可用、无忙无故障且位置误差小于 0.01。它检查位置，不检查本次命令序号。 *)
FUNCTION F_At : BOOL
VAR_INPUT
    stStatus : ST_DeviceStatus; (* 本模块对外发布的状态；字段含义见其数据类型。 *)
    lrTarget : LREAL; (* 要检查的目标位置；误差小于 0.01 且设备就绪、无忙无错时返回 TRUE。 *)
END_VAR
FUNCTION F_At : BOOL
(* 位置容差为 0.01 工程单位；这里不做新命令序号校验，用于姿态/互锁判断。 *)
F_At := stStatus.xReady AND NOT stStatus.xBusy
    AND NOT stStatus.xError AND (ABS(stStatus.lrPosition-lrTarget) < 0.01);
