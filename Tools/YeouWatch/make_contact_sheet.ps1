# =============================================================================
#  YeouWatch 1.1.0
#  Copyright (c) 2026 심혜연 (2p2poo67-arch). All rights reserved.
#  Licensed under the YeouWatch License 1.0 - see LICENSE.txt. Keep this notice.
# =============================================================================
# Token saver: packs every PNG of one AutoShot run into ONE labelled JPEG grid.
# An AI assistant reads contact_sheet.jpg (a few hundred KB) instead of 20+ full-size PNGs (1-2 MB each).
# Usage: make_contact_sheet.ps1 -Proj <project> [-Dir <shot folder>] [-Cols 4] [-Thumb 480] [-CropBottom 0]
# Default Dir = newest folder in Saved\AutoShots. Writes <Dir>\contact_sheet.jpg and Saved\contact_sheet.txt (path).
param([string]$Proj, [string]$Dir = '', [int]$Cols = 4, [int]$Thumb = 480, [int]$CropBottom = 0, [int]$Quality = 82)
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing
if (-not $Dir) {
    $Dir = (Get-ChildItem (Join-Path $Proj 'Saved\AutoShots') -Directory | Sort-Object LastWriteTime -Descending | Select-Object -First 1).FullName
}
$files = Get-ChildItem $Dir -Filter *.png | Sort-Object Name
if (-not $files) { throw "no png in $Dir" }
$first = [Drawing.Image]::FromFile($files[0].FullName)
$th = [int]([double]$Thumb * ($first.Height - $CropBottom) / $first.Width)
$first.Dispose()
$label = 22
$rows = [Math]::Ceiling($files.Count / $Cols)
$sheet = New-Object Drawing.Bitmap ($Cols * $Thumb), ($rows * ($th + $label))
$g = [Drawing.Graphics]::FromImage($sheet)
$g.Clear([Drawing.Color]::FromArgb(18, 18, 20))
$g.InterpolationMode = 'HighQualityBicubic'
$font = New-Object Drawing.Font 'Segoe UI', 10
$brush = [Drawing.Brushes]::Gainsboro
for ($i = 0; $i -lt $files.Count; $i++) {
    $img = [Drawing.Image]::FromFile($files[$i].FullName)
    $x = ($i % $Cols) * $Thumb; $y = [Math]::Floor($i / $Cols) * ($th + $label)
    $src = New-Object Drawing.Rectangle 0, 0, $img.Width, ($img.Height - $CropBottom)
    $g.DrawImage($img, (New-Object Drawing.Rectangle $x, ($y + $label), $Thumb, $th), $src, 'Pixel')
    $g.DrawString(('{0:D2} {1}' -f ($i + 1), $files[$i].BaseName), $font, $brush, ($x + 4), ($y + 3))
    $img.Dispose()
}
$enc = [Drawing.Imaging.ImageCodecInfo]::GetImageEncoders() | Where-Object { $_.MimeType -eq 'image/jpeg' }
$ep = New-Object Drawing.Imaging.EncoderParameters 1
$ep.Param[0] = New-Object Drawing.Imaging.EncoderParameter ([Drawing.Imaging.Encoder]::Quality), ([long]$Quality)
$out = Join-Path $Dir 'contact_sheet.jpg'
$sheet.Save($out, $enc, $ep)
$g.Dispose(); $sheet.Dispose()
[IO.File]::WriteAllText((Join-Path $Proj 'Saved\contact_sheet.txt'), $out, (New-Object Text.UTF8Encoding $false))
Write-Output "contact sheet: $out ($($files.Count) shots)"
