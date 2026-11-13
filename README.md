# Tuning an i7-12700K on an ASUS TUF Z790 D4

From an ASUS auto-overclocked BIOS ("Remove All Limits") to a cooler, more stable and lower-latency build for **gaming and real-time audio**. A measured, step-by-step account, mistakes included.

**I am not an overclocking professional.** I did this with an AI assistant (Claude) as a co-pilot, and part of the point of this repo is to show what that is worth: one change at a time, the right sensor to read, a measurement after every step, cautious values (power cap instead of "no limits"), and an audit of this write-up against the original conversation that caught overstated claims. Several weeks later the PC runs well and feels very responsive (subjective; the measurements and their limits are below). The assistant and I both made mistakes: they are listed in the guide.

> **Status: work in progress.** The undervolt (AC load line 0.20) has **not** passed long-term validation yet (CoreCycler, Geekbench/3DMark loops). Items marked **TODO** below are not measured yet. Every CPU is different: use this as a *method* and as starting points, never as settings to copy.

**Hardware**: i7-12700K · ASUS TUF GAMING Z790-PLUS WIFI D4 (BIOS 1805) · 4 × 8 GB DDR4-3600 CL18 (Micron Rev. E) · RTX 5080 · Windows 11 build 26200.

**Read the full method**: [GUIDE.md](GUIDE.md)

---

## Results at a glance

PC feels snappier in everyday use (subjective). What the measurements say:

| What | Before | After | Confidence |
|---|---|---|---|
| Load voltage, OCCT CPU + RAM | ~1.231 V (1 h average) | 1.181 V (instantaneous), about −50 mV | Good: same test and settings, but average vs instantaneous reading ([evidence](evidence/README.md)) |
| Load voltage, Cinebench R23 | 1.252 V | 1.172 V, about −80 mV | Good: same test; ring also raised 36 → 39 in between |
| Package power, OCCT CPU + RAM | ~129 W (average) | ~117 W (instantaneous) | Indicative: methods not matched. Under Cinebench it did not change (161 W → 163 W) |
| CPU temperature, OCCT CPU + RAM | ~55 °C (average) | ~49 °C (instantaneous) | Indicative: methods not matched. Under Cinebench: 68 °C → 70 °C max |
| Memory controller (SA) voltage | 1.38 to 1.39 V | **1.25 V** | Solid |
| Memory bandwidth (AIDA64) | 53.3 GB/s | **54.6 GB/s (+2.3 %)** | Solid (single-run noise applies) |
| Time lost to RAM refresh | ≈ 4.5 % | **≈ 1.1 %** | Calculated from tRFC ÷ tREFI |
| Power limits | None (4095 W) | **190 W** | Setting |
| Avg latency, interrupt → DPC (LatencyMon) | 12.4 µs | 4.4 µs | **Indicative only**: runs of 50 s vs 3 h, several changes at once; the baseline already had C3 and ASPM-off |
| Avg latency, interrupt → process (LatencyMon) | 30.2 µs | 19.2 µs | **Indicative only**: same caveat |
| Multi-core score (Cinebench R23) | **TODO (Auto baseline)** | 22 753 | The 190 W cap should cost about 5 % *(estimate)* |
| Idle power / temperature | **TODO** | **TODO** | Expect a cost from C3, ASPM off, EPP 0 |

### Things to know before you copy anything

- The **peak** LatencyMon values got slightly *worse* (1.6 → 2.7 ms) over the much longer run; only the averages improved.
- The snappier feel is subjective, and **which setting causes it is not established**. C3 and ASPM-off were already active in the baseline LatencyMon run, so their effect was never measured on its own; the interrupt affinity, EPP 0 and the tighter memory timings were added in steps that were not isolated either.
- The power-limit, SA-voltage and undervolt changes mainly serve temperature and longevity. The watt and degree savings of the undervolt show up in my OCCT numbers (with the method caveats above) but **not** under Cinebench R23.
- **tREFI 49151 / tRFC 530** was validated with 48 minutes of TM5, not a full hour. DIMMs were logged at 42 °C only on the earlier tREFI 32767 / tRFC 560 step, and never in a gaming session. Re-test in a hot room before trusting it in summer.
- The **AC load line 0.20** undervolt is provisional: Cinebench and short OCCT runs only. CoreCycler, Geekbench and 3DMark were never run. What I do have is an Event Viewer check on 2026-11-13: about three weeks of daily use with **no crash** (no Kernel-Power 41, no unexpected shutdown, no blue screen) and **no WHEA machine-check error**; the only WHEA entries are 7 informational boot-time records from 22 and 24/10, while I was changing BIOS settings, and none since. That is reassuring but not proof: a failing undervolt can corrupt silently, without Windows logging anything.
- MSI mode is **enabled** on the GPU, USB controller and sound card, and the interrupt affinity (CPU 4, 8 and 6) matches the guide; both were checked in the registry on 2026-11-13. I always enable MSI by hand on the GPU and sound card (so I can't say what the drivers do by default), and the toolbox script set the affinity. MSI was not measured separately, so the guide doesn't count it as a gain of this tuning.

## What's in this repo

| Path | Content |
|---|---|
| [GUIDE.md](GUIDE.md) | The full step-by-step method, final BIOS and Windows settings, measurements, mistakes, to-do list |
| [evidence/](evidence/) | 22 screenshots and BIOS photos from the tuning process (Auto BIOS, OCCT, HWiNFO, AIDA64, memory timings, interrupt affinity). They are **step captures, not final-configuration proof**, and the folder README lists what was never captured (Cinebench R23, LatencyMon summary, TM5) |
| [LICENSE.md](LICENSE.md) | CC BY 4.0 |

*Spotted a mistake, or have numbers from a similar setup? Please open an issue.*
