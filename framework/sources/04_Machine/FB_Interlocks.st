(* 模块说明：对手动、初始化和自动请求统一执行软件互锁。禁止动作时改为停止，并报告最后一个被阻挡设备。 *)
FUNCTION_BLOCK FB_Interlocks
VAR_INPUT
	xPermit : BOOL; (* 整机当前允许发出动作的总许可；仍需继续满足各设备互锁。 *)
	xManualMode : BOOL; (* 当前处于手动模式；手动模式暂不做机构互锁，互锁只约束自动流程。 *)
	stRecipe : ST_Recipe; (* 待校验配方或上层传入的运行配方，字段含义见 ST_Recipe。 *)
	stReal : ST_RealDeviceSettings; (* 真实设备接管设置；预留输入，当前手动已默认不查互锁，判定未使用。 *)
	aRequest : ARRAY[1..17] OF ST_DeviceCommand; (* 初始化/手动/自动产生的原始请求，每周期先清空，再交互锁筛选。 *)
	aStatus : ARRAY[1..17] OF ST_DeviceStatus; (* 各设备的反馈数组 1..17，供判断忙、完成序号、故障和位置。 *)
END_VAR
VAR_OUTPUT
	aCommand : ARRAY[1..17] OF ST_DeviceCommand; (* 统一设备请求数组 1..17；子流程写请求，设备管理器执行。 *)
	uiBlockedDevice : UINT; (* 本扫描最后一个被互锁阻挡的设备索引；0 表示无阻挡，可结合设备状态排查。 *)
END_VAR
VAR
	i : INT; (* 本扫描数组遍历索引；含义及范围以当前 FOR 循环为准。 *)
	xAllowed : BOOL; (* 当前遍历设备的最终互锁允许结果。 *)
	xMotion : BOOL; (* 当前请求是否为点动或离开当前位置的定位，决定是否检查机构避让。 *)
	xKnifeUp : BOOL; (* G9 刀具处于提升端且设备无忙无故障。 *)
	xPressUp : BOOL; (* G1 下压机构处于抬起端且设备无忙无故障。 *)
	xClampOpen : BOOL; (* G8 夹爪处于打开端且设备无忙无故障。 *)
END_VAR

(* 以下为普通程序互锁；实际急停、门锁、失气等安全功能须由最终硬件方案实现。 *)
uiBlockedDevice:=0;
xKnifeUp:=F_At(aStatus[17],0.0); xPressUp:=F_At(aStatus[9],0.0);
xClampOpen:=F_At(aStatus[16],0.0);
FOR i:=1 TO 17 DO
    aCommand[i]:=aRequest[i];
    xAllowed:=xPermit AND (i<>6);
    xMotion:=(aRequest[i].eAction=E_DeviceAction.Jog) OR
        ((aRequest[i].eAction=E_DeviceAction.Position) AND
        (ABS(aRequest[i].lrTarget-aStatus[i].lrPosition)>0.01));
    (* 手动模式暂不做机构互锁：单轴调试要求能独立动作，互锁只约束自动流程。
       手动下的硬干涉（D5 挡 D4 行程、平台旋转扫刀等）后续按调试情况逐条补回。
       xPermit 不受此影响，任何时候都要先满足。 *)
    IF xMotion AND NOT xManualMode THEN
        CASE i OF
        (* D4 平移之前，D5 定长升降必须已经升起。 *)
        4: xAllowed:=xAllowed AND F_At(aStatus[5],0.0);
        (* D8 平台旋转之前，盘刀和下压抬起、G3 侧推解除。 *)
        8: xAllowed:=xAllowed AND xKnifeUp AND xPressUp AND F_At(aStatus[11],0.0);
        (* G1 下压时，平台不得旋转，盘刀抬起且 D2 在回刀起点。 *)
        9:
            IF aRequest[i].lrTarget>0.5 THEN
                xAllowed:=xAllowed AND NOT aStatus[8].xBusy AND xKnifeUp AND F_At(aStatus[2],stRecipe.lrCutHome);
            END_IF
        (* G9 下刀时，下压到位、旋转停止、定长升起、流利条下降、侧挡下降。 *)
        17:
            IF aRequest[i].lrTarget>0.5 THEN
                xAllowed:=xAllowed AND F_At(aStatus[9],1.0) AND NOT aStatus[8].xBusy
                    AND F_At(aStatus[5],0.0) AND F_At(aStatus[12],0.0) AND F_At(aStatus[10],1.0);
            END_IF
        (* D2 正向切割需下压和盘刀下降到位且盘刀运行；回刀需盘刀抬起。 *)
        2:
            IF ((aRequest[i].eAction=E_DeviceAction.Position) AND (aRequest[i].lrTarget>stRecipe.lrCutHome+0.01))
               OR ((aRequest[i].eAction=E_DeviceAction.Jog) AND (aRequest[i].lrVelocity>0.0)) THEN
                xAllowed:=xAllowed AND F_At(aStatus[9],1.0) AND F_At(aStatus[17],1.0) AND aStatus[3].xActive;
            ELSE xAllowed:=xAllowed AND xKnifeUp;
            END_IF
        (* D7 机械手分点动、拉料、抬升平移与下降回位分别校验，保持后退/下降/回位顺序。 *)
        7:
            xAllowed:=xAllowed AND xKnifeUp AND xPressUp;
            IF aRequest[i].eAction=E_DeviceAction.Jog THEN
                xAllowed:=xAllowed AND F_At(aStatus[15],1.0) AND xClampOpen;
            ELSIF ABS(aRequest[i].lrTarget-stRecipe.lrGripperHome)<0.01 THEN
                xAllowed:=xAllowed AND F_At(aStatus[15],0.0) AND xClampOpen;
            ELSIF ABS(aRequest[i].lrTarget-stRecipe.lrGripperPull)<0.01 THEN
                xAllowed:=xAllowed AND F_At(aStatus[15],1.0) AND F_At(aStatus[16],1.0);
            ELSE xAllowed:=xAllowed AND F_At(aStatus[15],1.0) AND xClampOpen;
            END_IF
        END_CASE
    END_IF
    (* 互锁不满足则用 Stop 覆盖该设备请求；记录最后一个被阻挡编号，便于排查。 *)
    IF NOT xAllowed THEN
        IF aRequest[i].eAction<>E_DeviceAction.None THEN uiBlockedDevice:=INT_TO_UINT(i); END_IF
        aCommand[i].eAction:=E_DeviceAction.Stop;
    END_IF
END_FOR
