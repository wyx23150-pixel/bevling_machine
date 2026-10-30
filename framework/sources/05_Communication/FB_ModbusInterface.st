(* 模块说明：Modbus 协议 v2：只解析可选的远程启动/停止，发布整机状态。模式只读；参数映射另行配置。 *)
FUNCTION_BLOCK FB_ModbusInterface
VAR_INPUT
    xEnable : BOOL; (* 通信解析许可；首次使能只记录现有序号，防止重放旧命令。 *)
    stStatus : ST_MachineStatus; (* 本模块对外发布的状态；字段含义见其数据类型。 *)
    aStatus : ARRAY[1..17] OF ST_DeviceStatus; (* 各设备的反馈数组 1..17，供判断忙、完成序号、故障和位置。 *)
END_VAR
VAR_IN_OUT
    awRx : ARRAY[0..31] OF WORD; (* v2 接收字：0=版本2，1=序号，2=命令2启动/3停止；3/4 保留且必须为0，不接受模式写入。 *)
    awTx : ARRAY[0..127] OF WORD; (* 发布字缓冲区 0..127；包含确认、状态、报警、计数和位置，详见程序内索引注释。 *)
END_VAR
VAR_OUTPUT
    xRequest : BOOL; (* 解析到一帧合法新命令时给整机的单扫描请求。 *)
    wRequestSequence : WORD; (* 解析出的新命令序号，供整机处理后原样确认。 *)
    stCommand : ST_RemoteCommand; (* 合法新帧产生的单扫描远程启停请求，没有模式字段。 *)
    uiParseResult : UINT; (* 帧格式检查结果：0 合法，2 版本/模式/命令码不合法，非法帧不下发。 *)
END_VAR
VAR
    aSnapshot : ARRAY[0..31] OF WORD; (* 新命令帧快照，读取后再次核对序号，降低写入过程中读取半帧的风险。 *)
    wLastSeen : WORD; (* 已观察过的帧序号，包含非法帧；相同序号不会重复处理。 *)
    xWasEnabled : BOOL; (* 上扫描通信使能状态；首次使能只记录序号，不执行缓冲区旧命令。 *)
    i : INT; (* 本扫描数组遍历索引；含义及范围以当前 FOR 循环为准。 *)
END_VAR

(* 每扫描清除远程启停脉冲；模式、初始化、复位不属于远程命令。 *)
xRequest:=FALSE;
stCommand.xStart:=FALSE;
stCommand.xStop:=FALSE;
IF NOT xEnable OR NOT xWasEnabled THEN
    (* 首次启用仅记录当前序号，避免重新连接时执行缓冲区遗留命令。 *)
    wLastSeen:=awRx[1];
ELSIF (awRx[1]<>0) AND (awRx[1]<>wLastSeen) THEN
    (* v2：0=版本2，1=新序号，2=命令2启动/3停止，3/4 必须0；旧版或带模式的帧被拒绝。 *)
    aSnapshot:=awRx;
    IF aSnapshot[1]=awRx[1] THEN
        wLastSeen:=aSnapshot[1]; wRequestSequence:=aSnapshot[1]; uiParseResult:=0;
        IF (aSnapshot[0]<>2) OR (aSnapshot[3]<>0) OR (aSnapshot[4]<>0)
           OR ((aSnapshot[2]<>2) AND (aSnapshot[2]<>3)) THEN
            uiParseResult:=2;
        ELSE
            (* 合法新帧只产生启停请求，实际接受还须整机检查本地授权、旋钮模式及状态。 *)
            CASE aSnapshot[2] OF
            2: stCommand.xStart:=TRUE;
            3: stCommand.xStop:=TRUE;
            END_CASE
            xRequest:=TRUE;
        END_IF
    END_IF
END_IF
xWasEnabled:=xEnable;
(* 发布缓冲区是只读反馈，实际寄存器地址与参数下发映射尚未接入。 *)
FOR i:=0 TO 127 DO awTx[i]:=0; END_FOR
(* 0=协议版本2；1=整机处理序号；2=处理结果。 *)
awTx[0]:=2; awTx[1]:=stStatus.wRemoteAckSequence; awTx[2]:=UINT_TO_WORD(stStatus.uiRemoteResult);
(* 3=整机状态；4=自动主步骤。 *)
awTx[3]:=TO_WORD(stStatus.eState); awTx[4]:=TO_WORD(stStatus.eAutoStep);
(* 5/6=报警低字/高字；7/8=循环计数低字/高字。 *)
awTx[5]:=UDINT_TO_WORD(stStatus.udiAlarm); awTx[6]:=UDINT_TO_WORD(SHR(stStatus.udiAlarm,16));
awTx[7]:=UDINT_TO_WORD(stStatus.udiCycleCount); awTx[8]:=UDINT_TO_WORD(SHR(stStatus.udiCycleCount,16));
(* 9=仿真；10=已初始化；11=料到位；12=运行料型。 *)
awTx[9]:=BOOL_TO_WORD(stStatus.xSimulation); awTx[10]:=BOOL_TO_WORD(stStatus.xInitialized);
awTx[11]:=BOOL_TO_WORD(stStatus.xMaterialAtLength); awTx[12]:=UINT_TO_WORD(stStatus.uiActiveMaterialModel);
(* 13=解析器观察序号；14=格式结果0合法/2非法；15=实体旋钮模式0手动/1自动；16=远程启停授权。 *)
awTx[13]:=wRequestSequence; awTx[14]:=UINT_TO_WORD(uiParseResult);
awTx[15]:=TO_WORD(stStatus.eMode);
awTx[16]:=BOOL_TO_WORD(stStatus.xRemoteStartStopAllowed);
(* 17=真实设备接管掩码；18=安全来源0仿真/1真实/2调试旁路；19=是否相对验证；20=初始化拒绝原因。 *)
(* 上位机不能只看 xSimulation：混跑时它恒为 TRUE，必须结合 17 号字判断哪些编号已接实机。 *)
awTx[17]:=stStatus.wRealDeviceMask; awTx[18]:=UINT_TO_WORD(stStatus.uiSafetySource);
awTx[19]:=BOOL_TO_WORD(stStatus.xRelativeVerify); awTx[20]:=UINT_TO_WORD(stStatus.uiInitReject);
(* awTx[32..48]：设备 1..17 位置，按 0.1 工程单位缩放，解读为有符号 INT。 *)
FOR i:=1 TO 17 DO awTx[31+i]:=INT_TO_WORD(LREAL_TO_INT(aStatus[i].lrPosition*10.0)); END_FOR
