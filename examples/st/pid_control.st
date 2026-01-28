(* ============================================================================
   PID Controller with Anti-Windup
   ============================================================================
   Industrial PID control with:
   - Proportional, Integral, Derivative terms
   - Anti-windup using back-calculation
   - Output clamping with configurable limits
   - Bumpless transfer on setpoint changes
   - Manual/Auto mode switching
   ============================================================================ *)

VAR_GLOBAL
    (* Process variables *)
    PV : REAL := 0.0;              (* Process Value - measured *)
    SP : REAL := 50.0;             (* Setpoint *)
    CV : REAL := 0.0;              (* Control Variable - output *)

    (* Tuning parameters *)
    Kp : REAL := 2.0;              (* Proportional gain *)
    Ki : REAL := 0.5;              (* Integral gain *)
    Kd : REAL := 0.1;              (* Derivative gain *)

    (* Limits *)
    CV_Max : REAL := 100.0;
    CV_Min : REAL := 0.0;

    (* Mode *)
    AutoMode : BOOL := TRUE;
    ManualCV : REAL := 0.0;

    (* Status *)
    Error : REAL := 0.0;
    Saturated : BOOL := FALSE;
END_VAR

PROGRAM PIDControl
VAR
    (* Internal state *)
    integral : REAL := 0.0;
    prevError : REAL := 0.0;
    prevPV : REAL := 0.0;
    derivative : REAL := 0.0;

    (* Anti-windup *)
    cvUnclamped : REAL := 0.0;
    backCalc : REAL := 0.0;
    Kb : REAL := 1.0;              (* Back-calculation gain *)

    (* Timing *)
    dt : REAL := 0.1;              (* Sample time in seconds *)

    (* Derivative filter *)
    derivFilt : REAL := 0.0;
    Tf : REAL := 0.05;             (* Filter time constant *)
END_VAR

(* === Calculate Error === *)
Error := SP - PV;

IF AutoMode THEN
    (* === Proportional Term === *)
    (* P = Kp * error *)

    (* === Integral Term with Anti-Windup === *)
    (* Only integrate if not saturated, or if integration would reduce saturation *)
    IF NOT Saturated OR (Error * integral < 0.0) THEN
        integral := integral + Ki * Error * dt;
        (* Back-calculation anti-windup *)
        integral := integral + Kb * backCalc * dt;
    END_IF;

    (* === Derivative Term (on PV to avoid derivative kick) === *)
    (* Use filtered derivative to reduce noise *)
    derivative := (PV - prevPV) / dt;
    derivFilt := derivFilt + (dt / Tf) * (derivative - derivFilt);

    (* === Calculate Unclamped Output === *)
    cvUnclamped := Kp * Error + integral - Kd * derivFilt;

    (* === Clamp Output === *)
    IF cvUnclamped > CV_Max THEN
        CV := CV_Max;
        Saturated := TRUE;
        backCalc := CV - cvUnclamped;
    ELSIF cvUnclamped < CV_Min THEN
        CV := CV_Min;
        Saturated := TRUE;
        backCalc := CV - cvUnclamped;
    ELSE
        CV := cvUnclamped;
        Saturated := FALSE;
        backCalc := 0.0;
    END_IF;

ELSE
    (* Manual mode - direct control *)
    CV := ManualCV;
    (* Track integral for bumpless transfer *)
    integral := CV - Kp * Error;
    Saturated := FALSE;
END_IF;

(* === Update Previous Values === *)
prevError := Error;
prevPV := PV;

(* === Map to I/O === *)
(* Output to analog output (0-100% = 0-10000) *)
%QW0 := REAL_TO_INT(CV * 100.0);

(* Read process value from analog input *)
PV := INT_TO_REAL(%IW0) / 100.0;

(* Read setpoint from HMI *)
SP := INT_TO_REAL(%IW1) / 10.0;

(* Mode from digital input *)
AutoMode := %IX0.0;

END_PROGRAM
