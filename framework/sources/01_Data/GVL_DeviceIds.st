(* 模块说明：设备数组索引常量。D1..D8 对应索引 1..8，D6 保留；G1..G9 对应索引 9..17。

   全机所有设备数组共用这同一套 17 个索引，任何一处写错都会串到别人身上，所以先记住两条换算规则：
     D 编号 直接等于索引           D1..D8  ->  1..8
     G 编号 + 8 = 索引             G1..G9  ->  9..17

   ===== 17 个设备索引对照表 =====
   索引  代号  设备名称            类型       真实适配   绑定对象
   1     D1    送料皮带电机        Motor      仿真       -
   2     D2    切割走刀/回刀轴     Axis       已接       Axis_1     汇川 SV660N
   3     D3    盘刀旋转电机        Motor      已接       pandao     汇川 SV660N，按线性模式配置
   4     D4    定长平移轴          Axis       仿真       ASDA_E3_1  台达 ASDA-B3-E，尚未接管
   5     D5    定长升降            Axis       仿真       -          0=升起避让，1=下降检测
   6     D6    保留                -          -          -          编号空置，不要使用
   7     D7    机械手平移          Axis       仿真       -
   8     D8    平台旋转轴          Axis       已接       ASDA_E3_1  台达 ASDA-B3-E
   9     G1    下压气缸            Cylinder   已接       xDoG1Valve 0=抬起，1=下压
   10    G2    侧挡升降            Cylinder   已接       xDoG2Valve 0=提升，1=下降
   11    G3    推动气缸            Cylinder   已接       xDoG3Valve 0=放开，1=侧推
   12    G4    流利条升降          Cylinder   仿真       -          初始在提升端
   13    G5    喷油阀              Valve      仿真       xDoG5Spray 预留，待分配输出点
   14    G6    吹气阀              Valve      仿真       xDoG6Air   预留，待分配输出点
   15    G7    机械手升降          Cylinder   仿真       -          0=下降，1=提升
   16    G8    机械手夹爪          Cylinder   仿真       -          0=打开，1=夹紧
   17    G9    盘刀升降            Cylinder   已接       xDoG9Valve 0=提升，1=下降进刀

   报警码换算：整机报警 = 10000 + 索引。
     例：10001 = D1 皮带、10009 = G1 下压、10017 = G9 下刀。
     注意 10001 不是「1 号报警」，而是设备 1；真正的设备故障先看 udiErrorID 的千位。
   已在 FB_DeviceManager 中实现真实适配的编号：2、3、8（真实轴）与 9、10、11、17（真实气缸）。
   其余编号把 stReal.axRealDevice[i] 置 TRUE 会立即报 3002，不会被静默当仿真跑。 *)

VAR_GLOBAL CONSTANT
    D1_Belt : UINT := 1; (* D1 送料皮带电机，设备数组索引 1。 *)
    D2_CutFeed : UINT := 2; (* D2 切割走刀/回刀轴，设备数组索引 2。 *)
    D3_Spindle : UINT := 3; (* D3 盘刀旋转电机，设备数组索引 3。 *)
    D4_LengthMove : UINT := 4; (* D4 定长平移轴，设备数组索引 4。 *)
    D5_LengthLift : UINT := 5; (* D5 定长升降，0 升起避让，1 下降检测，索引 5。 *)
    D7_GripperMove : UINT := 7; (* D7 机械手平移，索引 7；索引 6 为保留设备 D6。 *)
    D8_Rotate : UINT := 8; (* D8 平台旋转轴，设备数组索引 8。 *)
    G1_Press : UINT := 9; (* G1 下压气缸，0 抬起，1 下压，索引 9。 *)
    G2_SideStop : UINT := 10; (* G2 侧挡升降，0 提升，1 下降；按料型选择继电器，索引 10。 *)
    G3_Push : UINT := 11; (* G3 推动气缸，0 放开，1 侧推，索引 11。 *)
    G4_RollerLift : UINT := 12; (* G4 流利条升降，0 下降，1 提升，索引 12。 *)
    G5_Spray : UINT := 13; (* G5 喷油阀，连续运行请求表示打开，索引 13。 *)
    G6_Air : UINT := 14; (* G6 吹气阀，切割开始打开、切割结束关闭，索引 14。 *)
    G7_GripperLift : UINT := 15; (* G7 机械手升降，0 下降，1 提升，索引 15。 *)
    G8_GripperClamp : UINT := 16; (* G8 机械手夹爪，0 打开，1 夹紧，索引 16。 *)
    G9_KnifeLift : UINT := 17; (* G9 盘刀升降，0 提升，1 下降，索引 17。 *)
END_VAR
