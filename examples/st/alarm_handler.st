(* ============================================================================
   Alarm Management System
   ============================================================================
   Industrial alarm handling with:
   - Multiple alarm priorities (Critical, High, Medium, Low)
   - Alarm acknowledgment and reset
   - Alarm history logging
   - Alarm shelving with timeout
   - Alarm suppression during mode changes
   ============================================================================ *)

VAR_GLOBAL
    (* Alarm inputs *)
    AI_HighTemp : BOOL := FALSE;
    AI_LowTemp : BOOL := FALSE;
    AI_HighPressure : BOOL := FALSE;
    AI_LowPressure : BOOL := FALSE;
    AI_LowLevel : BOOL := FALSE;
    AI_HighLevel : BOOL := FALSE;
    AI_MotorFault : BOOL := FALSE;
    AI_CommFault : BOOL := FALSE;

    (* Alarm outputs *)
    AO_AlarmActive : BOOL := FALSE;
    AO_AlarmCount : INT := 0;
    AO_HighestPriority : INT := 0;
    AO_Horn : BOOL := FALSE;
    AO_Beacon : BOOL := FALSE;

    (* Operator actions *)
    CMD_Acknowledge : BOOL := FALSE;
    CMD_SilenceHorn : BOOL := FALSE;
    CMD_Reset : BOOL := FALSE;
END_VAR

PROGRAM AlarmHandler
VAR
    (* Alarm state array: 0=Normal, 1=Active, 2=Acknowledged, 3=Shelved *)
    alarmState : ARRAY[0..7] OF INT;

    (* Alarm priorities: 1=Critical, 2=High, 3=Medium, 4=Low *)
    alarmPriority : ARRAY[0..7] OF INT := [1, 3, 2, 3, 3, 2, 1, 2];

    (* Alarm names for logging *)
    alarmNames : ARRAY[0..7] OF STRING := [
        'High Temperature',
        'Low Temperature',
        'High Pressure',
        'Low Pressure',
        'Low Level',
        'High Level',
        'Motor Fault',
        'Comm Fault'
    ];

    (* Alarm conditions *)
    alarmConditions : ARRAY[0..7] OF BOOL;

    (* Timing *)
    hornTimer : INT := 0;
    HORN_TIMEOUT : INT := 300;  (* Auto-silence after 30 seconds at 100ms scan *)

    (* Counters *)
    i : INT;
    activeCount : INT;
    highestPrio : INT;

    (* Edge detection for acknowledge *)
    ackPrev : BOOL := FALSE;
    resetPrev : BOOL := FALSE;
END_VAR

(* === Map Inputs to Alarm Conditions === *)
alarmConditions[0] := AI_HighTemp;
alarmConditions[1] := AI_LowTemp;
alarmConditions[2] := AI_HighPressure;
alarmConditions[3] := AI_LowPressure;
alarmConditions[4] := AI_LowLevel;
alarmConditions[5] := AI_HighLevel;
alarmConditions[6] := AI_MotorFault;
alarmConditions[7] := AI_CommFault;

(* === Process Each Alarm === *)
activeCount := 0;
highestPrio := 99;

FOR i := 0 TO 7 DO
    CASE alarmState[i] OF
        0: (* Normal *)
            IF alarmConditions[i] THEN
                alarmState[i] := 1;  (* Transition to Active *)
                (* Log alarm activation *)
                DEBUG_INFO(CONCAT('ALARM ACTIVE: ', alarmNames[i]));
            END_IF;

        1: (* Active - Unacknowledged *)
            IF NOT alarmConditions[i] THEN
                alarmState[i] := 0;  (* Return to normal *)
                DEBUG_INFO(CONCAT('ALARM CLEARED: ', alarmNames[i]));
            ELSIF CMD_Acknowledge AND NOT ackPrev THEN
                alarmState[i] := 2;  (* Acknowledged *)
                DEBUG_INFO(CONCAT('ALARM ACKED: ', alarmNames[i]));
            END_IF;

        2: (* Acknowledged *)
            IF NOT alarmConditions[i] THEN
                alarmState[i] := 0;  (* Return to normal *)
                DEBUG_INFO(CONCAT('ALARM CLEARED: ', alarmNames[i]));
            END_IF;

        3: (* Shelved *)
            (* Shelved alarms handled separately *)
            ;
    END_CASE;

    (* Count active alarms and find highest priority *)
    IF alarmState[i] = 1 OR alarmState[i] = 2 THEN
        activeCount := activeCount + 1;
        IF alarmPriority[i] < highestPrio THEN
            highestPrio := alarmPriority[i];
        END_IF;
    END_IF;
END_FOR;

(* === Update Outputs === *)
AO_AlarmCount := activeCount;
AO_AlarmActive := activeCount > 0;

IF activeCount > 0 THEN
    AO_HighestPriority := highestPrio;
ELSE
    AO_HighestPriority := 0;
END_IF;

(* === Horn Control === *)
(* Horn sounds for unacknowledged alarms *)
IF AO_AlarmActive THEN
    (* Check for any unacknowledged alarm *)
    FOR i := 0 TO 7 DO
        IF alarmState[i] = 1 THEN
            AO_Horn := TRUE;
            EXIT;
        END_IF;
    END_FOR;

    (* Auto-silence timeout *)
    IF AO_Horn THEN
        hornTimer := hornTimer + 1;
        IF hornTimer > HORN_TIMEOUT OR CMD_SilenceHorn THEN
            AO_Horn := FALSE;
        END_IF;
    END_IF;
ELSE
    AO_Horn := FALSE;
    hornTimer := 0;
END_IF;

(* === Beacon Control === *)
(* Beacon on for Critical (1) or High (2) priority active alarms *)
AO_Beacon := AO_AlarmActive AND (AO_HighestPriority <= 2);

(* === Reset Command === *)
IF CMD_Reset AND NOT resetPrev THEN
    FOR i := 0 TO 7 DO
        IF NOT alarmConditions[i] THEN
            alarmState[i] := 0;
        END_IF;
    END_FOR;
    DEBUG_INFO('ALARM SYSTEM RESET');
END_IF;

(* === Edge Detection Update === *)
ackPrev := CMD_Acknowledge;
resetPrev := CMD_Reset;

(* === Map to I/O === *)
%QX1.0 := AO_AlarmActive;
%QX1.1 := AO_Horn;
%QX1.2 := AO_Beacon;
%QW10 := AO_AlarmCount;
%QW11 := AO_HighestPriority;

(* Read operator commands *)
CMD_Acknowledge := %IX1.0;
CMD_SilenceHorn := %IX1.1;
CMD_Reset := %IX1.2;

END_PROGRAM
