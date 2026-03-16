// BACnet/IP Client Example
// Connects to a BACnet server and reads standard object types
PROGRAM BACnet_Client
VAR
    state       : DINT := 0;
    connected   : BOOL := FALSE;
    temp_zone1  : REAL;
    temp_zone2  : REAL;
    fan_status  : BOOL;
    setpoint    : REAL;
    tick_val    : REAL;
    prev_tick   : REAL;
    tick_live   : BOOL;
    cycles      : DINT := 0;
END_VAR

CASE state OF
    0: (* INIT — create BACnet client *)
        IF BACNET_CLIENT_CREATE('bac1', '10.0.0.100', 999, 0, 47808) THEN
            BACNET_CLIENT_CONNECT('bac1');
            state := 1;
        END_IF;

    1: (* WAIT FOR CONNECTION *)
        IF BACNET_CLIENT_IS_CONNECTED('bac1') THEN
            state := 10;
        END_IF;

    10: (* RUNNING — read BACnet objects *)
        temp_zone1 := BACNET_READ_AI('bac1', 0);
        temp_zone2 := BACNET_READ_AI('bac1', 1);
        fan_status := BACNET_READ_BI('bac1', 0);
        setpoint   := BACNET_READ_AV('bac1', 0);
        tick_val   := BACNET_READ_AI('bac1', 2);

        tick_live  := tick_val <> prev_tick;
        prev_tick  := tick_val;
        cycles     := cycles + 1;

    ELSE
        state := 0;
END_CASE;
END_PROGRAM
