(* 模块说明：仿真调试入口。可模拟来料、动作卡住、设备故障和安全许可丢失。 *)
VAR_GLOBAL
    stSettings : ST_SimulationSettings; (* 软件仿真参数，含来料方式和异常注入。 *)
    stPanelInputs : ST_PanelInputs; (* 仿真旋钮/按钮输入；xAutoMode 选择模式，其余按钮按住/释放模拟物理信号。 *)
END_VAR

