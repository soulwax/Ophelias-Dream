# Downloads the local voice model and the CPU server that runs it.
# Weights land in build/llm/, which is not part of the game.
$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $PSScriptRoot
$dest = Join-Path $root "build\llm"
New-Item -ItemType Directory -Force -Path $dest | Out-Null

$zip = Join-Path $dest "llama-cpu.zip"
curl.exe -L --fail -o $zip "https://github.com/ggml-org/llama.cpp/releases/download/b9565/llama-b9565-bin-win-cpu-x64.zip"
Expand-Archive -Path $zip -DestinationPath (Join-Path $dest "llama") -Force

$model = Join-Path $dest "Qwen_Qwen3-4B-Instruct-2507-Q4_K_M.gguf"
curl.exe -L --fail -o $model "https://huggingface.co/bartowski/Qwen_Qwen3-4B-Instruct-2507-GGUF/resolve/main/Qwen_Qwen3-4B-Instruct-2507-Q4_K_M.gguf"
Write-Output "Voice model ready: $model"
