# =============================================================================
#  YeouWatch 1.1.0
#  Copyright (c) 2026 심혜연 (2p2poo67-arch). All rights reserved.
#  Licensed under the YeouWatch License 1.0 - see LICENSE.txt. Keep this notice.
# =============================================================================
# Local HTML report: Saved\YeouWatch\report.html - request history, build success rate and time,
# latest screenshot contact sheet, what changed against the baseline, and per-shot frame/GPU time.
# Open it in a browser. It is also a ready-made "how this game was built" page for a portfolio.
# Usage: make_report.ps1 -Proj <project dir>
param([string]$Proj)
$ErrorActionPreference = 'Continue'
$dir = Join-Path $Proj 'Saved\YeouWatch'
New-Item -ItemType Directory -Force -Path $dir | Out-Null
function Enc([object]$s) { if ($null -eq $s) { return '' }; return [Net.WebUtility]::HtmlEncode([string]$s) }
function Rel([string]$p) { if (-not $p) { return '' }; return ('../' + ($p -replace '^Saved[\\/]', '')).Replace('\', '/') }

$hist = @()
$hf = Join-Path $dir 'history.jsonl'
if (Test-Path $hf) { $hist = @(Get-Content $hf -Encoding UTF8 | Where-Object { $_.Trim() } | ForEach-Object { try { $_ | ConvertFrom-Json } catch { } }) }
$builds = @($hist | Where-Object { $_.kind -eq 'build' })
$ok = @($builds | Where-Object { $_.status -eq 'SUCCESS' }).Count
$secs = @($builds | Where-Object { $_.seconds } | ForEach-Object { $_.seconds })
$avg = if ($secs.Count) { [int](($secs | Measure-Object -Average).Average) } else { 0 }
$shotRuns = @($hist | Where-Object { $_.kind -eq 'shot' }).Count
$pkgRuns = @($hist | Where-Object { $_.kind -eq 'pkg' }).Count
$pyRuns = @($hist | Where-Object { $_.kind -eq 'py' }).Count

$shot = $null; $sj = Join-Path $dir 'last_shot.json'
if (Test-Path $sj) { $shot = Get-Content $sj -Raw -Encoding UTF8 | ConvertFrom-Json }
$perf = @()
if ($shot -and $shot.shots_dir) {
    $pj = Join-Path $Proj ($shot.shots_dir + '\shots.json')
    if (Test-Path $pj) { $perf = @((Get-Content $pj -Raw -Encoding UTF8 | ConvertFrom-Json).shots) }
}

$sb = New-Object Text.StringBuilder
[void]$sb.Append(@'
<!doctype html><html lang="ko"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>YeouWatch report</title><style>
:root{--bg:#121110;--panel:#1b1917;--line:#34302b;--fg:#ece6dc;--muted:#a39a8d;--seal:#c8432f;--ok:#6aa86f}
body{margin:0;background:var(--bg);color:var(--fg);font:15px/1.6 "Malgun Gothic",system-ui,sans-serif}
main{max-width:1100px;margin:0 auto;padding:32px 16px}h1{font-size:1.6rem;margin:0 0 4px}h2{font-size:1.1rem;margin:36px 0 12px}
.muted{color:var(--muted)}.tiles{display:grid;grid-template-columns:repeat(auto-fit,minmax(150px,1fr));gap:12px;margin-top:20px}
.tile{background:var(--panel);border:1px solid var(--line);border-radius:6px;padding:14px}.tile b{display:block;font-size:1.6rem}
table{border-collapse:collapse;width:100%;font-size:.88rem}td,th{border-bottom:1px solid var(--line);padding:7px 8px;text-align:left;vertical-align:top}
th{color:var(--muted);font-weight:500}.ok{color:var(--ok)}.bad{color:var(--seal)}img{max-width:100%;border-radius:4px;border:1px solid var(--line)}
.scroll{overflow-x:auto}code{font-family:Consolas,monospace;font-size:.85em}
footer{margin-top:48px;color:var(--muted);font-size:.8rem}</style></head><body><main>
'@)
[void]$sb.Append('<h1>YeouWatch report</h1><div class="muted">' + (Enc (Split-Path $Proj -Leaf)) + ' · ' + (Get-Date -Format 'yyyy-MM-dd HH:mm') + '</div>')
[void]$sb.Append('<div class="tiles">')
[void]$sb.Append('<div class="tile"><span class="muted">빌드 성공</span><b>' + $ok + ' / ' + $builds.Count + '</b></div>')
[void]$sb.Append('<div class="tile"><span class="muted">평균 빌드 시간</span><b>' + $avg + 's</b></div>')
[void]$sb.Append('<div class="tile"><span class="muted">자동 촬영</span><b>' + $shotRuns + '</b></div>')
[void]$sb.Append('<div class="tile"><span class="muted">파이썬 실행</span><b>' + $pyRuns + '</b></div>')
[void]$sb.Append('<div class="tile"><span class="muted">패키징</span><b>' + $pkgRuns + '</b></div></div>')

if ($shot) {
    [void]$sb.Append('<h2>최근 촬영</h2><div class="muted">' + (Enc $shot.finished) + ' · ' + (Enc $shot.status) + '</div>')
    if ($shot.diff) {
        [void]$sb.Append('<h2>기준과 달라진 장면: ' + $shot.diff.changed + '개</h2>')
        if ($shot.diff.changed_image) { [void]$sb.Append('<img src="' + (Rel ($shot.diff.changed_image.Replace($Proj + '\', ''))) + '" alt="changed shots">') }
        [void]$sb.Append('<div class="scroll"><table><tr><th>장면</th><th>차이</th><th></th></tr>')
        foreach ($r in $shot.diff.shots) { [void]$sb.Append('<tr><td>' + (Enc $r.name) + '</td><td>' + (Enc $r.diff_pct) + '%</td><td class="' + ($(if ($r.changed) { 'bad' } else { 'ok' })) + '">' + ($(if ($r.changed) { '바뀜' } elseif ($r.note) { Enc $r.note } else { '같음' })) + '</td></tr>') }
        [void]$sb.Append('</table></div>')
    }
    if ($shot.contact_sheet) { [void]$sb.Append('<h2>모아보기</h2><img src="' + (Rel $shot.contact_sheet) + '" alt="contact sheet">') }
    if ($perf.Count) {
        [void]$sb.Append('<h2>장면별 성능</h2><div class="scroll"><table><tr><th>장면</th><th>평균 프레임 ms</th><th>최악 ms</th><th>GPU ms</th></tr>')
        foreach ($p in $perf) { [void]$sb.Append('<tr><td>' + (Enc $p.name) + '</td><td>' + (Enc $p.frame_ms) + '</td><td>' + (Enc $p.worst_ms) + '</td><td>' + (Enc $p.gpu_ms) + '</td></tr>') }
        [void]$sb.Append('</table></div>')
    }
}
[void]$sb.Append('<h2>요청 기록 (최근 60개)</h2><div class="scroll"><table><tr><th>끝난 시각</th><th>종류</th><th>결과</th><th>걸린 시간</th><th>오류</th></tr>')
foreach ($h in ($hist | Select-Object -Last 60 | Sort-Object finished -Descending)) {
    $cls = if ($h.status -match 'FAIL') { 'bad' } else { 'ok' }
    $e = ''
    if ($h.errors) { $e = ((@($h.errors) | Select-Object -First 2 | ForEach-Object { '<code>' + (Enc $_.file) + $(if ($_.line) { ':' + $_.line } else { '' }) + '</code> ' + (Enc $_.msg) }) -join '<br>') }
    [void]$sb.Append('<tr><td>' + (Enc $h.finished) + '</td><td>' + (Enc $h.kind) + '</td><td class="' + $cls + '">' + (Enc $h.status) + '</td><td>' + $(if ($h.seconds) { [string]$h.seconds + 's' } else { '' }) + '</td><td>' + $e + '</td></tr>')
}
[void]$sb.Append('</table></div><footer>YeouWatch 1.1.0 · © 2026 심혜연 (2p2poo67-arch) · YeouWatch License 1.0</footer></main></body></html>')
[IO.File]::WriteAllText((Join-Path $dir 'report.html'), $sb.ToString(), (New-Object Text.UTF8Encoding $true))
