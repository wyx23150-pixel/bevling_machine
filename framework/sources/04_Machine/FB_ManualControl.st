(* 模块说明：将手动按钮转为统一设备请求。点动松开即取消；定位与回零请求保持到本次完成；D6 不调度。 *)
FUNCTION_BLOCK FB_ManualControl
VAR_INPUT
	xEnable : BOOL; (* 手动模式且按钮释放联锁已满足时允许；未使能也同步按钮快照。 *)
	stReal : ST_RealDeviceSettings; (* 真实设备接管设置；真实编号的手动速度收紧到验证速度。 *)
	aManual : ARRAY[1..17] OF ST_ManualCommand; (* 各设备手动请求，索引 1..17；进入手动后先释放所有按钮再允许动作。 *)
END_VAR
VAR_IN_OUT
	aCommand : ARRAY[1..17] OF ST_DeviceCommand; (* 统一设备请求数组 1..17；子流程写请求，设备管理器执行。 *)
	aStatus : ARRAY[1..17] OF ST_DeviceStatus; (* 各设备的反馈数组 1..17，供判断忙、完成序号、故障和位置。 *)
	udiCounter : UDINT; (* 全机共享的动作序号计数器，通过引用传递；由 F_NextID 分配，0 不使用。 *)
END_VAR
VAR_OUTPUT
	uiRejectDevice : UINT; (* 本扫描最后一个手动拒绝设备索引；0 无，常见原因是冲突按钮或不支持该动作。 *)
END_VAR
VAR
	aPrev : ARRAY[1..17] OF ST_ManualCommand; (* 上扫描手动按钮快照；即使禁用仍更新，防止按住按钮切模式后被误作新上升沿。 *)
	aPending : ARRAY[1..17] OF ST_DeviceCommand; (* 手动定位或回零的锁存请求，直到本次命令完成；点动或运行优先时清除。 *)
	aRunID : ARRAY[1..17] OF UDINT; (* 各设备按住运行/点动时保持的序号，按钮释放后归零。 *)
	i : INT; (* 本扫描数组遍历索引；含义及范围以当前 FOR 循环为准。 *)
	lrVelocity : LREAL; (* 本扫描限幅后的手动速度，取绝对值限幅 0.1..100；反向点动时变为负值。 *)
	lrVelocityMax : LREAL; (* 本扫描速度上限；真实设备收紧到验证速度，防止全速冲出。 *)
	uiPressed : UINT; (* 本扫描该设备同时按下的手动按钮个数；大于 1 视为冲突并拒绝。 *)
END_VAR

(* 每扫描重新判断按钮冲突；无合法请求的设备由整机统一撤销动作。 *)
uiRejectDevice:=0;
FOR i:=1 TO 17 DO
    IF NOT xEnable THEN
        aPending[i].eAction:=E_DeviceAction.None;
        aRunID[i]:=0;
    ELSIF i<>6 THEN
        (* 先撤销本设备请求，只有命中合法按钮时才在下面重新写入。否则松开点动后，
           上一扫描的 Jog 会一直残留在共享请求数组里，真实轴靠 None/Stop 停止的逻辑永远等不到。 *)
        aCommand[i]:=F_Command(E_DeviceAction.None,0,0.0,0.0);
        (* 真实设备的手动速度收紧到验证速度，避免首次试车全速冲出去；仿真仍用 0.1..100。 *)
        lrVelocityMax:=100.0;
        IF stReal.axRealDevice[i] THEN lrVelocityMax:=LIMIT(0.1,stReal.lrVerifyVelocity,100.0); END_IF
        lrVelocity:=LIMIT(0.1,ABS(aManual[i].lrVelocity),lrVelocityMax);
        (* 任意两个手动按钮同时按下都算冲突：正反点动、点动与定位/运行/回零、定位与运行/回零、运行与回零。 *)
        uiPressed:=0;
        IF aManual[i].xJogPositive THEN uiPressed:=uiPressed+1; END_IF
        IF aManual[i].xJogNegative THEN uiPressed:=uiPressed+1; END_IF
        IF aManual[i].xMove THEN uiPressed:=uiPressed+1; END_IF
        IF aManual[i].xRun THEN uiPressed:=uiPressed+1; END_IF
        IF aManual[i].xHome THEN uiPressed:=uiPressed+1; END_IF
        IF uiPressed>1 THEN
            uiRejectDevice:=INT_TO_UINT(i); aPending[i].eAction:=E_DeviceAction.None;
        (* 点动电平控制，只支持 D2/D4/D5/D7/D8；速度符号决定方向，松开后不保持点动。 *)
        ELSIF aManual[i].xJogPositive OR aManual[i].xJogNegative THEN
            aPending[i].eAction:=E_DeviceAction.None;
            IF aRunID[i]=0 THEN aRunID[i]:=F_NextID(udiCounter); END_IF
            IF aManual[i].xJogNegative THEN lrVelocity:=-lrVelocity; END_IF
            IF (i=2) OR (i=4) OR (i=5) OR (i=7) OR (i=8) THEN
                aCommand[i]:=F_Command(E_DeviceAction.Jog,aRunID[i],0.0,lrVelocity);
            ELSE uiRejectDevice:=INT_TO_UINT(i);
            END_IF
        (* 连续运行电平控制，仅允许皮带、盘刀、喷油和吹气；盘刀接真实轴后走 FB_RealAxis 的 Run 相位。 *)
        ELSIF aManual[i].xRun THEN
            aPending[i].eAction:=E_DeviceAction.None;
            IF (i=1) OR (i=3) OR (i=13) OR (i=14) THEN
                IF aRunID[i]=0 THEN aRunID[i]:=F_NextID(udiCounter); END_IF
                aCommand[i]:=F_Command(E_DeviceAction.Run,aRunID[i],0.0,lrVelocity);
            ELSE uiRejectDevice:=INT_TO_UINT(i);
            END_IF
        (* 回零：上升沿锁存一次请求，之后每扫描重发直到完成；真实轴 D2/D8，D4 为仿真但保留入口。
           D3 盘刀是连续旋转主轴，只做 Run 不做回零，因此不在本白名单内。
           这里不能像点动那样在分支开头清 aPending —— 回零是保持型动作，清了就只剩一个扫描周期，
           设备刚接收就会被下一扫描的 None 撤销，表现为「下发了但不动」。 *)
        ELSIF aManual[i].xHome THEN
            aRunID[i]:=0;
            IF (i=2) OR (i=4) OR (i=8) THEN
                IF NOT aPrev[i].xHome THEN
                    aPending[i]:=F_Command(E_DeviceAction.Home,F_NextID(udiCounter),0.0,0.0);
                END_IF
                IF aPending[i].eAction<>E_DeviceAction.None THEN
                    aCommand[i]:=aPending[i];
                    IF F_Done(aStatus[i],aPending[i].udiID) THEN aPending[i].eAction:=E_DeviceAction.None; END_IF
                END_IF
            ELSE
                (* 不支持的编号：清掉可能从定位继承来的请求，避免继续执行上一个动作。 *)
                uiRejectDevice:=INT_TO_UINT(i);
                aPending[i].eAction:=E_DeviceAction.None;
            END_IF
        ELSE
            aRunID[i]:=0;
            (* 定位仅在按钮上升沿锁存目标和序号，然后持续等待本次完成。 *)
            IF aManual[i].xMove AND NOT aPrev[i].xMove THEN
                IF (i<>1) AND (i<>3) AND (i<>13) AND (i<>14) THEN
                    aPending[i]:=F_Command(E_DeviceAction.Position,F_NextID(udiCounter),aManual[i].lrTarget,lrVelocity);
                ELSE uiRejectDevice:=INT_TO_UINT(i);
                END_IF
            END_IF
            IF aPending[i].eAction<>E_DeviceAction.None THEN
                aCommand[i]:=aPending[i];
                IF F_Done(aStatus[i],aPending[i].udiID) THEN aPending[i].eAction:=E_DeviceAction.None; END_IF
            END_IF
        END_IF
    END_IF
    (* 禁用时仍同步按钮快照，避免按住定位按钮切入手动后产生虚假的新上升沿。 *)
    aPrev[i]:=aManual[i];
END_FOR
