// IEC 60870-5-104 Client Example
// Connects to a utility SCADA outstation and reads telemetry
PROGRAM IEC104_Client
VAR
    state       : DINT := 0;
    sp1         : BOOL;
    sp2         : BOOL;
    float_val   : REAL;
    scaled_val  : INT;
    counter_val : INT;
    tick_val    : INT;
    prev_tick   : INT;
    tick_live   : BOOL;
    cycles      : DINT := 0;
END_VAR

CASE state OF
    0: (* INIT — connect to IEC 104 outstation *)
        IF IEC104_CLIENT_CREATE('rtu1', '10.0.0.100', 2404) THEN
            IEC104_CLIENT_CONNECT('rtu1');
            state := 10;
        END_IF;

    10: (* RUNNING — read telemetry *)
        sp1        := IEC104_CLIENT_READ_SP('rtu1', 1);
        sp2        := IEC104_CLIENT_READ_SP('rtu1', 2);
        float_val  := IEC104_CLIENT_READ_FLOAT('rtu1', 10);
        scaled_val := IEC104_CLIENT_READ_SCALED('rtu1', 20);
        counter_val := IEC104_CLIENT_READ_COUNTER('rtu1', 30);
        tick_val   := IEC104_CLIENT_READ_COUNTER('rtu1', 31);

        tick_live  := tick_val <> prev_tick;
        prev_tick  := tick_val;
        cycles     := cycles + 1;

    ELSE
        state := 0;
END_CASE;
END_PROGRAM
