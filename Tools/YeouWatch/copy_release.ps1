# =============================================================================
#  YeouWatch 1.1.0
#  Copyright (c) 2026 심혜연 (2p2poo67-arch). All rights reserved.
#  Licensed under the YeouWatch License 1.0 - see LICENSE.txt. Keep this notice.
# =============================================================================
# Copies the newest release zip (Saved\pkg_zip_status.txt) to a share folder such as Google Drive
# and moves older zips of the same project there to the Recycle Bin. Result: Saved\copy_status.txt
param([string]$Proj, [string]$Dest)
$ErrorActionPreference = 'Stop'
$utf8   = New-Object Text.UTF8Encoding $false
$status = Join-Path $Proj 'Saved\copy_status.txt'
if (Test-Path $status) { Remove-Item $status -Force }
try {
    $zs = [IO.File]::ReadAllText((Join-Path $Proj 'Saved\pkg_zip_status.txt')).Trim().Split("`t")
    if ($zs[0] -ne 'DONE') { throw 'zip not DONE' }
    $zip = $zs[1]
    if (-not (Test-Path $Dest)) { throw "no folder $Dest" }
    $name = Split-Path $zip -Leaf
    $target = Join-Path $Dest $name
    Copy-Item $zip $target -Force
    if ((Get-Item $target).Length -ne (Get-Item $zip).Length) { throw 'size mismatch after copy' }
    $prefix = ($name -replace '_\d{8}_\d{4}\.zip$', '') + '_*.zip'
    Add-Type -AssemblyName Microsoft.VisualBasic
    Get-ChildItem $Dest -Filter $prefix | Where-Object { $_.Name -ne $name } | ForEach-Object {
        [Microsoft.VisualBasic.FileIO.FileSystem]::DeleteFile($_.FullName, 'OnlyErrorDialogs', 'SendToRecycleBin') }
    [IO.File]::WriteAllText($status, ("DONE`t" + $target + "`t" + (Get-Item $target).Length), $utf8)
} catch {
    [IO.File]::WriteAllText($status, ("FAILED`t" + $_.Exception.Message), $utf8)
}
