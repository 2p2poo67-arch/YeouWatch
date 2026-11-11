<!-- YeouWatch 1.1.0 · Copyright (c) 2026 심혜연 (2p2poo67-arch) · YeouWatch License 1.0 (LICENSE.txt) -->
# 요청 파일 예시 / Request file examples

모두 프로젝트의 `Saved\` 폴더에 씁니다. 첫 줄만 읽습니다.

| 파일 | 첫 줄 예시 | 결과 |
|---|---|---|
| `build_request.txt` | `go` (내용 상관없음) | `build_status.txt` = `SUCCESS ...` / `FAILED game ...` / `FAILED editor ...` |
| `py_request.txt` | `apply_materials.py` (`Content\Python` 안 스크립트) | `py_status.txt`, `py_log.txt` |
| `shot_request.txt` | `-YeouShots=corridor -YeouShotCVars=r.BloomQuality=0` 또는 빈 줄 | `shot_status.txt`, `AutoShots\<시간>\contact_sheet.jpg` |
| `shot_build.txt` | (내용 없음) — `shot_request.txt` 와 같이 두면 빌드 먼저 | |
| `pkg_request.txt` | `full` / `test` / `ship` / `shiptest` / `zip` | `pkg_status.txt`, `Release\<프로젝트>_<시간>.zip` |
| `yeou_shots.txt` | `hall 120 -340 180 -10 90 75` (이름 x y z pitch yaw [fov]) | 촬영할 카메라 목록 |

## 줄 세우기 (1.1)
`Saved\YeouQueue\` 에 `번호_종류.txt` — 종류: `build`, `py`, `shot`, `shotbuild`, `pkg`. 내용 = 위 표의 첫 줄.

```
Saved\YeouQueue\0001_build.txt       (내용 없음)
Saved\YeouQueue\0002_py.txt          apply_materials.py
Saved\YeouQueue\0003_shotbuild.txt   -YeouShots=corridor
Saved\YeouQueue\0004_pkg.txt         ship
```

## 결과 JSON 예시 (`Saved\YeouWatch\last_build.json`)
```json
{
  "kind": "build", "status": "FAILED", "detail": "game target", "seconds": 74,
  "errors": [
    { "file": "Source\\MyGame\\Private\\Door.cpp", "line": 120, "code": "C2065", "msg": "'OpenAngle': undeclared identifier" }
  ],
  "warnings": 3, "logs": ["Saved\\build_game_log.txt"]
}
```
