FUNCTION_BLOCK FB_DeviceManager
(* 模块说明：统一设备执行入口。首次建立类型和初始位置，每扫描周期按类型调用设备功能块并收集反馈。 *)
VAR_INPUT
	xEnable : BOOL; (* 本功能使能，电平有效；失能时不接受新的动作请求。 *)
	xSimulation : BOOL; (* TRUE 使用内部仿真；当前 FALSE 报未实现 3001，不会接管真实运动。 *)
	xReset : BOOL; (* 故障复位许可；仿真设备仅在故障注入已撤销时清除错误。 *)
	xFaultHold : BOOL; (* 整机故障保持：TRUE 时真实轴强制停车、真实阀失电，直到复位。 *)
	stSim : ST_SimulationSettings; (* 软件仿真设置；设备管理器按设备索引读取卡住与故障注入。 *)
	stReal : ST_RealDeviceSettings; (* 真实设备接管设置；逐台位决定该编号走真实轴还是仿真。 *)
	uiMaterialModel : UINT; (* 当前运行料型 300/450/600；G2 气缸组按此选通其中一个缸下降。 *)
	aCommand : ARRAY[1..17] OF ST_DeviceCommand; (* 统一设备请求数组 1..17；子流程写请求，设备管理器执行。 *)
END_VAR
VAR_OUTPUT
	aStatus : ARRAY[1..17] OF ST_DeviceStatus; (* 各设备的反馈数组 1..17，供判断忙、完成序号、故障和位置。 *)
	aValveOut : ARRAY[1..17] OF BOOL; (* 各设备的阀电气输出电平 1..17；只有已接管的真实气缸可能为 TRUE，供物理映射层取用。 *)
	aValveOutAux : ARRAY[1..17] OF BOOL; (* 第二个执行器的阀电气电平 1..17；当前只有 G1 双压板的 [9] 有效，其余恒 FALSE。 *)
	aG2Valve : ARRAY[1..3] OF BOOL; (* G2 三个侧挡阀的电气电平 1=300，2=450，3=600；未接管时全 FALSE。 *)
	uiG2Band : UINT; (* G2 当前实际下降的料型带号 300/450/600；0 表示三缸全部提升，供诊断观察。 *)
END_VAR
VAR
	aConfig : ARRAY[1..17] OF ST_DeviceConfig; (* 设备配置数组，首扫描按固定编号设置类型和初始姿态。 *)
	aAxis : ARRAY[1..17] OF FB_Axis; (* 定位轴功能块实例数组，只有设备类型为 Axis 的元素被调用。 *)
	aMotor : ARRAY[1..17] OF FB_Motor; (* 连续电机功能块实例数组，供 D1、D3 使用。 *)
	aCylinder : ARRAY[1..17] OF FB_Cylinder; (* 气缸功能块实例数组，按 G 编号驱动对应仿真实例。 *)
	aValve : ARRAY[1..17] OF FB_Valve; (* 阀功能块实例数组，供 G5 喷油及 G6 吹气使用。 *)
	fbRealD1 : FB_RealAxis; (* D1 送料皮带真实轴实例，绑定 songliao。 *)
	fbRealD2 : FB_RealAxis; (* D2 切割走刀真实轴实例，绑定 qiege。 *)
	fbRealD3 : FB_RealAxis; (* D3 盘刀旋转真实轴实例，绑定 pandao（当前按线性模式配置）。 *)
	fbRealD8 : FB_RealAxis; (* D8 平台旋转真实轴实例，绑定 xuanzhuan（台达 ASDA-B3-E）。 *)
	fbRealG1 : FB_RealCylinder; (* G1 下压气缸真实实例，绑定左右两路阀与 G1 两端传感器。 *)
	fbRealG2 : FB_RealCylinderGroup; (* G2 侧挡气缸组真实实例，一台管 300/450/600 三个缸。 *)
	fbRealG3 : FB_RealCylinder; (* G3 侧推气缸真实实例，绑定 xDoG3Valve 与 G3 两端传感器。 *)
	fbRealG9 : FB_RealCylinder; (* G9 盘刀升降真实实例，绑定 xDoG9Valve 与 G9 两端传感器。 *)
	fbRealD6 : FB_RealSensor; (* D6 定长光电真实实例，只读；接管后取代 FB_SimPlant 产生料到位信号。 *)
	axUseReal : ARRAY[1..17] OF BOOL; (* 本扫描逐台接管标志，直接取 stReal.axRealDevice；没有真实实例的编号由回填分支报 3002。 *)
	xBooted : BOOL; (* 本功能块首次初始化完成标志，防止每扫描重写初值。 *)
	i : INT; (* 本扫描数组遍历索引；含义及范围以当前 FOR 循环为准。 *)
END_VAR
FUNCTION_BLOCK FB_DeviceManager
IF NOT xBooted THEN
	(* D1 送料皮带：由真实轴 songliao 承担输送，按定位轴建模（点动/连续运行）。 *)
	aConfig[1].eKind := E_DeviceKind.Axis;
	aConfig[2].eKind := E_DeviceKind.Axis;
	aConfig[3].eKind := E_DeviceKind.Motor;
	aConfig[4].eKind := E_DeviceKind.Axis;
	(* D5 暂按定位升降建模：0=升起避让，1=下降检测，非实际机械坐标。 *)
	aConfig[5].eKind := E_DeviceKind.Axis;
	aConfig[7].eKind := E_DeviceKind.Axis;
	aConfig[8].eKind := E_DeviceKind.Axis;
	FOR i := 9 TO 17 DO aConfig[i].eKind := E_DeviceKind.Cylinder; END_FOR
	aConfig[13].eKind := E_DeviceKind.Valve;
	aConfig[14].eKind := E_DeviceKind.Valve;
	aConfig[12].lrInitialPosition := 1.0;
	FOR i := 1 TO 17 DO
		IF aConfig[i].eKind = E_DeviceKind.Cylinder THEN
			aConfig[i].lrMinPosition := 0.0; aConfig[i].lrMaxPosition := 1.0;
		END_IF
	END_FOR
	(* D2 切割走刀：配方要求 200mm/s、加速度 500；默认 100/50 会把速度削到 100 并拖长加减速段。 *)
	aConfig[2].lrMaxVelocity := 300.0;
	aConfig[2].lrMaxAcceleration := 500.0;
	aConfig[2].lrMaxDeceleration := 500.0;
	xBooted := TRUE;
END_IF

(* 逐台接管标志直接取设置位：是否真的接管由下方回填分支的 CASE 决定。
   新增真实实例时只改 CASE 和实例调用两处，不要再维护第二份白名单。 *)
FOR i := 1 TO 17 DO
	axUseReal[i] := stReal.axRealDevice[i];
END_FOR

(* 四个真实轴实例每扫描必须无条件调用；轴形参写死，无法放进 FOR 循环。
   绑定对照（换电机、改轴名后必须逐行核对：写错不会报编译错误，
   因为任何一个合法轴名都能通过类型检查，只能靠单点测试发现）：
     fbRealD1 -> songliao    设备索引 1，送料皮带（EtherCAT 从站 ASDA_B3_E_CoE_Drive_3）
     fbRealD2 -> qiege       设备索引 2，切割走刀（从站 ASDA_B3_E_CoE_Drive_1）
     fbRealD3 -> pandao      设备索引 3，盘刀旋转（从站 ASDA_B3_E_CoE_Drive_2）
     fbRealD8 -> xuanzhuan   设备索引 8，平台旋转（从站 ASDA_B3_E_CoE_Drive，台达）
   注意：ASDA_B3_E_CoE_Drive_* 是驱动器从站名，代码里写的必须是它下面那个
   轴对象名（songliao/qiege/pandao/xuanzhuan），两者不是一回事。 *)
fbRealD1(Axis := songliao, xUseReal := axUseReal[1], xEnable := xEnable, xReset := xReset,
	xFaultHold := xFaultHold,
	stConfig := aConfig[1], stCommand := aCommand[1], stReal := stReal);
fbRealD2(Axis := qiege, xUseReal := axUseReal[2], xEnable := xEnable, xReset := xReset,
	xFaultHold := xFaultHold,
	stConfig := aConfig[2], stCommand := aCommand[2], stReal := stReal);
fbRealD3(Axis := pandao, xUseReal := axUseReal[3], xEnable := xEnable, xReset := xReset,
	xFaultHold := xFaultHold,
	stConfig := aConfig[3], stCommand := aCommand[3], stReal := stReal);
fbRealD8(Axis := xuanzhuan, xUseReal := axUseReal[8], xEnable := xEnable, xReset := xReset,
	xFaultHold := xFaultHold,
	stConfig := aConfig[8], stCommand := aCommand[8], stReal := stReal);

(* 四个真实气缸实例同样必须无条件调用；传感器与阀逐一对应物理映射符号。
   极性默认 FALSE：传感器高电平有效、阀高电平使能。接线反了只改这里一行，不动流程与互锁。 *)
fbRealG1(xUseReal := axUseReal[9], xEnable := xEnable, xReset := xReset,
	xFaultHold := xFaultHold,
	xSensorRetract := GVL_IO_Physical.xDiG1LRetract, xSensorExtend := GVL_IO_Physical.xDiG1LExtend,
	xSensorRetract2 := GVL_IO_Physical.xDiG1RRetract, xSensorExtend2 := GVL_IO_Physical.xDiG1RExtend,
	xUseSecond := TRUE,
	(* 现场 G1 两只伸出到位传感器已失效：改成只看左右两个缩回信号，两者都无信号并稳定 1s 即认为压到位。
	   传感器修好后把 xExtendByRetract 改回 FALSE 就恢复两端判定，流程和互锁都不用动。 *)
	xExtendByRetract := TRUE, tExtendConfirm := T#1S,
	xInvertSensors := FALSE, xInvertValve := FALSE,
	stConfig := aConfig[9], stCommand := aCommand[9]);
fbRealG2(xUseReal := axUseReal[10], xEnable := xEnable, xReset := xReset,
	xFaultHold := xFaultHold,
	uiMaterialModel := uiMaterialModel,
	xSensorRetract1 := GVL_IO_Physical.xDiG2_300Retract, xSensorExtend1 := GVL_IO_Physical.xDiG2_300Extend,
	xSensorRetract2 := GVL_IO_Physical.xDiG2_450Retract, xSensorExtend2 := GVL_IO_Physical.xDiG2_450Extend,
	xSensorRetract3 := GVL_IO_Physical.xDiG2_600Retract, xSensorExtend3 := GVL_IO_Physical.xDiG2_600Extend,
	xInvertSensors := FALSE, xInvertValve := FALSE,
	stConfig := aConfig[10], stCommand := aCommand[10]);
fbRealG3(xUseReal := axUseReal[11], xEnable := xEnable, xReset := xReset,
	xFaultHold := xFaultHold,
	xSensorRetract := GVL_IO_Physical.xDiG3Retract, xSensorExtend := GVL_IO_Physical.xDiG3Extend,
	xInvertSensors := FALSE, xInvertValve := FALSE,
	stConfig := aConfig[11], stCommand := aCommand[11]);
fbRealG9(xUseReal := axUseReal[17], xEnable := xEnable, xReset := xReset,
	xFaultHold := xFaultHold,
	xSensorRetract := GVL_IO_Physical.xDiG9Retract, xSensorExtend := GVL_IO_Physical.xDiG9Extend,
	xInvertSensors := FALSE, xInvertValve := FALSE,
	stConfig := aConfig[17], stCommand := aCommand[17]);

(* D6 定长光电：只读设备，没有阀也没有动作。
   接线极性反了改 xInvertSensor；光电抖动大改 tDebounce；不需要常亮/常灭监视就把 tStuckTimeout 置 T#0MS。 *)
fbRealD6(xUseReal := axUseReal[6], xEnable := xEnable, xReset := xReset,
	xSensorRaw := GVL_IO_Physical.xDiMaterialLength, xInvertSensor := FALSE,
	tDebounce := T#20MS, tStuckTimeout := T#0MS,
	stConfig := aConfig[6], stCommand := aCommand[6]);

(* 每周期按接管标志二选一：有真实实例的直接回填，否则按设备类型走仿真。
   「实例即事实」：本 CASE 列出全部已实现真实适配的编号，没列到的编号若置了接管位，
   就在 ELSE 分支明确报 3002，避免静默走仿真被误认为已接实机。 *)
(* G2 三个阀默认失电：只有走真实气缸组且缸确实在下降时才会被下面的 CASE 置位。 *)
aG2Valve[1] := FALSE; aG2Valve[2] := FALSE; aG2Valve[3] := FALSE;
uiG2Band := 0;
FOR i := 1 TO 17 DO
	aValveOut[i] := FALSE; aValveOutAux[i] := FALSE;
	IF axUseReal[i] THEN
		CASE i OF
		1: aStatus[i] := fbRealD1.stStatus;
		2: aStatus[i] := fbRealD2.stStatus;
		3: aStatus[i] := fbRealD3.stStatus;
		6: aStatus[i] := fbRealD6.stStatus;
		8: aStatus[i] := fbRealD8.stStatus;
		9: aStatus[i] := fbRealG1.stStatus; aValveOut[i] := fbRealG1.xValve; aValveOutAux[i] := fbRealG1.xValve2;
		10: aStatus[i] := fbRealG2.stStatus; aG2Valve := fbRealG2.aValve; uiG2Band := fbRealG2.uiActiveBand;
		11: aStatus[i] := fbRealG3.stStatus; aValveOut[i] := fbRealG3.xValve;
		17: aStatus[i] := fbRealG9.stStatus; aValveOut[i] := fbRealG9.xValve;
		ELSE
			(* 请求接管但本版本没有对应真实实例：只报错，不启动仿真，保持与老逻辑一致 *)
			aStatus[i].xError := TRUE;
			aStatus[i].udiErrorID := 3002;
		END_CASE
	ELSE
		CASE aConfig[i].eKind OF
		E_DeviceKind.Axis:
			aAxis[i](xSimulation:=xSimulation,xEnable:=xEnable,xReset:=xReset,
				xStall:=stSim.axStall[i],xInjectFault:=stSim.axFault[i],stConfig:=aConfig[i],stCommand:=aCommand[i]);
			aStatus[i] := aAxis[i].stStatus;
		E_DeviceKind.Motor:
			aMotor[i](xSimulation:=xSimulation,xEnable:=xEnable,xReset:=xReset,
				xStall:=stSim.axStall[i],xInjectFault:=stSim.axFault[i],stConfig:=aConfig[i],stCommand:=aCommand[i]);
			aStatus[i] := aMotor[i].stStatus;
		E_DeviceKind.Cylinder:
			aCylinder[i](xSimulation:=xSimulation,xEnable:=xEnable,xReset:=xReset,
				xStall:=stSim.axStall[i],xInjectFault:=stSim.axFault[i],stConfig:=aConfig[i],stCommand:=aCommand[i]);
			aStatus[i] := aCylinder[i].stStatus;
		E_DeviceKind.Valve:
			aValve[i](xSimulation:=xSimulation,xEnable:=xEnable,xReset:=xReset,
				xStall:=stSim.axStall[i],xInjectFault:=stSim.axFault[i],stConfig:=aConfig[i],stCommand:=aCommand[i]);
			aStatus[i] := aValve[i].stStatus;
		END_CASE
	END_IF
END_FOR
