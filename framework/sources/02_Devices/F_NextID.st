(* 模块说明：生成本次动作的非零序号。计数到最大值后回到 1，用于排除上一步残留的完成反馈。 *)
FUNCTION F_NextID : UDINT
VAR_IN_OUT
    udiCounter : UDINT; (* 全机共享的动作序号计数器，通过引用传递；由 F_NextID 分配，0 不使用。 *)
END_VAR
FUNCTION F_NextID : UDINT
(* 最大值之后回到 1，跳过无效序号 0；同一机台所有流程共享该计数器。 *)
IF udiCounter = 16#FFFFFFFF THEN udiCounter := 1;
ELSE udiCounter := udiCounter + 1;
END_IF
F_NextID := udiCounter;
