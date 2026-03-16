// MQTT Publish/Subscribe Example
// Publishes telemetry and subscribes to command topics
PROGRAM MQTT_PubSub
VAR
    state        : DINT := 0;
    connected    : BOOL := FALSE;
    // Telemetry to publish
    temperature  : REAL := 22.5;
    humidity     : REAL := 45.0;
    pressure     : REAL := 1013.25;
    pub_ok       : BOOL;
    // Subscribed commands
    cmd_setpoint : REAL;
    cmd_enable   : BOOL;
    has_cmd      : BOOL;
    pub_tick     : DINT := 0;
    cycles       : DINT := 0;
END_VAR

CASE state OF
    0: (* INIT — connect to MQTT broker *)
        IF MQTT_CLIENT_CREATE('broker1', 'tcp://10.0.0.100:1883', 'goplc-plc01') THEN
            state := 1;
        END_IF;

    1: (* CONNECT and subscribe *)
        IF MQTT_CLIENT_CONNECT('broker1') THEN
            MQTT_SUBSCRIBE('broker1', 'plant/plc01/cmd/#');
            state := 10;
        END_IF;

    10: (* RUNNING — publish telemetry, check commands *)
        connected := MQTT_CLIENT_IS_CONNECTED('broker1');
        IF NOT connected THEN
            state := 1;
        END_IF;

        // Publish telemetry every 10 scans
        pub_tick := pub_tick + 1;
        IF pub_tick >= 10 THEN
            pub_tick := 0;
            MQTT_PUBLISH('broker1', 'plant/plc01/temperature', temperature);
            MQTT_PUBLISH('broker1', 'plant/plc01/humidity', humidity);
            pub_ok := MQTT_PUBLISH('broker1', 'plant/plc01/pressure', pressure);
        END_IF;

        // Check for incoming commands
        has_cmd := MQTT_HAS_MESSAGE('broker1', 'plant/plc01/cmd/setpoint');
        IF has_cmd THEN
            cmd_setpoint := MQTT_GET_MESSAGE_REAL('broker1', 'plant/plc01/cmd/setpoint');
        END_IF;

        cmd_enable := MQTT_GET_MESSAGE_BOOL('broker1', 'plant/plc01/cmd/enable');
        cycles := cycles + 1;

    ELSE
        state := 0;
END_CASE;
END_PROGRAM
