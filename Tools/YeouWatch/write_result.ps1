# =============================================================================
#  YeouWatch 1.1.0
#  Copyright (c) 2026 심혜연 (2p2poo67-arch). All rights reserved.
#  Licensed under the YeouWatch License 1.0 - see LICENSE.txt. Keep this notice.
# =============================================================================
# Writes one machine-readable result for a finished request and appends it to the history.
#   Saved\YeouWatch\last_<kind>.json   - the latest result of that kind (what the AI reads first)
#   Saved\YeouWatch\history.jsonl      - one line per request, for the HTML report
# For build / py it also digests the log into a short error list (file, line, code, message),
# so the AI reads ~1 KB instead of a 30-300 KB log.
# Usage: write_result.ps1 -Proj <dir> -Kind build|py|shot|pkg -Mark            (request started: remembers the time)
#        write_result.ps1 -Proj <dir> -Kind build|py|shot|pkg -Status SUCCESS|DONE|FAILED -Detail "<text>" [-Log <file>] [-Log2 <file>]
param([string]$Proj, [string]$Kind, [string]$Status = '', [string]$Detail = '', [string]$Log = '', [string]$Log2 = '', [switch]$Mark)
$ErrorActionPreference = 'Continue'
$dir = Join-Path $Proj 'Saved\YeouWatch'
New-Item -ItemType Directory -Force -Path $dir | Out-Null
$utf8 = New-Object Text.UTF8Encoding $false
$markFile = Join-Path $dir ('started_' + $Kind + '.txt')
if ($Mark) { [IO.File]::WriteAllText($markFile, (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'), $utf8); exit 0 }
$Started = ''
if (Test-Path $markFile) { $Started = [IO.File]::ReadAllText($markFile).Trim(); Remove-Item $markFile -Force }
# shot: the output folder is in shot_status.txt  ("DONE C:\...\AutoShots\20261111_120000 | shots 12")
if ($Kind -eq 'shot' -and -not $Detail) {
    $st = Join-Path $Proj 'Saved\shot_status.txt'
    if (Test-Path $st) { $m = [regex]::Match([IO.File]::ReadAllText($st), '^(?:DONE|RUNNING|FAILED)\s+(?:[^|]*?\s)?(?<d>[A-Za-z]:[\\/][^|]+?)\s*\|'); if ($m.Success) { $Detail = $m.Groups['d'].Value.Trim().Replace('/', '\') } }
}

function Get-Digest([string]$path, [int]$max = 25) {
    $errs = New-Object System.Collections.ArrayList
    $warn = 0
    if (-not $path -or -not (Test-Path $path)) { return @{ errors = @(); warnings = 0 } }
    $seen = @{}
    foreach ($ln in [IO.File]::ReadLines($path)) {
        # MSVC / clang / UHT:  C:\x\Foo.cpp(120): error C2065: 'Bar': undeclared identifier
        $m = [regex]::Match($ln, '^\s*(?<file>[A-Za-z]:[^()]+|[^()\s][^()]*)\((?<line>\d+)(?:,\d+)?\)\s*:\s*(?<sev>fatal error|error|Error|warning|Warning)\s*(?<code>[A-Z]+\d+)?\s*:?\s*(?<msg>.*)$')
        if ($m.Success) {
            if ($m.Groups['sev'].Value -match '^[Ww]arning') { $warn++; continue }
            $key = $m.Groups['file'].Value + ':' + $m.Groups['line'].Value + ':' + $m.Groups['msg'].Value
            if ($seen.ContainsKey($key)) { continue }; $seen[$key] = 1
            $f = $m.Groups['file'].Value.Trim()
            $pi = $f.IndexOf('\Source\'); if ($pi -ge 0) { $f = $f.Substring($pi + 1) }
            $pi = $f.IndexOf('\Plugins\'); if ($pi -ge 0) { $f = $f.Substring($pi + 1) }
            if ($errs.Count -lt $max) { [void]$errs.Add([ordered]@{ file = $f; line = [int]$m.Groups['line'].Value; code = $m.Groups['code'].Value; msg = $m.Groups['msg'].Value.Trim() }) }
            continue
        }
        # linker, UBT and Python errors without a file/line
        if ($ln -match '(LNK\d{4}|error LNK|Unable to build|ERROR: |LogPython: Error: |Traceback \(most recent call last\)|Error: [A-Za-z]+Error)') {
            $t = $ln.Trim(); if ($seen.ContainsKey($t)) { continue }; $seen[$t] = 1
            if ($errs.Count -lt $max) { [void]$errs.Add([ordered]@{ file = ''; line = 0; code = ''; msg = $t }) }
        }
    }
    return @{ errors = @($errs); warnings = $warn }
}

$d1 = Get-Digest $Log
$d2 = Get-Digest $Log2
$res = [ordered]@{
    tool     = 'YeouWatch 1.1.0'
    kind     = $Kind
    status   = $Status
    detail   = $Detail
    started  = $Started
    finished = (Get-Date -Format 'yyyy-MM-dd HH:mm:ss')
    errors   = @($d1.errors) + @($d2.errors)
    warnings = $d1.warnings + $d2.warnings
    logs     = @(@($Log, $Log2) | Where-Object { $_ } | ForEach-Object { $_.Replace($Proj + '\', '') })
}
if ($Started) {
    try { $res.seconds = [int]((Get-Date) - [datetime]::ParseExact($Started, 'yyyy-MM-dd HH:mm:ss', $null)).TotalSeconds } catch { }
}
if ($Kind -eq 'shot' -and $Detail -and (Test-Path (Join-Path $Detail 'shots.json'))) {
    $res.shots_dir = $Detail.Replace($Proj + '\', '')
    $cs = Join-Path $Detail 'contact_sheet.jpg'
    if (Test-Path $cs) { $res.contact_sheet = $cs.Replace($Proj + '\', '') }
    $dj = Join-Path $Detail 'diff.json'
    if (Test-Path $dj) { $res.diff = (Get-Content $dj -Raw | ConvertFrom-Json) }
}
$json = $res | ConvertTo-Json -Depth 6
[IO.File]::WriteAllText((Join-Path $dir ("last_" + $Kind + ".json")), $json, $utf8)
$line = ($res | ConvertTo-Json -Depth 6 -Compress) + "`n"
[IO.File]::AppendAllText((Join-Path $dir 'history.jsonl'), $line, $utf8)
Write-Output $json
