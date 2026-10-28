(* 模块说明：每扫描先读取实体面板或仿真面板，形成唯一的本地命令来源。上位机不能修改此处的模式。 *)
FUNCTION_BLOCK FB_PanelInput
VAR_INPUT
    xSimulation : BOOL; (* TRUE 使用内部仿真；当前 FALSE 报未实现 3001，不会接管真实运动。 *)
    stReal : ST_PanelInputs; (* 从物理 I/O 映射得到的标准化面板输入，当前未分配端子地址。 *)
    stSim : ST_PanelInputs; (* 仿真用面板输入，代替尚未连接的实体旋钮和按钮。 *)
    xContinuous : BOOL; (* TRUE 连续循环；FALSE 在当前完整循环结束后回到就绪。 *)
END_VAR
VAR_OUTPUT
    stCommand : ST_OperatorCommand; (* 由本地面板生成的命令，模式仅由 xAutoMode 形成。 *)
END_VAR
VAR
    stSelected : ST_PanelInputs; (* 本扫描选中的实体/仿真面板输入快照。 *)
END_VAR

(* 这里只处理已归一化的逻辑信号；端子、常开/常闭和必要的输入滤波在实际 I/O 映射时确定。 *)
IF xSimulation THEN stSelected:=stSim;
ELSE stSelected:=stReal; END_IF
(* 默认手动，只有本地旋钮明确选择自动才转自动；急停反馈不混入普通停止按钮。 *)
stCommand.eMode:=E_MachineMode.Manual;
IF stSelected.xAutoMode THEN stCommand.eMode:=E_MachineMode.Automatic; END_IF
stCommand.xInitialize:=stSelected.xInitialize;
stCommand.xStart:=stSelected.xStart;
stCommand.xStop:=stSelected.xStop;
stCommand.xResetAlarm:=stSelected.xResetAlarm;
stCommand.xContinuous:=xContinuous;
