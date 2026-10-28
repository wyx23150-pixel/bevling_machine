(* 模块说明：锁存首次非零报警。只有复位有效且当前没有新报警时清除；同一扫描有新报警时仍会锁存。 *)
FUNCTION_BLOCK FB_AlarmManager
VAR_INPUT
    udiIncoming : UDINT; (* 当前扫描的新报警码；0 表示当前未提出报警。 *)
    xReset : BOOL; (* 故障复位许可；仿真设备仅在故障注入已撤销时清除错误。 *)
END_VAR
VAR_OUTPUT
    udiLatched : UDINT; (* 已锁存的首个非零报警码；后续报警不覆盖，满足复位条件后清零。 *)
END_VAR

(* 只有没有当前报警原因才清锁存；当前代码保留第一个非零报警，后续报警不覆盖。 *)
IF xReset AND (udiIncoming=0) THEN udiLatched:=0; END_IF
IF (udiLatched=0) AND (udiIncoming<>0) THEN udiLatched:=udiIncoming; END_IF
