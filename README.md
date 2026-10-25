# Sisyphusball

> There is no summit. Push anyway.

Pi Network에 올리는 Flutter 게임입니다. 게임 안의 모든 문구는 영어입니다.
공(돌)은 **좌우로 움직이지 않고 수직으로만** 움직입니다. 누르고 있으면 돌을 산 위로 밀어 올리고,
손을 떼면 경사를 따라 굴러 내려옵니다. 산길을 가로지르는 바위에 닿으면 돌은 **바닥까지 굴러 떨어지고** 그 판은 끝납니다.

- 점수는 **1m = 1점**이고, 선형적으로 1점씩만 오릅니다 (콤보, 배율, 보너스 없음).
- 모든 플레이어가 **같은 시드로 만들어진 같은 산**을 오르므로 랭킹이 같은 조건에서 비교됩니다.
- **Hall of Fame**(스코어보드)은 여러 사용자가 동시에 접속해도 비동기로 동작하고, WebSocket으로 실시간 갱신됩니다.
- 모드: **Push Alone**(랭킹 반영), **Push Together**(한 기기 2인 대전). Pi Browser 밖에서는 **Play as Guest**로 플레이합니다.

## 시지프 신화를 담은 장치

"무의미하지만 의미 있어 보이는" 시스템을 의도적으로 설계했습니다.

| 장치 | 의미 |
| --- | --- |
| 1m = 1점, 오직 선형 | 보상은 커지지 않습니다. 매 순간이 같은 무게의 1점입니다. |
| 판이 끝나면 돌은 항상 바닥으로 | 어떤 기록을 세워도 돌은 다시 바닥에서 시작합니다. |
| 시지프는 돌을 놓친 자리에 남음 | 돌만 굴러 떨어지고, 사람은 그 자리에 서 있습니다. |
| 칭호 8단계 (`Pebble at the Bottom` → `Happy Sisyphus`) | 그럴듯한 위계지만 마지막 칭호 뒤에도 정상은 없습니다. |
| "At the summit: 0" | 전 세계 누적 거리는 계속 늘지만 이 숫자는 영원히 0입니다. |
| "Every one of those stones is at the bottom." | 개인이 밀어 올린 총 거리를 보여 주고, 곧바로 그 허무를 함께 보여 줍니다. |
| 다른 플레이어가 반투명 돌(ghost)로 보임 | 같은 산에서 같은 형벌을 받는 다른 사람들이 동시에 존재합니다. |
| 점선 목표선 (My best, #1) | 목표는 보이지만 그 선은 아무것도 움직이지 않습니다. |
| 판이 끝날 때 나오는 문장 | "The rankings rise. The stone falls." / "One must imagine Sisyphus happy. — Albert Camus" |

## 구조와 디자인 패턴

모두 Dart로 작성되어 있습니다. JavaScript는 Pi SDK를 불러오는 `<script>` 한 줄뿐이고, 호출은 `dart:js_interop`으로 합니다.

```
packages/sisyphus_core/      순수 Dart, 앱·서버 공용
  src/observer.dart          Subject / Observer (n:m)
  src/game.dart              물리 · 산(장애물) 생성 · Climber
  src/ranks.dart             칭호 · 문장
app/lib/
  main.dart                  GameShell: 현재 화면을 고르는 얇은 UI
  app_services.dart          Composition root: 모든 객체 생성 + observer 연결
  events.dart                sealed AppEvent (앱 전체 이벤트)
  copy.dart                  모든 영어 문구
  auth/                      AuthService + AuthStrategy (Pi / Guest)
  data/                      ApiClient · LiveFeed · RunReporter · models
  game/                      GameController · GamePainter · GameView · scene
  models/                    PlayerModel · LeaderboardModel · PresenceModel · ScreenModel · SceneOverlayModel
  ui/                        theme · widgets · screens
  pi/                        Pi SDK 브리지 (웹: js_interop, 그 외: stub)
server/lib/
  sisyphus_server.dart       Composition root (SisyphusServer)
  src/events.dart            sealed ServerEvent
  src/auth/                  AuthService + AuthStrategy (PiAuthStrategy / GuestAuthStrategy)
  src/scores/                ScoreRepository (InMemory / JsonFile) · ScoreService · models
  src/runs/                  RunRegistry · Presence
  src/live/                  LiveClient · ActivityLog (observers)
  src/http/                  ApiRoutes (얇은 컨트롤러) · middleware
```

| 패턴 | 어디에 | 왜 |
| --- | --- | --- |
| **Observer (n:m)** | `sisyphus_core/src/observer.dart`, 아래 표 | 게임·서버·실시간 피드가 서로를 모른 채 이벤트만 주고받습니다 |
| **Strategy** | `AuthStrategy` (클라이언트·서버 각각) | Pi 로그인과 Guest 로그인을 같은 인터페이스로 교체 가능 |
| **Repository** | `ScoreRepository` → `InMemory` / `JsonFile` | 저장 방식(파일, 나중에 DB)을 서비스 코드와 분리 |
| **Composition root** | `AppServices`, `SisyphusServer` | 객체 생성과 연결을 한 곳에 모아 흐름을 한눈에 봅니다 |
| **Adapter** | `SceneOverlayModel implements SceneOverlay` | 앱 모델을 painter가 필요한 형태(ghost, marker)로 변환 |

### Observer: n:m 연결

모든 subject와 observer가 한 가지 sealed 이벤트 계열(`AppEvent` / `ServerEvent`)을 공유합니다.
그래서 observer 하나가 여러 subject에 붙을 수 있고, observer는 `switch`로 관심 있는 이벤트만 처리합니다.

**클라이언트** (`app/lib/app_services.dart`): subject 4개, observer 5개

| subject ↓ / observer → | RunReporter | ScreenModel | PlayerModel | LeaderboardModel | PresenceModel |
| --- | :---: | :---: | :---: | :---: | :---: |
| GameController (`RunStarted`, `StoneCrashed`, `RunEnded`) | ● | ● | | | |
| RunReporter (`RunRegistered`, `RunRecorded`) | | ● | ● | ● | ● |
| AuthService (`SignedIn`, `SignInFailed`) | | | ● | | |
| LiveFeed (`BoardUpdated`, `PresenceUpdated`) | | | | ● | ● |

`RunReporter`는 observer이면서 subject입니다. 게임 이벤트를 듣고 서버에 기록한 뒤, 그 결과를 다시 알립니다.

**서버** (`server/lib/sisyphus_server.dart`): subject 2개, observer N+1개

| subject ↓ / observer → | LiveClient × N (WebSocket마다 하나) | ActivityLog |
| --- | :---: | :---: |
| ScoreService (`LeaderboardChanged`, `PersonalBest`) | ● | ● |
| RunRegistry (`PresenceChanged`) | ● | |

### 동시 접속 / async 처리

- 서버는 Dart 단일 isolate 이벤트 루프에서 동작하고, `ScoreService.record`는 `await` 없이 한 번에 끝나는 동기 연산이라
  여러 요청이 동시에 들어와도 중간 상태가 섞이지 않습니다.
- `JsonFileScoreRepository`는 저장을 디바운스한 뒤 순서대로 이어서 쓰고, 임시 파일에 쓴 다음 `rename`으로 교체합니다.
- 판이 끝날 때마다 `board`, 1초마다(바뀌었을 때만) `live` 메시지가 모든 `LiveClient`에 전달됩니다.

### 점수 검증 (치트 방지)

- Pi 로그인은 클라이언트에서 `Pi.authenticate(['username'])`으로 받은 accessToken을 서버가
  `GET https://api.minepi.com/v2/me`로 검증합니다. 클라이언트가 보낸 uid나 이름은 믿지 않습니다.
- 판마다 서버가 `runId`를 발급하고, 한 판은 한 번만, 그 판의 주인만 끝낼 수 있습니다.
- 물리상 가장 빠른 상승 속도(`Phys.maxUp` = 4.5m/s)로 계산한 최대값(`maxReachableScore`)을 넘는 점수는 거부합니다(422).

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

Pi Browser 밖(일반 브라우저)에서는 Pi 로그인이 안 되므로, `ALLOW_GUEST`가 켜져 있으면 **Play as Guest** 창에서 이름을 입력하고 플레이합니다.

Flutter 개발 서버로 핫 리로드하며 개발하려면 서버를 따로 띄운 뒤:

```bash
cd app
flutter run -d chrome --dart-define=API_BASE=http://localhost:8080
```

### 조작

| | Push Alone | Push Together |
| --- | --- | --- |
| 터치/마우스 | 아무 곳이나 누르고 있기 | 왼쪽 절반 = P1, 오른쪽 절반 = P2 (멀티터치) |
| 키보드 | Space / ↑ / W | P1 = W, P2 = ↑ |

## 테스트

```bash
(cd packages/sisyphus_core && dart test)   # observer · 물리 · 산 생성 결정성 · 칭호
(cd server && dart test)                   # 인증 · 점수 검증 · 동시 제출 · subject 알림 · WebSocket · 저장
(cd app && flutter test)                   # 위젯 · 2P 입력 · observer 연결(n:m)
```

## Pi Network에 올리기

### 1. 개발 중: Sandbox (Development URL)

1. PC에서 웹 빌드 후 서버를 띄웁니다 (`로컬 실행` 참고). 기본값이 sandbox 모드입니다.
2. 포털 **Domain → Your App's development URL**에 `http://localhost:8080`을 넣습니다.
3. **Run in Sandbox**로 열고, 처음 한 번은 폰 Pi Browser로 sandbox 인증을 합니다.

### 2. 배포: Fly.io (Production App URL)

저장소 루트의 `fly.toml`과 `Dockerfile`로 배포합니다. 서버 하나가 게임(Flutter 웹 빌드), API, `/privacy`, `/terms`를 모두 제공합니다.

```bash
# 0) flyctl 설치 후 로그인
curl -L https://fly.io/install.sh | sh
fly auth login

# 1) 앱 만들기 — 이름은 Fly 전체에서 유일해야 하므로 겹치면 fly.toml의 app 값도 같이 바꿉니다
fly apps create sisyphusball-testnet

# 2) 랭킹 파일을 보관할 볼륨 (1GB면 충분)
fly volumes create sisyphus_data --region nrt --size 1

# 3) Privacy/Terms에 표시할 연락처
fly secrets set CONTACT_EMAIL=you@example.com

# 4) 배포 → https://sisyphusball-testnet.fly.dev
fly deploy
fly scale count 1   # 세션·실시간 피드가 메모리에 있으므로 머신은 꼭 1대
```

배포 후 포털에서:

| 포털 항목 | 넣을 값 |
| --- | --- |
| Domain → Your App's URL | `https://sisyphusball-testnet.fly.dev` |
| Privacy / TOS | `https://sisyphusball-testnet.fly.dev/privacy`, `https://sisyphusball-testnet.fly.dev/terms` |

도메인 검증:
1. 포털이 보여 주는 validation key를 서버에 넣습니다. secrets를 바꾸면 Fly가 서버를 자동으로 다시 띄웁니다.
   ```bash
   fly secrets set PI_VALIDATION_KEY=<포털에서 받은 키>
   ```
2. `https://sisyphusball-testnet.fly.dev/validation-key.txt`에 키가 보이는지 확인하고 포털에서 Verify를 누릅니다.

참고:
- `fly.toml`이 `APP_ENV=production`을 설정하므로 sandbox와 Guest 플레이는 꺼지고, Pi 계정으로만 플레이합니다.
- 주소 하나는 Pi 앱 하나에만 검증됩니다. 나중에 Mainnet 앱은 **별도 Fly 앱**으로 만드세요.
  ```bash
  fly apps create sisyphusball
  fly volumes create sisyphus_data --region nrt --size 1 -a sisyphusball
  fly secrets set CONTACT_EMAIL=you@example.com -a sisyphusball
  fly deploy -a sisyphusball && fly scale count 1 -a sisyphusball
  ```
- 내 도메인을 쓰려면 `fly certs add testnet.내도메인.com` 후 DNS에 안내된 레코드를 추가합니다.
- Fly.io는 사용량 기준 과금입니다. 작은 머신 1대와 1GB 볼륨이면 비용은 적지만, 정확한 금액은 Fly 요금 페이지에서 확인하세요.
- 로그 확인: `fly logs` (개인 최고 기록이 나오면 `[best] ...` 줄이 찍힙니다).

### Privacy Policy / Terms of Service

`server/legal/privacy.html`, `server/legal/terms.html`이 원본이고, 서버가 `/privacy`, `/terms`에서 제공합니다.
`{{contact}}` 자리는 `CONTACT_EMAIL` 값으로 채워지고, 비워 두면 Pi Browser의 앱 페이지로 연락하라는 문장이 들어갑니다.
수집하는 데이터(Pi 사용자명·ID, Guest 이름, 점수, 플레이 중 높이)가 바뀌면 이 두 파일도 함께 고쳐야 합니다.

### 환경 변수 (server)

| 이름 | 기본값 | 설명 |
| --- | --- | --- |
| `PORT` | `8080` | 포트 |
| `APP_ENV` | (없음) | `production`이면 `PI_SANDBOX`, `ALLOW_GUEST` 기본값이 `false`가 됩니다 |
| `PI_SANDBOX` | production이 아니면 `true` | 클라이언트 `Pi.init({sandbox})` 값 |
| `ALLOW_GUEST` | production이 아니면 `true` | Pi Browser 밖 Guest 플레이 허용. 운영에서는 꺼서 랭킹에 인증된 Pioneer만 남깁니다 |
| `PI_VALIDATION_KEY` | (없음) | `/validation-key.txt` 응답 |
| `PI_API_BASE` | `https://api.minepi.com` | Pi Platform API 주소 |
| `MOUNTAIN_SEED` | `333077` | 산 모양 시드. 바꾸면 모두에게 새로운 산이 됩니다 |
| `DATA_FILE` | `data/scores.json` | 랭킹 저장 파일 |
| `WEB_DIR` | `../app/build/web` | 서빙할 Flutter 웹 빌드 경로 |
| `CONTACT_EMAIL` | (없음) | Privacy/Terms 페이지의 연락처 |
| `LEGAL_DIR` | `legal` | `privacy.html`, `terms.html`이 있는 폴더 |

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
| GET | `/privacy`, `/terms` | Privacy Policy, Terms of Service (HTML) |
| GET | `/validation-key.txt` | Pi 도메인 검증 키 |
