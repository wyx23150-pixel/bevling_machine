(* 模块说明：周期入口：先解码实体面板，再解析通信、调度整机、发布反馈和映射逻辑输出，仅在 ETHERCAT1 调用一次。 *)
PROGRAM PLC_PRG
VAR
	fbPanel : FB_PanelInput; (* 实体/仿真面板解码实例，须先于通信和整机调度调用。 *)
	fbCommunication : FB_ModbusInterface; (* 通信命令解析和状态打包实例；打包的是上一扫描已发布的整机反馈。 *)
	fbMachine : FB_Machine; (* 整机调度实例，包含初始化、手动、自动、互锁、报警和设备管理。 *)
	fbIO : FB_IOMap; (* 逻辑 I/O 映射实例，当前只形成诊断需求，不驱动真实输出。 *)
	xSafetyBypassActive : BOOL; (* 安全许可两级旁路已生效；仅当一级开关与二级确认同时置位。 *)
END_VAR

(* 本程序只在 ETHERCAT1 中周期调用一次；内部功能块沿本调用链每扫描执行。 *)
(* 先解码实体/仿真面板；模式旋钮为唯一模式来源，随后发布到只读监控接口。 *)
fbPanel(xSimulation:=GVL_Parameters.xSimulation,stReal:=GVL_IO.stPanelInputs,
    stSim:=GVL_Simulation.stPanelInputs,xContinuous:=GVL_Parameters.xContinuous);
GVL_Interface.stPanel:=fbPanel.stCommand;
(* 1. 解析上位机新命令并打包上一扫描状态，供本扫描整机处理。 *)
fbCommunication(xEnable:=GVL_Modbus.xEnable,stStatus:=GVL_Interface.stStatus,
    aStatus:=GVL_Interface.aDeviceStatus,awRx:=GVL_Modbus.awRx,awTx:=GVL_Modbus.awTx);
(* 2. 安全许可旁路：一级开关与二级确认同时置位才生效，单开关无效。 *)
xSafetyBypassActive:=F_SafetyBypassActive(GVL_RealDevice.stSettings);
(* 3. 整机选择操作来源，调度工序，通过互锁后统一调用设备。 *)
fbMachine(xSimulation:=GVL_Parameters.xSimulation,stPanel:=GVL_Interface.stPanel,
    stRemote:=fbCommunication.stCommand,xRemoteRequest:=fbCommunication.xRequest,
    xAllowRemoteStartStop:=GVL_Parameters.xAllowRemoteStartStop,
    wRemoteSequence:=fbCommunication.wRequestSequence,aManual:=GVL_Interface.aManual,
    stRecipe:=GVL_Parameters.stRecipe,stSim:=GVL_Simulation.stSettings,
    stReal:=GVL_RealDevice.stSettings,xSafetyBypassActive:=xSafetyBypassActive,
    xRealSafetyOK:=GVL_IO.xSafetyOK,xRealMaterial:=GVL_IO.xMaterialAtLength);
(* 4. 将整机反馈发布到监控接口，建议调试时从这里查看主步骤和支线步骤。 *)
GVL_Interface.stStatus:=fbMachine.stStatus;
GVL_Interface.aDeviceStatus:=fbMachine.aDeviceStatus;
(* 5. 形成逻辑输出并下沉到物理点；真实气缸阀电平在此写入 GVL_IO_Physical。 *)
fbIO(uiMaterialModel:=fbMachine.stStatus.uiActiveMaterialModel,aCommand:=fbMachine.aSelectedCommand,
    aStatus:=fbMachine.aDeviceStatus,aValveOut:=fbMachine.aValveOut,
    axOutputs:=GVL_IO.axDigitalOutputs,axG2RelayDemand:=GVL_IO.axG2RelayDemand);
