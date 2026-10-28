(* 模块说明：单个设备的执行反馈。收到命令与完成命令是两个状态，不能只看忙标志判断完成。 *)
TYPE ST_DeviceStatus :
STRUCT
xReady : BOOL; (* 设备已使能且无故障，允许接收命令；不表示动作已经完成。 *)
xBusy : BOOL; (* 当前动作正在执行，定位完成或停止后清除。 *)
xActive : BOOL; (* 连续运行已建立或点动正在进行；定位动作完成后不保持该标志。 *)
xError : BOOL; (* 本设备或本子流程发生故障；具体原因见对应错误码。 *)
udiErrorID : UDINT; (* 错误码；0 表示无错误，设备或流程发生异常时赋值。 *)
udiAcceptedID : UDINT; (* 设备已接收的命令序号，用于区别尚未接收与正在执行。 *)
udiCompletedID : UDINT; (* 设备已完成的命令序号；应与本次 udiID 匹配后再切换步骤。 *)
lrPosition : LREAL; (* 实际或仿真反馈位置；气缸 0/1 的方向见设备编号说明。 *)
END_STRUCT
END_TYPE

