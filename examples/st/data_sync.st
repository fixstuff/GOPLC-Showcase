(* ============================================================================
   Multi-PLC Data Synchronization
   ============================================================================
   Demonstrates GOPLC's DataLayer for real-time variable sharing:
   - Publish local variables to other PLCs
   - Subscribe to variables from remote PLCs
   - Measure synchronization latency
   - Handle communication failures gracefully
   ============================================================================ *)

VAR_GLOBAL
    (* Local variables - published to other PLCs *)
    LOCAL_Counter : DINT := 0;
    LOCAL_Temperature : REAL := 0.0;
    LOCAL_Pressure : REAL := 0.0;
    LOCAL_Status : INT := 0;
    LOCAL_Alarm : BOOL := FALSE;

    (* Remote variables - received from PLC2 *)
    REMOTE_PLC2_Counter : DINT := 0;
    REMOTE_PLC2_Temperature : REAL := 0.0;
    REMOTE_PLC2_Status : INT := 0;

    (* Sync diagnostics *)
    SYNC_Latency_us : DINT := 0;
    SYNC_LastUpdate_ms : DINT := 0;
    SYNC_CommOK : BOOL := FALSE;
END_VAR

PROGRAM DataSync
VAR
    (* Simulation state *)
    simAngle : REAL := 0.0;
    scanCount : DINT := 0;

    (* Communication monitoring *)
    lastRemoteCounter : DINT := 0;
    commTimeout : INT := 0;
    COMM_TIMEOUT_LIMIT : INT := 100;  (* 100 scans without update = fault *)

    (* Calculated values *)
    avgTemperature : REAL := 0.0;
    tempDiff : REAL := 0.0;
END_VAR

(* === Increment Local Counter === *)
scanCount := scanCount + 1;
LOCAL_Counter := scanCount;

(* === Simulate Local Sensor Data === *)
simAngle := simAngle + 0.05;
IF simAngle > 6.28 THEN
    simAngle := 0.0;
END_IF;

(* Temperature: 20-30C with sine wave variation *)
LOCAL_Temperature := 25.0 + 5.0 * SIN(simAngle);

(* Pressure: 100-110 kPa with cosine variation *)
LOCAL_Pressure := 105.0 + 5.0 * COS(simAngle * 0.7);

(* Status: 0=OK, 1=Warning, 2=Alarm *)
IF LOCAL_Temperature > 28.0 THEN
    LOCAL_Status := 1;
    LOCAL_Alarm := FALSE;
ELSIF LOCAL_Temperature > 29.5 THEN
    LOCAL_Status := 2;
    LOCAL_Alarm := TRUE;
ELSE
    LOCAL_Status := 0;
    LOCAL_Alarm := FALSE;
END_IF;

(* === Read Remote Variables via DataLayer === *)
(* These are automatically populated by the DataLayer subscription *)
(* Check if we're receiving updates from PLC2 *)

IF REMOTE_PLC2_Counter <> lastRemoteCounter THEN
    (* Got new data from PLC2 *)
    lastRemoteCounter := REMOTE_PLC2_Counter;
    commTimeout := 0;
    SYNC_CommOK := TRUE;

    (* Measure sync latency *)
    SYNC_Latency_us := DL_LATENCY_US('plc2', 'LOCAL_Counter');
    SYNC_LastUpdate_ms := DINT_TO_INT(TICK_MS() MOD 100000);
ELSE
    (* No update this scan *)
    commTimeout := commTimeout + 1;
    IF commTimeout > COMM_TIMEOUT_LIMIT THEN
        SYNC_CommOK := FALSE;
    END_IF;
END_IF;

(* === Calculate Cross-PLC Metrics === *)
IF SYNC_CommOK THEN
    (* Average temperature across both PLCs *)
    avgTemperature := (LOCAL_Temperature + REMOTE_PLC2_Temperature) / 2.0;

    (* Temperature difference for load balancing *)
    tempDiff := ABS(LOCAL_Temperature - REMOTE_PLC2_Temperature);
END_IF;

(* === Map to Modbus Registers === *)
%QW0 := DINT_TO_INT(LOCAL_Counter MOD 32767);
%QW1 := REAL_TO_INT(LOCAL_Temperature * 10.0);
%QW2 := REAL_TO_INT(LOCAL_Pressure * 10.0);
%QW3 := LOCAL_Status;
%QW4 := DINT_TO_INT(REMOTE_PLC2_Counter MOD 32767);
%QW5 := REAL_TO_INT(REMOTE_PLC2_Temperature * 10.0);
%QW6 := DINT_TO_INT(SYNC_Latency_us MOD 32767);
%QX0.0 := SYNC_CommOK;
%QX0.1 := LOCAL_Alarm;

END_PROGRAM
