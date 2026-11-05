(* 模块说明：真实设备接管与调试旁路设置。默认全部 FALSE，行为与纯仿真完全一致。 *)
TYPE ST_RealDeviceSettings :
STRUCT
axRealDevice : ARRAY[1..17] OF BOOL; (* 逐台接管开关：TRUE = 该编号走真实硬件，FALSE = 走仿真。默认全 FALSE。
    索引对照（与 GVL_DeviceIds 的对照表完全一致，换算规则：D 编号=索引，G 编号+8=索引）：
      1=D1 送料皮带    2=D2 切割走刀    3=D3 盘刀旋转    4=D4 定长平移
      5=D5 定长升降    6=D6 保留        7=D7 机械手平移   8=D8 平台旋转
      9=G1 下压       10=G2 侧挡升降   11=G3 侧推       12=G4 流利条升降
      13=G5 喷油      14=G6 吹气       15=G7 机械手升降  16=G8 机械手夹爪
      17=G9 盘刀升降
    本版本只有 2、3、8（真实轴）与 9、10、11、17（真实气缸）已实现适配；
    其中 9（G1 下压）是左右双压板，共 4 个限位、2 路阀，设备索引仍按 1 个计。
    其余编号置 TRUE 会立即报 3002，不会被静默当仿真跑。
    改本数组会让整机强制回 Stopped 并要求重新初始化，见 FB_Machine 的 wRealMask 变化检测。 *)
xRelativeVerify : BOOL; (* 相对验证模式：未回零的真实轴把 Position 解释为正向 d 再反向 d 的往返；回零成功后自动改走绝对定位。 *)
xInterlockBypass : BOOL; (* 预留：手动模式已默认不做机构互锁，本开关当前不影响判定；后续手动按需补互锁时再用。 *)
xSafetyBypass : BOOL; (* 安全许可旁路一级开关；默认 FALSE，必须与二级同时置位才生效。 *)
xSafetyBypassConfirm : BOOL; (* 安全许可旁路二级确认；默认 FALSE，防止误点单开关就旁路。 *)
xUseRealMaterial : BOOL; (* TRUE 才使用真实定长光电；默认 FALSE 继续由 FB_SimPlant 产生来料。 *)
lrVerifyDistance : LREAL := 1.0; (* 相对验证单段距离，mm；首轮建议 0.5~2.0，代码内再限幅 20。 *)
lrVerifyVelocity : LREAL := 2.0; (* 相对验证速度，mm/s；同时作为真实设备的手动速度上限。 *)
lrVerifyAcceleration : LREAL := 50.0; (* 相对验证加速度，mm/s2。 *)
lrVerifyDeceleration : LREAL := 50.0; (* 相对验证减速度，mm/s2。 *)
tVerifyDwell : TIME := T#500MS; (* 正向到位后的停留，保证 Execute 拉低至少一个扫描以形成新上升沿。 *)
lrVerifyMeasuredByHand : LREAL; (* 人工用百分表量到的正向段实际位移，mm；用于核对轴单位标定。 *)
lrHomePosition : LREAL := 0.0; (* 预留：回零完成后的坐标由轴配置的“回零坐标”决定，MC_Homing 没有 Position 入口，本字段当前不参与下发。 *)
tHomeTimeout : TIME := T#30S; (* 单轴回零超时；超时报 2004，防止找不到原点时无限等待。 *)
END_STRUCT
END_TYPE
