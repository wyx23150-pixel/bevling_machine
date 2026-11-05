(* 模块说明：物理 I/O 符号层——传感器与电磁阀的唯一入口。
   本 GVL 刻意不带 AT %I* / AT %Q* 地址：通道由 InoProShop 的 I/O 映射页手工绑定，
   因此增减模块、调整 Local Bus 顺序都不会让符号与通道错位（地址由编译器重排，符号绑定不变）。

   极性约定（软件语义固定，与接线方式解耦）：
     DO  TRUE = 阀得电 = 设备动作（下压 / 伸出 / 下降）
     DI  TRUE = 该端到位
   若现场接线极性相反，只在本层取反，不改上层任何流程或互锁代码。

   当前分配建议（硬件工程师可调整，调整后同步改本注释即可）：
     DO  GL20_0032ETN  QB(I) bit0..bit4  -> G1左 / G1右 / G2 / G3 / G9
     DI  GL20_3200END  DI00..DI09        -> G1左(2) G2(2) G3(2) G9(2) G1右(2)
   右压板两点放在末尾，现有 G2/G3/G9 的接线和映射都不用动。
*)
VAR_GLOBAL
    (* ===== 数字输出：GL20-0032ETN，5 路单电控阀，高电平使能 ===== *)
    xDoG1ValveL : BOOL; (* G1 左压板阀：TRUE=下压，FALSE=抬起。建议 QB(I) bit0。 *)
    xDoG1ValveR : BOOL; (* G1 右压板阀：与左阀同命令同步动作。建议 QB(I) bit4。 *)
    xDoG2Valve : BOOL; (* G2 侧挡阀：TRUE=下降挡料，FALSE=提升。建议 QB(I) bit1。 *)
    xDoG3Valve : BOOL; (* G3 侧推阀：TRUE=侧推，FALSE=退回。建议 QB(I) bit2。 *)
    xDoG9Valve : BOOL; (* G9 盘刀升降阀：TRUE=下降进刀，FALSE=提升。建议 QB(I) bit3。 *)

    (* ===== 数字输入：GL20-3200END，G1 双压板 4 点 + 其余 3 台各 2 点 ===== *)
    (* G1 下压左压板 *)
    xDiG1LRetract : BOOL; (* 左缸抬起到位。建议 DI00。 *)
    xDiG1LExtend : BOOL; (* 左缸下压到位。建议 DI01。 *)

    (* G2 侧挡升降 *)
    xDiG2Retract : BOOL; (* G2 提升到位。建议 DI02。 *)
    xDiG2Extend : BOOL; (* G2 下降到位。建议 DI03。 *)

    (* G3 侧推气缸 *)
    xDiG3Retract : BOOL; (* G3 退回到位。建议 DI04。 *)
    xDiG3Extend : BOOL; (* G3 伸出到位。建议 DI05。 *)

    (* G9 盘刀升降 *)
    xDiG9Retract : BOOL; (* G9 提升到位。建议 DI06。 *)
    xDiG9Extend : BOOL; (* G9 下降到位。建议 DI07。 *)

    (* G1 下压右压板：与左压板同属设备索引 9，两组传感器必须同时到位才算该端到位 *)
    xDiG1RRetract : BOOL; (* 右缸抬起到位。建议 DI08。 *)
    xDiG1RExtend : BOOL; (* 右缸下压到位。建议 DI09。 *)

    (* ===== 预留：喷油 / 吹气（本轮不接，占位避免后期改结构） ===== *)
    xDoG5Spray : BOOL; (* 喷油阀：TRUE=喷油。待分配。 *)
    xDoG6Air : BOOL; (* 吹气阀：TRUE=吹气。待分配。 *)
END_VAR
