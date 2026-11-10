(* 模块说明：整机运行状态。停止或报警复位后须重新初始化，启动命令不会跳过初始化。 *)
{attribute 'qualified_only'}
TYPE E_MachineState :
(
    Stopped := 0, (* 停止，须初始化 *)
    Initializing := 10, (* 初始化中 *)
    Ready := 20, (* 初始化完成，等待自动启动 *)
    Manual := 30, (* 手动控制中 *)
    Automatic := 40, (* 自动工序运行中，包含正常等料 *)
    Fault := 90 (* 报警锁存，清除原因后复位 *)
);
END_TYPE
