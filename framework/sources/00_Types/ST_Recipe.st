(* 模块说明：加工配方。初始化和自动启动时校验并复制到运行配方，避免运行中参数变化影响当前工序。 *)
TYPE ST_Recipe :
STRUCT
uiMaterialModel : UINT := 300; (* 料型选择，仅支持 300/400/600，对应 G2 三个继电器；不是位移。 *)
lrCutHome : LREAL := 0.0; (* D2 回刀起点；切割终点为该位置加 lrCutLength。 *)
lrCutLength : LREAL := 80.0; (* D2 本次切割行程，示例默认 80；到达指定终点才结束切割。 *)
lrCutVelocity : LREAL := 10.0; (* D2 切割进给速度；示例参数，接实机前确认工程单位。 *)
lrPositionVelocity : LREAL := 10.0; (* 其余定位动作的公共请求速度，当前为仿真示例。 *)
lrBeltVelocity : LREAL := 10.0; (* D1 皮带运行速度请求，当前未换算到实际驱动器单位。 *)
lrSpindleVelocity : LREAL := 10.0; (* D3 盘刀运行速度请求，当前不是已标定的实际转速。 *)
lrLengthPosition : LREAL := 100.0; (* D4 定长检测工作位置；到位后再令 D5 下降。 *)
lrLengthClear : LREAL := 0.0; (* D4 切割前避让位置；移动前须 D5 升起。 *)
lrRotateAngle : LREAL := 0.0; (* D8 平台旋转目标角度，示例范围为正负 360，实机角度单位待标定。 *)
lrGripperFront : LREAL := 100.0; (* D7 机械手前进取料位置。 *)
lrGripperPull : LREAL := 200.0; (* D7 夹紧后拉料目标位置。 *)
lrGripperBack : LREAL := 50.0; (* D7 松开后的抬升后退位置；到位后先下降，再最终回位。 *)
lrGripperHome : LREAL := 0.0; (* D7 机械手下降后最终回位的位置。 *)
tSpray : TIME := T#300MS; (* 收尾支线 A 的喷油保持时间；该步结束后撤销喷油请求。 *)
tStepTimeout : TIME := T#30S; (* 单动作步骤超时时间；正常送料等料阶段不套用此超时。 *)
END_STRUCT
END_TYPE

