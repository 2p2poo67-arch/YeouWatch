# =============================================================================
#  YeouWatch 1.1.0
#  Copyright (c) 2026 심혜연 (2p2poo67-arch). All rights reserved.
#  Licensed under the YeouWatch License 1.0 - see LICENSE.txt. Keep this notice.
# =============================================================================
# Before/after check. For every shot name found in both runs it measures how much the picture changed
# (mean colour difference on a 64x36 thumbnail, 0-100 %) and marks shots over -Threshold as changed.
# Writes <B>\diff.json and, for changed shots only, side-by-side <name>_ab.jpg plus one stacked changed_ab.jpg
# into <B>\compare\, so the AI looks at one image of what changed instead of every shot twice.
# Usage: compare_shots.ps1 -A <baseline run dir> -B <new run dir> [-Threshold 4] [-Width 640] [-All]
param([string]$A, [string]$B, [double]$Threshold = 4, [int]$Width = 640, [switch]$All, [int]$Quality = 82)
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing
$out = Join-Path $B 'compare'
New-Item -ItemType Directory -Force -Path $out | Out-Null
$enc = [Drawing.Imaging.ImageCodecInfo]::GetImageEncoders() | Where-Object { $_.MimeType -eq 'image/jpeg' }
$ep = New-Object Drawing.Imaging.EncoderParameters 1
$ep.Param[0] = New-Object Drawing.Imaging.EncoderParameter ([Drawing.Imaging.Encoder]::Quality), ([long]$Quality)
$font = New-Object Drawing.Font 'Segoe UI', 11

function Get-Thumb([Drawing.Image]$img) {
    $t = New-Object Drawing.Bitmap 64, 36
    $g = [Drawing.Graphics]::FromImage($t); $g.InterpolationMode = 'HighQualityBilinear'
    $g.DrawImage($img, 0, 0, 64, 36); $g.Dispose(); return $t
}
function Get-Diff([Drawing.Bitmap]$x, [Drawing.Bitmap]$y) {
    $sum = 0.0
    for ($j = 0; $j -lt 36; $j++) { for ($i = 0; $i -lt 64; $i++) {
        $p = $x.GetPixel($i, $j); $q = $y.GetPixel($i, $j)
        $sum += [Math]::Abs($p.R - $q.R) + [Math]::Abs($p.G - $q.G) + [Math]::Abs($p.B - $q.B) } }
    return [Math]::Round($sum / (64 * 36 * 3 * 255) * 100, 2)
}

$rows = @(); $pairs = @()
# names without the NN_ prefix so a shot list that grew still lines up
$bFiles = @{}; foreach ($f in Get-ChildItem $B -Filter *.png) { $bFiles[($f.BaseName -replace '^\d+_', '')] = $f.FullName }
foreach ($fa in Get-ChildItem $A -Filter *.png | Sort-Object Name) {
    $key = $fa.BaseName -replace '^\d+_', ''
    if (-not $bFiles.ContainsKey($key)) { $rows += [ordered]@{ name = $key; diff_pct = $null; changed = $null; note = 'missing in new run' }; continue }
    $ia = [Drawing.Image]::FromFile($fa.FullName); $ib = [Drawing.Image]::FromFile($bFiles[$key])
    $ta = Get-Thumb $ia; $tb = Get-Thumb $ib
    $d = Get-Diff $ta $tb; $ta.Dispose(); $tb.Dispose()
    $changed = $d -ge $Threshold
    $rows += [ordered]@{ name = $key; diff_pct = $d; changed = $changed }
    if ($changed -or $All) {
        $h = [int]([double]$Width * $ia.Height / $ia.Width)
        $bmp = New-Object Drawing.Bitmap ($Width * 2 + 6), ($h + 24)
        $g = [Drawing.Graphics]::FromImage($bmp)
        $g.Clear([Drawing.Color]::FromArgb(18, 18, 20)); $g.InterpolationMode = 'HighQualityBicubic'
        $g.DrawImage($ia, 0, 24, $Width, $h); $g.DrawImage($ib, ($Width + 6), 24, $Width, $h)
        $g.DrawString(('BEFORE  ' + $key), $font, [Drawing.Brushes]::Gainsboro, 4, 3)
        $g.DrawString(('AFTER  changed ' + $d + '%'), $font, [Drawing.Brushes]::Salmon, ($Width + 10), 3)
        $p = Join-Path $out ($key + '_ab.jpg'); $bmp.Save($p, $enc, $ep); $pairs += $p
        $g.Dispose(); $bmp.Dispose()
    }
    $ia.Dispose(); $ib.Dispose()
}
# one stacked image of every changed pair
if ($pairs.Count -gt 0) {
    $imgs = $pairs | ForEach-Object { [Drawing.Image]::FromFile($_) }
    $sw = 900; $hs = $imgs | ForEach-Object { [int]([double]$sw * $_.Height / $_.Width) }
    $stack = New-Object Drawing.Bitmap $sw, (($hs | Measure-Object -Sum).Sum)
    $g = [Drawing.Graphics]::FromImage($stack); $g.InterpolationMode = 'HighQualityBicubic'; $y = 0
    for ($k = 0; $k -lt $imgs.Count; $k++) { $g.DrawImage($imgs[$k], 0, $y, $sw, $hs[$k]); $y += $hs[$k]; $imgs[$k].Dispose() }
    $stack.Save((Join-Path $out 'changed_ab.jpg'), $enc, $ep); $g.Dispose(); $stack.Dispose()
}
$res = [ordered]@{ baseline = $A; run = $B; threshold_pct = $Threshold; changed = @($rows | Where-Object { $_.changed }).Count; shots = $rows }
if ($pairs.Count -gt 0) { $res.changed_image = (Join-Path $out 'changed_ab.jpg') }
[IO.File]::WriteAllText((Join-Path $B 'diff.json'), ($res | ConvertTo-Json -Depth 5), (New-Object Text.UTF8Encoding $false))
Write-Output "compared $($rows.Count) shots, changed $($res.changed) -> $B\diff.json"
