# Companion to scripts/game/blackbox.gd. Tails the game's blackbox file and
# copies every line into a durable log, forcing each write to disk
# (FlushFileBuffers), alongside a once-a-second hardware sample. Run it before
# starting the game; whatever reached this file survives a hard reset.
param(
	[string]$GameLog = "$PSScriptRoot\..\build\blackbox\game.log",
	[string]$Out = "$PSScriptRoot\..\build\blackbox\durable.log",
	[int]$Seconds = 1800
)

$ErrorActionPreference = "SilentlyContinue"
New-Item -ItemType Directory -Force (Split-Path $Out) | Out-Null
$stream = [System.IO.FileStream]::new($Out, [System.IO.FileMode]::Append, [System.IO.FileAccess]::Write, [System.IO.FileShare]::ReadWrite)
$writer = [System.IO.StreamWriter]::new($stream)

function Put([string]$line) {
	$stamped = "{0:HH:mm:ss.fff} {1}" -f (Get-Date), $line
	$writer.WriteLine($stamped)
	$writer.Flush()
	$stream.Flush($true)
}

function Sample {
	$gpu = Get-CimInstance Win32_PerfFormattedData_GPUPerformanceCounters_GPUEngine |
		Where-Object { $_.Name -like "*engtype_3D" } |
		Measure-Object UtilizationPercentage -Sum
	$mem = Get-CimInstance Win32_PerfFormattedData_GPUPerformanceCounters_GPUAdapterMemory |
		Measure-Object SharedUsage, DedicatedUsage -Sum
	$cpu = Get-CimInstance Win32_PerfFormattedData_Counters_ProcessorInformation -Filter "Name='_Total'"
	$zones = Get-CimInstance Win32_PerfFormattedData_Counters_ThermalZoneInformation |
		ForEach-Object { "{0:N0}C" -f ($_.HighPrecisionTemperature / 10.0 - 273.15) }
	$godot = Get-Process -Name godot*, "Ophelia's Dream" -ErrorAction Ignore | Measure-Object WorkingSet64 -Sum
	$values = @(
		$gpu.Sum
		($mem | Where-Object Property -eq SharedUsage).Sum / 1MB
		($mem | Where-Object Property -eq DedicatedUsage).Sum / 1MB
		$cpu.PercentProcessorUtility
		$cpu.PercentProcessorPerformance
		$cpu.ProcessorFrequency
		($zones -join " ")
		$godot.Sum / 1MB
	)
	"hw gpu3d {0}% | gpumem shared {1:N0}MB dedicated {2:N0}MB | cpu {3}% perf {4}% {5}MHz | temps {6} | godot ws {7:N0}MB" -f $values
}

Put "monitor start, tailing $GameLog"
$position = 0L
$deadline = (Get-Date).AddSeconds($Seconds)
while ((Get-Date) -lt $deadline) {
	if (Test-Path $GameLog) {
		$read = [System.IO.FileStream]::new($GameLog, [System.IO.FileMode]::Open, [System.IO.FileAccess]::Read, [System.IO.FileShare]::ReadWrite -bor [System.IO.FileShare]::Delete)
		if ($read.Length -lt $position) { $position = 0L; Put "game log restarted" }
		$read.Position = $position
		$reader = [System.IO.StreamReader]::new($read)
		while ($null -ne ($line = $reader.ReadLine())) { Put "game $line" }
		$position = $read.Position
		$reader.Dispose()
	}
	Put (Sample)
	Start-Sleep -Milliseconds 250
}
Put "monitor stop"
$writer.Dispose()
