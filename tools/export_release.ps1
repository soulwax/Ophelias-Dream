<#
.SYNOPSIS
    Automates encrypted Windows release exports for Ophelia's Dream.

.DESCRIPTION
    1. Ensures a 256-bit AES key (64 hex chars) exists in godot.gdkey and syncs
       it to .godot/export_credentials.cfg.
    2. Ensures a custom Godot release export template compiled with
       SCRIPT_AES256_ENCRYPTION_KEY is cached in build/templates/ (automatically
       cloning Godot and building with SCons when missing or when the key changes).
    3. Synchronizes application and export versions between project.godot and
       export_presets.cfg.
    4. Configures export_presets.cfg for PCK encryption and runs headless Godot
       with GODOT_SCRIPT_ENCRYPTION_KEY set to produce build/windows/Ophelia's Dream.exe.

.EXAMPLE
    ./tools/export_release.ps1
    ./tools/export_release.ps1 -Version 0.0.15
    ./tools/export_release.ps1 -RotateKey
#>
[CmdletBinding()]
param(
	[string]$Version = "",
	[string]$KeyFile = "godot.gdkey",
	[string]$TemplatePath = "build/templates/windows_release_x86_64.exe",
	[string]$GodotTag = "",
	[switch]$RebuildTemplate,
	[switch]$RotateKey,
	[switch]$Unencrypted
)

$ErrorActionPreference = "Stop"
$root = (Resolve-Path "$PSScriptRoot\..").Path

function Get-GodotExecutable {
	foreach ($name in @("godot", "godot-mono", "godot4")) {
		$cmd = Get-Command $name -ErrorAction SilentlyContinue
		if ($cmd) {
			return $cmd.Source
		}
	}
	$scoopCandidates = Get-ChildItem -Path "$env:USERPROFILE\scoop\apps\godot*" -Filter "*.console.exe" -Recurse -ErrorAction SilentlyContinue |
		Sort-Object FullName -Descending
	if ($scoopCandidates) {
		return $scoopCandidates[0].FullName
	}
	throw "Could not find a Godot executable on PATH or in ~/scoop/apps."
}

function Get-GodotReleaseTag {
	param([string]$GodotExe, [string]$ExplicitTag)
	if ($ExplicitTag -ne "") {
		return $ExplicitTag
	}
	$verOut = (& $GodotExe --version 2>$null | Select-Object -First 1).Trim()
	if ($verOut -match "^(\d+\.\d+(?:\.\d+)?)\.([a-z0-9]+)") {
		return "$($Matches[1])-$($Matches[2])"
	}
	return "4.7.2-stable"
}

function Get-OrCreateEncryptionKey {
	param([string]$Path, [bool]$ForceNew)
	if ($ForceNew -or -not (Test-Path $Path)) {
		$bytes = [System.Security.Cryptography.RandomNumberGenerator]::GetBytes(32)
		$generated = [System.BitConverter]::ToString($bytes).Replace("-", "").ToLowerInvariant()
		Set-Content -Path $Path -Value $generated -NoNewline -Encoding ascii
		Write-Host "Generated new 256-bit encryption key in $Path"
	}
	$key = (Get-Content -Path $Path -Raw).Trim()
	if ($key -notmatch "^[0-9a-fA-F]{64}$") {
		throw "Encryption key in $Path must be exactly 64 hexadecimal characters (256-bit AES)."
	}
	return $key.ToLowerInvariant()
}

function Sync-ExportCredentials {
	param([string]$RootDir, [string]$Key)
	$godotDir = Join-Path $RootDir ".godot"
	New-Item -ItemType Directory -Force $godotDir | Out-Null
	$credPath = Join-Path $godotDir "export_credentials.cfg"
	$content = "[preset.0]`n`nscript_encryption_key=`"$Key`"`n"
	Set-Content -Path $credPath -Value $content -NoNewline -Encoding utf8
}

function Get-StringSha256 {
	param([string]$Text)
	$bytes = [System.Text.Encoding]::UTF8.GetBytes($Text)
	$hash = [System.Security.Cryptography.SHA256]::HashData($bytes)
	return [System.BitConverter]::ToString($hash).Replace("-", "").ToLowerInvariant()
}

function Ensure-EncryptedTemplate {
	param(
		[string]$RootDir,
		[string]$RelTemplatePath,
		[string]$Key,
		[string]$Tag,
		[bool]$ForceRebuild
	)
	$fullTemplatePath = Join-Path $RootDir $RelTemplatePath
	$stampPath = "$fullTemplatePath.stamp"
	$expectedStamp = Get-StringSha256 "$Tag`:$Key"

	if (-not $ForceRebuild -and (Test-Path $fullTemplatePath) -and (Test-Path $stampPath)) {
		$actualStamp = (Get-Content -Path $stampPath -Raw).Trim()
		if ($actualStamp -eq $expectedStamp) {
			Write-Host "Using cached encrypted export template: $RelTemplatePath"
			return $fullTemplatePath
		}
	}

	Write-Host "Building custom Godot export template ($Tag) with SCRIPT_AES256_ENCRYPTION_KEY..."
	$srcDir = Join-Path $RootDir "build\godot-src"
	if (-not (Test-Path (Join-Path $srcDir ".git"))) {
		New-Item -ItemType Directory -Force (Split-Path $srcDir -Parent) | Out-Null
		& git clone --depth 1 --branch $Tag https://github.com/godotengine/godot.git $srcDir
		if ($LASTEXITCODE -ne 0) {
			throw "Failed to clone Godot source for tag $Tag."
		}
	} else {
		Push-Location $srcDir
		try {
			& git fetch --depth 1 origin tag $Tag
			& git checkout -f $Tag
		} finally {
			Pop-Location
		}
	}

	$env:SCRIPT_AES256_ENCRYPTION_KEY = $Key
	Push-Location $srcDir
	try {
		$sconsCmd = Get-Command scons -ErrorAction SilentlyContinue
		$sconsArgs = @("platform=windows", "target=template_release", "arch=x86_64", "production=yes")
		if ($sconsCmd) {
			& $sconsCmd.Source @sconsArgs
		} elseif (Get-Command uv -ErrorAction SilentlyContinue) {
			& uv tool run scons @sconsArgs
		} else {
			throw "Neither 'scons' nor 'uv' was found to compile the Godot export template."
		}
		if ($LASTEXITCODE -ne 0) {
			throw "SCons failed while building the custom encrypted export template."
		}
	} finally {
		Pop-Location
	}

	$builtBins = Get-ChildItem -Path (Join-Path $srcDir "bin") -Filter "godot.windows.template_release*x86_64*.exe" |
		Where-Object { $_.Name -notmatch "console" } |
		Sort-Object LastWriteTime -Descending
	if (-not $builtBins) {
		throw "Compiled template binary not found in $srcDir\bin."
	}

	New-Item -ItemType Directory -Force (Split-Path $fullTemplatePath -Parent) | Out-Null
	Copy-Item -Path $builtBins[0].FullName -Destination $fullTemplatePath -Force
	Set-Content -Path $stampPath -Value $expectedStamp -NoNewline -Encoding ascii
	Write-Host "Built and cached encrypted export template at $RelTemplatePath"
	return $fullTemplatePath
}

function Sync-VersionAndExportPreset {
	param(
		[string]$RootDir,
		[string]$NewVersion,
		[string]$RelTemplatePath,
		[bool]$EnableEncryption
	)
	$projectPath = Join-Path $RootDir "project.godot"
	$presetPath = Join-Path $RootDir "export_presets.cfg"

	$projectText = Get-Content -Path $projectPath -Raw
	if ($NewVersion -ne "") {
		$projectText = [regex]::Replace($projectText, '(?m)^config/version="[^"]*"', "config/version=`"$NewVersion`"")
		Set-Content -Path $projectPath -Value $projectText -NoNewline -Encoding utf8
	} else {
		$match = [regex]::Match($projectText, '(?m)^config/version="([^"]*)"')
		if (-not $match.Success) {
			throw "Could not read config/version from project.godot"
		}
		$NewVersion = $match.Groups[1].Value
	}

	$fourPartVersion = if ($NewVersion.Split('.').Count -eq 3) { "$NewVersion.0" } else { $NewVersion }
	$normalizedTemplate = if ($EnableEncryption) { $RelTemplatePath.Replace('\', '/') } else { "" }
	$encFlag = if ($EnableEncryption) { "true" } else { "false" }

	$presetText = Get-Content -Path $presetPath -Raw
	$presetText = [regex]::Replace($presetText, '(?m)^encryption_include_filters="[^"]*"', 'encryption_include_filters="*"')
	$presetText = [regex]::Replace($presetText, '(?m)^encrypt_pck=(true|false)', "encrypt_pck=$encFlag")
	$presetText = [regex]::Replace($presetText, '(?m)^encrypt_directory=(true|false)', "encrypt_directory=$encFlag")
	$presetText = [regex]::Replace($presetText, '(?m)^custom_template/release="[^"]*"', "custom_template/release=`"$normalizedTemplate`"")
	$presetText = [regex]::Replace($presetText, '(?m)^application/file_version="[^"]*"', "application/file_version=`"$fourPartVersion`"")
	$presetText = [regex]::Replace($presetText, '(?m)^application/product_version="[^"]*"', "application/product_version=`"$fourPartVersion`"")
	Set-Content -Path $presetPath -Value $presetText -NoNewline -Encoding utf8

	return $NewVersion
}

$godot = Get-GodotExecutable
$resolvedTag = Get-GodotReleaseTag -GodotExe $godot -ExplicitTag $GodotTag

$keyPath = if ([System.IO.Path]::IsPathRooted($KeyFile)) { $KeyFile } else { Join-Path $root $KeyFile }
$key = Get-OrCreateEncryptionKey -Path $keyPath -ForceNew:$RotateKey
Sync-ExportCredentials -RootDir $root -Key $key

if (-not $Unencrypted) {
	Ensure-EncryptedTemplate `
		-RootDir $root `
		-RelTemplatePath $TemplatePath `
		-Key $key `
		-Tag $resolvedTag `
		-ForceRebuild:($RebuildTemplate -or $RotateKey) | Out-Null
}

$resolvedVersion = Sync-VersionAndExportPreset `
	-RootDir $root `
	-NewVersion $Version `
	-RelTemplatePath $TemplatePath `
	-EnableEncryption:(-not $Unencrypted)

$outDir = Join-Path $root "build\windows"
New-Item -ItemType Directory -Force $outDir | Out-Null
$outExe = Join-Path $outDir "Ophelia's Dream.exe"

Write-Host "Exporting Ophelia's Dream v$resolvedVersion using $godot..."

$env:GODOT_SCRIPT_ENCRYPTION_KEY = $key
$env:SCRIPT_AES256_ENCRYPTION_KEY = $key
try {
	& $godot --headless --path $root --export-release "Windows Desktop" $outExe
	if ($LASTEXITCODE -ne 0) {
		throw "Godot export failed with exit code $LASTEXITCODE."
	}
} finally {
	Remove-Item Env:GODOT_SCRIPT_ENCRYPTION_KEY -ErrorAction Ignore
	Remove-Item Env:SCRIPT_AES256_ENCRYPTION_KEY -ErrorAction Ignore
}

if (-not (Test-Path $outExe)) {
	throw "Export finished without producing $outExe."
}

$sizeMb = [math]::Round((Get-Item $outExe).Length / 1MB, 2)
Write-Host "Release export complete: $outExe ($sizeMb MB, v$resolvedVersion, encrypted=$(-not $Unencrypted))"
