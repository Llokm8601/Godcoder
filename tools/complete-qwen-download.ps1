<#
.SYNOPSIS
    Complete the Qwen2.5-Coder-7B-Instruct weight download.

.DESCRIPTION
    The bundled checkout under Qwen/Qwen2.5-Coder-7B-Instruct only contains
    shard 3 of 4 (the earlier `git clone` was interrupted). This script fetches
    the remaining safetensors shards from the Hugging Face Hub into the existing
    model folder so tools/serve-qwen.ps1 can load the full model.

    Uses the official `huggingface-cli` downloader (resumable, hash-verified).

.PREREQUISITES
    pip install -U "huggingface_hub[cli]"

.EXAMPLE
    pwsh tools/complete-qwen-download.ps1
#>
[CmdletBinding()]
param(
    [string]$TargetDir = "$PSScriptRoot\..\Qwen\Qwen2.5-Coder-7B-Instruct\Qwen2.5-Coder-7B-Instruct",
    [string]$RepoId = "Qwen/Qwen2.5-Coder-7B-Instruct"
)

$ErrorActionPreference = "Stop"

$TargetDir = (Resolve-Path -LiteralPath $TargetDir).Path
Write-Host "Completing weights for $RepoId" -ForegroundColor Cyan
Write-Host "  into: $TargetDir"

# Prefer the huggingface_hub Python API (robust; no CLI-on-PATH dependency).
$pyExe = (Get-Command py -ErrorAction SilentlyContinue) ?? (Get-Command python -ErrorAction SilentlyContinue) ?? (Get-Command python3 -ErrorAction SilentlyContinue)
if (-not $pyExe) {
    Write-Error "No Python interpreter found (py/python/python3). Install Python 3.10+."
    exit 1
}

# Ensure huggingface_hub is importable.
& $pyExe.Source -c "import huggingface_hub" 2>$null
if ($LASTEXITCODE -ne 0) {
    Write-Host "Installing huggingface_hub..." -ForegroundColor Yellow
    & $pyExe.Source -m pip install -U "huggingface_hub"
}

# Resumable snapshot download into the existing folder. Already-present files
# (shard 3, tokenizer, config) are skipped; only the missing shards pull.
$dl = @"
from huggingface_hub import snapshot_download
snapshot_download(
    repo_id=r'$RepoId',
    local_dir=r'$TargetDir',
    allow_patterns=['*.safetensors', '*.json', '*.txt', 'merges.txt', 'vocab.json', 'tokenizer*'],
    max_workers=4,
)
print('snapshot_download complete')
"@
$dl | & $pyExe.Source -

Write-Host ""
Write-Host "Verifying shards..." -ForegroundColor Cyan
$ok = $true
foreach ($i in 1..4) {
    $shard = Join-Path $TargetDir ("model-{0:00000}-of-00004.safetensors" -f $i)
    if (Test-Path -LiteralPath $shard) {
        Write-Host ("  [ok] " + (Split-Path $shard -Leaf)) -ForegroundColor Green
    } else {
        Write-Host ("  [missing] " + (Split-Path $shard -Leaf)) -ForegroundColor Red
        $ok = $false
    }
}
if ($ok) {
    Write-Host "`nAll shards present. Next:  pwsh tools/serve-qwen.ps1" -ForegroundColor Green
} else {
    Write-Warning "Some shards are still missing. Re-run this script to resume."
    exit 1
}
