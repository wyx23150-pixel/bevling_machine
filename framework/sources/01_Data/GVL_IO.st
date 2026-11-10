(* 模块说明：逻辑 I/O 预留接口，尚未绑定物理地址。数字输出数组当前每周期清零；G2 当前料型仅用于观察。 *)
VAR_GLOBAL
    (* 当前均为普通逻辑变量，没有 AT %Q / %I 物理地址绑定。 *)
    xSafetyOK : BOOL; (* 安全许可接口或仿真许可，TRUE 允许；不等同于安全级急停回路。 *)
    stPanelInputs : ST_PanelInputs; (* 实体面板的模式旋钮、初始化、启动、停止、复位逻辑信号；急停走独立安全许可。 *)
    xMaterialAtLength : BOOL; (* 真实光电到位预留输入，当前未映射物理输入，仿真时不采用此值。 *)
    axDigitalInputs : ARRAY[0..31] OF BOOL; (* 预留数字输入位，索引 0..31；当前未映射到真实输入。 *)
    axDigitalOutputs : ARRAY[0..31] OF BOOL; (* 预留数字输出位，索引 0..31；当前由 FB_IOMap 每周期清 FALSE。 *)
    uiG2BandActive : UINT; (* G2 当前实际下降的料型带号 300/450/600；0 表示三缸全部提升，供诊断观察。 *)
END_VAR
