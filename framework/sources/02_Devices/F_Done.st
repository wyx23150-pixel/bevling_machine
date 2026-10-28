(* 模块说明：只有设备完成序号等于本次命令序号、无忙且无故障，才返回动作完成。 *)
FUNCTION F_Done : BOOL
VAR_INPUT
    stStatus : ST_DeviceStatus; (* 本模块对外发布的状态；字段含义见其数据类型。 *)
    udiID : UDINT; (* 本次命令序号，0 无效；发起新定位时换新序号。 *)
END_VAR

(* 完成必须匹配本次请求；历史 Done 或仅 Busy=FALSE 都不足以作为本步完成条件。 *)
F_Done := (udiID <> 0) AND (stStatus.udiCompletedID = udiID)
    AND NOT stStatus.xBusy AND NOT stStatus.xError;
