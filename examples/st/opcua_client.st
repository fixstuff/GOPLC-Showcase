// OPC UA Client Example
// Connects to an OPC UA server and reads/writes nodes
PROGRAM OPCUA_Client
VAR
    state       : DINT := 0;
    connected   : BOOL := FALSE;
    // Read values
    temperature : REAL;
    speed_sp    : INT;
    run_status  : BOOL;
    product_id  : STRING;
    // Write values
    new_setpoint : REAL := 75.0;
    write_ok    : BOOL;
    cycles      : DINT := 0;
END_VAR

CASE state OF
    0: (* INIT — create OPC UA client *)
        IF OPCUA_CLIENT_CREATE('srv1', 'opc.tcp://10.0.0.100:4840') THEN
            state := 1;
        END_IF;

    1: (* CONNECT *)
        IF OPCUA_CLIENT_CONNECT('srv1') THEN
            state := 10;
        END_IF;

    10: (* RUNNING — read and write nodes *)
        connected := OPCUA_CLIENT_IS_CONNECTED('srv1');
        IF NOT connected THEN
            state := 1;
        END_IF;

        // Read process values by Node ID
        temperature := OPCUA_CLIENT_READ_REAL('srv1', 'ns=2;s=Temperature');
        speed_sp    := OPCUA_CLIENT_READ_INT('srv1', 'ns=2;s=SpeedSetpoint');
        run_status  := OPCUA_CLIENT_READ_BOOL('srv1', 'ns=2;s=Running');
        product_id  := OPCUA_CLIENT_READ_STRING('srv1', 'ns=2;s=ProductID');

        // Write a setpoint
        write_ok := OPCUA_CLIENT_WRITE_REAL('srv1', 'ns=2;s=TempSetpoint', new_setpoint);

        cycles := cycles + 1;

    ELSE
        state := 0;
END_CASE;
END_PROGRAM
