// Modbus TCP Client Example
// Reads holding registers, input registers, and coils from a Modbus server
PROGRAM Modbus_Client
VAR
    state       : DINT := 0;
    hr_data     : ARRAY[0..10] OF INT;
    ir_data     : ARRAY[0..1] OF INT;
    coils       : ARRAY[0..2] OF BOOL;
    prev_tick   : INT;
    tick_live   : BOOL;
    write_ok    : BOOL;
    readback    : ARRAY[0..1] OF INT;
    write_pass  : BOOL;
    cycles      : DINT := 0;
END_VAR

CASE state OF
    0: (* INIT — connect to Modbus server *)
        IF MB_CLIENT_CREATE('mb1', '10.0.0.100', 502) THEN
            MB_CLIENT_CONNECT('mb1');
            state := 10;
        END_IF;

    10: (* RUNNING — read registers and coils *)
        hr_data := MB_READ_HOLDING('mb1', 0, 11);
        ir_data := MB_READ_INPUT('mb1', 0, 2);
        coils   := MB_READ_COILS('mb1', 0, 3);

        tick_live := hr_data[10] <> prev_tick;
        prev_tick := hr_data[10];

        // Write-back test
        write_ok  := MB_WRITE_REGISTER('mb1', 20, 7777);
        readback  := MB_READ_HOLDING('mb1', 20, 2);
        write_pass := readback[0] = 7777;

        cycles := cycles + 1;

    ELSE
        state := 0;
END_CASE;
END_PROGRAM
