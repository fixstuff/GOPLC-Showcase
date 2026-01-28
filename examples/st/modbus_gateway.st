(* ============================================================================
   Modbus Gateway - Bridge Between Modbus Devices
   ============================================================================
   This program demonstrates GOPLC's protocol bridging capabilities:
   - Read from remote Modbus TCP devices
   - Aggregate data into local registers
   - Expose via built-in Modbus server
   ============================================================================ *)

VAR_GLOBAL
    (* Gateway status *)
    GW_DevicesOnline : INT := 0;
    GW_TotalReads : DINT := 0;
    GW_TotalErrors : DINT := 0;
    GW_LastError : STRING := '';

    (* Aggregated sensor data *)
    Sensor_Temp_Zone1 : REAL := 0.0;
    Sensor_Temp_Zone2 : REAL := 0.0;
    Sensor_Temp_Zone3 : REAL := 0.0;
    Sensor_Humidity : REAL := 0.0;
    Sensor_Pressure : REAL := 0.0;

    (* Control outputs *)
    Control_Setpoint : REAL := 22.0;
    Control_Enable : BOOL := TRUE;
END_VAR

PROGRAM ModbusGateway
VAR
    (* Modbus client handles *)
    mbClient1 : DINT := 0;
    mbClient2 : DINT := 0;
    mbClient3 : DINT := 0;

    (* Polling state *)
    pollCycle : INT := 0;
    initialized : BOOL := FALSE;

    (* Read buffers *)
    rawTemp1 : INT;
    rawTemp2 : INT;
    rawTemp3 : INT;
    rawHumidity : INT;
    rawPressure : INT;

    (* Conversion constants *)
    TEMP_SCALE : REAL := 0.1;    (* Raw value * 0.1 = degrees C *)
    HUM_SCALE : REAL := 0.1;     (* Raw value * 0.1 = %RH *)
    PRESS_SCALE : REAL := 0.01;  (* Raw value * 0.01 = kPa *)
END_VAR

(* === Initialize Modbus Clients === *)
IF NOT initialized THEN
    (* Create client connections to remote devices *)
    mbClient1 := MB_CLIENT_CREATE('device1', '192.168.1.10', 502, 1);
    mbClient2 := MB_CLIENT_CREATE('device2', '192.168.1.11', 502, 1);
    mbClient3 := MB_CLIENT_CREATE('device3', '192.168.1.12', 502, 1);

    IF mbClient1 > 0 AND mbClient2 > 0 AND mbClient3 > 0 THEN
        initialized := TRUE;
        GW_DevicesOnline := 3;
    END_IF;
END_IF;

(* === Poll Devices in Round-Robin === *)
IF initialized THEN
    pollCycle := pollCycle + 1;
    IF pollCycle > 2 THEN
        pollCycle := 0;
    END_IF;

    CASE pollCycle OF
        0: (* Read Zone 1 Temperature from Device 1 *)
            IF MB_READ_HOLDING_REGISTERS(mbClient1, 0, 1, rawTemp1) THEN
                Sensor_Temp_Zone1 := INT_TO_REAL(rawTemp1) * TEMP_SCALE;
                GW_TotalReads := GW_TotalReads + 1;
            ELSE
                GW_TotalErrors := GW_TotalErrors + 1;
                GW_LastError := 'Device1 read failed';
            END_IF;

        1: (* Read Zone 2 & 3 from Device 2 *)
            IF MB_READ_HOLDING_REGISTERS(mbClient2, 0, 2, rawTemp2) THEN
                Sensor_Temp_Zone2 := INT_TO_REAL(rawTemp2) * TEMP_SCALE;
                Sensor_Temp_Zone3 := INT_TO_REAL(rawTemp3) * TEMP_SCALE;
                GW_TotalReads := GW_TotalReads + 1;
            ELSE
                GW_TotalErrors := GW_TotalErrors + 1;
                GW_LastError := 'Device2 read failed';
            END_IF;

        2: (* Read Humidity & Pressure from Device 3 *)
            IF MB_READ_HOLDING_REGISTERS(mbClient3, 0, 2, rawHumidity) THEN
                Sensor_Humidity := INT_TO_REAL(rawHumidity) * HUM_SCALE;
                Sensor_Pressure := INT_TO_REAL(rawPressure) * PRESS_SCALE;
                GW_TotalReads := GW_TotalReads + 1;
            ELSE
                GW_TotalErrors := GW_TotalErrors + 1;
                GW_LastError := 'Device3 read failed';
            END_IF;
    END_CASE;
END_IF;

(* === Map to Modbus Server Registers === *)
(* These are accessible via the built-in Modbus server *)
%QW0 := REAL_TO_INT(Sensor_Temp_Zone1 / TEMP_SCALE);
%QW1 := REAL_TO_INT(Sensor_Temp_Zone2 / TEMP_SCALE);
%QW2 := REAL_TO_INT(Sensor_Temp_Zone3 / TEMP_SCALE);
%QW3 := REAL_TO_INT(Sensor_Humidity / HUM_SCALE);
%QW4 := REAL_TO_INT(Sensor_Pressure / PRESS_SCALE);
%QW5 := REAL_TO_INT(Control_Setpoint / TEMP_SCALE);
%QW6 := GW_DevicesOnline;
%QW7 := DINT_TO_INT(GW_TotalReads MOD 32767);
%QW8 := DINT_TO_INT(GW_TotalErrors MOD 32767);

(* Read setpoint from external SCADA *)
Control_Setpoint := INT_TO_REAL(%IW0) * TEMP_SCALE;
Control_Enable := %IX0.0;

END_PROGRAM
