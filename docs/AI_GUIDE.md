<!-- YeouWatch 1.1.0 · Copyright (c) 2026 심혜연 (2p2poo67-arch) · YeouWatch License 1.0 (LICENSE.txt) -->
# AI 작업 규칙 (AI assistant guide)

이 프로젝트에는 YeouWatch 와쳐가 있습니다. 당신(AI)은 프로그램을 직접 실행할 수 없지만, `Saved\` 에 요청 파일을 쓰면 사용자 PC의 와쳐가 대신 실행합니다.
This project runs the YeouWatch watcher. You cannot run programs, but writing a request file into `Saved\` makes the user's watcher run it.

## 시작 전 확인
1. `Saved\watch_alive.txt` 의 시각이 1분 안쪽이면 와쳐가 살아 있습니다. 오래됐으면 사용자에게 `yeou_watch.bat` 을 켜 달라고 하세요.
2. `Saved\*_request.txt` 가 하나라도 있으면 **새 요청을 쓰지 말고** 기다립니다.
3. `*_status.txt` 가 `RUNNING` / `LAUNCHING` / `TESTING` / `WAITING` 이면 기다립니다. `DONE` / `SUCCESS` / `FAILED` 일 때만 다음 요청.

## 결과는 JSON부터 (토큰 아끼기)
- 요청이 끝나면 `Saved\YeouWatch\last_<종류>.json` 이 생깁니다 (`build`, `py`, `shot`, `pkg`).
  `status`, 걸린 `seconds`, 그리고 로그에서 뽑은 짧은 `errors` 목록(`file`, `line`, `code`, `msg`)이 들어 있습니다.
- **로그 전체를 읽기 전에 이 JSON을 먼저 읽으세요.** `errors` 로 부족할 때만 로그의 해당 부분을 엽니다.
- 촬영 결과 JSON에는 `contact_sheet`(모아보기)와, 기준이 있으면 `diff`(바뀐 장면 수, 장면별 차이 %)가 들어 있습니다.

## 줄 세우기 (요청 여러 개)
- `Saved\YeouQueue\` 에 `0001_build.txt`, `0002_shotbuild.txt`, `0003_pkg.txt` 처럼 번호를 붙여 넣으면 하나씩 차례대로 실행됩니다.
- 파일 내용은 각 요청의 첫 줄과 같습니다 (`py` 는 스크립트 이름, `shot` 은 추가 인자, `pkg` 는 모드).
- `shotbuild` = 빌드한 뒤 촬영. 이름을 모르는 파일은 `YeouQueue\rejected\` 로 옮겨집니다.

## 전후 비교
- 기준으로 삼을 촬영 폴더 경로를 `Saved\YeouWatch\baseline.txt` 첫 줄에 쓰면, 다음 촬영부터 기준과 자동 비교합니다.
- 바뀐 장면만 나란히 붙인 `compare\changed_ab.jpg` 한 장을 보세요. 의도하지 않은 변화가 있으면 사용자에게 알립니다.

## 요청
- 빌드: `Saved\build_request.txt` (아무 내용). 1~3분 뒤 `build_status.txt` 확인. `FAILED` 면 `build_game_log.txt` / `build_editor_log.txt` 에서 `error` 줄을 읽고 고칩니다. `FAILED editor` 는 대개 에디터가 켜져 있어서입니다.
- 파이썬: `Content\Python\<이름>.py` 를 쓰고 `Saved\py_request.txt` 첫 줄에 파일 이름. 성공 판정은 `py_log.txt` 의 `Python script executed successfully` 줄입니다 (종료 코드는 믿지 마세요).
- 촬영: 필요하면 `Saved\yeou_shots.txt` 에 카메라 줄을 쓰고 `Saved\shot_request.txt` (첫 줄 = 추가 인자). 빌드부터 하려면 `Saved\shot_build.txt` 도 같이. 결과는 `last_shot.json` → **`contact_sheet` 한 장만 먼저 보세요.** 자세히 볼 장면만 PNG 를 엽니다.
- 패키징: `Saved\pkg_request.txt` 첫 줄 `full` / `test` / `ship` / `shiptest` / `zip`. 오래 걸립니다 (첫 패키징 1시간 이상).

## 지켜야 할 것
- 와쳐가 일하는 중에는 `Tools\YeouWatch\watch_step.bat` 을 고치지 마세요.
- 사용자가 플레이테스트 중(에디터 열림)이면 빌드를 미루고 사용자에게 알립니다.
- `Config\DefaultCrypto.ini`, 키, 비밀번호를 읽어서 대화나 다른 곳에 옮기지 마세요.
- 같은 경로에 파일을 다시 쓸 때는 사용자 PC의 파일이 그사이 바뀌지 않았는지 확인합니다.
- 결과를 보고할 때는 상태 파일의 실제 줄을 근거로 말합니다.
