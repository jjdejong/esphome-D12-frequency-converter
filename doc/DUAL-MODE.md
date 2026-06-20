# Dual-Mode Control — Heat-pump (PAC) / Irrigation with automatic detection

This document describes the `dual-mode-control.yaml` ESPHome package, which turns the
D12 + D1 mini into an autonomous variable-speed pump controller serving **two uses**
from the same 100 L buffer tank:

- **PAC mode** — the ground-source heat pump draws well water through a low-resistance
  exchanger. Goal: lowest energy (≈144 W) at a low fixed economy frequency.
- **Irrigation mode** — sprinklers/nozzles, a high-resistance circuit. Goal: regulated
  pressure (≈2.5 bar) with automatic sleep when taps are closed.

The two uses are told apart **automatically**, from the hydraulics alone — no extra wire
to the heat pump.

> The package is optional and self-contained. It is loaded from the main config via
> `packages: dual_mode: !include dual-mode-control.yaml`. Comment that line to disable it.

---

## 1. Principle of automatic detection

Both consumers draw a **similar flow** (PAC ≈ 2.44 m³/h, irrigation ≈ 2.0 m³/h), so the
*rate of pressure drop* does **not** distinguish them. What differs by ~6× is the
**hydraulic resistance** of the active circuit:

| | Circuit | Resistance | Pressure at a fixed frequency |
|---|---|---|---|
| **PAC** | exchanger, large bore | low ("soft") | **low** (~0.4–1 bar) |
| **Irrigation** | nozzles | high ("stiff") | **high** (≈2.5 bar) |

So the controller **imposes a reference probe frequency** (`F probe`, ~38 Hz) for a few
seconds at start-up and reads the resulting **operating point** (steady pressure +
current):

- low pressure + real current ⇒ **PAC** → economy fixed-frequency mode;
- high pressure ⇒ **irrigation** → PID pressure regulation to the setpoint;
- high pressure + negligible current ⇒ **no draw** → go back to sleep.

The buffer tank only adds a short settling delay; at equilibrium it does not hide the
consumer's signature.

---

## 2. Architecture

- **Brain = ESPHome** (`P0.02 = Communication`, `P0.03 = Communication`): start/stop,
  mode detection, frequency command, PID, sleep. All logic is visible and tunable from
  Home Assistant.
- **Independent hardware safety net = the mechanical pressure switch** wired to the D12
  *external-fault* input, set at **wide limits (0.1 / 5.0 bar)** — dry-run and
  over-pressure protection that works **even if the ESP fails**. Plus the D12's own
  over-current / over-temperature protections.

This is the design chosen for this installation: a flexible software brain plus a simple
hardware guardian.

---

## 3. State machine

![Dual-mode state machine](dual-mode-state-machine.svg)

State names map to the `DM État` text sensor: **Repos** (IDLE), **Détection** (PROBE),
**PAC (éco)**, **Arrosage (PID)**, **Anti-court-cycle** (COOLDOWN).

### Mode selector (`DM Mode`)

| Option | Behaviour |
|---|---|
| **Auto** | full automatic detection (probe → PAC or Irrigation) |
| **PAC** | force economy fixed-frequency mode (skip probe) |
| **Arrosage** | force PID pressure regulation (skip probe) |
| **Off** | controller idle, pump kept stopped — **default after a fresh flash** |

---

## 4. Tunable parameters (Home Assistant)

| Entity | Default | Meaning |
|---|---|---|
| `DM P start (marche)` | 1.5 bar | pressure below which a cycle starts |
| `DM P stop (arrêt PAC)` | 2.0 bar | PAC fill/stop target (draw-ended detection) |
| `DM P consigne arrosage` | 2.5 bar | irrigation PID setpoint |
| `DM F éco PAC` | 38 Hz | fixed economy frequency in PAC mode |
| `DM F sonde (détection)` | 38 Hz | reference frequency during detection |
| `DM P seuil classification` ⚙️ | 1.4 bar | **calibrate** — PAC below / irrigation above, at F probe |
| `DM I mini débit` ⚙️ | 0.3 A | **calibrate** — min current proving a real draw |
| `DM F max` | 50 Hz | upper frequency limit |
| `DM F min (plancher sleep)` | 22 Hz | lower frequency / sleep floor |
| `DM PID Kp (Hz par bar)` | 8.0 | irrigation PID proportional gain |
| `DM PID Ki (Hz par bar.s)` | 2.0 | irrigation PID integral gain |

Fixed timers (in the lambda): probe 10 s, min run 60 s, min off 90 s, sleep delay 45 s,
max run 20 min (runaway guard).

---

## 5. Use-case timing diagrams

### Case A — PAC cycle (Auto)
Detection finds a soft circuit, the pump runs at the economy frequency, fills the tank,
stops at `P stop`, then waits out the anti-short-cycle delay.

![PAC cycle](dual-mode-pac-cycle.svg)

### Case B — Irrigation with sleep / wake
Detection finds a stiff circuit, the PID holds 2.5 bar; when the tap closes the frequency
falls to `F min`, and after 45 s the pump sleeps. Reopening a tap wakes it.

![Irrigation + sleep](dual-mode-irrigation-sleep.svg)

### Case C — PAC purge ride-through
At every power-up the heat pump runs a ~3 min air purge with intermittent short draws.
Because start/stop is driven by **tank pressure** (not by any heat-pump contact) and the
anti-short-cycle timer caps restarts, the saw-tooth purge is absorbed by the buffer tank.

![Purge handling](dual-mode-purge.svg)

### Case D — Communication-loss safety
If the D12 stops answering, the raw Modbus registers read NaN; the "comms-alive" guard
forces the pump OFF and the state back to Repos. (Note: the `Pressure` sensor reads
**0.00 bar, not NaN**, when offline, so the guard checks the raw registers
`pid_feedback` / `output_frequency`, never `pressure_sensor`.)

![Comms loss](dual-mode-comms-loss.svg)

---

## 6. Commissioning & calibration

Do this **in order**:

1. **Hardware safety first** — wire the mechanical pressure switch (0.1 / 5.0 bar) to the
   D12 external-fault input. Do not run automatically before this is in place.
2. **Pressure-register check** — set `P0.03 = Communication` and confirm the *Pressure*
   entity still tracks real pressure (it is read from register `0x210E`, fed by the ACI
   feedback channel `P3.00` hundreds = ACI). This is the only open unknown.
3. **D12 parameters** — `P0.02 = 2`, `P0.03 = 6`, `P3.00` hundreds = 1 (ACI), plus the
   ACI scaling (`P2.04..P2.07`, `P3.18`).
4. **Calibrate detection** — run the pump at `F probe` (38 Hz) once in **PAC only** and
   once in **irrigation only**; read the steady pressure each time. Set
   `DM P seuil classification` halfway between them. Read the running current to set
   `DM I mini débit`.
5. **Go live** — keep `DM Mode = Off`, then switch to `Auto`; watch `DM État` and
   `DM Mode détecté`. Tune `Kp` / `Ki` if the irrigation pressure oscillates.

---

## 7. Safety summary

- **Default mode `Off`** on a fresh device — never auto-runs the pump until explicitly set
  to `Auto`.
- **Comms-alive guard** — no pump command unless the D12 is answering.
- **Anti-short-cycle** (min on/off) and **max-run** software guards.
- **Mechanical pressure switch** at wide limits = independent hardware protection.
- These software guards do **not** replace the hardware pressure switch.

---

## 8. Wiring note (RS485 module)

This installation uses an **auto-direction** RS485↔TTL module (MAX485 + direction-control
IC, 3.3 V / 5 V compatible). There is **no DE/RE pin** to wire, so ESPHome's
`flow_control_pin: GPIO5` is unused and can be removed (freeing GPIO5). Power the module
at **3.3 V** so logic levels match the D1 mini. See the main [README](../README.md#wiring-connections)
for the full pinout.
