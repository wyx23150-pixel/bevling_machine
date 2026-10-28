(* 模块说明：自动主流程步骤。正常循环从送料等料开始，切割完成后执行三路收尾。 *)
{attribute 'qualified_only'}
TYPE E_AutoStep :
(
    Idle := 0, (* 主流程待机 *)
    FeedWait := 10, (* 正常送料等料，可长期等待 *)
    StopFeed := 20, (* 撤销皮带运行并等待停止 *)
    Push := 30, (* G3 推动气缸动作 *)
    Clearance := 40, (* 并行避让 P/Q，全完成后继续 *)
    Rotate := 50, (* D8 平台旋转到配方角度 *)
    PressDown := 60, (* G1 下压到位 *)
    KnifeDown := 70, (* G9 盘刀下降到位 *)
    SpindleOn := 80, (* D3 盘刀运行状态建立 *)
    Cutting := 90, (* D2 走刀和 G6 吹气，等待指定行程到位 *)
    StopCut := 100, (* 停止盘刀和吹气 *)
    PostCut := 110, (* 抬刀、抬压、并行三路收尾 *)
    Complete := 120, (* 整循环完成，连续模式回送料 *)
    Fault := 900 (* 自动流程错误，退出执行后复位 *)
);
END_TYPE

