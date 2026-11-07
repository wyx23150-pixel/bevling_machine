(* 模块说明：由本地实体面板解码形成的整机命令。模式取自旋钮，初始化/启动/复位取按钮；运行态由 FB_Machine 锁存。 *)
TYPE ST_OperatorCommand :
STRUCT
eMode : E_MachineMode := E_MachineMode.Manual; (* 本地模式旋钮的当前选择：Manual 手动，Automatic 自动；上位机仅可读取。 *)
xInitialize : BOOL; (* 初始化请求，上升沿有效；只允许从停止且许可满足时进入。 *)
xStart : BOOL; (* 自动启动请求，上升沿有效；须先初始化到 Ready。 *)
xStop : BOOL; (* 停止事件，兼容保留：远程停止帧仍会写一个扫描；物理停止按钮走 xRunStop。 *)
xResetAlarm : BOOL; (* 报警复位请求，上升沿有效；原因清除后复位，不会自动重新启动。 *)
xContinuous : BOOL; (* TRUE 连续循环；FALSE 在当前完整循环结束后回到就绪。 *)
xRunStart : BOOL; (* 启动按钮标准化电平，按一下一次上升沿；FB_Machine 用它的上升沿置运行态。 *)
xRunStop : BOOL; (* 停止按钮标准化电平（常闭已取反），按一下一次上升沿；FB_Machine 用它的上升沿清运行态。 *)
END_STRUCT
END_TYPE
