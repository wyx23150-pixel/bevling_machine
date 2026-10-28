(* 模块说明：实体旋钮与按钮的逻辑输入；映射层先处理常开/常闭和极性，不在此处指定物理地址。仿真使用相同格式。 *)
TYPE ST_PanelInputs :
STRUCT
xAutoMode : BOOL; (* 模式旋钮的标准化逻辑值：TRUE 自动，FALSE 手动；不是上位机设定值。 *)
xInitialize : BOOL; (* 初始化请求，上升沿有效；只允许从停止且许可满足时进入。 *)
xStart : BOOL; (* 自动启动请求，上升沿有效；须先初始化到 Ready。 *)
xStop : BOOL; (* 普通停止，TRUE 持续有效；取消动作并清除初始化，不能替代硬件急停。 *)
xResetAlarm : BOOL; (* 报警复位请求，上升沿有效；原因清除后复位，不会自动重新启动。 *)
END_STRUCT
END_TYPE

