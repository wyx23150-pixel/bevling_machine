(* 模块说明：操作模式。手动与自动分别提出动作请求，共用设备执行和互锁。 *)
{attribute 'qualified_only'}
TYPE E_MachineMode :
(
    Manual := 0, (* 手动点动/单机构调试 *)
    Automatic := 1 (* 自动循环工序 *)
);
END_TYPE
