// ctrlX Data Layer — EtherCAT I/O via Native IPC
// Reads digital inputs and toggles digital outputs on ctrlX CORE
PROGRAM DataLayer_EtherCat
VAR
    state       : DINT := 0;
    connected   : BOOL := FALSE;
    di1         : BOOL := FALSE;
    di2         : BOOL := FALSE;
    di3         : BOOL := FALSE;
    di4         : BOOL := FALSE;
    do1         : BOOL := FALSE;
    toggle      : BOOL := FALSE;
    toggle_tmr  : TON;
    write_ok    : BOOL := FALSE;
    stats       : STRING := '';
    tick        : DINT := 0;
END_VAR

CASE state OF
    0: (* INIT — create EtherCAT connection, native IPC mode *)
        IF CTRLX_EC_CREATE('ec1', '', '', '', 'XI110116', 'XI211116', 16, 16, 10, 'dl') THEN
            CTRLX_EC_START('ec1');
            state := 10;
        END_IF;

    10: (* RUNNING — read inputs, toggle outputs *)
        connected := CTRLX_EC_CONNECTED('ec1');
        IF NOT connected THEN
            state := 0;
        END_IF;

        di1 := CTRLX_EC_READ_DI('ec1', 1);
        di2 := CTRLX_EC_READ_DI('ec1', 2);
        di3 := CTRLX_EC_READ_DI('ec1', 3);
        di4 := CTRLX_EC_READ_DI('ec1', 4);

        // Toggle output every 100ms
        toggle_tmr(IN := NOT toggle_tmr.Q, PT := T#100ms);
        IF toggle_tmr.Q THEN
            toggle := NOT toggle;
        END_IF;

        write_ok := CTRLX_EC_WRITE_DO('ec1', 1, toggle);
        do1 := CTRLX_EC_READ_DO('ec1', 1);
        stats := CTRLX_EC_STATS('ec1');
        tick := tick + 1;

    ELSE
        state := 0;
END_CASE;
END_PROGRAM
