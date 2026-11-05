(* 模块说明：检查框架允许的料型、速度、行程和位置顺序。通过仅表示符合示例边界，不代表实机参数已经确认。 *)
FUNCTION F_RecipeValid : BOOL
VAR_INPUT
    stRecipe : ST_Recipe; (* 待校验配方或上层传入的运行配方，字段含义见 ST_Recipe。 *)
END_VAR

(* 示例边界：切长 0..1000、速度 0..300、角度正负360，并要求机械手回位<后退<前进<拉料。边界是否适合实机仍需标定。 *)
F_RecipeValid := ((stRecipe.uiMaterialModel = 300) OR
    (stRecipe.uiMaterialModel = 400) OR (stRecipe.uiMaterialModel = 600))
    AND (stRecipe.lrCutLength > 0.0) AND (stRecipe.lrCutLength <= 1000.0)
    AND (stRecipe.lrCutVelocity > 0.0) AND (stRecipe.lrCutVelocity <= 300.0)
    AND (stRecipe.lrReturnVelocity > 0.0) AND (stRecipe.lrReturnVelocity <= 300.0)
    AND (stRecipe.lrPositionVelocity > 0.0) AND (stRecipe.lrPositionVelocity <= 100.0)
    AND (stRecipe.lrBeltVelocity > 0.0) AND (stRecipe.lrBeltVelocity <= 100.0)
    AND (stRecipe.lrSpindleVelocity > 0.0) AND (stRecipe.lrSpindleVelocity <= 100.0)
    AND (stRecipe.tStepTimeout >= T#1S) AND (stRecipe.tSpray > T#0MS)
    AND (ABS(stRecipe.lrCutHome) <= 500.0)
    AND (ABS(stRecipe.lrCutHome + stRecipe.lrCutLength) <= 1200.0)
    AND (ABS(stRecipe.lrLengthPosition) <= 1000.0)
    AND (ABS(stRecipe.lrLengthClear) <= 1000.0)
    AND (ABS(stRecipe.lrRotateAngle) <= 360.0)
    AND (stRecipe.lrGripperHome < stRecipe.lrGripperBack)
    AND (stRecipe.lrGripperBack < stRecipe.lrGripperFront)
    AND (stRecipe.lrGripperFront < stRecipe.lrGripperPull)
    AND (ABS(stRecipe.lrGripperPull) <= 1000.0);
