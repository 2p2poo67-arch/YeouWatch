# =============================================================================
#  YeouWatch 1.1.0
#  Copyright (c) 2026 심혜연 (2p2poo67-arch). All rights reserved.
#  Licensed under the YeouWatch License 1.0 - see LICENSE.txt. Keep this notice.
# =============================================================================
# Zips the Shipping package (Saved\PackageShip\Windows) into Release\<Name>_<time>.zip.
# Refuses to zip debug symbols (.pdb), encryption key files (*Crypto*) or a Saved folder.
# Result line: Saved\pkg_zip_status.txt  (DONE<tab>zip path<tab>bytes / FAILED<tab>reason)
param([string]$Proj, [string]$Name)
$ErrorActionPreference = 'Stop'
$utf8   = New-Object Text.UTF8Encoding $false
$win    = Join-Path $Proj 'Saved\PackageShip\Windows'
$root   = Join-Path $Proj 'Saved\ReleaseZip'
$stage  = Join-Path $root $Name
$outDir = Join-Path $Proj 'Release'
$zip    = Join-Path $outDir ($Name + '_' + (Get-Date -Format 'yyyyMMdd_HHmm') + '.zip')
$status = Join-Path $Proj 'Saved\pkg_zip_status.txt'
if (Test-Path $status) { Remove-Item $status -Force }
try {
    if (-not (Test-Path (Join-Path $win ($Name + '.exe')))) { throw "no package at $win" }
    if (Test-Path $root) { Remove-Item $root -Recurse -Force }
    New-Item -ItemType Directory -Force -Path $stage, $outDir | Out-Null
    robocopy $win $stage /E /XD Saved /XF *.pdb Manifest_*.txt /NFL /NDL /NJH /NJS /NP | Out-Null
    if ($LASTEXITCODE -ge 8) { throw "robocopy failed $LASTEXITCODE" }
    # ZIP_EXTRA_FILES from yeou_watch_config.bat: "a\b.txt" "c d\e.pdf"
    foreach ($m in [regex]::Matches([string]$env:ZIP_EXTRA_FILES, '"([^"]+)"')) {
        $f = Join-Path $Proj $m.Groups[1].Value
        if (Test-Path $f) { Copy-Item $f $stage -Force } else { throw "extra file missing: $f" }
    }
    $bad = Get-ChildItem $stage -Recurse -File | Where-Object {
        $_.Extension -eq '.pdb' -or $_.Name -like '*Crypto*' -or ('\' + $_.FullName.Substring($stage.Length + 1)) -like '*\Saved\*' }
    if ($bad) { throw ('forbidden files: ' + (($bad | ForEach-Object { $_.FullName }) -join '; ')) }
    Get-ChildItem $stage -Recurse -File | ForEach-Object { $_.FullName.Substring($stage.Length + 1) + "`t" + $_.Length } |
        Set-Content -Path (Join-Path $Proj 'Saved\pkg_zip_files.txt') -Encoding UTF8
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    if (Test-Path $zip) { Remove-Item $zip -Force }
    [IO.Compression.ZipFile]::CreateFromDirectory($stage, $zip, [IO.Compression.CompressionLevel]::Optimal, $true)
    [IO.File]::WriteAllText($status, ("DONE`t" + $zip + "`t" + (Get-Item $zip).Length), $utf8)
} catch {
    [IO.File]::WriteAllText($status, ("FAILED`t" + $_.Exception.Message), $utf8)
}
