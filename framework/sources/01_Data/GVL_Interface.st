(* 模块说明：监控与调试接口。stPanel 每周期由面板解码覆盖，不是上位机命令入口；手动请求保留待物理按钮映射。 *)
VAR_GLOBAL
    stPanel : ST_OperatorCommand; (* 本地面板解码结果，只读观察；每周期覆盖，操作请使用实体或仿真面板输入。 *)
    aManual : ARRAY[1..17] OF ST_ManualCommand; (* 各设备手动请求，索引 1..17；进入手动后先释放所有按钮再允许动作。 *)
    stStatus : ST_MachineStatus; (* 本模块对外发布的状态；字段含义见其数据类型。 *)
    aDeviceStatus : ARRAY[1..17] OF ST_DeviceStatus; (* 设备管理器汇总反馈，索引 1..17；供工序判断及在线监控。 *)
END_VAR
