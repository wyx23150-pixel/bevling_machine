(* 模块说明：物理 I/O 符号层——传感器与电磁阀的唯一入口。
   本 GVL 刻意不带 AT %I* / AT %Q* 地址：通道由 InoProShop 的 I/O 映射页手工绑定，
   因此增减模块、调整 Local Bus 顺序都不会让符号与通道错位（地址由编译器重排，符号绑定不变）。

   极性约定（软件语义固定，与接线方式解耦）：
     DO  TRUE = 阀得电 = 设备动作（下压 / 伸出 / 下降）
     DI  TRUE = 该端到位
   若现场接线极性相反，只在本层取反，不改上层任何流程或互锁代码。

   当前分配建议（硬件工程师可调整，调整后同步改本注释即可）：
     DO  GL20_0032ETN  QB(I) bit0..bit4  -> G1左 / G1右 / G2-300 / G2-450 / G2-600
     DO  GL20_0032ETN  QB(I) bit5..bit6  -> G9 / 备用
     DO  指示灯另分配                    -> 绿灯 / 红灯
     DI  GL20_3200END  DI00..DI09        -> G1左(2) G2-300(2) G3(2) G9(2) G1右(2)
     DI  新增 4 点                       -> G2-450(2) G2-600(2)

   注意：G2 从单缸改成 300/450/600 三缸后，输出多占 2 点、输入多占 4 点。
   3200END 的 16 点 DI 原本已用 10 点，加 4 点后剩 2 点，仍然不够面板 8 点用，
   面板输入必须另加一块 DI 模块（这一点与改造前结论一致）。
   旧符号 xDoG2Valve / xDiG2Retract / xDiG2Extend 已停用，保留仅为避免已画好的
   映射页断开时报“符号不存在”，物理通道改绑到下方三个新阀与六个新限位符号。
*)
VAR_GLOBAL
    (* ===== 数字输出：GL20-0032ETN，单电控阀，高电平使能 ===== *)
    xDoG1ValveL : BOOL; (* G1 左压板阀：TRUE=下压，FALSE=抬起。建议 QB(I) bit0。 *)
    xDoG1ValveR : BOOL; (* G1 右压板阀：与左阀同命令同步动作。建议 QB(I) bit1。 *)
    xDoG2Valve300 : BOOL; (* G2 料型 300 侧挡阀：TRUE=该缸下降挡料，FALSE=提升。建议 QB(I) bit2。 *)
    xDoG2Valve450 : BOOL; (* G2 料型 450 侧挡阀：TRUE=该缸下降挡料，FALSE=提升。建议 QB(I) bit3。 *)
    xDoG2Valve600 : BOOL; (* G2 料型 600 侧挡阀：TRUE=该缸下降挡料，FALSE=提升。建议 QB(I) bit4。 *)
    xDoG3Valve : BOOL; (* G3 侧推阀：TRUE=侧推，FALSE=退回。建议 QB(I) bit5。 *)
    xDoG9Valve : BOOL; (* G9 盘刀升降阀：TRUE=下降进刀，FALSE=提升。建议 QB(I) bit6。 *)

    (* ===== 已停用：G2 原单缸阀。物理接线改绑 xDoG2Valve300/450/600，本符号保留不复用。 ===== *)
    xDoG2Valve : BOOL; (* 停用：G2 单缸阀旧符号，程序不再写入，保留仅为兼容已有映射页。 *)

    (* ===== 面板指示灯：两个纯输出，只有电平没有反馈 ===== *)
    xDoLampGreen : BOOL; (* 绿灯：手动/就绪常亮，自动循环运行中慢闪。 *)
    xDoLampRed : BOOL; (* 红灯：停机或故障时常亮。 *)

    (* ===== 数字输入：GL20-3200END，G1 双压板 4 点 + G3/G9 各 2 点 + G2 三缸 6 点 ===== *)
    (* G1 下压左压板 *)
    xDiG1LRetract : BOOL; (* 左缸抬起到位。建议 DI00。 *)
    xDiG1LExtend : BOOL; (* 左缸下压到位。建议 DI01。 *)

    (* G2 侧挡 300 缸 *)
    xDiG2_300Retract : BOOL; (* 300 缸提升到位。建议 DI02。 *)
    xDiG2_300Extend : BOOL; (* 300 缸下降到位。建议 DI03。 *)

    (* G3 侧推气缸 *)
    xDiG3Retract : BOOL; (* G3 退回到位。建议 DI04。 *)
    xDiG3Extend : BOOL; (* G3 伸出到位。建议 DI05。 *)

    (* G9 盘刀升降 *)
    xDiG9Retract : BOOL; (* G9 提升到位。建议 DI06。 *)
    xDiG9Extend : BOOL; (* G9 下降到位。建议 DI07。 *)

    (* G1 下压右压板：与左压板同属设备索引 9，两组传感器必须同时到位才算该端到位 *)
    xDiG1RRetract : BOOL; (* 右缸抬起到位。建议 DI08。 *)
    xDiG1RExtend : BOOL; (* 右缸下压到位。建议 DI09。 *)

    (* G2 侧挡 450 / 600 缸：新增 4 点，3200END 已无空位，需另加 DI 模块或换 32 点模块 *)
    xDiG2_450Retract : BOOL; (* 450 缸提升到位。 *)
    xDiG2_450Extend : BOOL; (* 450 缸下降到位。 *)
    xDiG2_600Retract : BOOL; (* 600 缸提升到位。 *)
    xDiG2_600Extend : BOOL; (* 600 缸下降到位。 *)

    (* ===== 已停用：G2 原单缸限位。改用上方三缸各自的六个限位符号。 ===== *)
    xDiG2Retract : BOOL; (* 停用：G2 单缸提升到位旧符号，程序不再读取。 *)
    xDiG2Extend : BOOL; (* 停用：G2 单缸下降到位旧符号，程序不再读取。 *)

    (* ===== 定长光电：D6，遮挡=有料。通道由映射页手工绑定，接哪个模块哪一位都行 ===== *)
    xDiMaterialLength : BOOL; (* 定长光电：TRUE=被遮挡=料已到位。建议接在还空着的 DI 上。 *)

    (* ===== 预留：喷油 / 吹气（本轮不接，占位避免后期改结构） ===== *)
    xDoG5Spray : BOOL; (* 喷油阀：TRUE=喷油。待分配。 *)
    xDoG6Air : BOOL; (* 吹气阀：TRUE=吹气。待分配。 *)

    (* ===== 测试控制面板输入：符号名固定，通道同样由映射页手工绑定 ===== *)
    (* 极性：除急停与停止外，均为常开触点，按下/到位为 TRUE。 *)
    xDiPanelAutoMode : BOOL; (* 自动/手动旋钮：TRUE=自动，FALSE=手动。 *)
    xDiPanelSafetyPermit : BOOL; (* 安全许可旋钮：TRUE=许可。 *)
    xDiEStop : BOOL; (* 急停自锁按钮，常开，按下=TRUE=不安全；断线读 FALSE 软件无法分辨，需外部安全回路。 *)
    xDiPanelRunStart : BOOL; (* 启动按钮，常开，按下=TRUE；上升沿把整机置为运行态。 *)
    xDiPanelRunStop : BOOL; (* 停止按钮，常闭：未按=TRUE，按下=FALSE；逻辑层取反后按上升沿处理。 *)
    xDiPanelStart : BOOL; (* start 按钮，常开，按下=TRUE；自动循环启动，须已初始化到 Ready。 *)
    xDiPanelInit : BOOL; (* 初始化按钮，常开，按下=TRUE。 *)
    xDiPanelReset : BOOL; (* 报警复位按钮，常开，按下=TRUE。 *)
END_VAR
