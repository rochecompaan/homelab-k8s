# Mosquitto MQTT Broker

Deploys Eclipse Mosquitto MQTT broker with persistence.

## Configuration

- **MQTT**: Port 1883 (TCP)
- **WebSockets**: Port 9001 (TCP)
- **Storage**: 1Gi persistent volume on longhorn

## Authentication

Currently running with `allow_anonymous true` for easy homelab testing.

### To enable authentication:

1. Generate a password file using `mosquitto_passwd`:

```bash
# Run a temporary container to generate the hash
docker run --rm -it eclipse-mosquitto:2.0.21 \
  mosquitto_passwd -c /tmp/pwfile mqttuser
```

2. Create a Secret with the password file:

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: mosquitto-auth
type: Opaque
stringData:
  pwfile: |
    mqttuser:$7$101$...
```

3. Update the ConfigMap to reference the password file and set `allow_anonymous false`

4. Mount the Secret into the Deployment

## Usage Example

```bash
# Subscribe to a topic
mosquitto_sub -h mosquitto.iot.svc.cluster.local -t "test/topic"

# Publish to a topic
mosquitto_pub -h mosquitto.iot.svc.cluster.local -t "test/topic" -m "Hello"
```
