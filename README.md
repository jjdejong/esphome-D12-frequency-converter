# D12 Frequency Converter - ESPHome Configuration

Complete ESPHome configuration for monitoring and controlling a D12 Series Frequency Converter (VFD) via RS485/Modbus RTU using a Wemos D1 Mini.

## Hardware Requirements

1. **Wemos D1 Mini** (ESP8266)
2. **RS485 to TTL Module** (e.g., MAX485, MAX3485)
3. **D12 Frequency Converter** with RS485 terminals
4. Wiring cables

## Wiring Connections

### RS485 Module to Wemos D1 Mini

| RS485 Module | Wemos D1 Mini | Description |
|--------------|---------------|-------------|
| VCC          | 5V            | Power supply |
| GND          | GND           | Ground |
| DI (TXD)     | GPIO1 (TX)    | Transmit data |
| RO (RXD)     | GPIO3 (RX)    | Receive data |
| DE           | GPIO5 (D1)    | Driver Enable (optional) |
| RE           | GPIO5 (D1)    | Receiver Enable (optional) |

### RS485 Module to D12 Frequency Converter

From the D12 wiring diagram (page 4), connect to the RS485 terminals:

| RS485 Module | D12 Terminal | Description |
|--------------|--------------|-------------|
| A (or +)     | 485+         | RS485 A line |
| B (or -)     | 485-         | RS485 B line |

**Important Notes:**
- The D12 has J8 jumper for 485 terminal resistor selection (default disconnected)
- For long cable runs or multiple devices, you may need to connect the 120Ω termination resistor
- Use twisted pair cable for RS485 connections
- Maximum cable length: ~1000m (depending on baud rate)

## D12 VFD Configuration

Before using this ESPHome configuration, configure the D12 VFD parameters:

### Essential Parameters (P6 Group - Communication)

| Parameter | Name | Recommended Value | Description |
|-----------|------|-------------------|-------------|
| P6.00 | Local Address | 1 | Modbus slave address (1-247) |
| P6.01 | Communication Config | 0001 | 19200 baud, no parity |
| P6.02 | Timeout | 10.0s | Communication timeout |
| P6.03 | Response Delay | 5ms | Response delay time |

### Run Control Parameters

| Parameter | Name | Recommended Value | Description |
|-----------|------|-------------------|-------------|
| P0.02 | Run Command Channel | 2 | Set to "Communication" for ESPHome control |
| P0.03 | Frequency Source | 6 | Set to "Communication" for ESPHome control |
| P0.04 | Maximum Frequency | 50.0 Hz | Adjust based on your motor |
| P0.05 | Upper Limit Frequency | 50.0 Hz | Maximum allowed frequency |

### Optional: Baud Rate Configuration (P6.01)

The tens digit of P6.01 controls the baud rate:
- 0 = 9600 bps
- 1 = 19200 bps (default)
- 2 = 38400 bps

The ones digit controls parity:
- 0 = No parity (default)
- 1 = Even parity
- 2 = Odd parity

## ESPHome Setup

### 1. Install ESPHome

```bash
pip install esphome
```

### 2. Configure Secrets

Edit `secrets.yaml` with your WiFi credentials and passwords:

```yaml
wifi_ssid: "Your_WiFi_SSID"
wifi_password: "Your_WiFi_Password"
ota_password: "your_secure_password"
ap_password: "fallback_password"
```

### 3. Validate Configuration

```bash
esphome config d12-frequency-converter.yaml
```

### 4. Compile and Upload

First upload (via USB):
```bash
esphome run d12-frequency-converter.yaml
```

Subsequent uploads (OTA):
```bash
esphome run d12-frequency-converter.yaml --device d12-frequency-converter.local
```

## Home Assistant Integration

### Available Entities

#### Sensors (Read-only)
- **Output Frequency** - Current motor frequency (Hz)
- **Set Frequency** - Target frequency setpoint (Hz)
- **Output Current** - Motor current draw (A)
- **Bus Voltage** - DC bus voltage (V)
- **Output Voltage** - AC output voltage (V)
- **Temperature** - Inverter module temperature (°C)
- **PID Feedback** - PID feedback value
- **PID Setpoint** - PID target value
- **Estimated Power** - Calculated power output (W)

#### Binary Sensors (Status)
- **Running** - VFD is running
- **Stopped** - VFD is stopped
- **Jogging** - Jog mode active
- **Forward Direction** - Running in forward direction
- **Reverse Direction** - Running in reverse direction
- **Overload Warning** - Overload pre-alarm

#### Controls
- **Frequency Setpoint** - Number slider (-100% to 100%)
- **Run Forward** - Switch to start forward rotation
- **Run Reverse** - Switch to start reverse rotation
- **Stop** - Button to stop the VFD
- **Jog Forward/Reverse** - Buttons for jog operation
- **Fault Reset** - Button to reset fault conditions

#### Configuration
- **Run Command Source** - Select control source (Panel/Terminal/Communication)
- **Frequency Source** - Select frequency source

### Example Home Assistant Automations

#### Start VFD at 50% Speed

```yaml
automation:
  - alias: "Start VFD Morning"
    trigger:
      - platform: time
        at: "08:00:00"
    action:
      - service: number.set_value
        target:
          entity_id: number.d12_frequency_converter_frequency_setpoint
        data:
          value: 50
      - service: switch.turn_on
        target:
          entity_id: switch.d12_frequency_converter_run_forward
```

#### Temperature Protection

```yaml
automation:
  - alias: "VFD Overtemp Protection"
    trigger:
      - platform: numeric_state
        entity_id: sensor.d12_frequency_converter_temperature
        above: 75
    action:
      - service: switch.turn_off
        target:
          entity_id: switch.d12_frequency_converter_run_forward
      - service: notify.mobile_app
        data:
          message: "VFD temperature too high! Stopped for safety."
```

## Features

### Monitoring
- Real-time frequency, voltage, current monitoring
- Temperature monitoring with overheating protection
- Status indicators (running, direction, warnings)
- Power estimation
- PID control feedback (if enabled on VFD)

### Control
- Start/Stop with forward or reverse direction
- Frequency setpoint adjustment (-100% to 100%)
- Jog operation for precise control
- Fault reset functionality
- Remote configuration of control sources

### Safety Features
- Communication timeout detection
- Overload warning indication
- Fault status monitoring
- Temperature monitoring

## Modbus Communication Details

### Protocol
- **Type**: Modbus RTU
- **Baud Rate**: 19200 bps (configurable)
- **Data Bits**: 8
- **Stop Bits**: 1
- **Parity**: None
- **Function Codes**: 03 (Read), 06 (Write)

### Key Register Addresses

| Address | Type | Description | Units |
|---------|------|-------------|-------|
| 0x2000 | W | Control command | - |
| 0x2001 | W | Frequency setpoint | 0.01% |
| 0x2102 | R | Set frequency | 0.01 Hz |
| 0x2103 | R | Output frequency | 0.01 Hz |
| 0x2104 | R | Output current | 0.1 A |
| 0x2105 | R | Bus voltage | 1 V |
| 0x2106 | R | Output voltage | 1 V |
| 0x210D | R | Module temperature | 0.1 °C |
| 0x2101 | R | Status word | Bitmap |

### Control Commands (0x2000)

| Value | Command |
|-------|---------|
| 0x0001 | Stop |
| 0x0012 | Forward |
| 0x0013 | Forward Jog |
| 0x0022 | Reverse |
| 0x0023 | Reverse Jog |

## Troubleshooting

### No Communication

1. **Check wiring** - Verify RS485 A/B connections are correct
2. **Check baud rate** - Ensure ESPHome config matches VFD setting (P6.01)
3. **Check address** - Verify modbus address matches (P6.00)
4. **Check control source** - Set P0.02 and P0.03 to "Communication" (value 2/6)
5. **RS485 polarity** - Try swapping A and B lines if no response

### VFD Not Responding to Commands

1. **Verify P0.02 = 2** - Run command channel must be set to Communication
2. **Verify P0.03 = 6** - Frequency source must be set to Communication
3. **Check parameter lock** - Ensure P0.23 (user password) allows modifications
4. **Check fault status** - VFD won't run if there's an active fault

### Reading Errors

1. **Increase update interval** - Try 5s instead of 2s in configuration
2. **Check RS485 termination** - Add 120Ω resistor if needed (J8 jumper)
3. **Reduce EMI** - Keep RS485 cables away from motor power cables
4. **Add delay** - Increase P6.03 (response delay) if needed

### Temperature Issues

- Ensure adequate ventilation around VFD
- Check ambient temperature (should be below 40°C)
- Clean dust from cooling fins
- Verify cooling fan operation

## Advanced Configuration

### Multiple VFDs

To control multiple D12 VFDs:

1. Set each VFD to a unique address (P6.00): 1, 2, 3, etc.
2. Create separate yaml files or use substitutions:

```yaml
substitutions:
  device_name: d12-vfd-pump1
  modbus_address: "1"

# ... rest of config
```

3. Connect all VFDs to the same RS485 bus (parallel connection)
4. Add 120Ω termination resistor only at the ends of the bus

### Custom Parameters

You can add read/write access to any D12 parameter by adding its address. Parameter addresses follow the pattern:

- P0.00 = 0x0000
- P1.05 = 0x0105
- P6.01 = 0x0601

Example for reading acceleration time (P0.10):

```yaml
sensor:
  - platform: modbus_controller
    modbus_controller_id: d12_vfd
    name: "${friendly_name} Acceleration Time"
    address: 0x000A  # P0.10
    value_type: U_WORD
    unit_of_measurement: "s"
    accuracy_decimals: 1
    filters:
      - multiply: 0.1
```

## Safety Warnings

⚠️ **DANGER: HIGH VOLTAGE**

- The D12 VFD operates at mains voltage (220V AC)
- Only qualified electricians should perform electrical connections
- Always disconnect power before working on connections
- Follow all local electrical codes and regulations
- The motor must be properly grounded
- Use appropriate wire sizes for motor current

⚠️ **Motor Protection**

- Configure motor parameters (P4 group) correctly
- Set appropriate overload protection (P5 group)
- Ensure motor ratings match VFD output
- Do not exceed motor rated frequency

## Support and Documentation

- **ESPHome Documentation**: https://esphome.io
- **Modbus Protocol**: Standard Modbus RTU
- **D12 VFD Manual**: See `doc/D12 220V.pdf`

## License

This configuration is provided as-is for educational and personal use.

## Contributing

Feel free to submit issues or improvements to this configuration.
