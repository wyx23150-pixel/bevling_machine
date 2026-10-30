(* 模块说明：真实设备接管设置的唯一入口。默认全部 FALSE，整机行为与改造前完全一致。 *)
VAR_GLOBAL
	stSettings : ST_RealDeviceSettings; (* 接管开关、验证参数、旁路开关集中在此，便于 HMI 与调试统一读写。 *)
END_VAR
