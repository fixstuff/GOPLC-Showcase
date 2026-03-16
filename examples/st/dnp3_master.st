// DNP3 Master Example
// Connects to a utility outstation (RTU) and reads/writes points
PROGRAM DNP3_Master
VAR
    state       : DINT := 0;
    connected   : BOOL := FALSE;
    // Analog inputs — field measurements
    flow_rate   : REAL;
    pressure    : REAL;
    level       : REAL;
    // Binary inputs — equipment status
    pump_run    : BOOL;
    valve_open  : BOOL;
    alarm_hi    : BOOL;
    // Control outputs
    pump_cmd    : BOOL := FALSE;
    setpoint    : REAL := 50.0;
    write_ok    : BOOL;
    counter     : INT;
    cycles      : DINT := 0;
END_VAR

CASE state OF
    0: (* INIT — create DNP3 master, local addr 1, remote addr 10 *)
        IF DNP3_MASTER_CREATE('rtu1', '10.0.0.100', 20000, 1, 10) THEN
            state := 1;
        END_IF;

    1: (* CONNECT *)
        IF DNP3_MASTER_CONNECT('rtu1') THEN
            state := 10;
        END_IF;

    10: (* RUNNING — poll field data *)
        connected := DNP3_MASTER_IS_CONNECTED('rtu1');
        IF NOT connected THEN
            state := 1;
        END_IF;

        // Read analog inputs (field instruments)
        flow_rate := DNP3_MASTER_READ_AI('rtu1', 0);
        pressure  := DNP3_MASTER_READ_AI('rtu1', 1);
        level     := DNP3_MASTER_READ_AI('rtu1', 2);

        // Read binary inputs (equipment status)
        pump_run   := DNP3_MASTER_READ_BI('rtu1', 0);
        valve_open := DNP3_MASTER_READ_BI('rtu1', 1);
        alarm_hi   := DNP3_MASTER_READ_BI('rtu1', 2);

        // Read counter
        counter := DNP3_MASTER_READ_COUNTER('rtu1', 0);

        // Write control outputs
        write_ok := DNP3_MASTER_WRITE_BO('rtu1', 0, pump_cmd);
        DNP3_MASTER_WRITE_AO('rtu1', 0, setpoint);

        cycles := cycles + 1;

    ELSE
        state := 0;
END_CASE;
END_PROGRAM
