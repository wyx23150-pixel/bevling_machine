(* 模块说明：仿真开关和待执行配方。参数生效时机见 ST_Recipe；关闭仿真当前报 3001，未接入真实设备。 *)
VAR_GLOBAL
    (* 以下默认值仅供软件仿真，不能直接作为已确认的生产参数。 *)
    xSimulation : BOOL := TRUE; (* TRUE 使用内部仿真；当前 FALSE 报未实现 3001，不会接管真实运动。 *)
    xContinuous : BOOL := FALSE; (* 本地工程配置的单循环/连续选择；上位机启停帧不修改此设置，默认单循环。 *)
    xAllowRemoteStartStop : BOOL := FALSE; (* 本地工程配置授权远程启停，默认 FALSE；不授予改模式、初始化或复位权限，也不映射给上位机写。 *)
    stRecipe : ST_Recipe; (* 待执行配方：初始化和自动启动时校验并取快照，运行中修改不会立即生效。 *)
    xUseRealPanel : BOOL := TRUE; (* TRUE 读物理面板按钮/旋钮；FALSE 读仿真面板。与 xSimulation 解耦，后者恒为 TRUE。 *)
END_VAR
