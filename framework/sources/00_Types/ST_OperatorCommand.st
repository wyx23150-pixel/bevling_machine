(* 模块说明：由本地实体面板解码形成的整机命令。模式取自旋钮，初始化/启动/复位取按钮，停止为电平有效。 *)
TYPE ST_OperatorCommand :
STRUCT
eMode : E_MachineMode := E_MachineMode.Manual; (* 本地模式旋钮的当前选择：Manual 手动，Automatic 自动；上位机仅可读取。 *)
xInitialize : BOOL; (* 初始化请求，上升沿有效；只允许从停止且许可满足时进入。 *)
xStart : BOOL; (* 自动启动请求，上升沿有效；须先初始化到 Ready。 *)
xStop : BOOL; (* 普通停止，TRUE 持续有效；取消动作并清除初始化，不能替代硬件急停。 *)
xResetAlarm : BOOL; (* 报警复位请求，上升沿有效；原因清除后复位，不会自动重新启动。 *)
xContinuous : BOOL; (* TRUE 连续循环；FALSE 在当前完整循环结束后回到就绪。 *)
END_STRUCT
END_TYPE

