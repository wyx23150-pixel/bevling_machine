(* 模块说明：整机调度中心：命令选择、模式和报警管理、初始化/手动/自动调度、统一互锁、设备执行及状态发布。 *)
FUNCTION_BLOCK FB_Machine
VAR_INPUT
	xSimulation : BOOL; (* TRUE 使用内部仿真；当前 FALSE 报未实现 3001，不会接管真实运动。 *)
	stPanel : ST_OperatorCommand; (* 本地实体面板解码结果；模式、初始化、复位始终以它为准。 *)
	stRemote : ST_RemoteCommand; (* 上位机可选的启停请求，不包含模式或初始化/复位字段。 *)
	xRemoteRequest : BOOL; (* 远程新命令有效脉冲；无新帧时仅保留模式与连续选择。 *)
	xAllowRemoteStartStop : BOOL; (* 本地工程配置授权远程启停，默认 FALSE；不授予改模式、初始化或复位权限，也不映射给上位机写。 *)
	wRemoteSequence : WORD; (* 本次远程新命令序号，整机处理后写入确认状态。 *)
	aManual : ARRAY[1..17] OF ST_ManualCommand; (* 各设备手动请求，索引 1..17；进入手动后先释放所有按钮再允许动作。 *)
	stRecipe : ST_Recipe; (* 待校验配方或上层传入的运行配方，字段含义见 ST_Recipe。 *)
	stSim : ST_SimulationSettings; (* 软件仿真设置；设备管理器按设备索引读取卡住与故障注入。 *)
	stReal : ST_RealDeviceSettings; (* 真实设备接管设置；逐台位决定哪些编号走真实轴。 *)
	xRealSafetyOK : BOOL; (* 真实安全许可预留接口；当前仿真模式使用 stSim.xSafetyOK。 *)
	xRealMaterial : BOOL; (* 真实定长光电预留输入；当前仿真模式由 FB_SimPlant 提供。 *)
	xSafetyBypassActive : BOOL; (* 安全许可两级旁路已生效；仅在 xAnyReal 为 TRUE 时参与取或。 *)
END_VAR
VAR_OUTPUT
	stStatus : ST_MachineStatus; (* 本模块对外发布的状态；字段含义见其数据类型。 *)
	aDeviceStatus : ARRAY[1..17] OF ST_DeviceStatus; (* 设备管理器汇总反馈，索引 1..17；供工序判断及在线监控。 *)
	aSelectedCommand : ARRAY[1..17] OF ST_DeviceCommand; (* 通过统一互锁后的最终设备请求，交设备管理器执行。 *)
	aValveOut : ARRAY[1..17] OF BOOL; (* 各设备阀电气电平，索引同设备号；供物理映射层下沉到真实输出点。 *)
END_VAR
VAR
	stCommand : ST_OperatorCommand; (* 本周期选择并合并后的整机命令；本地停止始终优先于远程。 *)
	stActiveRecipe : ST_Recipe; (* 本次初始化/自动启动时采纳的配方快照，运行中不直接跟随参数区变化。 *)
	aRequest : ARRAY[1..17] OF ST_DeviceCommand; (* 初始化/手动/自动产生的原始请求，每周期先清空，再交互锁筛选。 *)
	stEmpty : ST_DeviceCommand; (* 默认全零设备命令，每周期用它清空原始请求，未被重新提出的动作自动取消。 *)
	fbDevices : FB_DeviceManager; (* 统一设备管理器，每周期调用一次，汇总各设备反馈。 *)
	fbManual : FB_ManualControl; (* 手动请求转换功能块，须处于手动并已释放全部按钮才使能。 *)
	fbAuto : FB_AutoCycle; (* 自动主流程功能块，仅在整机 Automatic 状态运行。 *)
	fbInitialize : FB_Initialize; (* 初始化功能块，仅在整机 Initializing 状态执行。 *)
	fbInterlocks : FB_Interlocks; (* 所有模式共用的软件互锁，输出最终允许的请求。 *)
	fbPlant : FB_SimPlant; (* 仿真整机来料模型；当前流程读取其上一扫描的到位反馈。 *)
	fbAlarm : FB_AlarmManager; (* 整机首报警锁存功能块。 *)
	rtInitialize : R_TRIG; (* 初始化按钮上升沿检测。 *)
	rtStart : R_TRIG; (* 自动启动按钮上升沿检测。 *)
	rtReset : R_TRIG; (* 报警复位按钮上升沿检测。 *)
	udiCounter : UDINT; (* 全机共享的动作序号计数器，通过引用传递；由 F_NextID 分配，0 不使用。 *)
	udiFault : UDINT; (* 本扫描整理出的报警原因；设备错误使用 10000+设备索引。 *)
	xSafetyOK : BOOL; (* 安全许可接口或仿真许可，TRUE 允许；不等同于安全级急停回路。 *)
	xMaterial : BOOL; (* 当前实际采用的来料信号，仿真与实机预留输入二选一。 *)
	xInitialized : BOOL; (* 初始化完成标志；停止、运行中切换模式或故障会清除。 *)
	xPermit : BOOL; (* 整机当前允许发出动作的总许可；仍需继续满足各设备互锁。 *)
	xRemoteAccepted : BOOL; (* 本扫描远程命令已获授权，用于回传状态拒绝或配方错误。 *)
	xStartRequest : BOOL; (* 本次启动事件=本地启动按钮上升沿或已接受的远程启动帧；两种事件分别处理以免相互吞掉。 *)
	xResetDevices : BOOL; (* 本扫描设备复位脉冲，需复位上升沿、安全许可和仿真模式均满足。 *)
	xLastSimulation : BOOL := TRUE; (* 上扫描仿真开关；切换模式时清除初始化并停止。 *)
	xManualReleased : BOOL; (* 所有手动按钮都已释放，用于避免带着按住命令进入手动。 *)
	xManualArmed : BOOL; (* 本次进入手动后已观察到全部按钮释放；离开手动即清除。 *)
	eActiveMode : E_MachineMode; (* 当前初始化/运行时采纳的操作模式，用于检测运行中切换模式。 *)
	xAnyReal : BOOL; (* 是否有任意设备由真实轴接管；全 FALSE 时后续分支与改造前逐语句一致。 *)
	xAllHomed : BOOL; (* 所有已接管的真实轴都已完成回零；未接真实轴时为 TRUE，用于状态发布。 *)
	wRealMask : WORD; (* 真实设备接管掩码，第 i 位置位表示设备 i 走真实轴。 *)
	wLastRealMask : WORD; (* 上扫描接管掩码；变化时清除初始化并回 Stopped。 *)
	xLastRelativeVerify : BOOL; (* 上扫描相对验证开关；切换时清除初始化并回 Stopped。 *)
	uiSafetySource : UINT; (* 安全许可来源：0 仿真源，1 真实源，2 调试旁路。 *)
	uiInitReject : UINT; (* 初始化被拒绝的原因：0 未拒绝；回零已并入初始化流程，当前无拒绝分支，字段预留。 *)
	i : INT; (* 本扫描数组遍历索引；含义及范围以当前 FOR 循环为准。 *)
END_VAR

(* 零、派生混跑标志：axRealDevice 全 FALSE 时 xAnyReal 为 FALSE，后续所有分支与改造前一致。 *)
xAnyReal:=FALSE; wRealMask:=0;
FOR i:=1 TO 17 DO
    IF stReal.axRealDevice[i] THEN
        xAnyReal:=TRUE;
        wRealMask:=wRealMask OR SHL(WORD#1,i-1);
    END_IF
END_FOR

(* 一、选择命令来源：本地默认优先；远程须授权，本地停止始终有效。 *)
stCommand:=stPanel;
(* 模式、初始化、复位来自实体面板；远程只可追加经过授权的启停，不能替换整份本地命令。 *)
xRemoteAccepted:=FALSE;
IF xRemoteRequest THEN
    stStatus.wRemoteAckSequence:=wRemoteSequence;
    IF xAllowRemoteStartStop THEN
        IF stRemote.xStop THEN
            stCommand.xStop:=TRUE;
            stStatus.uiRemoteResult:=0; xRemoteAccepted:=TRUE;
        ELSIF stRemote.xStart THEN
            IF (stPanel.eMode=E_MachineMode.Automatic)
               AND (stStatus.eState=E_MachineState.Ready) AND NOT stPanel.xStop THEN
                stStatus.uiRemoteResult:=0; xRemoteAccepted:=TRUE;
            ELSE stStatus.uiRemoteResult:=3; END_IF
        ELSE stStatus.uiRemoteResult:=2; END_IF
    ELSE stStatus.uiRemoteResult:=1;
    END_IF
END_IF
(* 二、提取初始化/启动/复位上升沿；采样仿真或真实预留输入。 *)
rtInitialize(CLK:=stCommand.xInitialize);
rtStart(CLK:=stCommand.xStart);
(* 本地启动取按钮上升沿，远程启动取新帧脉冲，分别形成事件；本地停止仍优先。 *)
xStartRequest:=rtStart.Q OR (xRemoteAccepted AND stRemote.xStart AND NOT stRemote.xStop);
rtReset(CLK:=stCommand.xResetAlarm);
(* 混跑时安全源改为真实优先：未接安全回路时靠两级旁路放行，旁路生效不报 1001。 *)
IF xAnyReal THEN
    xSafetyOK:=xRealSafetyOK OR xSafetyBypassActive;
    IF stReal.xUseRealMaterial THEN xMaterial:=xRealMaterial;
    ELSE xMaterial:=fbPlant.xMaterialAtLength; END_IF
ELSIF xSimulation THEN xSafetyOK:=stSim.xSafetyOK; xMaterial:=fbPlant.xMaterialAtLength;
ELSE xSafetyOK:=xRealSafetyOK; xMaterial:=xRealMaterial; END_IF
(* 安全来源：0 仿真源，1 真实源，2 调试旁路。 *)
IF NOT xAnyReal THEN uiSafetySource:=0;
ELSIF xSafetyBypassActive AND NOT xRealSafetyOK THEN uiSafetySource:=2;
ELSE uiSafetySource:=1; END_IF
(* 三、整理当前报警原因并清空本扫描请求；未被子流程重新提出的动作自动取消。 *)
udiFault:=0;
IF NOT xSafetyOK THEN udiFault:=1001; END_IF
IF NOT xSimulation THEN udiFault:=3001; END_IF
(* 仿真开关、接管掩码或验证模式变化，均清除初始化并回 Stopped。 *)
IF (xSimulation<>xLastSimulation) OR (wRealMask<>wLastRealMask) OR (stReal.xRelativeVerify<>xLastRelativeVerify) THEN
    stStatus.eState:=E_MachineState.Stopped; xInitialized:=FALSE;
END_IF
xLastSimulation:=xSimulation; wLastRealMask:=wRealMask; xLastRelativeVerify:=stReal.xRelativeVerify;
FOR i:=1 TO 17 DO
    IF aDeviceStatus[i].xError THEN udiFault:=10000+INT_TO_UDINT(i); END_IF
    aRequest[i]:=stEmpty;
END_FOR
(* 四、运行中切模式、停止或故障会撤销初始化，不能直接接续上一次工序。 *)
IF (stStatus.eState=E_MachineState.Automatic) OR (stStatus.eState=E_MachineState.Manual) THEN
    IF stCommand.eMode<>eActiveMode THEN stStatus.eState:=E_MachineState.Stopped; xInitialized:=FALSE; END_IF
END_IF
IF stCommand.xStop THEN stStatus.eState:=E_MachineState.Stopped; xInitialized:=FALSE; END_IF
IF udiFault<>0 THEN stStatus.eState:=E_MachineState.Fault; xInitialized:=FALSE; END_IF
(* 五、复位设备和首报警锁存；必须先撤销故障原因，复位不自动启动。 *)
xResetDevices:=rtReset.Q AND xSafetyOK AND xSimulation;
IF xResetDevices THEN
    (* 复位时先按仍有效的故障注入判断原因，再清设备错误和整机锁存；原因未撤销不能复位。 *)
    udiFault:=0;
    FOR i:=1 TO 17 DO IF stSim.axFault[i] THEN udiFault:=10000+INT_TO_UDINT(i); END_IF END_FOR
END_IF
fbAlarm(udiIncoming:=udiFault,xReset:=xResetDevices);
IF (stStatus.eState=E_MachineState.Fault) AND (fbAlarm.udiLatched=0) AND xResetDevices THEN
    stStatus.eState:=E_MachineState.Stopped;
END_IF
IF fbAlarm.udiLatched<>0 THEN stStatus.eState:=E_MachineState.Fault; END_IF
(* 六、仅停止态接受初始化；配方通过检查后取快照。 *)
IF rtInitialize.Q AND NOT stCommand.xStop THEN
    (* 真实轴的回零已并入初始化第 25 步，这里不再要求预先打开相对验证。 *)
    IF (stStatus.eState=E_MachineState.Stopped) AND xSimulation AND xSafetyOK AND F_RecipeValid(stRecipe) THEN
        stActiveRecipe:=stRecipe; stStatus.eState:=E_MachineState.Initializing;
        eActiveMode:=stCommand.eMode; xInitialized:=FALSE; uiInitReject:=0;
    ELSE
        (* 当前无拒绝分支：回零并入初始化，uiInitReject 保留字段但不再置位。 *)
        IF xRemoteAccepted THEN stStatus.uiRemoteResult:=3; END_IF
    END_IF
END_IF
(* 七、手动不依赖初始化：停机态只要模式在手动且没按停止就直接进入，开机后不必先跑初始化。
   自动仍必须先完成初始化到 Ready；停止按钮按住时留在 Stopped，松开后自动回到手动。 *)
IF (stStatus.eState=E_MachineState.Stopped) AND (stCommand.eMode=E_MachineMode.Manual)
   AND NOT stCommand.xStop THEN
    stStatus.eState:=E_MachineState.Manual; eActiveMode:=E_MachineMode.Manual;
END_IF
IF stStatus.eState=E_MachineState.Ready THEN
    IF stCommand.eMode=E_MachineMode.Manual THEN
        stStatus.eState:=E_MachineState.Manual; eActiveMode:=E_MachineMode.Manual;
    ELSIF xStartRequest AND NOT stCommand.xStop THEN
        IF stReal.xRelativeVerify THEN
            (* 相对验证模式下绝对位置不作生产依据，禁止进自动。 *)
            stStatus.uiRemoteResult:=4;
        ELSIF F_RecipeValid(stRecipe) THEN
            stActiveRecipe:=stRecipe; eActiveMode:=E_MachineMode.Automatic;
            stStatus.eState:=E_MachineState.Automatic;
        ELSIF xRemoteAccepted THEN stStatus.uiRemoteResult:=5;
        END_IF
    END_IF
ELSIF (stStatus.eState=E_MachineState.Manual) AND (stCommand.eMode=E_MachineMode.Automatic) THEN
    stStatus.eState:=E_MachineState.Stopped; xInitialized:=FALSE;
END_IF
IF xStartRequest AND xRemoteAccepted AND (stStatus.eState<>E_MachineState.Automatic)
   AND (stStatus.uiRemoteResult=0) THEN stStatus.uiRemoteResult:=3; END_IF

(* 八、手动进入联锁：观察到一次全部按钮释放后，才开放点动/定位操作。 *)
xManualReleased:=TRUE;
FOR i:=1 TO 17 DO
    IF aManual[i].xJogPositive OR aManual[i].xJogNegative OR aManual[i].xMove OR aManual[i].xRun OR aManual[i].xHome THEN xManualReleased:=FALSE; END_IF
END_FOR
IF stStatus.eState<>E_MachineState.Manual THEN xManualArmed:=FALSE;
ELSIF xManualReleased THEN xManualArmed:=TRUE;
END_IF
(* 九、每扫描调用各模式功能块，失能的流程同时复位；共享请求只由当前模式提出。 *)
fbInitialize(xExecute:=stStatus.eState=E_MachineState.Initializing,stRecipe:=stActiveRecipe,
    aCommand:=aRequest,aStatus:=aDeviceStatus,udiCounter:=udiCounter);
fbManual(xEnable:=(stStatus.eState=E_MachineState.Manual) AND xManualArmed,stReal:=stReal,
    aManual:=aManual,aCommand:=aRequest,aStatus:=aDeviceStatus,udiCounter:=udiCounter);
fbAuto(xRun:=stStatus.eState=E_MachineState.Automatic,xContinuous:=stCommand.xContinuous,
    xMaterialAtLength:=xMaterial,stRecipe:=stActiveRecipe,aCommand:=aRequest,aStatus:=aDeviceStatus,udiCounter:=udiCounter);
(* 十、汇总流程完成和流程错误，单循环完成后回到 Ready。 *)
IF fbInitialize.xDone THEN xInitialized:=TRUE; stStatus.eState:=E_MachineState.Ready; END_IF
IF fbInitialize.xError OR fbAuto.xError THEN
    udiFault:=MAX(fbInitialize.udiErrorID,fbAuto.udiErrorID);
    fbAlarm(udiIncoming:=udiFault,xReset:=FALSE);
    stStatus.eState:=E_MachineState.Fault; xInitialized:=FALSE;
END_IF
IF fbAuto.xDone THEN
    stStatus.udiCycleCount:=stStatus.udiCycleCount+1;
    IF NOT stCommand.xContinuous THEN stStatus.eState:=E_MachineState.Ready; END_IF
END_IF
(* 十一、总许可与机构互锁筛选请求，再调用设备管理器；流程判断使用此前的反馈。 *)
xPermit:=xSimulation AND xSafetyOK AND NOT stCommand.xStop AND (fbAlarm.udiLatched=0)
    AND ((stStatus.eState=E_MachineState.Initializing) OR (stStatus.eState=E_MachineState.Manual)
    OR (stStatus.eState=E_MachineState.Automatic));
fbInterlocks(xPermit:=xPermit,xManualMode:=(stStatus.eState=E_MachineState.Manual),
    stRecipe:=stActiveRecipe,stReal:=stReal,aRequest:=aRequest,aStatus:=aDeviceStatus);
aSelectedCommand:=fbInterlocks.aCommand;
fbDevices(xEnable:=xSimulation AND xSafetyOK,xSimulation:=xSimulation,xReset:=xResetDevices,
    xFaultHold:=(fbAlarm.udiLatched<>0),stSim:=stSim,stReal:=stReal,aCommand:=aSelectedCommand);
aDeviceStatus:=fbDevices.aStatus;
aValveOut:=fbDevices.aValveOut;
fbPlant(xEnable:=xSimulation,stSettings:=stSim,aStatus:=aDeviceStatus);
(* 十二、集中发布状态；机械手/定长/回刀卡在哪一步，可从对应 ui...Step 追踪。 *)
stStatus.eMode:=stCommand.eMode; stStatus.eAutoStep:=fbAuto.eStep;
stStatus.xSimulation:=xSimulation; stStatus.xRealBackendAvailable:=xAnyReal;
stStatus.xAnyRealDevice:=xAnyReal; stStatus.wRealDeviceMask:=wRealMask;
stStatus.xRelativeVerify:=stReal.xRelativeVerify;
stStatus.xSafetyBypassed:=xSafetyBypassActive AND xAnyReal;
stStatus.uiSafetySource:=uiSafetySource; stStatus.uiInitReject:=uiInitReject;
stStatus.xRemoteStartStopAllowed:=xAllowRemoteStartStop;
xAllHomed:=TRUE;
FOR i:=1 TO 17 DO
    (* 只有真实轴需要回零；D3 盘刀只做连续旋转不回零。气缸无回零动作，其 xHomed 表示
       “姿态已由传感器确立”，由 FB_RealCylinder 维护，不参与回零判定。 *)
    IF stReal.axRealDevice[i] AND (i<>3) AND (i<9) AND NOT aDeviceStatus[i].xHomed THEN xAllHomed:=FALSE; END_IF
END_FOR
stStatus.xRealAxesHomed:=xAllHomed;
stStatus.xInitialized:=xInitialized;
stStatus.xReady:=xInitialized AND (stStatus.eState=E_MachineState.Ready);
stStatus.xMaterialAtLength:=xMaterial; stStatus.xCycleComplete:=fbAuto.xDone;
stStatus.udiAlarm:=fbAlarm.udiLatched; stStatus.uiBlockedDevice:=fbInterlocks.uiBlockedDevice;
stStatus.uiManualReject:=fbManual.uiRejectDevice;
stStatus.uiClearLengthStep:=fbAuto.uiClearLengthStep; stStatus.uiClearTransferStep:=fbAuto.uiClearTransferStep;
stStatus.uiPostStep:=fbAuto.uiPostStep; stStatus.uiReturnKnifeStep:=fbAuto.uiReturnKnifeStep;
stStatus.uiUnloadStep:=fbAuto.uiUnloadStep; stStatus.uiResetLengthStep:=fbAuto.uiResetLengthStep;
stStatus.uiInitializeStep:=fbInitialize.uiStep; stStatus.uiActiveMaterialModel:=stActiveRecipe.uiMaterialModel;
