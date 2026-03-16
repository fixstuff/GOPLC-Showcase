// Omron FINS Client Example
// Reads/writes DM (Data Memory) words on an Omron PLC
PROGRAM FINS_Client
VAR
    state       : DINT := 0;
    dm_data     : ARRAY[0..10] OF INT;
    prev_tick   : INT;
    tick_live   : BOOL;
    write_ok    : BOOL;
    readback    : ARRAY[0..1] OF INT;
    write_pass  : BOOL;
    cycles      : DINT := 0;
END_VAR

CASE state OF
    0: (* INIT — connect to Omron PLC *)
        IF FINS_CLIENT_CREATE('omron1', '10.0.0.100', 9600) THEN
            FINS_CLIENT_CONNECT('omron1');
            state := 10;
        END_IF;

    10: (* RUNNING — bulk read DM, write-back test *)
        dm_data := FINS_CLIENT_READ_DM('omron1', 0, 11);

        tick_live := dm_data[10] <> prev_tick;
        prev_tick := dm_data[10];

        // Write a value and read it back to verify
        write_ok  := FINS_CLIENT_WRITE_DM_WORD('omron1', 20, 8888);
        readback  := FINS_CLIENT_READ_DM('omron1', 20, 2);
        write_pass := readback[0] = 8888;

        cycles := cycles + 1;

    ELSE
        state := 0;
END_CASE;
END_PROGRAM
