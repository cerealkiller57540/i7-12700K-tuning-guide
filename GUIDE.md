# Tuning an i7-12700K on an ASUS TUF Z790 D4: the full method

The detailed, step-by-step account behind the [README](README.md). Every number below was measured on my machine unless it is marked *(spec)*, *(estimate)* or **TODO** (not measured yet). The mistakes are included on purpose, because they teach more than the successes.

## Why this guide exists

I am **not** an overclocking professional. I did this tuning with an AI assistant (Claude) as a co-pilot, and part of the point of this guide is to show what that kind of help is worth for a job like this:

- It explained each BIOS setting before I touched it, and proposed **one change at a time**.
- It told me which sensor to trust and which to ignore (for example, the OCCT header voltage is not Vcore, and VRM output readings are unreliable), and asked me to **measure after every step** instead of trusting a setting.
- It kept the work cautious: power cap instead of "no limits", modest voltage steps, validation runs before moving on, and a rollback plan.
- It helped me document the process, and it later **audited this very guide against the original conversation log**, which is how several overstated claims (run lengths, which readings were averages, what was never measured) were found and corrected.

The assistant was not infallible, and neither was I: the mistakes of both are in [section 14](#14-mistakes-and-lessons-learned). That is why the guide shows its evidence and its gaps rather than just a list of settings.

**Outcome, several weeks after the tuning:** the PC runs well and feels very responsive in daily use. That feeling is **subjective**. The measured numbers, and how far each one can be trusted, are in [section 13](#13-results).

**Event Viewer check on 2026-11-13** (System log, read-only query):

- **No crash of any kind since 1 October**: no Kernel-Power 41 (reset without clean shutdown), no event 6008 (unexpected shutdown), no BugCheck 1001 (blue screen). The roughly 55 shutdowns in that period are all clean ones requested by the user (event 1074).
- **No machine-check or PCIe WHEA error** (the ones that signal an unstable CPU, cache, memory controller or PCIe link). The WHEA-Logger source holds only **7 informational events (ID 3)**, one per boot, on 22/10 (4 events) and 24/10 (3 events), the days I was changing BIOS settings. They all carry the same payload, with severity "informational" in the record header. I have **not** decoded what the firmware record means. None has appeared since 24/10 12:20, across about 26 later boots.
- **No GPU driver reset (TDR) and no disk error** in the period. One NVIDIA driver error (ID 153) dates from 13/10, before the tuning.
- Two "low virtual memory" Windows popups (21/10 and 23/10) happened while I was stress-testing memory. I did not check what was running.
- Other errors since 24/10 are unrelated to the tuning: the Google Update and Dropbox update services timing out at boot, DCOM registration warnings, and one crash of the Logitech Options+ agent on 02/11.

**What this does and does not show.** It shows about three weeks of daily use with no crash and no hardware error logged. It does **not** prove the undervolt is fully stable: an unstable undervolt can also produce silent calculation errors that Windows never logs, which is why CoreCycler, Geekbench and 3DMark loops are still on the to-do list. This is the evidence that supports "the PC runs well" with something measurable.

> **Status: work in progress.** The undervolt (AC load line 0.20) has passed Cinebench R23 and OCCT, but **not** the long validation (CoreCycler overnight, Geekbench/3DMark loops, several days of WHEA-free use). See [section 15](#15-whats-still-on-the-to-do-list). Do not copy the undervolt value without running those tests on your own chip.
>
> **Disclaimer**: every CPU, RAM kit and motherboard is different. Use the values below as a *method* and as starting points, not as settings to copy. Test after every change.

**Tested on**: BIOS 1805, Windows 11 build 26200, NVIDIA driver **TODO (version)**. Last updated: 2026-11-13.

---

## Table of contents

1. [The hardware](#1-the-hardware)
2. [The goal](#2-the-goal)
3. [What I found in the BIOS](#3-what-i-found-in-the-bios)
4. [Ground rules](#4-ground-rules)
5. [Step 1: power limits and removing the auto-overclock](#5-step-1-power-limits-and-removing-the-auto-overclock)
6. [Step 2: System Agent voltage](#6-step-2-system-agent-voltage)
7. [Step 3: C-states and ASPM for latency](#7-step-3-c-states-and-aspm-for-latency)
8. [Step 4: memory timings](#8-step-4-memory-timings)
9. [Step 5: ring (cache) frequency](#9-step-5-ring-cache-frequency)
10. [Step 6: undervolting with the AC load line](#10-step-6-undervolting-with-the-ac-load-line)
11. [Step 7: Windows-side latency (DPC, interrupts, EPP)](#11-step-7-windows-side-latency-dpc-interrupts-epp)
12. [Final configuration](#12-final-configuration)
13. [Results](#13-results)
14. [Mistakes and lessons learned](#14-mistakes-and-lessons-learned)
15. [What's still on the to-do list](#15-whats-still-on-the-to-do-list)
16. [Tools used](#16-tools-used)

---

## 1. The hardware

| Component | Model |
|---|---|
| CPU | Intel Core i7-12700K (Alder Lake, 8 P-cores + 4 E-cores, 20 threads) |
| Motherboard | ASUS TUF GAMING Z790-PLUS WIFI D4, BIOS 1805 |
| RAM | 4 × 8 GB Corsair Dominator Platinum RGB, CMT32GX4M4C3600C18 (DDR4-3600 CL18, XMP) |
| RAM ICs | Micron **Rev. E** (D9VPP / MT40A1G8SA-075:E), single rank |
| GPU | NVIDIA GeForce RTX 5080 (PCIe 5.0 x16) |
| Cooling | 360 mm AIO, case fans managed by FanControl |
| Audio | Creative Sound Blaster PCIe card |
| OS | Windows 11 (build 26200) |

Two details matter a lot here:
- **Four DIMMs** means two DIMMs per channel. That puts more stress on the memory controller and limits how far the RAM can be tightened.
- **Micron Rev. E** chips tune reasonably well, but they are not Samsung B-die. Don't copy B-die timings.

---

## 2. The goal

Not a benchmark record. The goals, in this order:

1. **Stability** (a crash during a recording session is the worst outcome).
2. **Low latency** (gaming responsiveness, and real-time audio without clicks or pops).
3. **Lower temperatures** and less wasted power.
4. Performance, as long as it doesn't hurt the first three.

---

## 3. What I found in the BIOS

I had never asked for an overclock, yet the board was running one. ASUS enables it by default on Z790 boards with "K" CPUs, or through a first-boot pop-up that is easy to click through.

| Setting | Value found | Why it's a problem |
|---|---|---|
| Performance Preferences | ASUS Advanced OC Profile | Vendor overclocking profile |
| MultiCore Enhancement (MCE) | Enabled: Remove All Limits (90 °C) | No power limits at all |
| PL1 / PL2 | 4095 W / 4095 W | Effectively unlimited (Intel spec: 125 W / 190 W) |
| ICCMAX | 511.75 A (Auto) | Effectively unlimited |
| PL1 time window | 56 s (Auto) | Irrelevant when PL1 = PL2 = 4095 W |
| IA AC / DC load line | Auto / 0.20 (DC greyed out) | Auto AC value never displayed; see [section 10](#10-step-6-undervolting-with-the-ac-load-line) |
| Overclocking TVB | +2 Boost Profile | Up to 53× on one core (fused max is 49 to 50×) |
| OC Tuner | OC Tuner I | Extra automatic overclock |
| **CPU System Agent (SA) voltage** | **Auto → 1.377 to 1.393 V** | **Far more than needed for this memory setup, and higher than I wanted to run long term** |
| LLC | Level 4 (already the Auto setting, "Synch ACDC Loadline" Disabled) | Fine on its own |
| VMD controller | Enabled, nothing mapped | Useless, a classic source of driver issues |

*Evidence for this table: photos of the Auto BIOS screens in [evidence/](evidence/README.md) (`bios-auto-power-limits.jpg`, `bios-auto-llc.jpg`, `bios-auto-voltages-sa.jpg`). They are phone photos of the monitor; the SA reading 1.377 V is visible there, the 1.393 V upper end comes from monitoring logs.*

**Good news**: the 12700K (Alder Lake) is *not* affected by the 13th/14th-gen instability and degradation issue. The risk was moderate, but real, and none of it brought any benefit I could feel.

---

## 4. Ground rules

These rules saved me several times:

1. **One change at a time.** If two settings change and the PC crashes, you can't know which one caused it.
2. **Test every change**, with the right test for the right component (see [Tools](#16-tools-used)).
3. **Save a BIOS profile at every stable step** (Tool → ASUS User Profile). It's your way back.
4. **Measure before and after**, under the *same* load and with the *same* method. Comparing a peak value to an average, or one stress test to another, leads to wrong conclusions. (I broke this rule myself in two places; they are flagged in [sections 10](#10-step-6-undervolting-with-the-ac-load-line) and [13](#13-results).)
5. **Read the right sensor.** More on that in the [mistakes section](#14-mistakes-and-lessons-learned).

---

## 5. Step 1: power limits and removing the auto-overclock

| Setting | Before | After |
|---|---|---|
| Long Duration Package Power Limit (PL1) | Auto (4095 W) | **190 W** |
| Short Duration Package Power Limit (PL2) | Auto (4095 W) | **190 W** |
| Overclocking TVB | +2 Boost Profile | **Disabled** |
| TVB Voltage Optimizations | Enabled | Enabled (Intel feature, lowers voltage when cold) |

**Why 190 W for both?** Intel's spec is 125 W sustained and 190 W boost *(spec)*. With a 360 mm AIO, 190 W sustained is a sane compromise: a defined ceiling, roughly 5 % less multi-thread performance than "unlimited" *(estimate, see [section 13](#13-results))*, and much less heat. Manual PL values take priority over MCE, so the "Remove All Limits" no longer applies to power.

**Why disable Overclocking TVB?** It adds 1 or 2 frequency bins at light load, with extra voltage. That's +2 to 4 % single-thread, barely noticeable, in exactly the load zone where instability tends to appear.

**Result**: the CPU never even reaches 190 W in practice. In the heaviest test (Cinebench R23) it sits around 160 W, limited by its own all-core ratio (48×), not by power.

---

## 6. Step 2: System Agent voltage

The **System Agent (SA)** powers the memory controller. On Auto, ASUS was giving it **1.377 to 1.393 V** to make 4 DIMMs at 3600 MHz in Gear 1 work "safely". Most Alder Lake setups only need **1.15 to 1.25 V** for that (community experience, not an Intel figure).

| Setting | Before | After |
|---|---|---|
| CPU System Agent Voltage | Auto (1.377 V) | **Manual, 1.250 V** (measured VCCSA ≈ 1.232 V) |

**Why it's low-risk**: an SA voltage that is too low doesn't damage anything. At worst the PC fails to POST, retrains memory, or shows memory errors in a test. A high SA voltage is the side that is commonly considered riskier for long-term wear, so I preferred to run the lowest value that tests clean. I have no data of my own on actual wear; this is a precaution, not a measured benefit.

**Validation**: 1 hour of OCCT Memory, **0 errors**.

---

## 7. Step 3: C-states and ASPM for latency

Low latency and low power partly contradict each other. Deep power states save energy but take time to wake up from, and that wake-up time shows up as latency spikes. **The cost of these choices is higher idle power and idle temperature** (idle numbers: **TODO**, see [section 13](#13-results)). Also note that the LatencyMon baseline in [section 13](#13-results) was taken *after* the C3 limit and ASPM-off were applied, so the effect of those two settings was never measured on its own.

| Setting | Value | Why |
|---|---|---|
| CPU C-states | **Enabled** | Turning them all off barely helps latency and makes idle temps worse |
| Package C-State Limit | **C3** | Blocks the deep package states (C6 to C10) that cause the worst wake-up spikes |
| Native ASPM, L1 Substates, DMI ASPM, PEG ASPM | **Disabled** | ASPM adds wake-up delay on PCIe links (GPU, NVMe, sound card) for a negligible power saving |
| Acoustic Noise Mitigation | Disabled | Enabling it slows voltage ramps, which is bad for latency |
| VMD Controller | **Disabled** | Nothing was mapped to it |
| Intel DTT, SA GV, Dynamic Memory Boost | Disabled | Laptop or dynamic features; they only add variability |

> **Lesson**: I first enabled ASPM to save power, then reverted it once the latency goal was clear. Settings only make sense relative to a goal.

---

## 8. Step 4: memory timings

### Understanding the two "refresh" timings

DRAM cells must be refreshed regularly. During a refresh, the memory can't be accessed.

- **tREFI** = how often a refresh happens (higher is better for performance).
- **tRFC** = how long a refresh blocks the memory (lower is better).

The fraction of time lost to refresh is roughly **tRFC ÷ tREFI**:

| Configuration | tRFC | tREFI | Time lost to refresh |
|---|---|---|---|
| Auto (from SPD) | 630 | ~14 000 | **≈ 4.5 %** |
| tREFI raised | 560 | 32 767 | ≈ 1.7 % |
| Final | 530 | 49 151 | **≈ 1.1 %** |

The big win was the **tREFI**. After that, every further step brings less and less. Going from tRFC 560 to 520, for example, only saves about 0.1 point: invisible in practice.

> **Caveat: temperature.** A higher tREFI makes the RAM more sensitive to temperature. Errors usually start above ~50 °C. My DIMMs plateaued at **42 °C** during a 45-minute OCCT Memory run with tREFI 32767 / tRFC 560, in my current room conditions. **I did not log DIMM temperatures with the final tREFI 49151 / tRFC 530, nor during a gaming session.** The case fans ramp with CPU/GPU temperature while gaming. A warm summer room, or a case with less airflow, can push the DIMMs well above that, so **re-test in the worst conditions you expect** (see the to-do list) and back off tREFI if errors appear.

### Why the Auto values were so loose

The SPD (the chip on each DIMM that tells the motherboard what it can do) lists JEDEC-safe minimums, valid for every chip of that type. ASUS simply converts them into clock cycles:

| Timing | SPD value | At 3600 MT/s (1800 MHz) | Auto | Final |
|---|---|---|---|---|
| tRFC1 | 350 ns | 630 | 630 | **530** |
| tRRD_S | 3.7 ns | 7 | 7 | **4** |
| tRRD_L | 5.3 ns | 10 | 10 | **6** |
| tFAW | 21 ns | 38 | 38 | **16** |
| tRTP | not listed in the SPD | n/a | 12 | **8** |
| tWR | not listed in the SPD | n/a | 20 | **16** (= 2 × tRTP) |

A few rules of thumb used here:
- **tFAW = 4 × tRRD_S**. Going lower than that has no effect.
- **tWR = 2 × tRTP**.
- On this board, the tertiary timings follow the secondaries automatically: `tWRPRE = tCWL + 4 + tWR` and `tWRRD = tCWL + 4 + tWTR + 2`.

### Things I deliberately did *not* do

- **Lower CAS latency** (CL16 at 1.40 V): possible on Rev. E, about −1 ns, but more heat. Left as an optional next step.
- **Higher frequency** (3733 or 3800): with 4 DIMMs in Gear 1 it would require raising the SA voltage again, undoing step 2.
- **Command Rate 1T**: almost never stable with two DIMMs per channel.

### Validation

What was actually run, all with 0 errors reported:

| Configuration | Test | Duration |
|---|---|---|
| SA 1.25 V | OCCT Memory | 1 h |
| tREFI 32767 / tRFC 560 | OCCT Memory | about 1 h |
| + tRRD 4/6, tFAW 16 | OCCT Memory | about 30 to 35 min |
| tREFI 49151 / tRFC 530 / tWR 16 / tRTP 8 (final) | TM5 | **48 min** (the full hour was not completed; I did not record which TM5 profile was used) |

The final timings therefore have a shorter validation than the "1 hour per step" I intended. A full-length TM5 run (anta777 Extreme) on the final configuration is on the to-do list.

---

## 9. Step 5: ring (cache) frequency

The ring bus links the cores, the L3 cache and the memory controller. A faster ring means slightly lower memory latency.

| Setting | Before | After |
|---|---|---|
| Ring Down Bin | Auto | **Disabled** |
| Max CPU Cache Ratio | Auto (36) | **39** |

**The surprise**: under heavy load, the ring stayed at **3600 MHz**. On Alder Lake, **when the E-cores are active, the ring is capped around 3.6 GHz**, whatever the BIOS says. It only reaches 3.9 GHz when the E-cores are idle.

So the real-world gain is small: AIDA64 latency went from **62.0 to 61.1 ns**, which is within measurement noise. I kept 39 because it ran 43 minutes of OCCT CPU + RAM with no errors reported (I did not log the full hour) and costs nothing, but I didn't push to 40.

---

## 10. Step 6: undervolting with the AC load line

### Why not a simple global offset?

My first undervolt attempt, months earlier, used a **global negative voltage offset**, and the system became unstable at **light load**. An offset removes the same voltage everywhere, including at idle and at light load, where the CPU is most fragile.

### How the AC load line works

The voltage the CPU requests (VID) is roughly:

```
VID ≈ base voltage + AC_LL × current
```

- **At light load**, the current is low, so lowering AC_LL changes almost nothing. The fragile zone is protected by design.
- **Under heavy load**, the current is high, so the reduction is large. That's where the heat and power savings are.

That matches the problem exactly: gains under load, protection at light load.

### Two settings, two roles

- **AC load line (AC_LL)**: changes the *voltage requested* by the CPU. This is the undervolt lever.
- **DC load line (DC_LL)**: tells the CPU how much the voltage really drops, so it can *calculate its own power and voltage correctly*. It must match the real impedance of your LLC level. A wrong DC_LL means wrong power readings and power limits triggering at the wrong time.

**Simple check for DC_LL**: under full load, the CPU's own power reading (IA Cores Power) should match the VRM's reading (VR VCC Power, SVID POUT) within about ±15 W. Mine: **114.6 W vs 114.4 W**, averages of the roughly 1 h OCCT CPU + RAM run, taken with AC_LL still on Auto, before I changed it. DC_LL = 0.20 was therefore correct for LLC 4 on this board. I did not repeat the full check at AC 0.20; a short OCCT capture at AC 0.20 (early in the run) shows IA Cores 103.0 W vs VR POUT 104.0 W, which agrees within 1 W.

### The measurements

Same stress test (OCCT CPU + RAM, default settings), same LLC 4:

| AC_LL / DC_LL | P-core VID | Vcore (motherboard) | CPU Package Power | CPU temp |
|---|---|---|---|---|
| Auto / Auto (averages) | ~1.266 V | ~1.231 V | ~129 W | ~55 °C avg, 68 °C max |
| **0.60 / 0.20** | 1.306 V | 1.261 V | 139 W | 52 °C |
| **0.20 / 0.20** | **1.213 V** | **1.181 V** | **117 W** | **48 to 49 °C** |

**How these numbers were taken (from my logs).** The Auto row is the *average* over a roughly 1 h OCCT CPU + RAM run (default preset) with AC_LL on Auto; the two HWiNFO average tables it was read from are in [evidence/](evidence/README.md) (`hwinfo-1h-avg-intel-auto.jpg`, `hwinfo-1h-avg-nct-auto.jpg`: Vcore average 1.231 V, package 129.48 W, 55.2 °C). The 0.60 and 0.20 rows are *instantaneous* readings taken mid-run, before the planned 10 minutes had elapsed. The three rows therefore do not share a method. Voltage is the most robust column: **about −50 mV** (Vcore 1.231 → 1.181 V; VID 1.266 → 1.213 V). The −12 W and −6 °C are **indicative only**: the 0.60 row (more power than Auto, yet a lower temperature) shows the readings are not directly comparable, and an earlier reading of the same Auto test gave 135 W / 59 °C, a gap I never explained. The actual value of the Auto AC load line was never read either (I guessed several different values along the way). **TODO**: re-log all three rows with one method (same duration, same averaging window, same ambient temperature).

> **The 0.60 mistake**: I assumed the Auto value was around 1.1 (a common Intel default), so 0.60 should have lowered the voltage. It *raised* it by 30 to 40 mV. On this board, Auto was already lower than 0.60. **Never assume the direction of a change: measure it.**

Cinebench R23 gives a second, like-for-like voltage comparison: Vcore **1.252 V** at Auto (161 W, 68 °C, taken before the ring and undervolt changes; the capture is an OCCT monitoring window, `occt-auto-cinebench-load.jpg`, and that it was recorded during Cinebench comes from my chat log, not from the screenshot itself) versus **1.172 V** at AC 0.20 (163 W, 70 °C max), so **about −80 mV**. Two caveats: the ring was also raised from 36 to 39 between the two runs, and power and temperature under Cinebench did **not** go down (the 48× all-core ratio sets the load either way), so the watt and degree savings are only seen in the OCCT numbers above, which have the method issues described. The score at AC 0.20 is **22 753** (PL 190 W, SA 1.25 V, ring 39, C3, tREFI 32767 / tRFC 560). I have **no** Cinebench score from Auto settings, so I can't say what the undervolt did to the score (see [section 13](#13-results)). A too-aggressive undervolt can lower the score through "clock stretching" while the reported frequency looks normal, which is exactly why a before/after Cinebench comparison is needed.

**Re-measured on the final configuration (2026-11-13, one method).** I logged a full run with a script ([tools/measure.ps1](tools/measure.ps1)): 5 minutes idle, then Cinebench R23 multi-core for 10 minutes, every sensor read once per second, load averages taken after the first 60 seconds, FanControl running as in daily use, and HWiNFO logging alongside for Vcore. Result at AC 0.20, final memory timings (tREFI 49151 / tRFC 530): Vcore **1.173 V** average (HWiNFO), core VID 1.224 V, package **162 W** average (168 W max), package **66 °C average, 69 °C max**, no thermal throttling and no PL1 limit hit, score **22 721**. That matches the earlier screenshots (1.172 V, 163 W, 70 °C, 22 753). The files are in [measurements/](measurements/README.md). The Auto side has **not** been re-measured this way yet.

Empirically, each 0.05 step of AC_LL is worth about **10 mV** under full load on this setup.

### Testing an undervolt properly

Cinebench alone is not enough. An unstable undervolt usually fails on **one core at maximum frequency**, or during **sudden load changes**, not under a steady all-core load. The test plan:

1. Cinebench R23 at AC 0.20. *(done; run length not recorded)*
2. Geekbench (3 runs) and 3DMark in a loop for 20 minutes, for load transients. *(**TODO**)*
3. **CoreCycler** (y-cruncher, 1 thread, core by core), at least 1 hour, ideally overnight. *(**TODO**)*
4. OCCT with WHEA monitoring, then a few days of normal use, checking Event Viewer for **WHEA-Logger** errors. *(OCCT done; about three weeks of daily use with no crash and no WHEA machine-check error logged, see the top of this guide; the CoreCycler-type validation is still **TODO**)*

A failing undervolt can cause silent errors or crashes, not just a visible blue screen. Until steps 2 to 4 are done, treat 0.20 as *provisional*.

---

## 11. Step 7: Windows-side latency (DPC, interrupts, EPP)

### Measuring with LatencyMon: do it right

Three traps I fell into:
- **Don't run it alongside a stress test.** My first run showed a 7.6 ms spike and thousands of hard page faults, all caused by OCCT filling the RAM.
- **It's cumulative.** Maximums stay displayed until you restart LatencyMon. Two of my "new" reports were the same session continuing.
- **Close monitoring tools** (HWiNFO, OCCT, FanControl, etc.): they poll sensors constantly through kernel drivers.

### Reading the Drivers tab

`ntoskrnl.exe` (the Windows kernel) and `Wdf01000.sys` (the Kernel-Mode Driver Framework) are **wrappers**: many drivers run through them. They're rarely the real culprit. The useful column is **Highest execution (ms)** for named drivers. In my case every driver stayed under 1 ms, except occasional spikes from the NVIDIA driver.

### Interrupt affinity and MSI mode

I used the [Latency Toolbox](https://rigpolice.com/system/latency-toolbox/) scripts (free, open source, GitHub-hosted; the page does not state a license). Five of the six scripts write an undo file before changing anything; the "Remove Hidden Devices" script does not. The same page notes that most of these tweaks did not raise FPS on its own test PC, which matches my goal: I was after DPC/interrupt latency, not frame rate. On a 12700K, logical CPUs 0 to 15 are the P-cores (two threads per core) and 16 to 19 are the E-cores.

| Device | Pinned to | Reason |
|---|---|---|
| RTX 5080 | CPU 4 (P-core 2) | The NVIDIA driver is the biggest DPC producer; keep it away from audio |
| Sound Blaster | CPU 6 (P-core 3) | A dedicated P-core, away from CPU 0 where the kernel's DPCs pile up |
| USB 3.2 controller | CPU 8 (P-core 4) | Mouse and keyboard on yet another core |
| Ethernet (I226-V) | Default | It uses RSS (multiple queues on multiple cores); pinning it can hurt networking |
| NVMe / SATA controllers | Default (SpreadMessages) | Already optimal |

Rules: only the first thread of each P-core, one device per core, no CPU 0, no E-cores for latency-sensitive devices.

**Checked on 2026-11-13 in the registry** (`Enum\PCI\...\Device Parameters\Interrupt Management`): `MSISupported = 1` on the RTX 5080, the Sound Blaster and the USB 3.20 controller, so MSI mode is **enabled** on all three. The affinity policy is also confirmed: `DevicePolicy = 4` (specified processors) with masks that decode to **CPU 4** (GPU), **CPU 6** (Sound Blaster) and **CPU 8** (USB), exactly as in the table above. The SATA and NVMe controllers are on policy 5 (spread across processors), the Intel Wi-Fi on policy 0 (default), and the Intel Ethernet has no affinity entry. Who set what: I **always enable MSI by hand on the Sound Blaster and the RTX** as a habit, so I can't say whether the drivers would do it on their own. The **affinity** was changed by the toolbox script, which is the change specific to this tuning. For the USB controller I don't know who enabled MSI. Because MSI was already part of my habits and was not measured separately, it is not counted as a gain of this tuning.

I skipped other scripts on purpose: changing the platform tick or dynamic tick through `bcdedit`, disabling Fullscreen Optimizations, and removing hidden devices are either placebo, risky, or cosmetic.

### EPP (Energy Performance Preference)

EPP tells the CPU how to balance efficiency against responsiveness, on a scale from 0 to 100. The Balanced plan uses **33** on AC power. At **0**, the CPU ramps up to full frequency immediately, at the cost of somewhat higher idle clocks and power.

On a hybrid CPU there are **two** settings, one per core class:

```powershell
# Check current values first (note them for undo)
powercfg /qh scheme_current sub_processor PERFEPP
powercfg /qh scheme_current sub_processor PERFEPP1

# Set both to 0 on AC power
powercfg -setacvalueindex scheme_current sub_processor PERFEPP 0
powercfg -setacvalueindex scheme_current sub_processor PERFEPP1 0
powercfg -setactive scheme_current

# Undo: same commands with the old value (33)
```

Disabling **core parking** wasn't necessary: on a desktop with the Balanced plan, the cores weren't being parked in the first place, so it would have changed nothing.

---

## 12. Final configuration

### BIOS

| Area | Setting | Value |
|---|---|---|
| Power | PL1 / PL2 | 190 W / 190 W |
| Boost | Overclocking TVB | Disabled |
| Boost | TVB Voltage Optimizations | Enabled |
| Voltage | CPU System Agent Voltage | Manual 1.250 V |
| Voltage | CPU Load-line Calibration | Level 4 |
| Voltage | IA AC / DC Load Line | 0.20 / 0.20 *(provisional, see [section 10](#testing-an-undervolt-properly))* |
| Voltage | Global Core SVID | Adaptive, no offset |
| Ring | Ring Down Bin / Max Cache Ratio | Disabled / 39 |
| Power states | CPU C-states / Package C-State Limit | Enabled / C3 |
| PCIe | All ASPM options, L1 Substates | Disabled |
| Storage | VMD Controller | Disabled |
| Memory | Profile | XMP I, DDR4-3600, 1.35 V, Gear 1 |
| Memory | Primaries | 18-19-19-39, 2T |
| Memory | tRFC / tREFI | 530 / 49151 |
| Memory | tRRD_S / tRRD_L / tFAW | 4 / 6 / 16 |
| Memory | tWR / tRTP | 16 / 8 |
| Memory | SA GV, Dynamic Memory Boost | Disabled |

### Windows

| Setting | Value |
|---|---|
| EPP (PERFEPP and PERFEPP1), AC | 0 |
| Interrupt affinity | GPU → CPU 4, Sound Blaster → CPU 6, USB → CPU 8 |
| MSI mode | Enabled on GPU, USB and sound card (registry check, 2026-11-13). Enabled by hand on GPU and sound card as a habit, not measured separately; affinity set by the toolbox script (see [section 11](#interrupt-affinity-and-msi-mode)) |

---

## 13. Results

### CPU

| | Auto (ASUS) | Final |
|---|---|---|
| Vcore, OCCT CPU + RAM (same test, same LLC; average vs instantaneous reading, see [section 10](#the-measurements)) | ~1.231 V | 1.181 V (about −50 mV) |
| Vcore, Cinebench R23 | 1.252 V | 1.172 V (about −80 mV; ring also raised 36 → 39 in between). Re-measured 2026-11-13: 1.173 V average over 9 minutes |
| Package power / max temperature, Cinebench R23 | 161 W / 68 °C | 163 W / 70 °C (no drop under this load). Re-measured 2026-11-13: 162 W average / 69 °C max |
| Package power, OCCT CPU + RAM | ~129 W avg | ~117 W *(indicative, see [section 10](#the-measurements))* |
| CPU temperature, same test | ~55 °C avg | ~49 °C *(indicative)* |
| Cinebench R23 multi-core | **TODO (Auto baseline)** | 22 753; re-measured 2026-11-13 on the final timings: 22 721 |
| Power limits | None | **190 W** |
| SA voltage | 1.377 to 1.393 V | **1.25 V** |
| Idle package power / temperature | **TODO** | 17 W / 28 °C average over 5 minutes (2026-11-13) |

About the multi-core score: I have not measured the Auto baseline, so I can't claim "no performance lost". The 190 W cap alone should cost something like 5 % in all-core loads *(estimate)*, and I don't have a trustworthy reference score to compare 22 753 against. The two final-configuration scores (22 753 and 22 721, about 0.1 % apart) show the run-to-run spread and no sign of clock stretching between the two memory steps.

About the idle figure: it is a desktop idle with my usual background apps open (not a clean boot), so it varies (11 to 48 W within the 5 minutes). It has **no Auto counterpart** yet, so it does not show what C3, ASPM off and EPP 0 cost. DIMMs stayed at 33 to 35 °C during this run, idle and under Cinebench (a CPU load, not a memory or gaming load).

### Memory (AIDA64)

| Step | Read bandwidth | Latency |
|---|---|---|
| After tREFI / tRFC | 53 337 MB/s | 62.0 ns |
| After ring 39 | n/a | 61.1 ns |
| After tWR / tRTP / tRFC 530 / tREFI 49151 | **54 565 MB/s (+2.3 %)** | 61.8 ns (same, within noise) |

> Secondary timings mostly improve **bandwidth**. Latency is dominated by CAS, tRCD and ring frequency.

### Latency (LatencyMon)

| Run | Duration | Avg interrupt → process | Avg interrupt → DPC | Peak |
|---|---|---|---|---|
| Clean baseline | 50 s | 30.2 µs | 12.4 µs | 1.6 ms |
| + interrupt affinity | 5 min 38 s | 23.2 µs | 7.9 µs | 2.3 ms |
| + EPP 0, real use | **3 h** | **19.2 µs** | **4.4 µs** | 2.7 ms |

**Read this table with care.** These runs are *not* controlled, which breaks my own rule 4. What was already applied before each run matters:

- **Run 1 (50 s)** was taken *after* the C3 limit, ASPM-off, SA 1.25 V and the first memory timings. This comparison therefore does **not** measure the effect of C3 or ASPM.
- **Run 2** added ring 39, AC_LL 0.20 and the interrupt affinity (GPU, Sound Blaster, USB). EPP 0 was not applied yet. I did not take the planned before-reboot reference, so the affinity effect is not isolated.
- **Run 3 (3 h of real use)** added EPP 0 (PERFEPP and PERFEPP1), tREFI 49151 / tRFC 530, tWR 16 / tRTP 8, and SA GV / Dynamic Memory Boost off. The EPP and timing changes can't be separated.

The averages did drop by about 35 to 65 %, but I can't attribute the gain to any single setting, and part of it may simply be run length and load (runs 1 and 2 are short, run 3 is real use). Also note that **the peaks went up** (1.6 → 2.7 ms); a longer run catches rarer events, but the peak is not better.

The remaining spikes come almost entirely from the **NVIDIA driver** (one 2.6 ms DPC), with **19 DPCs above 1 ms out of 18 million** in 3 hours.

In practice: with a **256-sample audio buffer**, this is comfortably safe. At 128 samples, an occasional click is still possible as long as the NVIDIA driver produces those rare spikes.

**TODO**: repeat the baseline and the final configuration with the same duration (for example 30 minutes) and the same idle-plus-light-use scenario, so the comparison is fair.

---

## 14. Mistakes and lessons learned

1. **"The PC boots" doesn't mean "the PC is stable".** A slightly too-low SA voltage can pass boot and only corrupt data under load. Always run the memory test.
2. **Read the right sensor**:
   - I once read *VDDQ TX Voltage* (the memory interface, fixed at 1.200 V) as Vcore, and built a wrong load-line calculation on it.
   - On this board, the VRM controller's own telemetry (OnSemi NCP81530: "VR VOUT", "VR IOUT") was inconsistent: 44 A versus 104 A reported by the CPU, and an output voltage *higher* than the requested VID. Use the CPU's SVID IOUT/POUT and the motherboard's Vcore instead.
   - Libre Hardware Monitor couldn't name this board's sensors; one of them reported a phantom 115 °C. HWiNFO and OCCT were reliable.
3. **SPD values are not active timings.** The XMP profile stored on the DIMM never changes. Check what the memory controller actually applies (HWiNFO "Memory Timings", AIDA64, or the CHA/CHB boxes in the ASUS BIOS).
4. **A BIOS field is not an applied value.** I set tWTR_S/L to 4/10; the memory controller kept the equivalent of 8/14. The real applied values were visible in the tertiary timings (tWRRD).
5. **Don't assume the direction of a change.** AC_LL 0.60 *increased* voltage because Auto was already lower.
6. **Guides don't transfer between platforms.** The excellent ROG Maximus / i9-13900K guide I first followed uses LLC impedances, V/F point numbers and boost strategies that don't apply to a 12700K on a TUF board. The *method* transfers; the numbers don't.
7. **Some "performance tweaks" fight your goal.** OC TVB, deep package C-states and E-core overclocking all chase peak performance. For low latency and stability, they go the wrong way.
8. **Alder Lake caps the ring when the E-cores are active.** Raising the max cache ratio only helps when the E-cores are idle.
9. **Changing several things at once happens.** When it does, test them together, and if something fails, roll back starting from the most likely culprit.
10. **Mixing measurement methods muddies the headline.** In my first write-up of this guide I compared voltages from two different tests and presented one latency comparison across runs of very different length. Compare like with like, or say clearly that you didn't.

---

## 15. What's still on the to-do list

**Validation and measurement gaps (needed to back the claims above):**

- [ ] Full undervolt validation at AC 0.20: CoreCycler overnight, Geekbench, 3DMark loops. (The "days of WHEA-free use" part is covered by the Event Viewer check at the top of this guide, but only for crashes and logged errors, not for silent errors.)
- [ ] Cinebench R23 with Auto settings, for a real before/after score.
- [ ] Full-length TM5 (anta777 Extreme) or OCCT Memory on the final timings (48 min of TM5 done, profile not recorded).
- [x] MSI mode enabled on GPU, USB and sound card: checked in the registry on 2026-11-13.
- [ ] Re-log the Auto / 0.60 / 0.20 table (voltage, power, temperature) with one method and one time window.
- [ ] Idle package power and temperature, before and after (C3, ASPM off, EPP 0). The "after" is measured (17 W / 28 °C, 2026-11-13); the Auto run with the same script is still to do.
- [ ] LatencyMon: baseline and final with the same duration and the same scenario.
- [ ] Re-test memory stability in worst-case room temperature (summer), watching DIMM temperatures; back off tREFI if errors appear.
- [ ] Check DIMM temperatures during a 1 to 2 hour gaming session (target: under 48 to 50 °C).
- [ ] Record the NVIDIA driver version used for the measurements.

**Possible improvements:**

- [ ] Set tWRRD_sg / tWRRD_dg directly (33 / 27), since the BIOS ignores the tWTR fields.
- [ ] Min CPU Cache Ratio = 36, to stop the ring dropping to 800 MHz at idle (better light-load latency, costs a few watts).
- [ ] Try the NVIDIA **Studio** driver and "Prefer maximum performance" for the DAW, to tame the remaining DPC spikes.
- [ ] Disable the unused Wi-Fi adapter (LatencyMon flagged a network-related issue).
- [ ] Exclude audio project, sample and plugin folders from Windows Defender real-time scanning (Defender caused most hard page faults). This reduces protection on those folders, so only do it for folders you trust.
- [ ] Optional: +1 all-core ratio using the thermal headroom gained, or CL16 at 1.40 V.
- [ ] Optional: update the BIOS. Write down every setting first: saved profiles usually don't load across BIOS versions.

---

## 16. Tools used

| Tool | Used for |
|---|---|
| **HWiNFO64** | Sensors, active memory timings, ring clock |
| **LibreHardwareMonitorLib** + [tools/measure.ps1](tools/measure.ps1) | Scripted idle + Cinebench logging, one method for every run. Its motherboard "Vcore" reads about 0.12 V low on this board, so Vcore comes from HWiNFO |
| **OCCT** | CPU, memory and combined stress tests, with WHEA error monitoring |
| **TM5** (anta777 Extreme profile) | Memory stability, more sensitive to refresh-timing errors |
| **Cinebench R23** | Heavy all-core load, score as a sanity check |
| **CoreCycler** | Per-core stability, the best test for undervolts |
| **AIDA64** (trial) | Memory bandwidth and latency |
| **LatencyMon** | DPC/ISR latency for real-time audio |
| **CPU-Z / Thaiphoon Burner** | SPD data and RAM chip identification |
| **Latency Toolbox** (RigPolice) | MSI mode and interrupt affinity |
| **FanControl** | Fan curves based on max(CPU, GPU) temperature |
| **Windows Event Viewer** | WHEA-Logger errors after tests and normal use |

---

*If you spot a mistake or have numbers from a similar setup, feel free to open an issue.*
