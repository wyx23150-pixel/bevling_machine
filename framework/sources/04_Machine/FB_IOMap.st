(* 模块说明：物理 I/O 映射预留。当前数字输出全为 FALSE；G2 按料型形成三个未映射的继电器需求。 *)
FUNCTION_BLOCK FB_IOMap
VAR_INPUT
    uiMaterialModel : UINT; (* 料型选择，仅支持 300/400/600，对应 G2 三个继电器；不是位移。 *)
    aCommand : ARRAY[1..17] OF ST_DeviceCommand; (* 最终设备命令预留输入，当前映射实现未使用该数组。 *)
    aStatus : ARRAY[1..17] OF ST_DeviceStatus; (* 各设备的反馈数组 1..17，供判断忙、完成序号、故障和位置。 *)
END_VAR
VAR_IN_OUT
    axOutputs : ARRAY[0..31] OF BOOL; (* 预留物理数字输出数组 0..31，当前实现每周期强制清 FALSE。 *)
    axG2RelayDemand : ARRAY[1..3] OF BOOL; (* G2 三路逻辑继电器需求：1=300 料型，2=400，3=600；未映射物理输出。 *)
END_VAR
VAR
    i : INT; (* 本扫描数组遍历索引；含义及范围以当前 FOR 循环为准。 *)
END_VAR

(* 物理输出尚未实现；G2 三路继电器需求只用于逻辑观察。 *)
FOR i:=0 TO 31 DO axOutputs[i]:=FALSE; END_FOR
FOR i:=1 TO 3 DO axG2RelayDemand[i]:=FALSE; END_FOR
(* 仅当 G2 下降反馈大于 0.5 时，按运行料型选择一条需求；未绑定物理继电器。 *)
IF aStatus[10].lrPosition>0.5 THEN
    CASE uiMaterialModel OF
    300: axG2RelayDemand[1]:=TRUE;
    400: axG2RelayDemand[2]:=TRUE;
    600: axG2RelayDemand[3]:=TRUE;
    END_CASE
END_IF
