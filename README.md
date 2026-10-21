# Sisyphusball

> 정상은 없다. 그래도 민다.

Pi Network에 올리는 Flutter 게임입니다. 공(돌)은 **좌우로 움직이지 않고 수직으로만** 움직입니다.
화면을 누르고 있으면 돌을 산 위로 밀어 올리고, 손을 떼면 경사를 따라 굴러 내려옵니다.
산길을 가로지르는 바위에 닿으면 돌은 **바닥까지 굴러 떨어지고** 그 판은 끝납니다.

- 점수는 **1m = 1점**이고, 선형적으로 1점씩만 오릅니다 (콤보, 배율, 보너스 없음).
- 모든 플레이어가 **같은 시드로 만들어진 같은 산**을 오르므로 랭킹이 같은 조건에서 비교됩니다.
- **명예의 전당**(스코어보드)은 여러 사용자가 동시에 접속해도 비동기로 동작하고, WebSocket으로 실시간 갱신됩니다.
- 혼자 밀기(랭킹 반영)와 **둘이서 밀기**(한 기기에서 2인 대전) 모드가 있습니다.

## 시지프 신화를 담은 장치

"무의미하지만 의미 있어 보이는" 시스템을 의도적으로 설계했습니다.

| 장치 | 의미 |
| --- | --- |
| 1m = 1점, 오직 선형 | 보상은 커지지 않습니다. 매 순간이 같은 무게의 1점입니다. |
| 판이 끝나면 돌은 항상 바닥으로 | 어떤 기록을 세워도 돌은 다시 바닥에서 시작합니다. |
| 시지프는 돌을 놓친 자리에 남음 | 돌만 굴러 떨어지고, 사람은 그 자리에 서 있습니다. |
| 칭호 8단계 (`바닥의 조약돌` → `행복한 시지프`) | 그럴듯한 위계지만 마지막 칭호 뒤에도 정상은 없습니다. |
| "지금 정상에 있는 돌: 0개" | 전 세계 누적 거리는 계속 늘지만 이 숫자는 영원히 0입니다. |
| 누적 거리 "그 돌은 모두 바닥에 있다" | 개인이 밀어 올린 총 거리를 보여 주고, 곧바로 그 허무를 함께 보여 줍니다. |
| 다른 플레이어가 반투명 돌(유령)로 보임 | 같은 산에서 같은 형벌을 받는 다른 사람들이 동시에 존재합니다. |
| 점선 목표선(나의 최고, 1위) | 목표는 보이지만 그 선은 아무것도 움직이지 않습니다. |
| 판이 끝날 때 나오는 문장들 | "랭킹은 오르고, 돌은 내려간다." / "우리는 행복한 시지프를 상상해야 한다. — 알베르 카뮈" |

## 구조

모두 Dart로 작성되어 있습니다. JavaScript는 Pi SDK를 불러오는 `<script>` 태그 한 줄뿐이고, 호출은 `dart:js_interop`으로 합니다.

```
packages/sisyphus_core/   순수 Dart: 물리, 산(장애물) 생성, 칭호 — 앱과 서버가 함께 사용
app/                      Flutter Web 클라이언트
  lib/pi/                 Pi SDK 연동 (웹: dart:js_interop, 그 외: stub)
  lib/net/api.dart        REST 클라이언트 + WebSocket 실시간 피드(자동 재연결)
  lib/game/               GameController(Ticker 구동) · CustomPainter · 입력 처리
  lib/screens/            타이틀 · 게임오버 · 2P 결과 · 명예의 전당 · HUD
server/                   Dart(shelf) 서버: Pi 토큰 검증 · 점수 검증 · 랭킹 · WebSocket 브로드캐스트
```

### 동시 접속 / async 처리

- 서버는 Dart 단일 isolate 이벤트 루프에서 동작하고, 점수 반영은 `await` 없이 한 번에 끝나는 동기 연산이라
  여러 요청이 동시에 들어와도 중간 상태가 섞이지 않습니다.
- 저장은 디바운스된 뒤 순서대로 이어지며, 임시 파일에 쓴 다음 `rename`으로 교체해서 저장이 겹쳐도 파일이 깨지지 않습니다.
- 판이 끝날 때마다 `board` 메시지를, 1초마다 (바뀌었을 때만) `live` 메시지(지금 오르는 사람과 높이)를 모든 클라이언트에 보냅니다.

### 점수 검증 (치트 방지)

- Pi 로그인은 클라이언트에서 `Pi.authenticate(['username'])`으로 받은 accessToken을 서버가
  `GET https://api.minepi.com/v2/me`로 검증합니다. 클라이언트가 보낸 uid나 이름은 믿지 않습니다.
- 판마다 서버가 `runId`를 발급하고, 한 판은 한 번만, 그 판의 주인만 끝낼 수 있습니다.
- 물리상 가장 빠른 상승 속도(`Phys.maxUp` = 4.5m/s)로 계산한 최대값을 넘는 점수는 거부합니다(422).

## 로컬 실행

필요: Flutter 3.27 이상 (Dart 3.6 이상). Flutter 3.47.7 / Dart 3.13.5에서 테스트했습니다.

```bash
# 1) 웹 클라이언트 빌드
cd app
flutter pub get
flutter build web --release --no-web-resources-cdn

# 2) 서버 실행 (app/build/web을 함께 서빙)
cd ../server
dart pub get
dart run bin/server.dart          # http://localhost:8080
```

Pi Browser 밖(일반 브라우저)에서는 Pi 로그인이 안 되므로, `ALLOW_GUEST`가 켜져 있으면 손님 이름을 입력하고 플레이합니다.

Flutter 개발 서버로 핫 리로드하며 개발하려면 서버를 따로 띄운 뒤:

```bash
cd app
flutter run -d chrome --dart-define=API_BASE=http://localhost:8080
```

### 조작

| | 혼자 밀기 | 둘이서 밀기 |
| --- | --- | --- |
| 터치/마우스 | 아무 곳이나 누르고 있기 | 왼쪽 절반 = P1, 오른쪽 절반 = P2 (멀티터치) |
| 키보드 | Space / ↑ / W | P1 = W, P2 = ↑ |

## 테스트

```bash
(cd packages/sisyphus_core && dart test)   # 물리 · 산 생성 결정성 · 칭호
(cd server && dart test)                   # 인증 · 점수 검증 · 동시 제출 · WebSocket · 저장
(cd app && flutter test)                   # 위젯 · 2P 입력
```

## Pi Network에 올리기

1. Pi Browser에서 `develop.pi`(Pi Developer Portal)를 열고 새 앱을 등록합니다.
2. 이 서버를 HTTPS가 되는 곳에 배포합니다. Dockerfile이 들어 있습니다.
   ```bash
   docker build -t sisyphusball .
   docker run -p 8080:8080 -v sisyphus-data:/data \
     -e PI_VALIDATION_KEY=<포털에서 받은 키> sisyphusball
   ```
3. 포털의 **App URL**에 배포한 주소를 넣고, 도메인 검증을 실행합니다.
   서버가 `/validation-key.txt`에서 `PI_VALIDATION_KEY` 값을 돌려줍니다.
4. 샌드박스에서 먼저 확인합니다: 서버를 `PI_SANDBOX=true`로 띄우고, 포털에 표시되는 sandbox URL로 접속합니다.
5. 메인넷 공개 시 `PI_SANDBOX=false`(production 기본값)로 실행합니다.

### 환경 변수 (server)

| 이름 | 기본값 | 설명 |
| --- | --- | --- |
| `PORT` | `8080` | 포트 |
| `APP_ENV` | (없음) | `production`이면 `PI_SANDBOX`, `ALLOW_GUEST` 기본값이 `false`가 됩니다 |
| `PI_SANDBOX` | production이 아니면 `true` | 클라이언트 `Pi.init({sandbox})` 값 |
| `ALLOW_GUEST` | production이 아니면 `true` | Pi Browser 밖 손님 플레이 허용. 운영에서는 꺼서 랭킹에 인증된 Pioneer만 남깁니다 |
| `PI_VALIDATION_KEY` | (없음) | `/validation-key.txt` 응답 |
| `PI_API_BASE` | `https://api.minepi.com` | Pi Platform API 주소 |
| `MOUNTAIN_SEED` | `333077` | 산 모양 시드. 바꾸면 모두에게 새로운 산이 됩니다 |
| `DATA_FILE` | `data/scores.json` | 랭킹 저장 파일 |
| `WEB_DIR` | `../app/build/web` | 서빙할 Flutter 웹 빌드 경로 |

## API

| | 경로 | 설명 |
| --- | --- | --- |
| GET | `/api/config` | `{sandbox, allowGuest, seed}` |
| POST | `/api/auth` | `{accessToken}` 또는 `{guest: true, name}` → `{token, user, standing}` |
| GET | `/api/me` | 내 기록 (Bearer) |
| GET | `/api/leaderboard` | `{top, stats}` |
| POST | `/api/runs` | 판 시작 → `{runId, seed}` (Bearer) |
| POST | `/api/runs/{id}/progress` | `{height}` 1초마다 — 실시간 "지금 밀고 있는 사람들"에 반영 |
| POST | `/api/runs/{id}/finish` | `{score}` → `{isBest, standing, stats}` |
| WS | `/ws` | 서버 → 클라이언트: `{"type":"board",...}`, `{"type":"live",...}` |
