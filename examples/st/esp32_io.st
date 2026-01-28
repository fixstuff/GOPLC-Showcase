(* ============================================================================
   ESP32 Remote I/O Controller
   ============================================================================
   Control an ESP32-S3 running as a Modbus TCP I/O module:
   - 8 Digital Inputs
   - 8 Digital Outputs
   - 3 Analog Inputs (12-bit ADC)
   - 2 PWM Outputs
   - RGB NeoPixel LED
   ============================================================================ *)

PROGRAM ESP32_IO
VAR
    (* Digital Inputs from ESP32 *)
    DI0 AT %IX0.0 : BOOL;
    DI1 AT %IX0.1 : BOOL;
    DI2 AT %IX0.2 : BOOL;
    DI3 AT %IX0.3 : BOOL;
    DI4 AT %IX0.4 : BOOL;
    DI5 AT %IX0.5 : BOOL;
    DI6 AT %IX0.6 : BOOL;
    DI7 AT %IX0.7 : BOOL;

    (* Digital Outputs to ESP32 *)
    DO0 AT %QX0.0 : BOOL;
    DO1 AT %QX0.1 : BOOL;
    DO2 AT %QX0.2 : BOOL;
    DO3 AT %QX0.3 : BOOL;
    DO4 AT %QX0.4 : BOOL;
    DO5 AT %QX0.5 : BOOL;
    DO6 AT %QX0.6 : BOOL;
    DO7 AT %QX0.7 : BOOL;

    (* ADC Inputs (12-bit, 0-4095) *)
    ADC0 AT %IW0 : INT;
    ADC1 AT %IW1 : INT;
    ADC2 AT %IW2 : INT;

    (* PWM Outputs (0-1023) *)
    PWM0 AT %QW0 : INT;
    PWM1 AT %QW1 : INT;

    (* RGB LED (0-255 each) *)
    LED_R AT %QW10 : INT;
    LED_G AT %QW11 : INT;
    LED_B AT %QW12 : INT;

    (* Calculated values *)
    ADC0_Volts : REAL;
    ADC1_Volts : REAL;
    ADC2_Volts : REAL;

    (* Demo state *)
    Heartbeat : BOOL := FALSE;
    Counter : INT := 0;
    ColorPhase : INT := 0;
END_VAR

(* === Heartbeat Output === *)
Heartbeat := NOT Heartbeat;
DO0 := Heartbeat;

(* === Convert ADC to Voltage === *)
(* ESP32 ADC: 3.3V reference, 12-bit resolution *)
ADC0_Volts := INT_TO_REAL(ADC0) * 3.3 / 4095.0;
ADC1_Volts := INT_TO_REAL(ADC1) * 3.3 / 4095.0;
ADC2_Volts := INT_TO_REAL(ADC2) * 3.3 / 4095.0;

(* === PWM Based on ADC === *)
(* Map ADC0 (0-4095) to PWM0 (0-1023) *)
PWM0 := ADC0 / 4;

(* Map ADC1 to PWM1 with deadband *)
IF ADC1 > 200 THEN
    PWM1 := (ADC1 - 200) / 4;
ELSE
    PWM1 := 0;
END_IF;

(* === RGB LED Color Cycle === *)
Counter := Counter + 1;
IF Counter > 50 THEN
    Counter := 0;
    ColorPhase := ColorPhase + 1;
    IF ColorPhase > 5 THEN
        ColorPhase := 0;
    END_IF;
END_IF;

CASE ColorPhase OF
    0: (* Red *)
        LED_R := 50; LED_G := 0; LED_B := 0;
    1: (* Yellow *)
        LED_R := 50; LED_G := 30; LED_B := 0;
    2: (* Green *)
        LED_R := 0; LED_G := 50; LED_B := 0;
    3: (* Cyan *)
        LED_R := 0; LED_G := 50; LED_B := 50;
    4: (* Blue *)
        LED_R := 0; LED_G := 0; LED_B := 50;
    5: (* Magenta *)
        LED_R := 50; LED_G := 0; LED_B := 50;
END_CASE;

(* Override color based on input *)
IF DI1 THEN
    (* Input 1 = Force Red (alarm) *)
    LED_R := 255; LED_G := 0; LED_B := 0;
ELSIF DI2 THEN
    (* Input 2 = Force Green (OK) *)
    LED_R := 0; LED_G := 255; LED_B := 0;
END_IF;

(* === Digital Output Loopback === *)
DO1 := DI0;
DO2 := DI1;
DO3 := DI2;

END_PROGRAM
