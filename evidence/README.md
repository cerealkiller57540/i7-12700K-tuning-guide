# Evidence

Screenshots and photos backing the numbers in [GUIDE.md](../GUIDE.md). They were recovered from the original tuning conversation (22 October to early November 2026) and converted to JPEG.

**Read this first.** Every file here is a **process capture**: it documents one step, on the date it was taken, **not** the final configuration. None of them is a "final settings" proof. A fresh set on the final configuration is still to do (see the last section).

Photos of the BIOS are phone photos of the monitor. Screenshots show the Windows taskbar; nothing else personal was found (no serial number, key, MAC, account name). The interrupt-affinity tables contain PCI device IDs and registry paths, which are hardware identifiers, not personal data.

## Auto configuration (before any change)

| File | What it shows | Backs |
|---|---|---|
| [bios-auto-power-limits.jpg](bios-auto-power-limits.jpg) | PL1/PL2 4095 W, time window 56 s, current limit 511.75 A, IA AC load line Auto, DC load line 0.20 greyed out | Guide section 3 |
| [bios-auto-llc.jpg](bios-auto-llc.jpg) | LLC Level 4 (already Auto), "Synch ACDC Loadline" Disabled | Guide section 3 |
| [bios-auto-voltages-sa.jpg](bios-auto-voltages-sa.jpg) | CPU System Agent Voltage on Auto, reading 1.377 V; DRAM 1.35 V (reads 1.360 V) | SA voltage "before" |
| [occt-auto-cinebench-load.jpg](occt-auto-cinebench-load.jpg) | OCCT monitoring under all-core load at Auto: 161 W, Vcore 1.252 V, 68 °C, VCCSA 1.248 V, 0 errors | Cinebench "Auto" voltage row |
| [hwinfo-1h-avg-intel-auto.jpg](hwinfo-1h-avg-intel-auto.jpg) | HWiNFO averages over the ~1 h OCCT CPU + RAM run, AC load line Auto: 129.48 W, 55.2 °C | OCCT "Auto" row (power, temperature) |
| [hwinfo-1h-avg-nct-auto.jpg](hwinfo-1h-avg-nct-auto.jpg) | Same run, motherboard sensors: Vcore average 1.231 V | OCCT "Auto" row (voltage) |
| [aida64-before-53337.jpg](aida64-before-53337.jpg) | AIDA64: 53 337 MB/s, 62.0 ns | Memory "before" |

## Undervolt steps (AC load line)

| File | What it shows | Note |
|---|---|---|
| [occt-cpu-ram-ac060.jpg](occt-cpu-ram-ac060.jpg) | AC 0.60, 2 min 10 s into the OCCT CPU + RAM run: 139 W, Vcore 1.261 V, P-core VID 1.306 V | The attempt that *raised* the voltage |
| [occt-cpu-ram-ac020.jpg](occt-cpu-ram-ac020.jpg) | AC 0.20, 1 min 47 s into the run: 117 W, Vcore 1.181 V, 0 errors | Early in the run, still warming up: temperature is not steady-state |
| [occt-monitoring-heavy-load-ac020.jpg](occt-monitoring-heavy-load-ac020.jpg) | AC 0.20 under Cinebench-type load: 163 W, Vcore 1.172 V, 70 °C max | The Min/Avg columns include idle time (min 12 W, 30 °C), so the averages are **not** load averages |
| [occt-idle.jpg](occt-idle.jpg) | Idle snapshot at the tRFC 560 step: about 32 W, 29 to 34 °C | A single idle reading, **no Auto counterpart**: it does not show an idle before/after |

## Memory steps

| File | What it shows | Note |
|---|---|---|
| [memory-timings-trfc560.jpg](memory-timings-trfc560.jpg) | HWiNFO timings with tRFC 560, tREFI 32767, tWR 20, tFAW 16 | Intermediate step |
| [memory-timings-trfc560-trefi32767.jpg](memory-timings-trfc560-trefi32767.jpg) | HWiNFO timings tRFC 560, tREFI 32767, tWR 16 | Intermediate step |
| [aida64-chipset-trfc560-trefi32767.jpg](aida64-chipset-trfc560-trefi32767.jpg) | AIDA64 chipset page: tRFC 560, tREFI 32767, tRRD 4/6, tFAW 16, tWR 16, tRTP 8, 2T | Intermediate step; photo of the screen, taken at an angle |
| [bios-trefi-49151-pending.jpg](bios-trefi-49151-pending.jpg) | BIOS: tREFI 49151 typed while the channels still show 32767 | A value *pending reboot* (lesson 4), not a contradiction |
| [memory-timings-trfc530-trefi49151.jpg](memory-timings-trfc530-trefi49151.jpg) | HWiNFO: tRFC 530, tREFI 49151 applied, tWTR applied as 8/14 although 4/10 was typed | The final memory values |
| [aida64-after-54565.jpg](aida64-after-54565.jpg) | AIDA64: 54 565 MB/s, 61.8 ns at 18-19-19-39, 2T | Memory "after", single run |

## Other settings

| File | What it shows |
|---|---|
| [bios-dynamic-frequency-switching-disabled.jpg](bios-dynamic-frequency-switching-disabled.jpg) | Dynamic Memory Boost, Realtime Memory Frequency and SA GV all Disabled |
| [bios-dtt-disabled.jpg](bios-dtt-disabled.jpg) | Intel Dynamic Tuning Technology Disabled |
| [interrupt-affinity-before.jpg](interrupt-affinity-before.jpg) | Latency Toolbox, before pinning: every device on Default |
| [interrupt-affinity-after.jpg](interrupt-affinity-after.jpg) | After pinning: RTX 5080 on CPU 4, USB 3.20 xHCI on CPU 8, Sound Blaster on CPU 6, the rest Default or SpreadMessages |
| [latencymon-drivers-tab.jpg](latencymon-drivers-tab.jpg) | LatencyMon "Drivers" tab (per-driver DPC/ISR); **not** the summary page |

## Things to check before using these as proof

- **The two Auto rows of the undervolt table come from different sources.** The OCCT "Auto" row (~129 W, ~55 °C, Vcore 1.231 V) is the *average* of a ~1 h run (the two `hwinfo-1h-avg-*` files), while the 0.60 and 0.20 rows are *instantaneous* mid-run readings. The same averages (128.96 W, 55.48 °C) also appear in the AC 0.20 heavy-load capture, which has min 12 W, so idle is included there. I can't tell whether that is a coincidence. The voltage difference (about −50 mV) is the robust part; re-measure power and temperature with one method.
- **OCCT header voltage** (1.25 V / 1.23 V) is not Vcore: in the same screenshots Vcore reads 1.172 V / 1.181 V. The "~1.25 V" before-undervolt figure comes from the Auto load capture (Vcore 1.252 V), not from the header.
- **Temperature at 1:47 or 2:10** is not a steady-state value.
- The **OnSemi "VR VOUT" / "VR IOUT"** lines visible in the OCCT captures (for example 44 A against about 104 A from the CPU's SVID) are the sensor I judged unreliable; read Vcore and SVID IOUT/POUT instead.
- The AIDA64 AFTER photo and the earlier ones are single runs; run-to-run noise applies.

## Not in the evidence (never captured, or never kept)

- Cinebench R23 screenshots, including the 22 753 score (it exists only as a number I typed in the chat) and any Auto-settings score.
- LatencyMon **summary** pages (the 12.4 / 4.4 / 30.2 / 19.2 µs averages and the 1.6 / 2.7 ms peaks): only the Drivers tab survives.
- TM5 / anta777 runs (the 48 minutes) and OCCT Memory runs.
- DIMM temperatures at the final tRFC 530 / tREFI 49151 timings. The 42 °C figure comes from the earlier 560 / 32767 step (OCCT captures show 33 to 38 °C at that time; a 44 °C peak appears in my logs).
- CoreCycler, Geekbench, 3DMark.
- A final-configuration set: BIOS photos of the final values, idle and load monitoring, memory timings, a Cinebench R23 run, with both Auto and AC 0.20 measured with the same method.
