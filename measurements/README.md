# Measurements

Runs logged with [tools/measure.ps1](../tools/measure.ps1): 5 minutes idle, then Cinebench R23 multi-core (minimum 10 minutes), every LibreHardwareMonitor sensor read once per second. Load averages skip the first 60 seconds. Each run has four files with the same prefix:

| Suffix | Content |
|---|---|
| `-summary.txt` | Phase times, mean / min / max per sensor and phase, Cinebench score |
| `-samples.csv` | Every reading (time, phase, seconds into the phase, sensor, value) |
| `-cinebench.txt` | Cinebench console output (score of each pass) |
| `-hwinfo.csv` | HWiNFO sensor log started by hand during the run, when present |

**Use HWiNFO for Vcore.** LibreHardwareMonitor reads the Nuvoton NCT6798D "Vcore" about 0.12 V low on this board (1.057 V against 1.173 V in HWiNFO, same run). Its CPU VID, package power and temperatures agree with HWiNFO.

## Runs

| Prefix | Settings | Valid? | Idle (package) | Cinebench load (package, after 60 s) | Score |
|---|---|---|---|---|---|
| `20261113-1459-ac020` | Final configuration, AC load line 0.20 | **Yes**. FanControl running | 17 W, 28 °C | Vcore 1.173 V (HWiNFO), VID 1.224 V, 162 W, 66 °C avg / 69 °C max, no throttling | 22 721 |
| `20261113-1432-ac020-fancontrol-off` | Same settings | **Temperatures invalid**: FanControl was not running, so the fans followed the BIOS curves (78 °C max). Power, VID and score are usable | 14 W | 164 W, VID 1.232 V | 22 811 |

The HWiNFO log of the valid run starts at 15:03, partway through the idle phase (15:00:29 to 15:05:30); the load phase runs from 15:05:30 to 15:16:10.

No Auto-settings run has been logged this way yet.
