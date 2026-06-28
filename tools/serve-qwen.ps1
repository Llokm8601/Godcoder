<#
.SYNOPSIS
    (ADVANCED / large-GPU path) Serve the local FP16 Qwen2.5-Coder-7B-Instruct
    safetensors behind an OpenAI-compatible endpoint via vLLM.

.NOTE
    On commodity hardware the default GodCoder "Qwen2.5-Coder (local)" provider
    instead points at Ollama (http://localhost:11434/v1, model
    qwen2.5-coder:7b-instruct) which runs on CPU / small GPUs. Use THIS script
    only on a machine with a large NVIDIA GPU (>= ~16 GB VRAM) and a vLLM-
    supported Python (3.10-3.12). If you use it, update the provider's base_url
    to http://localhost:8000/v1 and model to Qwen2.5-Coder-7B-Instruct in
    Settings (or commands.rs default_providers()).

.DESCRIPTION
    GodCoder talks to OpenAI/Anthropic-compatible endpoints only -- it never loads
    raw safetensors directly. This script starts an OpenAI-compatible server in
    front of the on-disk weights.

.PREREQUISITES
    - All 4 safetensors shards present. Run tools/complete-qwen-download.ps1 first
      (the bundled checkout only contains shard 3 of 4).
    - An NVIDIA GPU with recent CUDA drivers (recommended) and Python 3.10+.
    - vLLM installed in the active environment:  pip install vllm

.EXAMPLE
    pwsh tools/serve-qwen.ps1
    pwsh tools/serve-qwen.ps1 -Port 8000 -MaxModelLen 32768
#>
[CmdletBinding()]
param(
    [int]$Port = 8000,
    [string]$ServedModelName = "Qwen2.5-Coder-7B-Instruct",
    [int]$MaxModelLen = 32768,
    [string]$ModelPath = "$PSScriptRoot\..\Qwen\Qwen2.5-Coder-7B-Instruct\Qwen2.5-Coder-7B-Instruct"
)

$ErrorActionPreference = "Stop"

$resolved = (Resolve-Path -LiteralPath $ModelPath -ErrorAction SilentlyContinue)
if (-not $resolved) {
    Write-Error "Model folder not found: $ModelPath"
    exit 1
}
$ModelPath = $resolved.Path

# Verify all 4 shards are present before attempting to load.
$missing = @()
foreach ($i in 1..4) {
    $shard = Join-Path $ModelPath ("model-{0:00000}-of-00004.safetensors" -f $i)
    if (-not (Test-Path -LiteralPath $shard)) { $missing += (Split-Path $shard -Leaf) }
}
if ($missing.Count -gt 0) {
    Write-Warning "Missing weight shards: $($missing -join ', ')"
    Write-Warning "Run:  pwsh tools/complete-qwen-download.ps1   then retry."
    exit 1
}

if (-not (Get-Command python -ErrorAction SilentlyContinue)) {
    Write-Error "python not found on PATH. Install Python 3.10+ and 'pip install vllm'."
    exit 1
}

Write-Host "Starting OpenAI-compatible Qwen server" -ForegroundColor Cyan
Write-Host "  model     : $ModelPath"
Write-Host "  endpoint  : http://localhost:$Port/v1"
Write-Host "  model id  : $ServedModelName"
Write-Host "  ctx len   : $MaxModelLen"
Write-Host ""
Write-Host "GodCoder provider 'Qwen2.5-Coder (local)' already points here." -ForegroundColor Green

python -m vllm.entrypoints.openai.api_server `
    --model "$ModelPath" `
    --served-model-name "$ServedModelName" `
    --host 0.0.0.0 `
    --port $Port `
    --max-model-len $MaxModelLen
