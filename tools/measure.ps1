# Measurement session: idle, then Cinebench R23 multi-core, logged with one method.
# Must run elevated (LibreHardwareMonitorLib needs its kernel driver to read CPU/SuperIO/SPD sensors).
# Usage: pwsh -File measure.ps1 -Label ac020 [-IdleSec 300] [-LoadSec 600] [-WarmupSec 60]
param(
    [Parameter(Mandatory)][string]$Label,
    [int]$IdleSec = 300,
    [int]$LoadSec = 600,
    [int]$WarmupSec = 60,
    [string]$LhmDir = 'D:\LibreHardwareMonitor.NET.10',
    [string]$Cinebench = "$env:USERPROFILE\Downloads\CinebenchR23\Cinebench.exe",
    [string]$OutDir = (Join-Path $PSScriptRoot '..\measurements'),
    [switch]$SkipFanCheck
)
# LHM reads the NCT6798D "Vcore" about 0.12 V low on this board. For a Vcore comparable to HWiNFO/OCCT,
# start HWiNFO sensor logging by hand during the run (the free edition rejects command-line parameters);
# the phase times in the summary let you cut that CSV into idle and load.
$ErrorActionPreference = 'Stop'
$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) { throw 'Run this script as administrator: sensors read empty otherwise.' }
# Without the usual fan software the BIOS curves apply and temperatures are not comparable between runs.
if (-not $SkipFanCheck -and -not (Get-Process FanControl -ErrorAction SilentlyContinue)) { throw 'FanControl is not running: start it (or pass -SkipFanCheck) before measuring.' }

New-Item -ItemType Directory -Force $OutDir | Out-Null
$stamp = Get-Date -Format 'yyyyMMdd-HHmm'
$csv = Join-Path $OutDir "$stamp-$Label-samples.csv"
$sum = Join-Path $OutDir "$stamp-$Label-summary.txt"

Add-Type -Path (Join-Path $LhmDir 'LibreHardwareMonitorLib.dll')
$pc = New-Object LibreHardwareMonitor.Hardware.Computer
$pc.IsCpuEnabled = $true; $pc.IsMotherboardEnabled = $true; $pc.IsMemoryEnabled = $true
$pc.Open()

$wanted = 'Voltage|Power|Temperature|Clock|Fan'
function Read-Sensors {
    $row = @{}
    foreach ($h in $pc.Hardware) {
        $h.Update()
        foreach ($sh in $h.SubHardware) { $sh.Update() }
        foreach ($s in @($h.Sensors) + @($h.SubHardware | ForEach-Object { $_.Sensors })) {
            if ($null -ne $s.Value -and "$($s.SensorType)" -match $wanted) {
                $row["$($s.Hardware.Name) / $($s.SensorType) / $($s.Name)"] = [double]$s.Value
            }
        }
    }
    $row
}

$samples = [System.Collections.Generic.List[object]]::new()
function Sample-Phase([string]$phase, [int]$seconds, [scriptblock]$stopWhen) {
    $t0 = Get-Date
    while (((Get-Date) - $t0).TotalSeconds -lt $seconds) {
        $r = Read-Sensors
        $el = [int]((Get-Date) - $t0).TotalSeconds
        foreach ($k in $r.Keys) { $samples.Add([pscustomobject]@{ t = (Get-Date).ToString('HH:mm:ss'); phase = $phase; elapsed = $el; sensor = $k; value = $r[$k] }) }
        if ($stopWhen -and (& $stopWhen)) { break }
        Start-Sleep -Milliseconds 1000
    }
}

Read-Sensors | Out-Null; Start-Sleep 2   # first read primes energy counters (power reads 0)
$phaseTimes = @{}
$phaseTimes.idleStart = Get-Date
Write-Host "Idle phase: $IdleSec s. Leave the PC alone."
Sample-Phase 'idle' $IdleSec $null

$phaseTimes.loadStart = Get-Date
Write-Host "Load phase: Cinebench R23 multi-core, minimum $LoadSec s."
$cbOut = Join-Path $OutDir "$stamp-$Label-cinebench.txt"
$cb = Start-Process -FilePath $Cinebench -ArgumentList 'g_CinebenchCpuXTest=true', "g_CinebenchMinimumTestDuration=$LoadSec" `
      -RedirectStandardOutput $cbOut -PassThru -WindowStyle Minimized
Sample-Phase 'load' ($LoadSec + 300) { $cb.HasExited }
if (-not $cb.HasExited) { $cb.Kill() }
$phaseTimes.loadEnd = Get-Date
$pc.Close()

$samples | Export-Csv $csv -NoTypeInformation -Encoding utf8

# One method for every row: mean and max over the phase; load mean excludes the first $WarmupSec seconds.
$keys = 'CPU Package$|Vcore|Core \(SVID\)|CPU Core$|P-Core #1$|Core Max|DIMM|CPU Platform|CPU Cores$|Bus Speed|Ring|/ Fan /'
$lines = @("Label: $Label   Date: $(Get-Date -Format 'yyyy-MM-dd HH:mm')   Idle $IdleSec s, load mean excludes first $WarmupSec s",
           ('Phases: idle {0:HH:mm:ss}, load {1:HH:mm:ss} to {2:HH:mm:ss}   FanControl running: {3}' -f $phaseTimes.idleStart, $phaseTimes.loadStart, $phaseTimes.loadEnd, [bool](Get-Process FanControl -ErrorAction SilentlyContinue)), '')
foreach ($ph in 'idle', 'load') {
    $lines += "== $ph =="
    $set = $samples | Where-Object { $_.phase -eq $ph -and ($ph -eq 'idle' -or $_.elapsed -ge $WarmupSec) }
    foreach ($g in ($set | Where-Object { $_.sensor -match $keys } | Group-Object sensor | Sort-Object Name)) {
        $m = $g.Group.value | Measure-Object -Average -Maximum -Minimum
        $lines += '{0,-70} mean {1,9:N3}  min {2,9:N3}  max {3,9:N3}  n={4}' -f $g.Name, $m.Average, $m.Minimum, $m.Maximum, $m.Count
    }
    $lines += ''
}
$score = Select-String -Path $cbOut -Pattern 'CB\s+([\d.]+)' -ErrorAction SilentlyContinue | Select-Object -Last 1
$lines += "Cinebench R23 multi-core: " + $(if ($score) { $score.Matches[0].Groups[1].Value } else { 'not found, see ' + $cbOut })
$lines | Set-Content $sum -Encoding utf8
$lines | Write-Host
Write-Host "`nSamples: $csv`nSummary: $sum"
