# D12 Frequency Converter - ESPHome Configuration

Complete ESPHome configuration for monitoring and controlling a D12 Series Frequency Converter (VFD) via RS485/Modbus RTU using a Wemos D1 Mini.

> **Dual-mode pump control (PAC / irrigation):** an optional package adds an autonomous
> variable-speed controller that **automatically detects** whether the heat pump or the
> irrigation circuit is drawing (from the hydraulics alone) and switches between an
> energy-economy fixed-frequency mode and PID pressure regulation with sleep.
> See **[doc/DUAL-MODE.md](doc/DUAL-MODE.md)** for the full description, state machine and
> use-case timing diagrams.

The heat-pump "demand" signal is deliberately not used as a direct pump-start command:
it also controls the exchanger valve during the heat pump power-on purge. The restored
external start condition is the pressostat low-threshold contact; mode detection remains
hydraulic.

## Hardware Requirements

1. **Wemos D1 Mini** (ESP8266)
2. **RS485 to TTL Module** — *auto-direction* type (MAX485 + direction-control IC, 3.3 V / 5 V compatible, no DE/RE pin)
3. **D12 Frequency Converter** with RS485 terminals
4. Wiring cables

## Wiring Connections

### RS485 Module (TTL side) to Wemos D1 Mini

The auto-direction module exposes a 4-pin TTL header (no DE/RE). Cross TX↔RX:

| RS485 Module | Wemos D1 Mini | Description |
|--------------|---------------|-------------|
| VCC          | **3V3**       | Power — module is 3.3 V/5 V tolerant; use 3.3 V to match the ESP logic levels |
| GND          | GND           | Common ground — this is the RS485 reference, do not omit |
| TXD          | GPIO3 (RX)    | Module → ESP receive |
| RXD          | GPIO1 (TX)    | ESP → module transmit |

> **Auto-direction module:** there is no DE/RE wire, so the `flow_control_pin: GPIO5`
> line in `d12-frequency-converter.yaml` is **unused and can be removed** (this frees
> GPIO5). The module toggles the bus direction by itself.

### RS485 Module (485 side) to D12 Frequency Converter

From the D12 wiring diagram (page 4), connect to the RS485 terminals:

| RS485 Module | D12 Terminal | Description |
|--------------|--------------|-------------|
| A+           | 485+         | RS485 A line |
| B−           | 485-         | RS485 B line |
| 接大地 (earth) | —          | Cable shield / protective earth — **leave unconnected** for a short indoor run; connect to earth only for long outdoor runs |

**Important Notes:**
- The 485 side has **no signal GND** — only the A/B pair (the ground reference is the TTL-side GND, shared ESP ↔ module)
- The module has a built-in 120 Ω termination (jumper `R0`); leave it **open** for the short bus to the D12, the D12's J8 jumper too
- Use twisted pair cable for RS485 connections
- Maximum cable length: ~1000 m (depending on baud rate)

## D12 VFD Configuration

Before using this ESPHome configuration, configure the D12 VFD parameters:

### Essential Parameters (P6 Group - Communication)

| Parameter | Name | Recommended Value | Description |
|-----------|------|-------------------|-------------|
| P6.00 | Local Address | 1 | Modbus slave address (1-247) |
| P6.01 | Communication Config | **0000** | **9600 baud** (the only rate this VFD supports), no parity |
| P6.02 | Timeout | 10.0s | Communication timeout (0 disables) |
| P6.03 | Response Delay | 5ms | Response delay time |

> ⚠️ The **ZT-D12-220V** firmware supports **9600 bps only** — `P6.01` ones digit `1`/`2` are *reserved*, **not** 19200/38400. The ESPHome `uart: baud_rate` must be **9600** to match.

### Run Control Parameters

| Parameter | Name | Recommended Value | Description |
|-----------|------|-------------------|-------------|
| P0.02 | Run Command Channel | 2 | Set to "Communication" for ESPHome control |
| P0.03 | Frequency Source | 6 | Set to "Communication" for ESPHome control |
| P0.04 | Maximum Frequency | 50.0 Hz | Adjust based on your motor |
| P0.05 | Upper Limit Frequency | 50.0 Hz | Maximum allowed frequency |
| P0.09 | Digital Frequency Control | x0xx | Keep thousands digit `0`; the D12 internal PID overlay must not fight ESPHome's Modbus frequency command |

`P0.03` selects the frequency source only. It does not decide where the pressure
sensor is wired. The manuals conflict on this frequency-source table: the older PDF
says `P0.03 = 5` is `ACI` and `7` is pulse input, while the newer OCR addendum says
`5` and `7` are reserved and adds `8 = MPPT`. Pressure feedback still depends on the
PID feedback channel selected by `P3.00`.

### Optional: Communication Format (P6.01)

P6.01 is encoded as `[thousands][hundreds][tens][ones]`.

The ones digit controls the baud rate (ZT-D12-220V):
- 0 = 9600 bps (**only supported rate**)
- 1 = reserved
- 2 = reserved

The tens digit controls parity:
- 0 = No parity (default)
- 1 = Even parity
- 2 = Odd parity

The hundreds digit controls replies:
- 0 = Normal response
- 1 = Respond only to addressed frames
- 2 = No response
- 3 = No response to broadcast free-stop command

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
- **Pressure** - Current pressure from 4-20mA sensor (bar)
- **Pressure Setpoint** - Target pressure setpoint (bar)
- **PID Feedback** - PID feedback value (raw %)
- **PID Setpoint** - PID target value (raw %)
- **Estimated Power** - Calculated power output (W)

#### Binary Sensors (Status)
- **Running** - VFD is running
- **Stopped** - VFD is stopped
- **Jogging** - Jog mode active
- **Forward Direction** - Running in forward direction
- **Reverse Direction** - Running in reverse direction
- **Overload** - VFD/motor overload (from fault code 0x2100)
- **Fault** - any active fault (0x2100 ≠ 0)

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

## Pressure Sensor Configuration (4-20mA Current Input)

The D12 documentation is inconsistent across versions:

- The older PDF and the AliExpress terminal diagrams show both `AVI` and `ACI`, and
  define `P3.00` hundreds digit as `0 = AVI`, `1 = ACI`. In that variant, a 4-20 mA
  pressure sensor is expected on `ACI/GND`.
- The newer OCR addendum says the PID feedback channel is `AVI (0-10 V / 0-20 mA)`
  and marks the old `ACI` feedback option as reserved.

Do not move the pressure sensor based on `P0.03`; that parameter is only the frequency
source. Use the PID feedback variant actually accepted by your D12, then verify that
register `0x210E` follows real pressure.

### Hardware Connection

From the D12 wiring diagram (page 4):

| Component | Terminal | Notes |
|-----------|----------|-------|
| Pressure sensor + | ACI | 4-20mA signal (read raw from Modbus 0x2108) |
| Pressure sensor - | GND | Common ground |
| Sensor power | External 24V | Do NOT power from D12 |

**Important**: Most 4-20mA sensors require external 24V power supply. The D12's auxiliary power outputs (+10V, +12V) are insufficient for powering the Wemos AND sensors.

### D12 / ESPHome Configuration

The ZT-D12-220V exposes the **raw ACI input on Modbus register `0x2108`** (value in mA ×100),
so ESPHome reads the sensor **directly** — **no** D12-side analog scaling (`P2.04–P2.07`),
**no** PID feedback channel (`P3.00`) and **no** `P3.18` are needed. Just:

- set the board's **AI jumper to current (Cin)**;
- wire the sensor **+ → ACI**, **− → GND**, powered from an external 24 V supply.

ESPHome converts it to bar in the `Pressure` template sensor (reads `aci_input` = 0x2108):

```yaml
lambda: |-
  const float range_bar = 10.0;  // pressure at 20 mA — set to your sensor's full scale
  float ma = id(aci_input).state;
  if (isnan(ma)) return NAN;
  float p = (ma - 4.0) / 16.0 * range_bar;
  return p > 0.0 ? p : 0.0;
```

Set `range_bar` to your sensor's span (10.0 for 0-10 bar / 0-1 MPa, 16.0 for 0-16 bar).

### Testing the Pressure Sensor

1. Wire the sensor to **ACI/GND**, AI jumper on **Cin**, apply 24 V to the sensor
2. Check Home Assistant for `sensor.d12_frequency_converter_pressure`
3. At 4 mA → 0 bar; 12 mA → half scale; 20 mA → full scale

### Example Home Assistant Automation

```yaml
automation:
  - alias: "High Pressure Alarm"
    trigger:
      - platform: numeric_state
        entity_id: sensor.d12_frequency_converter_pressure
        above: 8.5
    action:
      - service: switch.turn_off
        target:
          entity_id: switch.d12_frequency_converter_run_forward
      - service: notify.mobile_app
        data:
          message: "Pressure too high! System stopped at {{ states('sensor.d12_frequency_converter_pressure') }} bar"
```

## Features

### Monitoring
- Real-time frequency, voltage, current monitoring
- Pressure monitoring via 4-20mA sensor (optional)
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
- **Baud Rate**: 9600 bps (ZT-D12-220V supports 9600 only)
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
4. **Check response mode** - P6.01 hundreds digit must not be `2` ("no response")
5. **RS485 polarity** - Try swapping A and B lines if no response
6. **Check transceiver type** - A true auto-direction module needs no DE/RE pin. A manual MAX485-style module must have DE and /RE tied together and driven by ESPHome `flow_control_pin`.

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
- **D12 VFD Manual**: See `doc/ZT-D12-220V.pdf` (current firmware; supersedes the older `D12 220V.pdf`)

## License

This configuration is provided as-is for educational and personal use.

## Contributing

Feel free to submit issues or improvements to this configuration.
