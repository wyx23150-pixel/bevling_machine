(* 模块说明：实体旋钮与按钮的逻辑输入；映射层先处理常开/常闭和极性，不在此处指定物理地址。仿真使用相同格式。 *)
TYPE ST_PanelInputs :
STRUCT
xAutoMode : BOOL; (* 模式旋钮的标准化逻辑值：TRUE 自动，FALSE 手动；不是上位机设定值。 *)
xInitialize : BOOL; (* 初始化请求，上升沿有效；只允许从停止且许可满足时进入。 *)
xStart : BOOL; (* 自动启动请求，上升沿有效；须先初始化到 Ready。 *)
xStop : BOOL; (* 停止事件，兼容保留：远程停止帧仍会写一个扫描；物理停止按钮不走这里。 *)
xResetAlarm : BOOL; (* 报警复位请求，上升沿有效；原因清除后复位，不会自动重新启动。 *)
xRunStart : BOOL; (* 启动按钮原始电平，常开、按下为 TRUE；上升沿在 FB_Machine 内锁存运行态。 *)
xRunStop : BOOL; (* 停止按钮标准化电平：常闭触点已在本层取反，按下为 TRUE；上升沿清除运行态。 *)
END_STRUCT
END_TYPE
