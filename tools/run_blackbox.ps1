# Launch the game with the blackbox on, plus the disk-flushing monitor.
# Logs land in build/blackbox/ (durable.log is the one that survives a freeze).
# Extra arguments go to Godot, e.g. ./tools/run_blackbox.ps1 or with RUN_GRAPHICS=full set.
$root = Resolve-Path "$PSScriptRoot\.."
$box = Join-Path $root "build\blackbox"
New-Item -ItemType Directory -Force $box | Out-Null
$stamp = Get-Date -Format "yyyyMMdd-HHmmss"
$gameLog = Join-Path $box "game-$stamp.log"
$durable = Join-Path $box "durable-$stamp.log"

$monitor = Start-Process pwsh -PassThru -WindowStyle Hidden -ArgumentList @(
	"-NoProfile", "-File", "$PSScriptRoot\blackbox_monitor.ps1",
	"-GameLog", $gameLog, "-Out", $durable, "-Seconds", "7200"
)
Start-Sleep -Seconds 2
$env:RUN_BLACKBOX = $gameLog
try {
	$game = Start-Process godot -PassThru -ArgumentList (@("--path", "$root") + $args)
	"game pid $($game.Id), durable log $durable"
	$game.WaitForExit()
	"game exited with code $($game.ExitCode)"
} finally {
	Remove-Item Env:RUN_BLACKBOX -ErrorAction Ignore
	Start-Sleep -Seconds 2
	Stop-Process -Id $monitor.Id -ErrorAction Ignore
}
