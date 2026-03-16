// EtherNet/IP Scanner Example
// Connects to a ControlLogix PLC and reads/writes CIP tags
PROGRAM ENIP_Scanner
VAR
    state       : DINT := 0;
    int_val     : INT;
    real_val    : REAL;
    bool_val    : BOOL;
    dint_val    : DINT;
    prev_int    : INT;
    changing    : BOOL;
    cycles      : DINT := 0;
END_VAR

CASE state OF
    0: (* INIT — create scanner with tag list *)
        IF ENIP_SCANNER_CREATE('plc1', '10.0.0.100', 44818) THEN
            ENIP_SCANNER_ADD_INT_TAG('plc1', 'Speed_SP', 1);
            ENIP_SCANNER_ADD_REAL_TAG('plc1', 'Temperature', 1);
            ENIP_SCANNER_ADD_BOOL_TAG('plc1', 'RunStatus', 1);
            ENIP_SCANNER_ADD_DINT_TAG('plc1', 'TotalCount', 1);
            ENIP_SCANNER_CONNECT('plc1');
            state := 10;
        END_IF;

    10: (* RUNNING — read tags *)
        int_val  := ENIP_SCANNER_READ_INT('plc1', 'Speed_SP', 0);
        real_val := ENIP_SCANNER_READ_REAL('plc1', 'Temperature', 0);
        bool_val := ENIP_SCANNER_READ_BOOL('plc1', 'RunStatus', 0);
        dint_val := ENIP_SCANNER_READ_DINT('plc1', 'TotalCount', 0);

        changing := int_val <> prev_int;
        prev_int := int_val;
        cycles   := cycles + 1;

    ELSE
        state := 0;
END_CASE;
END_PROGRAM
