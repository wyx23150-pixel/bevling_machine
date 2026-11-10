FUNCTION_BLOCK FB_IOMap
(* 模块说明：设备输出到物理 I/O 的唯一下沉点。真实气缸的阀电平在此写到 GVL_IO_Physical，
   同时仍维护逻辑输出数组供诊断观察。G2 三个侧挡阀在这里按料型逐路下沉。 *)
VAR_INPUT
    aCommand : ARRAY[1..17] OF ST_DeviceCommand; (* 最终设备命令，当前仅用于诊断，不直接驱动输出。 *)
    aStatus : ARRAY[1..17] OF ST_DeviceStatus; (* 各设备的反馈数组 1..17，供判断忙、完成序号、故障和位置。 *)
    aValveOut : ARRAY[1..17] OF BOOL; (* 设备管理器给出的阀电气电平 1..17，真实气缸在此下沉到物理点。 *)
    aValveOutAux : ARRAY[1..17] OF BOOL; (* 第二个执行器的阀电气电平 1..17；G1 右压板在此下沉到物理点。 *)
    aG2Valve : ARRAY[1..3] OF BOOL; (* G2 三个侧挡阀电气电平 1=300，2=450，3=600。 *)
    uiG2Band : UINT; (* G2 当前实际下降的料型带号 300/450/600；0 表示三缸全部提升。 *)
END_VAR
VAR_IN_OUT
    axOutputs : ARRAY[0..31] OF BOOL; (* 逻辑数字输出数组 0..31，按阀电平填写，供在线监视与后续扩展。 *)
END_VAR
VAR
    i : INT; (* 本扫描数组遍历索引；含义及范围以当前 FOR 循环为准。 *)
END_VAR
FUNCTION_BLOCK FB_IOMap
(* 逻辑输出先清零，只由下面明确赋值的位置置位；未被接管的气缸输出保持失电。 *)
FOR i:=0 TO 31 DO axOutputs[i]:=FALSE; END_FOR

(* ===== 1. 真实气缸阀输出：直接写物理映射符号，TRUE=阀得电=设备动作 ===== *)
(* 未接管时 aValveOut / aG2Valve 为 FALSE，物理点随之失电，不会带着上一个状态一直通电。 *)
GVL_IO_Physical.xDoG1ValveL := aValveOut[9];
GVL_IO_Physical.xDoG1ValveR := aValveOutAux[9];
GVL_IO_Physical.xDoG2Valve300 := aG2Valve[1];
GVL_IO_Physical.xDoG2Valve450 := aG2Valve[2];
GVL_IO_Physical.xDoG2Valve600 := aG2Valve[3];
GVL_IO_Physical.xDoG3Valve := aValveOut[11];
GVL_IO_Physical.xDoG9Valve := aValveOut[17];

(* ===== 2. G2 当前料型带号：供诊断观察，不再从下降反馈反推 ===== *)
GVL_IO.uiG2BandActive := uiG2Band;

(* ===== 3. 逻辑输出镜像：便于在监视表按索引观察，不直接对应物理点 ===== *)
axOutputs[0] := aValveOut[9];
axOutputs[1] := aG2Valve[1];
axOutputs[2] := aG2Valve[2];
axOutputs[3] := aG2Valve[3];
axOutputs[4] := aValveOut[11];
axOutputs[5] := aValveOut[17];
