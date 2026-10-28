"""Build reviewable IEC ST objects for the simulation-first machine framework.

Run locally to regenerate manifest.json and sources/. Import uses the existing
MCP create/set tools; this script does not connect to any PLC or IDE.
"""
from pathlib import Path
import json
import textwrap
from comments_zh import annotate_object

ROOT = Path(__file__).resolve().parent
OBJECTS = []


def obj(folder, name, kind, declaration, implementation='', **extra):
    declaration = textwrap.dedent(declaration).strip() + '\n'
    implementation = textwrap.dedent(implementation).strip() + '\n' if implementation.strip() else ''
    declaration, implementation = annotate_object(name, declaration, implementation)
    OBJECTS.append(dict(folder=folder, name=name, kind=kind,
                        declaration=declaration, implementation=implementation, **extra))


def enum(name, members):
    obj('00_Types', name, 'dut', "{attribute 'qualified_only'}\nTYPE " + name + ' :\n(\n    ' + ',\n    '.join(members) + '\n);\nEND_TYPE', dutType='Enumeration')


def struct(name, fields):
    obj('00_Types', name, 'dut', f'TYPE {name} :\nSTRUCT\n{textwrap.dedent(fields).strip()}\nEND_STRUCT\nEND_TYPE', dutType='Structure')


enum('E_MachineMode', ['Manual := 0', 'Automatic := 1'])
enum('E_MachineState', ['Stopped := 0', 'Initializing := 10', 'Ready := 20', 'Manual := 30', 'Automatic := 40', 'Fault := 90'])
enum('E_AutoStep', ['Idle := 0', 'FeedWait := 10', 'StopFeed := 20', 'Push := 30', 'Clearance := 40', 'Rotate := 50', 'PressDown := 60', 'KnifeDown := 70', 'SpindleOn := 80', 'Cutting := 90', 'StopCut := 100', 'PostCut := 110', 'Complete := 120', 'Fault := 900'])
enum('E_DeviceAction', ['None := 0', 'Position := 1', 'Run := 2', 'Jog := 3', 'Stop := 4'])
enum('E_DeviceKind', ['Unused := 0', 'Axis := 1', 'Motor := 2', 'Cylinder := 3', 'Valve := 4'])
struct('ST_DeviceCommand', '''
    eAction : E_DeviceAction;
    udiID : UDINT;
    lrTarget : LREAL;
    lrVelocity : LREAL;
''')
struct('ST_DeviceStatus', '''
    xReady : BOOL;
    xBusy : BOOL;
    xActive : BOOL;
    xError : BOOL;
    udiErrorID : UDINT;
    udiAcceptedID : UDINT;
    udiCompletedID : UDINT;
    lrPosition : LREAL;
''')
struct('ST_DeviceConfig', '''
    eKind : E_DeviceKind;
    lrInitialPosition : LREAL;
    lrMinPosition : LREAL := -1000.0;
    lrMaxPosition : LREAL := 1000.0;
    lrMaxVelocity : LREAL := 100.0;
    tSimAction : TIME := T#500MS;
''')
struct('ST_ManualCommand', '''
    xJogPositive : BOOL;
    xJogNegative : BOOL;
    xMove : BOOL;
    xRun : BOOL;
    lrTarget : LREAL;
    lrVelocity : LREAL := 10.0;
''')
struct('ST_OperatorCommand', '''
    eMode : E_MachineMode := E_MachineMode.Manual;
    xInitialize : BOOL;
    xStart : BOOL;
    xStop : BOOL;
    xResetAlarm : BOOL;
    xContinuous : BOOL;
''')
struct('ST_PanelInputs', '''
    xAutoMode : BOOL;
    xInitialize : BOOL;
    xStart : BOOL;
    xStop : BOOL;
    xResetAlarm : BOOL;
''')
struct('ST_RemoteCommand', '''
    xStart : BOOL;
    xStop : BOOL;
''')
struct('ST_Recipe', '''
    uiMaterialModel : UINT := 300;
    lrCutHome : LREAL := 0.0;
    lrCutLength : LREAL := 20.0;
    lrCutVelocity : LREAL := 10.0;
    lrPositionVelocity : LREAL := 10.0;
    lrBeltVelocity : LREAL := 10.0;
    lrSpindleVelocity : LREAL := 10.0;
    lrLengthPosition : LREAL := 100.0;
    lrLengthClear : LREAL := 0.0;
    lrRotateAngle : LREAL := 0.0;
    lrGripperFront : LREAL := 100.0;
    lrGripperPull : LREAL := 200.0;
    lrGripperBack : LREAL := 50.0;
    lrGripperHome : LREAL := 0.0;
    tSpray : TIME := T#300MS;
    tStepTimeout : TIME := T#30S;
''')
struct('ST_SimulationSettings', '''
    xSafetyOK : BOOL := TRUE;
    xAutoMaterial : BOOL := TRUE;
    xMaterialSensor : BOOL;
    tMaterialDelay : TIME := T#1S;
    axStall : ARRAY[1..17] OF BOOL;
    axFault : ARRAY[1..17] OF BOOL;
''')
struct('ST_MachineStatus', '''
    eState : E_MachineState;
    eMode : E_MachineMode;
    eAutoStep : E_AutoStep;
    xSimulation : BOOL;
    xRealBackendAvailable : BOOL;
    xRemoteStartStopAllowed : BOOL;
    xInitialized : BOOL;
    xReady : BOOL;
    xMaterialAtLength : BOOL;
    xCycleComplete : BOOL;
    udiCycleCount : UDINT;
    udiAlarm : UDINT;
    uiBlockedDevice : UINT;
    uiManualReject : UINT;
    uiClearLengthStep : UINT;
    uiClearTransferStep : UINT;
    uiPostStep : UINT;
    uiReturnKnifeStep : UINT;
    uiUnloadStep : UINT;
    uiResetLengthStep : UINT;
    uiInitializeStep : UINT;
    uiActiveMaterialModel : UINT;
    wRemoteAckSequence : WORD;
    uiRemoteResult : UINT;
''')

obj('01_Data', 'GVL_DeviceIds', 'gvl', '''
VAR_GLOBAL CONSTANT
    D1_Belt : UINT := 1;
    D2_CutFeed : UINT := 2;
    D3_Spindle : UINT := 3;
    D4_LengthMove : UINT := 4;
    D5_LengthLift : UINT := 5;
    D7_GripperMove : UINT := 7;
    D8_Rotate : UINT := 8;
    G1_Press : UINT := 9;
    G2_SideStop : UINT := 10;
    G3_Push : UINT := 11;
    G4_RollerLift : UINT := 12;
    G5_Spray : UINT := 13;
    G6_Air : UINT := 14;
    G7_GripperLift : UINT := 15;
    G8_GripperClamp : UINT := 16;
    G9_KnifeLift : UINT := 17;
END_VAR
''')
obj('01_Data', 'GVL_Interface', 'gvl', '''
VAR_GLOBAL
    stPanel : ST_OperatorCommand;
    aManual : ARRAY[1..17] OF ST_ManualCommand;
    stStatus : ST_MachineStatus;
    aDeviceStatus : ARRAY[1..17] OF ST_DeviceStatus;
END_VAR
''')
obj('01_Data','GVL_Parameters','gvl','''
VAR_GLOBAL
    (* Simulation examples only: these are NOT commissioned machine settings. *)
    xSimulation : BOOL := TRUE;
    xContinuous : BOOL := FALSE;
    xAllowRemoteStartStop : BOOL := FALSE;
    stRecipe : ST_Recipe;
END_VAR
''')
obj('01_Data','GVL_Simulation','gvl','''
VAR_GLOBAL
    stSettings : ST_SimulationSettings;
    stPanelInputs : ST_PanelInputs;
END_VAR
''')
obj('01_Data','GVL_IO','gvl','''
VAR_GLOBAL
    (* Unmapped interface. No AT %Q / %I bindings in this framework. *)
    xSafetyOK : BOOL;
    stPanelInputs : ST_PanelInputs;
    xMaterialAtLength : BOOL;
    axDigitalInputs : ARRAY[0..31] OF BOOL;
    axDigitalOutputs : ARRAY[0..31] OF BOOL;
    axG2RelayDemand : ARRAY[1..3] OF BOOL;
END_VAR
''')
obj('01_Data','GVL_Modbus','gvl','''
VAR_GLOBAL
    (* Buffers only; the existing MODBUS_TCP driver is not bound yet. *)
    xEnable : BOOL;
    awRx : ARRAY[0..31] OF WORD;
    awTx : ARRAY[0..127] OF WORD;
END_VAR
''')

obj('02_Devices','F_NextID','function','''
FUNCTION F_NextID : UDINT
VAR_IN_OUT
    udiCounter : UDINT;
END_VAR
''','''
IF udiCounter = 16#FFFFFFFF THEN udiCounter := 1;
ELSE udiCounter := udiCounter + 1;
END_IF
F_NextID := udiCounter;
''')
obj('02_Devices','F_Command','function','''
FUNCTION F_Command : ST_DeviceCommand
VAR_INPUT
    eAction : E_DeviceAction;
    udiID : UDINT;
    lrTarget : LREAL;
    lrVelocity : LREAL;
END_VAR
''','''
F_Command.eAction := eAction;
F_Command.udiID := udiID;
F_Command.lrTarget := lrTarget;
F_Command.lrVelocity := lrVelocity;
''')
obj('02_Devices','F_Done','function','''
FUNCTION F_Done : BOOL
VAR_INPUT
    stStatus : ST_DeviceStatus;
    udiID : UDINT;
END_VAR
''','''
F_Done := (udiID <> 0) AND (stStatus.udiCompletedID = udiID)
    AND NOT stStatus.xBusy AND NOT stStatus.xError;
''')
obj('02_Devices','F_At','function','''
FUNCTION F_At : BOOL
VAR_INPUT
    stStatus : ST_DeviceStatus;
    lrTarget : LREAL;
END_VAR
''','''
F_At := stStatus.xReady AND NOT stStatus.xBusy
    AND NOT stStatus.xError AND (ABS(stStatus.lrPosition-lrTarget) < 0.01);
''')
obj('04_Machine','F_RecipeValid','function','''
FUNCTION F_RecipeValid : BOOL
VAR_INPUT
    stRecipe : ST_Recipe;
END_VAR
''','''
F_RecipeValid := ((stRecipe.uiMaterialModel = 300) OR
    (stRecipe.uiMaterialModel = 400) OR (stRecipe.uiMaterialModel = 600))
    AND (stRecipe.lrCutLength > 0.0) AND (stRecipe.lrCutLength <= 500.0)
    AND (stRecipe.lrCutVelocity > 0.0) AND (stRecipe.lrCutVelocity <= 100.0)
    AND (stRecipe.lrPositionVelocity > 0.0) AND (stRecipe.lrPositionVelocity <= 100.0)
    AND (stRecipe.lrBeltVelocity > 0.0) AND (stRecipe.lrBeltVelocity <= 100.0)
    AND (stRecipe.lrSpindleVelocity > 0.0) AND (stRecipe.lrSpindleVelocity <= 100.0)
    AND (stRecipe.tStepTimeout >= T#1S) AND (stRecipe.tSpray > T#0MS)
    AND (ABS(stRecipe.lrCutHome) <= 500.0)
    AND (ABS(stRecipe.lrCutHome + stRecipe.lrCutLength) <= 1000.0)
    AND (ABS(stRecipe.lrLengthPosition) <= 1000.0)
    AND (ABS(stRecipe.lrLengthClear) <= 1000.0)
    AND (ABS(stRecipe.lrRotateAngle) <= 360.0)
    AND (stRecipe.lrGripperHome < stRecipe.lrGripperBack)
    AND (stRecipe.lrGripperBack < stRecipe.lrGripperFront)
    AND (stRecipe.lrGripperFront < stRecipe.lrGripperPull)
    AND (ABS(stRecipe.lrGripperPull) <= 1000.0);
''')

obj('06_Simulation','FB_SimDevice','fb','''
FUNCTION_BLOCK FB_SimDevice
VAR_INPUT
    xEnable : BOOL;
    xReset : BOOL;
    xStall : BOOL;
    xInjectFault : BOOL;
    stConfig : ST_DeviceConfig;
    stCommand : ST_DeviceCommand;
END_VAR
VAR_OUTPUT
    stStatus : ST_DeviceStatus;
END_VAR
VAR
    xBooted : BOOL;
    xAction : BOOL;
    udiLastID : UDINT;
    lrStart : LREAL;
    lrTarget : LREAL;
    lrJogDelta : LREAL;
    tLastJog : TIME;
    tonAction : TON;
    tonJog : TON;
END_VAR
''','''
IF NOT xBooted THEN
    stStatus.lrPosition := stConfig.lrInitialPosition;
    xBooted := TRUE;
END_IF
IF xReset AND NOT xInjectFault THEN
    stStatus.xError := FALSE; stStatus.udiErrorID := 0;
END_IF
IF xInjectFault THEN stStatus.xError := TRUE; stStatus.udiErrorID := 9001; END_IF
stStatus.xReady := xEnable AND NOT stStatus.xError AND (stConfig.eKind <> E_DeviceKind.Unused);

IF NOT stStatus.xReady OR (stCommand.eAction = E_DeviceAction.None)
   OR (stCommand.eAction = E_DeviceAction.Stop) THEN
    xAction := FALSE; udiLastID := 0;
    stStatus.xBusy := FALSE; stStatus.xActive := FALSE;
    stStatus.udiAcceptedID := 0; stStatus.udiCompletedID := 0;
ELSIF (stCommand.udiID <> 0) AND (stCommand.udiID <> udiLastID) THEN
    udiLastID := stCommand.udiID;
    stStatus.udiAcceptedID := udiLastID; stStatus.udiCompletedID := 0;
    lrStart := stStatus.lrPosition; lrTarget := stCommand.lrTarget;
    IF (ABS(stCommand.lrVelocity) > stConfig.lrMaxVelocity)
       OR ((stCommand.eAction = E_DeviceAction.Position) AND
           ((lrTarget < stConfig.lrMinPosition) OR (lrTarget > stConfig.lrMaxPosition))) THEN
        stStatus.xError := TRUE; stStatus.udiErrorID := 2001; xAction := FALSE;
    ELSE
        xAction := stCommand.eAction <> E_DeviceAction.Jog;
        stStatus.xBusy := TRUE; stStatus.xActive := FALSE;
    END_IF
    (* Reset on acceptance; the regular call below starts the new timer. *)
    tonAction(IN := FALSE);
END_IF
tonAction(IN := xAction AND stStatus.xReady, PT := stConfig.tSimAction);
IF xAction AND NOT xStall AND stStatus.xReady THEN
    IF stCommand.eAction = E_DeviceAction.Position THEN
        stStatus.lrPosition := lrStart + (lrTarget-lrStart) *
            MIN(1.0, TIME_TO_LREAL(tonAction.ET) / MAX(1.0, TIME_TO_LREAL(stConfig.tSimAction)));
    END_IF
    IF tonAction.Q THEN
        IF stCommand.eAction = E_DeviceAction.Position THEN stStatus.lrPosition := lrTarget; END_IF
        stStatus.xBusy := FALSE;
        stStatus.xActive := stCommand.eAction = E_DeviceAction.Run;
        stStatus.udiCompletedID := udiLastID;
        xAction := FALSE;
    END_IF
END_IF
tonJog(IN := stStatus.xReady AND (stCommand.eAction = E_DeviceAction.Jog), PT := T#24H);
IF tonJog.IN THEN
    lrJogDelta := TIME_TO_LREAL(tonJog.ET-tLastJog) / 1000.0;
    IF NOT xStall THEN
        stStatus.lrPosition := LIMIT(stConfig.lrMinPosition,
            stStatus.lrPosition+stCommand.lrVelocity*lrJogDelta, stConfig.lrMaxPosition);
    END_IF
    stStatus.xBusy := TRUE; stStatus.xActive := TRUE;
    tLastJog := tonJog.ET;
ELSE tLastJog := T#0MS;
END_IF
IF stStatus.xError THEN
    stStatus.xReady := FALSE; stStatus.xBusy := FALSE; stStatus.xActive := FALSE;
END_IF
''')

for name in ['FB_Axis','FB_Motor','FB_Cylinder','FB_Valve']:
    obj('02_Devices', name, 'fb', f'''
FUNCTION_BLOCK {name}
VAR_INPUT
    xSimulation : BOOL;
    xEnable : BOOL;
    xReset : BOOL;
    xStall : BOOL;
    xInjectFault : BOOL;
    stConfig : ST_DeviceConfig;
    stCommand : ST_DeviceCommand;
END_VAR
VAR_OUTPUT
    stStatus : ST_DeviceStatus;
END_VAR
VAR
    fbSimulation : FB_SimDevice;
END_VAR
''','''
(* The real hardware adapter is intentionally not commissioned. *)
fbSimulation(xEnable := xEnable AND xSimulation, xReset := xReset,
    xStall := xStall, xInjectFault := xInjectFault,
    stConfig := stConfig, stCommand := stCommand);
stStatus := fbSimulation.stStatus;
IF NOT xSimulation THEN
    stStatus.xReady := FALSE; stStatus.xBusy := FALSE; stStatus.xActive := FALSE;
    stStatus.xError := TRUE; stStatus.udiErrorID := 3001;
END_IF
''')

obj('02_Devices','FB_DeviceManager','fb','''
FUNCTION_BLOCK FB_DeviceManager
VAR_INPUT
    xEnable : BOOL;
    xSimulation : BOOL;
    xReset : BOOL;
    stSim : ST_SimulationSettings;
    aCommand : ARRAY[1..17] OF ST_DeviceCommand;
END_VAR
VAR_OUTPUT
    aStatus : ARRAY[1..17] OF ST_DeviceStatus;
END_VAR
VAR
    aConfig : ARRAY[1..17] OF ST_DeviceConfig;
    aAxis : ARRAY[1..17] OF FB_Axis;
    aMotor : ARRAY[1..17] OF FB_Motor;
    aCylinder : ARRAY[1..17] OF FB_Cylinder;
    aValve : ARRAY[1..17] OF FB_Valve;
    xBooted : BOOL;
    i : INT;
END_VAR
''','''
IF NOT xBooted THEN
    aConfig[1].eKind := E_DeviceKind.Motor;
    aConfig[2].eKind := E_DeviceKind.Axis;
    aConfig[3].eKind := E_DeviceKind.Motor;
    aConfig[4].eKind := E_DeviceKind.Axis;
    (* D5 is modeled as a positioning lift; 0/1 are simulation up/down points. *)
    aConfig[5].eKind := E_DeviceKind.Axis;
    aConfig[7].eKind := E_DeviceKind.Axis;
    aConfig[8].eKind := E_DeviceKind.Axis;
    FOR i := 9 TO 17 DO aConfig[i].eKind := E_DeviceKind.Cylinder; END_FOR
    aConfig[13].eKind := E_DeviceKind.Valve;
    aConfig[14].eKind := E_DeviceKind.Valve;
    aConfig[12].lrInitialPosition := 1.0;
    FOR i := 1 TO 17 DO
        IF aConfig[i].eKind = E_DeviceKind.Cylinder THEN
            aConfig[i].lrMinPosition := 0.0; aConfig[i].lrMaxPosition := 1.0;
        END_IF
    END_FOR
    xBooted := TRUE;
END_IF
FOR i := 1 TO 17 DO
    CASE aConfig[i].eKind OF
    E_DeviceKind.Axis:
        aAxis[i](xSimulation:=xSimulation,xEnable:=xEnable,xReset:=xReset,
            xStall:=stSim.axStall[i],xInjectFault:=stSim.axFault[i],stConfig:=aConfig[i],stCommand:=aCommand[i]);
        aStatus[i] := aAxis[i].stStatus;
    E_DeviceKind.Motor:
        aMotor[i](xSimulation:=xSimulation,xEnable:=xEnable,xReset:=xReset,
            xStall:=stSim.axStall[i],xInjectFault:=stSim.axFault[i],stConfig:=aConfig[i],stCommand:=aCommand[i]);
        aStatus[i] := aMotor[i].stStatus;
    E_DeviceKind.Cylinder:
        aCylinder[i](xSimulation:=xSimulation,xEnable:=xEnable,xReset:=xReset,
            xStall:=stSim.axStall[i],xInjectFault:=stSim.axFault[i],stConfig:=aConfig[i],stCommand:=aCommand[i]);
        aStatus[i] := aCylinder[i].stStatus;
    E_DeviceKind.Valve:
        aValve[i](xSimulation:=xSimulation,xEnable:=xEnable,xReset:=xReset,
            xStall:=stSim.axStall[i],xInjectFault:=stSim.axFault[i],stConfig:=aConfig[i],stCommand:=aCommand[i]);
        aStatus[i] := aValve[i].stStatus;
    END_CASE
END_FOR
''')

# Stable device indices; D6 is reserved and never scheduled.
def command(i, target, action='Position', token='udiToken', speed='stRecipe.lrPositionVelocity'):
    return f'aCommand[{i}] := F_Command(E_DeviceAction.{action}, {token}, {target}, {speed});'


def done(i, token='udiToken'):
    return f'F_Done(aStatus[{i}], {token})'


def sequence(name, steps, codebase):
    """Each step holds requests until the matching command token completes."""
    decl=f'''FUNCTION_BLOCK {name}
VAR_INPUT
    xExecute : BOOL;
    stRecipe : ST_Recipe;
END_VAR
VAR_IN_OUT
    aCommand : ARRAY[1..17] OF ST_DeviceCommand;
    aStatus : ARRAY[1..17] OF ST_DeviceStatus;
    udiCounter : UDINT;
END_VAR
VAR_OUTPUT
    xDone : BOOL;
    xError : BOOL;
    udiErrorID : UDINT;
    uiStep : UINT;
END_VAR
VAR
    uiPrevStep : UINT := 65535;
    udiToken : UDINT;
    xEntry : BOOL;
    tonStep : TON;
    tonSpray : TON;
END_VAR'''
    impl=['IF NOT xExecute THEN uiStep := 0; xError := FALSE; udiErrorID := 0; END_IF;',
          'xEntry := uiStep <> uiPrevStep;',
          'IF xEntry THEN udiToken := F_NextID(udiCounter); END_IF;',
          'uiPrevStep := uiStep;',
          'tonStep(IN := xExecute AND (uiStep > 0) AND (uiStep < 1000) AND NOT xEntry, PT := stRecipe.tStepTimeout);',
          'tonSpray(IN := xExecute AND (uiStep = 10) AND aStatus[13].xActive, PT := stRecipe.tSpray);',
          'IF xExecute AND NOT xError THEN', 'CASE uiStep OF', '0: uiStep := 10;']
    for idx,(label,commands,condition) in enumerate(steps):
        step=(idx+1)*10; nxt=(idx+2)*10 if idx+1<len(steps) else 1000
        impl.extend([f'{step}: (* {label} *)',*commands,f'IF {condition} THEN uiStep := {nxt}; END_IF;'])
    impl.extend(['1000: ;',f'ELSE xError := TRUE; udiErrorID := {codebase};',
                 'END_CASE;',f'IF tonStep.Q THEN xError := TRUE; udiErrorID := {codebase} + UINT_TO_UDINT(uiStep); END_IF;',
                 'END_IF;', 'xDone := xExecute AND (uiStep = 1000) AND NOT xError;'])
    obj('03_Units',name,'fb',decl,'\n'.join(impl))


sequence('FB_ClearLength', [
 ('P010 length up',[command(5,'0.0')],done(5)),
 ('P020 move length clear',[command(4,'stRecipe.lrLengthClear')],done(4)),
],4100)
sequence('FB_ClearTransfer', [
 ('Q010 roller down',[command(12,'0.0')],done(12)),
 ('Q020 release side push',[command(11,'0.0')],done(11)),
 ('Q030 lower selected side stop',[command(10,'1.0')],done(10)),
],4200)
sequence('FB_ReturnKnife', [
 ('A010 spray before return',[command(13,'0.0','Run',speed='0.0')],'tonSpray.Q'),
 ('A020 return cut axis',[command(2,'stRecipe.lrCutHome')],done(2)),
],4300)
sequence('FB_Unload', [
 ('B010 side stop up',[command(10,'0.0')],done(10)),
 ('B020 rollers up',[command(12,'1.0')],done(12)),
 ('B030 gripper lift up',[command(15,'1.0')],done(15)),
 ('B040 gripper open',[command(16,'0.0')],done(16)),
 ('B050 gripper forward',[command(7,'stRecipe.lrGripperFront')],done(7)),
 ('B060 gripper clamp',[command(16,'1.0')],done(16)),
 ('B070 pull product',[command(7,'stRecipe.lrGripperPull')],done(7)),
 ('B080 gripper open',[command(16,'0.0')],done(16)),
 ('B090 retreat while raised',[command(7,'stRecipe.lrGripperBack')],done(7)),
 ('B100 lower gripper',[command(15,'0.0')],done(15)),
 ('B110 final return while lowered',[command(7,'stRecipe.lrGripperHome')],done(7)),
],4400)
sequence('FB_ResetLength', [
 ('C010 length to detection position',[command(4,'stRecipe.lrLengthPosition')],done(4)),
 ('C020 lower length sensor',[command(5,'1.0')],done(5)),
 ('C030 verify down, detection permission follows physical position',[], 'F_At(aStatus[5],1.0)'),
],4500)
sequence('FB_Initialize', [
 ('SIMULATION initialization: lift knife, press; open gripper',
  [command(17,'0.0'),command(9,'0.0'),command(16,'0.0')], ' AND '.join(done(i) for i in [17,9,16])),
 ('Prepare clear positions', [command(5,'0.0'),command(10,'0.0'),command(11,'0.0'),command(12,'1.0'),command(15,'0.0')],
  ' AND '.join(done(i) for i in [5,10,11,12,15])),
 ('Move to simulation initial coordinates', [command(2,'stRecipe.lrCutHome'),command(4,'stRecipe.lrLengthPosition'),command(7,'stRecipe.lrGripperHome'),command(8,'0.0')],
  ' AND '.join(done(i) for i in [2,4,7,8])),
 ('Length down for detection',[command(5,'1.0')],done(5)),
],4600)

obj('03_Units','FB_ClearanceUnit','fb','''
FUNCTION_BLOCK FB_ClearanceUnit
VAR_INPUT
    xExecute : BOOL;
    stRecipe : ST_Recipe;
END_VAR
VAR_IN_OUT
    aCommand : ARRAY[1..17] OF ST_DeviceCommand;
    aStatus : ARRAY[1..17] OF ST_DeviceStatus;
    udiCounter : UDINT;
END_VAR
VAR_OUTPUT
    xDone : BOOL;
    xError : BOOL;
    udiErrorID : UDINT;
    uiLengthStep : UINT;
    uiTransferStep : UINT;
END_VAR
VAR
    fbLength : FB_ClearLength;
    fbTransfer : FB_ClearTransfer;
END_VAR
''','''
fbLength(xExecute:=xExecute,stRecipe:=stRecipe,aCommand:=aCommand,aStatus:=aStatus,udiCounter:=udiCounter);
fbTransfer(xExecute:=xExecute,stRecipe:=stRecipe,aCommand:=aCommand,aStatus:=aStatus,udiCounter:=udiCounter);
xDone := fbLength.xDone AND fbTransfer.xDone;
xError := fbLength.xError OR fbTransfer.xError;
udiErrorID := MAX(fbLength.udiErrorID,fbTransfer.udiErrorID);
uiLengthStep := fbLength.uiStep; uiTransferStep := fbTransfer.uiStep;
''')
obj('03_Units','FB_PostCut','fb','''
FUNCTION_BLOCK FB_PostCut
VAR_INPUT
    xExecute : BOOL;
    stRecipe : ST_Recipe;
END_VAR
VAR_IN_OUT
    aCommand : ARRAY[1..17] OF ST_DeviceCommand;
    aStatus : ARRAY[1..17] OF ST_DeviceStatus;
    udiCounter : UDINT;
END_VAR
VAR_OUTPUT
    xDone : BOOL;
    xError : BOOL;
    udiErrorID : UDINT;
    uiStep : UINT;
    uiKnifeStep : UINT;
    uiUnloadStep : UINT;
    uiLengthStep : UINT;
END_VAR
VAR
    fbKnife : FB_ReturnKnife;
    fbUnload : FB_Unload;
    fbLength : FB_ResetLength;
    uiPrevStep : UINT := 65535;
    udiToken : UDINT;
    xEntry : BOOL;
    tonStep : TON;
END_VAR
''','''
IF NOT xExecute THEN uiStep := 0; xError := FALSE; udiErrorID := 0; END_IF
xEntry := uiStep <> uiPrevStep;
IF xEntry THEN udiToken := F_NextID(udiCounter); END_IF
uiPrevStep := uiStep;
tonStep(IN:=xExecute AND NOT xEntry AND (uiStep>0) AND (uiStep<1000),PT:=stRecipe.tStepTimeout);
IF xExecute AND NOT xError THEN
    CASE uiStep OF
    0: uiStep := 10;
    10:
        aCommand[17] := F_Command(E_DeviceAction.Position,udiToken,0.0,stRecipe.lrPositionVelocity);
        IF F_Done(aStatus[17],udiToken) THEN uiStep := 20; END_IF
    20:
        aCommand[9] := F_Command(E_DeviceAction.Position,udiToken,0.0,stRecipe.lrPositionVelocity);
        IF F_Done(aStatus[9],udiToken) THEN uiStep := 30; END_IF
    30:
        IF fbKnife.xDone AND fbUnload.xDone AND fbLength.xDone THEN uiStep := 1000; END_IF
    1000: ;
    ELSE xError := TRUE; udiErrorID := 4700;
    END_CASE
    IF tonStep.Q THEN xError := TRUE; udiErrorID := 4700+UINT_TO_UDINT(uiStep); END_IF
END_IF
fbKnife(xExecute:=xExecute AND (uiStep=30),stRecipe:=stRecipe,aCommand:=aCommand,aStatus:=aStatus,udiCounter:=udiCounter);
fbUnload(xExecute:=xExecute AND (uiStep=30),stRecipe:=stRecipe,aCommand:=aCommand,aStatus:=aStatus,udiCounter:=udiCounter);
fbLength(xExecute:=xExecute AND (uiStep=30),stRecipe:=stRecipe,aCommand:=aCommand,aStatus:=aStatus,udiCounter:=udiCounter);
IF fbKnife.xError OR fbUnload.xError OR fbLength.xError THEN
    xError:=TRUE; udiErrorID:=MAX(fbKnife.udiErrorID,MAX(fbUnload.udiErrorID,fbLength.udiErrorID));
END_IF
xDone := xExecute AND (uiStep=1000) AND NOT xError;
uiKnifeStep:=fbKnife.uiStep; uiUnloadStep:=fbUnload.uiStep; uiLengthStep:=fbLength.uiStep;
''')

obj('04_Machine','FB_AutoCycle','fb','''
FUNCTION_BLOCK FB_AutoCycle
VAR_INPUT
    xRun : BOOL;
    xContinuous : BOOL;
    xMaterialAtLength : BOOL;
    stRecipe : ST_Recipe;
END_VAR
VAR_IN_OUT
    aCommand : ARRAY[1..17] OF ST_DeviceCommand;
    aStatus : ARRAY[1..17] OF ST_DeviceStatus;
    udiCounter : UDINT;
END_VAR
VAR_OUTPUT
    eStep : E_AutoStep;
    xDone : BOOL;
    xError : BOOL;
    udiErrorID : UDINT;
    uiClearLengthStep : UINT;
    uiClearTransferStep : UINT;
    uiPostStep : UINT;
    uiReturnKnifeStep : UINT;
    uiUnloadStep : UINT;
    uiResetLengthStep : UINT;
END_VAR
VAR
    ePrevStep : E_AutoStep := E_AutoStep.Fault;
    udiToken : UDINT;
    udiSpindleToken : UDINT;
    xEntry : BOOL;
    xSawSensorClear : BOOL;
    tonStep : TON;
    fbClear : FB_ClearanceUnit;
    fbPost : FB_PostCut;
END_VAR
''','''
xDone := FALSE;
IF NOT xRun THEN eStep:=E_AutoStep.Idle; xError:=FALSE; udiErrorID:=0; xSawSensorClear:=FALSE; END_IF
xEntry := eStep <> ePrevStep;
IF xEntry THEN udiToken := F_NextID(udiCounter); END_IF
ePrevStep := eStep;
tonStep(IN:=xRun AND NOT xEntry AND (eStep<>E_AutoStep.Idle)
    AND (eStep<>E_AutoStep.FeedWait) AND (eStep<>E_AutoStep.Complete)
    AND (eStep<>E_AutoStep.Fault),PT:=stRecipe.tStepTimeout);
IF xRun AND NOT xError THEN
CASE eStep OF
E_AutoStep.Idle: eStep:=E_AutoStep.FeedWait;
E_AutoStep.FeedWait:
    IF xEntry THEN xSawSensorClear:=FALSE; END_IF
    IF NOT xMaterialAtLength THEN xSawSensorClear:=TRUE; END_IF
    aCommand[1]:=F_Command(E_DeviceAction.Run,udiToken,0.0,stRecipe.lrBeltVelocity);
    IF xSawSensorClear AND xMaterialAtLength AND F_At(aStatus[5],1.0) THEN eStep:=E_AutoStep.StopFeed; END_IF
E_AutoStep.StopFeed:
    IF NOT aStatus[1].xActive AND NOT aStatus[1].xBusy THEN eStep:=E_AutoStep.Push; END_IF
E_AutoStep.Push:
    aCommand[11]:=F_Command(E_DeviceAction.Position,udiToken,1.0,stRecipe.lrPositionVelocity);
    IF F_Done(aStatus[11],udiToken) THEN eStep:=E_AutoStep.Clearance; END_IF
E_AutoStep.Clearance:
    IF fbClear.xDone THEN eStep:=E_AutoStep.Rotate; END_IF
E_AutoStep.Rotate:
    aCommand[8]:=F_Command(E_DeviceAction.Position,udiToken,stRecipe.lrRotateAngle,stRecipe.lrPositionVelocity);
    IF F_Done(aStatus[8],udiToken) THEN eStep:=E_AutoStep.PressDown; END_IF
E_AutoStep.PressDown:
    aCommand[9]:=F_Command(E_DeviceAction.Position,udiToken,1.0,stRecipe.lrPositionVelocity);
    IF F_Done(aStatus[9],udiToken) THEN eStep:=E_AutoStep.KnifeDown; END_IF
E_AutoStep.KnifeDown:
    aCommand[17]:=F_Command(E_DeviceAction.Position,udiToken,1.0,stRecipe.lrPositionVelocity);
    IF F_Done(aStatus[17],udiToken) THEN eStep:=E_AutoStep.SpindleOn; END_IF
E_AutoStep.SpindleOn:
    udiSpindleToken:=udiToken;
    aCommand[3]:=F_Command(E_DeviceAction.Run,udiSpindleToken,0.0,stRecipe.lrSpindleVelocity);
    IF F_Done(aStatus[3],udiSpindleToken) AND aStatus[3].xActive THEN eStep:=E_AutoStep.Cutting; END_IF
E_AutoStep.Cutting:
    aCommand[3]:=F_Command(E_DeviceAction.Run,udiSpindleToken,0.0,stRecipe.lrSpindleVelocity);
    aCommand[14]:=F_Command(E_DeviceAction.Run,udiToken,0.0,0.0);
    aCommand[2]:=F_Command(E_DeviceAction.Position,udiToken,stRecipe.lrCutHome+stRecipe.lrCutLength,stRecipe.lrCutVelocity);
    IF F_Done(aStatus[2],udiToken) THEN eStep:=E_AutoStep.StopCut; END_IF
E_AutoStep.StopCut:
    IF NOT aStatus[3].xActive AND NOT aStatus[3].xBusy AND NOT aStatus[14].xActive THEN eStep:=E_AutoStep.PostCut; END_IF
E_AutoStep.PostCut:
    IF fbPost.xDone THEN eStep:=E_AutoStep.Complete; END_IF
E_AutoStep.Complete:
    xDone:=xEntry;
    IF xContinuous THEN eStep:=E_AutoStep.FeedWait; END_IF
E_AutoStep.Fault: xError:=TRUE;
ELSE xError:=TRUE; udiErrorID:=4800;
END_CASE
IF tonStep.Q THEN xError:=TRUE; udiErrorID:=4800+TO_UDINT(eStep); END_IF
END_IF
fbClear(xExecute:=xRun AND (eStep=E_AutoStep.Clearance),stRecipe:=stRecipe,aCommand:=aCommand,aStatus:=aStatus,udiCounter:=udiCounter);
fbPost(xExecute:=xRun AND (eStep=E_AutoStep.PostCut),stRecipe:=stRecipe,aCommand:=aCommand,aStatus:=aStatus,udiCounter:=udiCounter);
IF fbClear.xError OR fbPost.xError THEN xError:=TRUE; udiErrorID:=MAX(fbClear.udiErrorID,fbPost.udiErrorID); END_IF
IF xError THEN eStep:=E_AutoStep.Fault; END_IF
uiClearLengthStep:=fbClear.uiLengthStep; uiClearTransferStep:=fbClear.uiTransferStep;
uiPostStep:=fbPost.uiStep; uiReturnKnifeStep:=fbPost.uiKnifeStep;
uiUnloadStep:=fbPost.uiUnloadStep; uiResetLengthStep:=fbPost.uiLengthStep;
''')

obj('04_Machine','FB_ManualControl','fb','''
FUNCTION_BLOCK FB_ManualControl
VAR_INPUT
    xEnable : BOOL;
    aManual : ARRAY[1..17] OF ST_ManualCommand;
END_VAR
VAR_IN_OUT
    aCommand : ARRAY[1..17] OF ST_DeviceCommand;
    aStatus : ARRAY[1..17] OF ST_DeviceStatus;
    udiCounter : UDINT;
END_VAR
VAR_OUTPUT
    uiRejectDevice : UINT;
END_VAR
VAR
    aPrev : ARRAY[1..17] OF ST_ManualCommand;
    aPending : ARRAY[1..17] OF ST_DeviceCommand;
    aRunID : ARRAY[1..17] OF UDINT;
    i : INT;
    lrVelocity : LREAL;
END_VAR
''','''
uiRejectDevice:=0;
FOR i:=1 TO 17 DO
    IF NOT xEnable THEN
        aPending[i].eAction:=E_DeviceAction.None;
        aRunID[i]:=0;
    ELSIF i<>6 THEN
        lrVelocity:=LIMIT(0.1,ABS(aManual[i].lrVelocity),100.0);
        IF (aManual[i].xJogPositive AND aManual[i].xJogNegative)
           OR ((aManual[i].xJogPositive OR aManual[i].xJogNegative) AND (aManual[i].xMove OR aManual[i].xRun))
           OR (aManual[i].xMove AND aManual[i].xRun) THEN
            uiRejectDevice:=INT_TO_UINT(i); aPending[i].eAction:=E_DeviceAction.None;
        ELSIF aManual[i].xJogPositive OR aManual[i].xJogNegative THEN
            aPending[i].eAction:=E_DeviceAction.None;
            IF aRunID[i]=0 THEN aRunID[i]:=F_NextID(udiCounter); END_IF
            IF aManual[i].xJogNegative THEN lrVelocity:=-lrVelocity; END_IF
            IF (i=2) OR (i=4) OR (i=5) OR (i=7) OR (i=8) THEN
                aCommand[i]:=F_Command(E_DeviceAction.Jog,aRunID[i],0.0,lrVelocity);
            ELSE uiRejectDevice:=INT_TO_UINT(i);
            END_IF
        ELSIF aManual[i].xRun THEN
            aPending[i].eAction:=E_DeviceAction.None;
            IF (i=1) OR (i=3) OR (i=13) OR (i=14) THEN
                IF aRunID[i]=0 THEN aRunID[i]:=F_NextID(udiCounter); END_IF
                aCommand[i]:=F_Command(E_DeviceAction.Run,aRunID[i],0.0,lrVelocity);
            ELSE uiRejectDevice:=INT_TO_UINT(i);
            END_IF
        ELSE
            aRunID[i]:=0;
            IF aManual[i].xMove AND NOT aPrev[i].xMove THEN
                IF (i<>1) AND (i<>3) AND (i<>13) AND (i<>14) THEN
                    aPending[i]:=F_Command(E_DeviceAction.Position,F_NextID(udiCounter),aManual[i].lrTarget,lrVelocity);
                ELSE uiRejectDevice:=INT_TO_UINT(i);
                END_IF
            END_IF
            IF aPending[i].eAction<>E_DeviceAction.None THEN
                aCommand[i]:=aPending[i];
                IF F_Done(aStatus[i],aPending[i].udiID) THEN aPending[i].eAction:=E_DeviceAction.None; END_IF
            END_IF
        END_IF
    END_IF
    (* Synchronize while disabled: held buttons never acquire a fresh move edge. *)
    aPrev[i]:=aManual[i];
END_FOR
''')

obj('04_Machine','FB_Interlocks','fb','''
FUNCTION_BLOCK FB_Interlocks
VAR_INPUT
    xPermit : BOOL;
    stRecipe : ST_Recipe;
    aRequest : ARRAY[1..17] OF ST_DeviceCommand;
    aStatus : ARRAY[1..17] OF ST_DeviceStatus;
END_VAR
VAR_OUTPUT
    aCommand : ARRAY[1..17] OF ST_DeviceCommand;
    uiBlockedDevice : UINT;
END_VAR
VAR
    i : INT;
    xAllowed : BOOL;
    xMotion : BOOL;
    xKnifeUp : BOOL;
    xPressUp : BOOL;
    xClampOpen : BOOL;
END_VAR
''','''
uiBlockedDevice:=0;
xKnifeUp:=F_At(aStatus[17],0.0); xPressUp:=F_At(aStatus[9],0.0);
xClampOpen:=F_At(aStatus[16],0.0);
FOR i:=1 TO 17 DO
    aCommand[i]:=aRequest[i];
    xAllowed:=xPermit AND (i<>6);
    xMotion:=(aRequest[i].eAction=E_DeviceAction.Jog) OR
        ((aRequest[i].eAction=E_DeviceAction.Position) AND
        (ABS(aRequest[i].lrTarget-aStatus[i].lrPosition)>0.01));
    IF xMotion THEN
        CASE i OF
        4: xAllowed:=xAllowed AND F_At(aStatus[5],0.0);
        8: xAllowed:=xAllowed AND xKnifeUp AND xPressUp AND F_At(aStatus[11],0.0);
        9:
            IF aRequest[i].lrTarget>0.5 THEN
                xAllowed:=xAllowed AND NOT aStatus[8].xBusy AND xKnifeUp AND F_At(aStatus[2],stRecipe.lrCutHome);
            END_IF
        17:
            IF aRequest[i].lrTarget>0.5 THEN
                xAllowed:=xAllowed AND F_At(aStatus[9],1.0) AND NOT aStatus[8].xBusy
                    AND F_At(aStatus[5],0.0) AND F_At(aStatus[12],0.0) AND F_At(aStatus[10],1.0);
            END_IF
        2:
            IF ((aRequest[i].eAction=E_DeviceAction.Position) AND (aRequest[i].lrTarget>stRecipe.lrCutHome+0.01))
               OR ((aRequest[i].eAction=E_DeviceAction.Jog) AND (aRequest[i].lrVelocity>0.0)) THEN
                xAllowed:=xAllowed AND F_At(aStatus[9],1.0) AND F_At(aStatus[17],1.0) AND aStatus[3].xActive;
            ELSE xAllowed:=xAllowed AND xKnifeUp;
            END_IF
        7:
            xAllowed:=xAllowed AND xKnifeUp AND xPressUp;
            IF aRequest[i].eAction=E_DeviceAction.Jog THEN
                xAllowed:=xAllowed AND F_At(aStatus[15],1.0) AND xClampOpen;
            ELSIF ABS(aRequest[i].lrTarget-stRecipe.lrGripperHome)<0.01 THEN
                xAllowed:=xAllowed AND F_At(aStatus[15],0.0) AND xClampOpen;
            ELSIF ABS(aRequest[i].lrTarget-stRecipe.lrGripperPull)<0.01 THEN
                xAllowed:=xAllowed AND F_At(aStatus[15],1.0) AND F_At(aStatus[16],1.0);
            ELSE xAllowed:=xAllowed AND F_At(aStatus[15],1.0) AND xClampOpen;
            END_IF
        END_CASE
    END_IF
    IF NOT xAllowed THEN
        IF aRequest[i].eAction<>E_DeviceAction.None THEN uiBlockedDevice:=INT_TO_UINT(i); END_IF
        aCommand[i].eAction:=E_DeviceAction.Stop;
    END_IF
END_FOR
''')

obj('06_Simulation','FB_SimPlant','fb','''
FUNCTION_BLOCK FB_SimPlant
VAR_INPUT
    xEnable : BOOL;
    stSettings : ST_SimulationSettings;
    aStatus : ARRAY[1..17] OF ST_DeviceStatus;
END_VAR
VAR_OUTPUT
    xMaterialAtLength : BOOL;
END_VAR
VAR
    xLatched : BOOL;
    tonMaterial : TON;
END_VAR
''','''
IF NOT xEnable OR NOT F_At(aStatus[5],1.0) THEN xLatched:=FALSE; END_IF
tonMaterial(IN:=xEnable AND stSettings.xAutoMaterial AND aStatus[1].xActive
    AND F_At(aStatus[5],1.0) AND NOT xLatched,PT:=stSettings.tMaterialDelay);
IF tonMaterial.Q THEN xLatched:=TRUE; END_IF
IF stSettings.xAutoMaterial THEN xMaterialAtLength:=xLatched;
ELSE xMaterialAtLength:=xEnable AND F_At(aStatus[5],1.0) AND stSettings.xMaterialSensor;
END_IF
''')

obj('04_Machine','FB_AlarmManager','fb','''
FUNCTION_BLOCK FB_AlarmManager
VAR_INPUT
    udiIncoming : UDINT;
    xReset : BOOL;
END_VAR
VAR_OUTPUT
    udiLatched : UDINT;
END_VAR
''','''
IF xReset AND (udiIncoming=0) THEN udiLatched:=0; END_IF
IF (udiLatched=0) AND (udiIncoming<>0) THEN udiLatched:=udiIncoming; END_IF
''')

obj('05_Communication','FB_ModbusInterface','fb','''
FUNCTION_BLOCK FB_ModbusInterface
VAR_INPUT
    xEnable : BOOL;
    stStatus : ST_MachineStatus;
    aStatus : ARRAY[1..17] OF ST_DeviceStatus;
END_VAR
VAR_IN_OUT
    awRx : ARRAY[0..31] OF WORD;
    awTx : ARRAY[0..127] OF WORD;
END_VAR
VAR_OUTPUT
    xRequest : BOOL;
    wRequestSequence : WORD;
    stCommand : ST_RemoteCommand;
    uiParseResult : UINT;
END_VAR
VAR
    aSnapshot : ARRAY[0..31] OF WORD;
    wLastSeen : WORD;
    xWasEnabled : BOOL;
    i : INT;
END_VAR
''','''
xRequest:=FALSE;
stCommand.xStart:=FALSE;
stCommand.xStop:=FALSE;
IF NOT xEnable OR NOT xWasEnabled THEN
    (* Baseline on enable, so reconnect never replays a stale command. *)
    wLastSeen:=awRx[1];
ELSIF (awRx[1]<>0) AND (awRx[1]<>wLastSeen) THEN
    aSnapshot:=awRx;
    IF aSnapshot[1]=awRx[1] THEN
        wLastSeen:=aSnapshot[1]; wRequestSequence:=aSnapshot[1]; uiParseResult:=0;
        IF (aSnapshot[0]<>2) OR (aSnapshot[3]<>0) OR (aSnapshot[4]<>0)
           OR ((aSnapshot[2]<>2) AND (aSnapshot[2]<>3)) THEN
            uiParseResult:=2;
        ELSE
            CASE aSnapshot[2] OF
            2: stCommand.xStart:=TRUE;
            3: stCommand.xStop:=TRUE;
            END_CASE
            xRequest:=TRUE;
        END_IF
    END_IF
END_IF
xWasEnabled:=xEnable;
FOR i:=0 TO 127 DO awTx[i]:=0; END_FOR
awTx[0]:=2; awTx[1]:=stStatus.wRemoteAckSequence; awTx[2]:=UINT_TO_WORD(stStatus.uiRemoteResult);
awTx[3]:=TO_WORD(stStatus.eState); awTx[4]:=TO_WORD(stStatus.eAutoStep);
awTx[5]:=UDINT_TO_WORD(stStatus.udiAlarm); awTx[6]:=UDINT_TO_WORD(SHR(stStatus.udiAlarm,16));
awTx[7]:=UDINT_TO_WORD(stStatus.udiCycleCount); awTx[8]:=UDINT_TO_WORD(SHR(stStatus.udiCycleCount,16));
awTx[9]:=BOOL_TO_WORD(stStatus.xSimulation); awTx[10]:=BOOL_TO_WORD(stStatus.xInitialized);
awTx[11]:=BOOL_TO_WORD(stStatus.xMaterialAtLength); awTx[12]:=UINT_TO_WORD(stStatus.uiActiveMaterialModel);
awTx[13]:=wRequestSequence; awTx[14]:=UINT_TO_WORD(uiParseResult);
awTx[15]:=TO_WORD(stStatus.eMode);
awTx[16]:=BOOL_TO_WORD(stStatus.xRemoteStartStopAllowed);
(* Positions at [32..48]: signed INT, 0.1 engineering-unit scaling. *)
FOR i:=1 TO 17 DO awTx[31+i]:=INT_TO_WORD(LREAL_TO_INT(aStatus[i].lrPosition*10.0)); END_FOR
''')

obj('04_Machine','FB_PanelInput','fb','''
FUNCTION_BLOCK FB_PanelInput
VAR_INPUT
    xSimulation : BOOL;
    stReal : ST_PanelInputs;
    stSim : ST_PanelInputs;
    xContinuous : BOOL;
END_VAR
VAR_OUTPUT
    stCommand : ST_OperatorCommand;
END_VAR
VAR
    stSelected : ST_PanelInputs;
END_VAR
''','''
(* Logical signals are normalized at the I/O boundary; no physical addresses are assigned here. *)
IF xSimulation THEN stSelected:=stSim;
ELSE stSelected:=stReal; END_IF
stCommand.eMode:=E_MachineMode.Manual;
IF stSelected.xAutoMode THEN stCommand.eMode:=E_MachineMode.Automatic; END_IF
stCommand.xInitialize:=stSelected.xInitialize;
stCommand.xStart:=stSelected.xStart;
stCommand.xStop:=stSelected.xStop;
stCommand.xResetAlarm:=stSelected.xResetAlarm;
stCommand.xContinuous:=xContinuous;
''')

obj('04_Machine','FB_Machine','fb','''
FUNCTION_BLOCK FB_Machine
VAR_INPUT
    xSimulation : BOOL;
    stPanel : ST_OperatorCommand;
    stRemote : ST_RemoteCommand;
    xRemoteRequest : BOOL;
    xAllowRemoteStartStop : BOOL;
    wRemoteSequence : WORD;
    aManual : ARRAY[1..17] OF ST_ManualCommand;
    stRecipe : ST_Recipe;
    stSim : ST_SimulationSettings;
    xRealSafetyOK : BOOL;
    xRealMaterial : BOOL;
END_VAR
VAR_OUTPUT
    stStatus : ST_MachineStatus;
    aDeviceStatus : ARRAY[1..17] OF ST_DeviceStatus;
    aSelectedCommand : ARRAY[1..17] OF ST_DeviceCommand;
END_VAR
VAR
    stCommand : ST_OperatorCommand;
    stActiveRecipe : ST_Recipe;
    aRequest : ARRAY[1..17] OF ST_DeviceCommand;
    stEmpty : ST_DeviceCommand;
    fbDevices : FB_DeviceManager;
    fbManual : FB_ManualControl;
    fbAuto : FB_AutoCycle;
    fbInitialize : FB_Initialize;
    fbInterlocks : FB_Interlocks;
    fbPlant : FB_SimPlant;
    fbAlarm : FB_AlarmManager;
    rtInitialize : R_TRIG;
    rtStart : R_TRIG;
    rtReset : R_TRIG;
    udiCounter : UDINT;
    udiFault : UDINT;
    xSafetyOK : BOOL;
    xMaterial : BOOL;
    xInitialized : BOOL;
    xPermit : BOOL;
    xRemoteAccepted : BOOL;
    xStartRequest : BOOL;
    xResetDevices : BOOL;
    xLastSimulation : BOOL := TRUE;
    xManualReleased : BOOL;
    xManualArmed : BOOL;
    eActiveMode : E_MachineMode;
    i : INT;
END_VAR
''','''
stCommand:=stPanel;
(* Physical panel owns mode, initialization, reset and local stop. *)
xRemoteAccepted:=FALSE;
IF xRemoteRequest THEN
    stStatus.wRemoteAckSequence:=wRemoteSequence;
    IF xAllowRemoteStartStop THEN
        IF stRemote.xStop THEN
            stCommand.xStop:=TRUE;
            stStatus.uiRemoteResult:=0; xRemoteAccepted:=TRUE;
        ELSIF stRemote.xStart THEN
            IF (stPanel.eMode=E_MachineMode.Automatic)
               AND (stStatus.eState=E_MachineState.Ready) AND NOT stPanel.xStop THEN
                stStatus.uiRemoteResult:=0; xRemoteAccepted:=TRUE;
            ELSE stStatus.uiRemoteResult:=3; END_IF
        ELSE stStatus.uiRemoteResult:=2; END_IF
    ELSE stStatus.uiRemoteResult:=1;
    END_IF
END_IF
rtInitialize(CLK:=stCommand.xInitialize);
rtStart(CLK:=stCommand.xStart);
(* Local start uses an edge; each accepted remote frame is already a one-scan request. *)
xStartRequest:=rtStart.Q OR (xRemoteAccepted AND stRemote.xStart AND NOT stRemote.xStop);
rtReset(CLK:=stCommand.xResetAlarm);
IF xSimulation THEN xSafetyOK:=stSim.xSafetyOK; xMaterial:=fbPlant.xMaterialAtLength;
ELSE xSafetyOK:=xRealSafetyOK; xMaterial:=xRealMaterial; END_IF
udiFault:=0;
IF NOT xSafetyOK THEN udiFault:=1001; END_IF
IF NOT xSimulation THEN udiFault:=3001; END_IF
IF xSimulation<>xLastSimulation THEN
    stStatus.eState:=E_MachineState.Stopped; xInitialized:=FALSE;
END_IF
xLastSimulation:=xSimulation;
FOR i:=1 TO 17 DO
    IF aDeviceStatus[i].xError THEN udiFault:=10000+INT_TO_UDINT(i); END_IF
    aRequest[i]:=stEmpty;
END_FOR
IF (stStatus.eState=E_MachineState.Automatic) OR (stStatus.eState=E_MachineState.Manual) THEN
    IF stCommand.eMode<>eActiveMode THEN stStatus.eState:=E_MachineState.Stopped; xInitialized:=FALSE; END_IF
END_IF
IF stCommand.xStop THEN stStatus.eState:=E_MachineState.Stopped; xInitialized:=FALSE; END_IF
IF udiFault<>0 THEN stStatus.eState:=E_MachineState.Fault; xInitialized:=FALSE; END_IF
xResetDevices:=rtReset.Q AND xSafetyOK AND xSimulation;
IF xResetDevices THEN
    (* Reset injected/device errors before clearing the machine latch next scan. *)
    udiFault:=0;
    FOR i:=1 TO 17 DO IF stSim.axFault[i] THEN udiFault:=10000+INT_TO_UDINT(i); END_IF END_FOR
END_IF
fbAlarm(udiIncoming:=udiFault,xReset:=xResetDevices);
IF (stStatus.eState=E_MachineState.Fault) AND (fbAlarm.udiLatched=0) AND xResetDevices THEN
    stStatus.eState:=E_MachineState.Stopped;
END_IF
IF fbAlarm.udiLatched<>0 THEN stStatus.eState:=E_MachineState.Fault; END_IF
IF rtInitialize.Q AND NOT stCommand.xStop THEN
    IF (stStatus.eState=E_MachineState.Stopped) AND xSimulation AND xSafetyOK AND F_RecipeValid(stRecipe) THEN
        stActiveRecipe:=stRecipe; stStatus.eState:=E_MachineState.Initializing;
        eActiveMode:=stCommand.eMode; xInitialized:=FALSE;
    ELSIF xRemoteAccepted THEN stStatus.uiRemoteResult:=3;
    END_IF
END_IF
IF stStatus.eState=E_MachineState.Ready THEN
    IF stCommand.eMode=E_MachineMode.Manual THEN
        stStatus.eState:=E_MachineState.Manual; eActiveMode:=E_MachineMode.Manual;
    ELSIF xStartRequest AND NOT stCommand.xStop THEN
        IF F_RecipeValid(stRecipe) THEN
            stActiveRecipe:=stRecipe; eActiveMode:=E_MachineMode.Automatic;
            stStatus.eState:=E_MachineState.Automatic;
        ELSIF xRemoteAccepted THEN stStatus.uiRemoteResult:=5;
        END_IF
    END_IF
ELSIF (stStatus.eState=E_MachineState.Manual) AND (stCommand.eMode=E_MachineMode.Automatic) THEN
    stStatus.eState:=E_MachineState.Stopped; xInitialized:=FALSE;
END_IF
IF xStartRequest AND xRemoteAccepted AND (stStatus.eState<>E_MachineState.Automatic)
   AND (stStatus.uiRemoteResult=0) THEN stStatus.uiRemoteResult:=3; END_IF

xManualReleased:=TRUE;
FOR i:=1 TO 17 DO
    IF aManual[i].xJogPositive OR aManual[i].xJogNegative OR aManual[i].xMove OR aManual[i].xRun THEN xManualReleased:=FALSE; END_IF
END_FOR
IF stStatus.eState<>E_MachineState.Manual THEN xManualArmed:=FALSE;
ELSIF xManualReleased THEN xManualArmed:=TRUE;
END_IF
fbInitialize(xExecute:=stStatus.eState=E_MachineState.Initializing,stRecipe:=stActiveRecipe,
    aCommand:=aRequest,aStatus:=aDeviceStatus,udiCounter:=udiCounter);
fbManual(xEnable:=(stStatus.eState=E_MachineState.Manual) AND xManualArmed,
    aManual:=aManual,aCommand:=aRequest,aStatus:=aDeviceStatus,udiCounter:=udiCounter);
fbAuto(xRun:=stStatus.eState=E_MachineState.Automatic,xContinuous:=stCommand.xContinuous,
    xMaterialAtLength:=xMaterial,stRecipe:=stActiveRecipe,aCommand:=aRequest,aStatus:=aDeviceStatus,udiCounter:=udiCounter);
IF fbInitialize.xDone THEN xInitialized:=TRUE; stStatus.eState:=E_MachineState.Ready; END_IF
IF fbInitialize.xError OR fbAuto.xError THEN
    udiFault:=MAX(fbInitialize.udiErrorID,fbAuto.udiErrorID);
    fbAlarm(udiIncoming:=udiFault,xReset:=FALSE);
    stStatus.eState:=E_MachineState.Fault; xInitialized:=FALSE;
END_IF
IF fbAuto.xDone THEN
    stStatus.udiCycleCount:=stStatus.udiCycleCount+1;
    IF NOT stCommand.xContinuous THEN stStatus.eState:=E_MachineState.Ready; END_IF
END_IF
xPermit:=xSimulation AND xSafetyOK AND NOT stCommand.xStop AND (fbAlarm.udiLatched=0)
    AND ((stStatus.eState=E_MachineState.Initializing) OR (stStatus.eState=E_MachineState.Manual)
    OR (stStatus.eState=E_MachineState.Automatic));
fbInterlocks(xPermit:=xPermit,stRecipe:=stActiveRecipe,aRequest:=aRequest,aStatus:=aDeviceStatus);
aSelectedCommand:=fbInterlocks.aCommand;
fbDevices(xEnable:=xSimulation AND xSafetyOK,xSimulation:=xSimulation,xReset:=xResetDevices,
    stSim:=stSim,aCommand:=aSelectedCommand);
aDeviceStatus:=fbDevices.aStatus;
fbPlant(xEnable:=xSimulation,stSettings:=stSim,aStatus:=aDeviceStatus);
stStatus.eMode:=stCommand.eMode; stStatus.eAutoStep:=fbAuto.eStep;
stStatus.xSimulation:=xSimulation; stStatus.xRealBackendAvailable:=FALSE;
stStatus.xRemoteStartStopAllowed:=xAllowRemoteStartStop;
stStatus.xInitialized:=xInitialized;
stStatus.xReady:=xInitialized AND (stStatus.eState=E_MachineState.Ready);
stStatus.xMaterialAtLength:=xMaterial; stStatus.xCycleComplete:=fbAuto.xDone;
stStatus.udiAlarm:=fbAlarm.udiLatched; stStatus.uiBlockedDevice:=fbInterlocks.uiBlockedDevice;
stStatus.uiManualReject:=fbManual.uiRejectDevice;
stStatus.uiClearLengthStep:=fbAuto.uiClearLengthStep; stStatus.uiClearTransferStep:=fbAuto.uiClearTransferStep;
stStatus.uiPostStep:=fbAuto.uiPostStep; stStatus.uiReturnKnifeStep:=fbAuto.uiReturnKnifeStep;
stStatus.uiUnloadStep:=fbAuto.uiUnloadStep; stStatus.uiResetLengthStep:=fbAuto.uiResetLengthStep;
stStatus.uiInitializeStep:=fbInitialize.uiStep; stStatus.uiActiveMaterialModel:=stActiveRecipe.uiMaterialModel;
''')

obj('04_Machine','FB_IOMap','fb','''
FUNCTION_BLOCK FB_IOMap
VAR_INPUT
    uiMaterialModel : UINT;
    aCommand : ARRAY[1..17] OF ST_DeviceCommand;
    aStatus : ARRAY[1..17] OF ST_DeviceStatus;
END_VAR
VAR_IN_OUT
    axOutputs : ARRAY[0..31] OF BOOL;
    axG2RelayDemand : ARRAY[1..3] OF BOOL;
END_VAR
VAR
    i : INT;
END_VAR
''','''
(* Physical writes remain unimplemented. Logical relay demand is diagnostic. *)
FOR i:=0 TO 31 DO axOutputs[i]:=FALSE; END_FOR
FOR i:=1 TO 3 DO axG2RelayDemand[i]:=FALSE; END_FOR
IF aStatus[10].lrPosition>0.5 THEN
    CASE uiMaterialModel OF
    300: axG2RelayDemand[1]:=TRUE;
    400: axG2RelayDemand[2]:=TRUE;
    600: axG2RelayDemand[3]:=TRUE;
    END_CASE
END_IF
''')

obj('', 'PLC_PRG', 'existing', '''
PROGRAM PLC_PRG
VAR
    fbPanel : FB_PanelInput;
    fbCommunication : FB_ModbusInterface;
    fbMachine : FB_Machine;
    fbIO : FB_IOMap;
END_VAR
''','''
(* One cyclic owner in ETHERCAT1. All lower device FBs are called each scan. *)
fbPanel(xSimulation:=GVL_Parameters.xSimulation,stReal:=GVL_IO.stPanelInputs,
    stSim:=GVL_Simulation.stPanelInputs,xContinuous:=GVL_Parameters.xContinuous);
GVL_Interface.stPanel:=fbPanel.stCommand;
fbCommunication(xEnable:=GVL_Modbus.xEnable,stStatus:=GVL_Interface.stStatus,
    aStatus:=GVL_Interface.aDeviceStatus,awRx:=GVL_Modbus.awRx,awTx:=GVL_Modbus.awTx);
fbMachine(xSimulation:=GVL_Parameters.xSimulation,stPanel:=GVL_Interface.stPanel,
    stRemote:=fbCommunication.stCommand,xRemoteRequest:=fbCommunication.xRequest,
    xAllowRemoteStartStop:=GVL_Parameters.xAllowRemoteStartStop,
    wRemoteSequence:=fbCommunication.wRequestSequence,aManual:=GVL_Interface.aManual,
    stRecipe:=GVL_Parameters.stRecipe,stSim:=GVL_Simulation.stSettings,
    xRealSafetyOK:=GVL_IO.xSafetyOK,xRealMaterial:=GVL_IO.xMaterialAtLength);
GVL_Interface.stStatus:=fbMachine.stStatus;
GVL_Interface.aDeviceStatus:=fbMachine.aDeviceStatus;
fbIO(uiMaterialModel:=fbMachine.stStatus.uiActiveMaterialModel,aCommand:=fbMachine.aSelectedCommand,
    aStatus:=fbMachine.aDeviceStatus,
    axOutputs:=GVL_IO.axDigitalOutputs,axG2RelayDemand:=GVL_IO.axG2RelayDemand);
''')

if __name__ == '__main__':
    baseline = json.loads((ROOT/'baseline-20261015.json').read_text(encoding='ascii'))
    demo = next(x for x in baseline if x['path'].endswith('/Application/PLC_PRG'))
    # Keep the Chinese legacy comments when regenerating the source export.
    legacy_comments = {
        "(* ---- SoftMotion function block instances ---- *)": "(* 运动控制功能块：伺服使能、复位、停止及位置反馈。 *)",
        "(* enable / disable the axis *)": "(* 伺服轴使能／关闭 *)",
        "(* reset axis error *)": "(* 复位伺服轴故障 *)",
        "(* auto cycle move *)": "(* 自动往返运动指令 *)",
        "(* position feedback *)": "(* 读取轴实际位置 *)",
        "(* ---- edge detection ---- *)": "(* 启动信号上升沿检测 *)",
        "(* ---- auto cycle ---- *)": "(* 自动测试循环的内部状态 *)",
        "(* ---- diagnostics ---- *)": "(* 运行状态与故障诊断 *)",
        "(* Single low-speed 20 mm out-and-back test cycle.\n   Start only on a rising edge of GVL_Motion.xStartCycle.\n   Travel is capped at 20 mm per leg and 10 mm/s. *)": "(* 中文注释显示核对：单次低速 20 mm 往返测试。\n   GVL_Motion.xStartCycle 的上升沿启动一次循环。\n   单程距离最多 20 mm，速度最多 10 mm/s。 *)",
        "(* Idle; one rising edge starts one round trip. *)": "(* 等待启动：一次上升沿触发一次完整往返。 *)",
        "(* Forward leg. *)": "(* 正向运动：等待轴到达指定位置。 *)",
        "(* Dwell before return leg. *)": "(* 正向到位后停留，再发出反向运动指令。 *)",
        "(* Return leg. *)": "(* 反向返回：等待轴完成回程。 *)",
        "(* Dwell after returning to the start position, then finish. *)": "(* 返回起点后停留，本次循环结束。 *)",
        "(* Error latch; require a successful reset and completed stop. *)": "(* 故障保持：复位成功且停止完成后，允许回到待机。 *)"
    }
    for old_comment, chinese_comment in legacy_comments.items():
        for section in ('declaration', 'implementation'):
            demo[section] = demo[section].replace(old_comment, chinese_comment)
    obj('90_Legacy','PRG_AxisDemo','program',demo['declaration'].replace('PROGRAM PLC_PRG','PROGRAM PRG_AxisDemo',1),demo['implementation'])
    # The old Demo globals stay at their existing root location in the IDE.
    legacy_motion = next(x for x in baseline if x['path'].endswith('/Application/GVL_Motion'))
    obj('', 'GVL_Motion', 'existing', legacy_motion['declaration'])
    source = ROOT/'sources'
    source.mkdir(exist_ok=True)
    for o in OBJECTS:
        folder=source/o['folder']; folder.mkdir(exist_ok=True)
        (folder/(o['name']+'.st')).write_text(o['declaration']+'\n'+o['implementation'],encoding='utf-8')
    (ROOT/'manifest.json').write_text(json.dumps(OBJECTS,ensure_ascii=True,indent=2),encoding='ascii')
    print(f'Generated {len(OBJECTS)} objects under {source}')
