<!-- YeouWatch 1.1.0 · Copyright (c) 2026 심혜연 (2p2poo67-arch) · YeouWatch License 1.0 (LICENSE.txt) -->
# YeouWatch 여우와쳐

![version](https://img.shields.io/badge/version-1.1.0-b8322a) ![license](https://img.shields.io/badge/license-YeouWatch%201.0-2b2b2b) ![engine](https://img.shields.io/badge/Unreal%20Engine-5.x-313131) ![platform](https://img.shields.io/badge/platform-Windows-0b6aa2)

**AI가 고친 게임을 AI가 직접 보고 확인하게 해 주는 도구.**
"조명 좀 어둡게 해 줘"라고 하면 AI가 코드를 고치고, 빌드하고, 게임을 띄워 장면을 찍고, 전후 사진을 가져옵니다.

빌드는 MCP나 Claude Code, Cursor 로도 됩니다. 막히는 곳은 그다음, **화면에 실제로 어떻게 나왔는지 확인하는 일**입니다. 지금은 사람이 게임을 켜서 스크린샷을 보내 주거나, 토큰이 많이 드는 화면 원격 조작을 써야 합니다. YeouWatch 는 그 확인을 AI가 스스로, 싸게 하게 합니다. MCP 와 같이 써도 됩니다.

언리얼 5 공포게임 「여우고택」 데모 전체(코드 수정 → 빌드 → 자동 촬영 → 자동 플레이 테스트 → 암호화 출시 zip)를 이 방식으로 만들었습니다.

## 왜 쓰나요
- **AI가 결과를 직접 봅니다.** 게임이 혼자 떠서 정해 둔 장면을 찍고, 고치기 전과 달라진 장면만 짚어 줍니다.
- **토큰을 아낍니다.** 스크린샷 여러 장 대신 모아보기 한 장, 긴 빌드 로그 대신 오류 몇 줄만 AI가 읽습니다.
- **화면을 넘기지 않습니다.** 정해진 일 네 가지(빌드·파이썬·촬영·패키징)만 실행합니다.
- **사람 없이 한 바퀴.** 고침 → 빌드 → 확인 → 다시 고침, 그리고 밤새 패키징 → 자동 테스트 → zip 까지.

## 1.1 에서 더해진 것
- **오류 요약 JSON**: 빌드·파이썬이 끝나면 `Saved\YeouWatch\last_build.json` 에 `파일:줄 + 오류 메시지` 목록만 남깁니다. AI는 긴 로그 대신 이걸 읽습니다.
- **요청 줄 세우기**: `Saved\YeouQueue\0001_build.txt`, `0002_shotbuild.txt`, `0003_pkg.txt` … 차례대로 실행.
- **자동 전후 비교**: `Saved\YeouWatch\baseline.txt` 에 기준 촬영 폴더를 적어 두면 바뀐 장면만 골라 한 장으로 보여 줍니다.
- **HTML 리포트**: `Saved\YeouWatch\report.html` — 빌드 성공률, 평균 빌드 시간, 요청 기록, 모아보기, 장면별 성능. 포트폴리오 자료로도 씁니다.

## 준비물
- Windows 10/11, Unreal Engine 5.x (5.8 에서 사용), Visual Studio 2022 (C++ 게임 개발 워크로드)
- 프로젝트 폴더를 읽고 쓸 수 있는 AI 도구 (예: Claude 데스크톱 앱 폴더 연결, Claude Code)

## 설치 (5분)
1. zip 안의 내용을 언리얼 프로젝트 폴더(`.uproject` 옆)에 풉니다.
   `yeou_watch.bat`, `yeou_watch_config.bat`, `Tools\YeouWatch\`, `Plugins\YeouAutoShot\`
2. `yeou_watch_config.bat` 를 메모장으로 열어 `UE_DIR`(엔진 설치 폴더)를 맞춥니다. 나머지는 비워 두면 자동입니다.
3. (자동 촬영을 쓸 때) 에디터에서 **편집 → 플러그인 → YeouAutoShot** 을 켜고 한 번 빌드합니다.
4. `yeou_watch.bat` 를 더블클릭하고 창을 열어 둡니다. 끝.

AI에게는 `docs/AI_GUIDE.md` 를 읽게 하세요. 요청 규칙과 지켜야 할 예절이 들어 있습니다.

## 요청 → 결과
| AI가 쓰는 파일 (`Saved\`) | 와쳐가 하는 일 | 결과 |
|---|---|---|
| `build_request.txt` | 게임 → 에디터 대상 C++ 빌드 | `build_status.txt`, `build_*_log.txt` |
| `py_request.txt` | `Content\Python\<스크립트>` 를 화면 없이 실행 | `py_status.txt`, `py_log.txt` |
| `shot_request.txt` | 게임을 `-YeouAutoShot` 으로 띄워 자동 촬영 | `shot_status.txt`, `AutoShots\<시간>\contact_sheet.jpg` |
| `pkg_request.txt` | `full`/`test`/`ship`/`shiptest`/`zip` 패키징·테스트·zip | `pkg_status.txt`, `Release\*.zip` |

모든 요청은 끝나면 `Saved\YeouWatch\last_<종류>.json` (상태, 걸린 시간, 오류 요약)과 `history.jsonl`, `report.html` 을 갱신합니다.

## 자동 촬영 (YeouAutoShot)
- 레벨에 놓은 액터에 태그 `YeouShot` (이름은 `YeouName=복도_02`)을 달거나, AI가 `Saved\yeou_shots.txt` 에 `이름 x y z pitch yaw [fov]` 줄을 씁니다.
- `-YeouShotCVars=r.Foo=1;my.Bar=0.5` 로 값만 바꿔 다시 찍고 `compare_shots.ps1` 로 전후 비교.
- `shots.json` 에 장면마다 평균·최악 프레임 시간과 GPU 시간이 남아 성능 비교도 됩니다.

## MCP (선택)
언리얼 5.8 의 실험 기능 `ModelContextProtocol` 플러그인을 켜면 에디터가 `127.0.0.1:8000/mcp` 에 MCP 서버를 엽니다. `templates/` 의 `.mcp.json` 을 프로젝트 맨 위에 두면 같은 PC에서 돌리는 Claude Code 가 붙습니다. 이 서버는 내 PC 안에서만 열리므로 클라우드 AI는 와쳐 방식을 씁니다.

## 안전 규칙
- 요청 파일이 이미 있으면 새로 쓰지 않습니다 (앞 작업이 끝날 때까지 대기).
- 에디터가 켜져 있으면 빌드·촬영·패키징을 기다립니다. `auto_close_editor.txt` 를 두면 저장을 묻는 방식으로 정중히 닫습니다.
- 출시 zip 에 `.pdb`, `*Crypto*` (암호화 키), `Saved` 폴더가 들어가면 실패 처리합니다. **`Config\DefaultCrypto.ini` 는 절대 공유하지 마세요.**
- 와쳐가 단계를 실행하는 중에는 `watch_step.bat` 을 고치지 마세요 (cmd 는 파일을 바이트 위치로 이어 읽습니다).

## 라이선스
YeouWatch License 1.0 — 무료로 쓰고 고치고, 만든 게임은 팔아도 됩니다. 다시 배포할 때는 `LICENSE.txt`·`NOTICE.txt` 와 각 파일 머리말을 그대로 두세요. 키트 자체를 파는 것은 허락이 필요합니다. 전문은 [LICENSE.txt](LICENSE.txt).

Copyright (c) 2026 심혜연 (2p2poo67-arch). All rights reserved.

---

## English (short)
YeouWatch lets a cloud AI assistant drive your local Unreal Engine through request files: it writes `Saved\build_request.txt` (or py / shot / pkg), the watcher window on your PC runs the job and writes a status file back. The YeouAutoShot plugin takes scripted in-game screenshots and the watcher packs them into a single contact sheet, so the assistant reads one small JPEG instead of driving your screen. Install: unzip next to your `.uproject`, set `UE_DIR` in `yeou_watch_config.bat`, enable the YeouAutoShot plugin, double-click `yeou_watch.bat`. License: YeouWatch License 1.0 (free use and modification, attribution required, no resale of the kit itself without permission).
