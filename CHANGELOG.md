<!-- YeouWatch 1.1.0 · Copyright (c) 2026 심혜연 (2p2poo67-arch) · YeouWatch License 1.0 (LICENSE.txt) -->
# 바뀐 점 / Changelog

형식: [Keep a Changelog](https://keepachangelog.com/ko/1.1.0/), 버전: [Semantic Versioning](https://semver.org/lang/ko/)

## [1.1.0] - 2026-11-11
1인 개발자·학생이 AI와 함께 쓰기 좋게 결과를 기계가 읽는 형태로 바꾸고, 비교·기록을 더했습니다.

### 더한 것
- **오류 요약 JSON**: 요청이 끝날 때마다 `Saved\YeouWatch\last_<종류>.json` 에 상태·걸린 시간·로그에서 뽑은 오류 목록(파일, 줄, 코드, 메시지)을 남김. AI가 30~300KB 로그 대신 1KB 남짓만 읽음 (`write_result.ps1`)
- **요청 줄 세우기**: `Saved\YeouQueue\0001_build.txt` 처럼 쌓아 두면 차례대로 실행. `shotbuild` = 빌드 후 촬영
- **기준 비교**: `Saved\YeouWatch\baseline.txt` 를 두면 촬영마다 기준과 장면별 차이 %를 재고, 바뀐 장면만 `changed_ab.jpg` 한 장으로 묶음 (`compare_shots.ps1` 다시 작성)
- **HTML 리포트**: `Saved\YeouWatch\report.html` 에 빌드 성공률·평균 시간, 요청 기록, 최근 모아보기, 바뀐 장면, 장면별 성능 (`make_report.ps1`)
- 모든 요청 기록 `Saved\YeouWatch\history.jsonl`

### 실제 기기 검증에서 고친 것 (UE 5.8 새 프로젝트)
- 와쳐 창을 두 번 켜면 두 번째는 바로 꺼짐 (잠금 파일)
- 와쳐가 꺼지며 `RUNNING` 으로 남은 상태 파일은 다음 시작 때 `FAILED interrupted` 로 정리
- 에디터 모듈이 아직 없으면 촬영 전에 자동으로 한 번 빌드, 촬영 실행에 `-unattended` 추가 (물어보는 창 없음)
- 빌드가 실패하면 줄 서 있던 나머지 요청은 `Saved\YeouQueue\skipped\` 로 옮기고 멈춤
- `TEST_ARGS` 를 비워 두면 패키지 테스트는 60초 살아 있는지만 보는 가벼운 검사(`smoke_ok`)
- 리포트 생성 오류(함수 이름 충돌), 촬영 결과 JSON 에 폴더·모아보기·차이가 빠지던 문제


## [1.0.0] - 2026-11-11
첫 공개판. 「여우고택」 제작(2026-10-25 ~ 11-06)에 쓴 와쳐를 일반 프로젝트용으로 정리했습니다.

### 들어 있는 것
- `yeou_watch.bat` 본체 + `Tools/YeouWatch/watch_step.bat` 단계 파일 (본체를 다시 켜지 않고 단계만 바꿀 수 있음)
- 요청 4종: 빌드(`build_request.txt`), 파이썬(`py_request.txt`), 자동 촬영(`shot_request.txt`), 패키징(`pkg_request.txt`: full / test / ship / shiptest / zip)
- 스위치 2종: `auto_close_editor.txt`(에디터 정중히 닫기), `copy_after_pkg.txt`(출시 zip을 공유 폴더로 복사)
- `YeouAutoShot` 언리얼 플러그인: 태그·텍스트 파일로 정한 카메라 위치를 자동 촬영, `shots.json`에 프레임·GPU 시간 기록
- `make_contact_sheet.ps1`: 촬영본을 한 장짜리 모아보기 JPEG로 (토큰 절약), `compare_shots.ps1`: 전후 비교
- `make_release_zip.ps1`: .pdb·암호화 키·Saved 폴더가 들어가면 실패 처리하는 출시 zip
- MCP 연결 예시(`templates/`), AI 작업 규칙(`docs/AI_GUIDE.md`)

### 「여우고택」판에서 바꾼 것
- 프로젝트 경로·이름·엔진 경로를 `yeou_watch_config.bat` 한 곳으로 모음, 게임 전용 인자 제거
- 촬영 시스템을 게임 코드에서 떼어 내 독립 플러그인으로 새로 작성
- 공유 폴더 복사 시 예전 zip을 바로 지우지 않고 휴지통으로 보냄
