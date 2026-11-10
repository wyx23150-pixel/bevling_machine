(* 模块说明：安全许可软件旁路的唯一判定点。两级开关同时置位才返回 TRUE。 *)
FUNCTION F_SafetyBypassActive : BOOL
VAR_IN_OUT
	stReal : ST_RealDeviceSettings; (* 引用传递，避免每次扫描拷贝整个设置结构体。 *)
END_VAR
FUNCTION F_SafetyBypassActive : BOOL
(* 一级开关与二级确认必须同时置位；任一为 FALSE 就返回 FALSE，保持原有安全逻辑。 *)
F_SafetyBypassActive := stReal.xSafetyBypass AND stReal.xSafetyBypassConfirm;
