(* 模块说明：上位机可选启停请求，不含模式、初始化、复位或连续选择字段。参数通过独立配方接口下发。 *)
TYPE ST_RemoteCommand :
STRUCT
xStart : BOOL; (* 自动启动请求，上升沿有效；须先初始化到 Ready。 *)
xStop : BOOL; (* 普通停止，TRUE 持续有效；取消动作并清除初始化，不能替代硬件急停。 *)
END_STRUCT
END_TYPE

