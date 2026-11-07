# Azure for Students에 배포하기

Sisyphusball 서버를 Azure의 작은 Linux 서버(VM) 한 대에 올리는 가이드입니다.
처음 한 번 따라 하면 그 뒤에는 서버가 24시간 혼자 돌아갑니다. 내 컴퓨터는 꺼도 됩니다.

```
GitHub (main에 머지) ──▶ GitHub Actions가 Docker 이미지 빌드 ──▶ ghcr.io에 저장
                                                                  │ docker pull
Pi Browser ──HTTPS──▶ Azure VM [ Caddy(자동 HTTPS) ──▶ Sisyphusball 서버 ── ./data(랭킹, 백업) ]
```

## 비용

- Azure for Students는 **카드 없이** $100 크레딧(12개월)을 줍니다. 학생 신분이 유지되면 매년 갱신할 수 있습니다.
- **B1s** 또는 **B2ats v2** 크기의 Linux VM은 12개월 동안 매달 750시간까지 무료입니다. 750시간이면 한 달 내내 1대를 켜 둘 수 있습니다.
- 공인 IP, 디스크처럼 무료 범위를 넘는 소액은 $100 크레딧에서 차감됩니다.
- 크레딧이 다 떨어지면 서비스가 멈추고, 카드로 청구되지는 않습니다.
- 며칠 뒤 **Azure Portal → Subscriptions → Azure for Students**에서 남은 크레딧을 한 번 확인하세요.

## 준비물

- 학교 이메일 (Azure for Students 인증용)
- 터미널이 있는 컴퓨터 한 대. Windows는 PowerShell, Mac은 터미널이면 됩니다.
- 이 저장소의 PR이 `main`에 머지되어 있어야 합니다. 머지되면 GitHub Actions가 Docker 이미지를 만듭니다.

---

## 1단계. Azure for Students 시작 (5분)

1. https://azure.microsoft.com/free/students 접속 → **Start free**
2. 학교 이메일로 학생 인증
3. https://portal.azure.com 에 로그인되면 완료

## 2단계. Docker 이미지를 공개로 바꾸기 (3분, 처음 한 번)

서버가 로그인 없이 이미지를 받을 수 있게 합니다. 이미지에는 비밀번호나 키가 들어 있지 않습니다. 키는 서버의 `.env`에만 있습니다.

1. GitHub에서 PR이 `main`에 머지된 뒤, 저장소 **Actions** 탭에서 `CI`가 초록색이 될 때까지 기다립니다 (10분 정도).
2. GitHub 프로필 → **Packages** → `sisyphusball` → **Package settings**
3. 맨 아래 **Change visibility → Public**

## 3단계. 가상 서버(VM) 만들기 (10분)

Azure Portal → **Create a resource** → **Virtual machine**

| 항목 | 값 |
| --- | --- |
| Subscription | Azure for Students |
| Resource group | 새로 만들기: `sisyphusball` |
| Virtual machine name | `sisyphusball` |
| Region | `(Asia Pacific) Korea Central`. 원하는 크기가 없으면 `Japan East` |
| Image | **Ubuntu Server 24.04 LTS - x64 Gen2** |
| Size | **B1s** 또는 **B2ats v2** ("free services eligible" 표시가 있는 것) |
| Authentication type | SSH public key (Key pair name: `sisyphusball-key`) |
| Username | `azureuser` |
| Public inbound ports | **SSH (22), HTTP (80), HTTPS (443)** 모두 체크 |

> ⚠️ **B2pts v2는 고르지 마세요.** ARM 서버라서 이 게임의 이미지(x86)가 실행되지 않습니다.

**Review + create → Create**를 누르면 **개인 키(.pem) 다운로드** 창이 뜹니다. 꼭 받아 두세요. 다시 받을 수 없습니다.

### 주소(DNS 이름) 붙이기

1. 만든 VM 화면 → **Overview** → `DNS name` 옆 **Not configured** 클릭
2. DNS name label: `sisyphusball-testnet` → **Save**
3. 최종 주소를 기록해 둡니다. 예: `sisyphusball-testnet.koreacentral.cloudapp.azure.com`

## 4단계. 서버에 접속해서 설치 (10분)

내 컴퓨터 터미널에서 (`.pem` 파일이 있는 폴더에서):

```bash
ssh -i sisyphusball-key.pem azureuser@sisyphusball-testnet.koreacentral.cloudapp.azure.com
```

> Mac/Linux에서 `UNPROTECTED PRIVATE KEY FILE` 오류가 나면 `chmod 600 sisyphusball-key.pem` 후 다시 시도하세요.

접속되면 VM 안에서:

```bash
# 저장소가 비공개라면 비밀번호 칸에 GitHub 토큰을 넣습니다 (아래 참고)
git clone https://github.com/KhankhanLee/Sisyphusball.git
cd Sisyphusball/deploy/azure
./setup.sh
```

`setup.sh`가 물어보는 값:

| 질문 | 입력 |
| --- | --- |
| Domain | 3단계에서 만든 주소 (`https://` 없이) |
| Contact email | 엔터 → `hajinchoi139@gmail.com` |

1분쯤 뒤 브라우저에서 `https://<주소>/privacy`가 열리면 배포 성공입니다. 🎉

> **비공개 저장소 clone용 토큰 만들기**: GitHub → Settings → Developer settings →
> Personal access tokens → **Fine-grained tokens** → Generate new token →
> Repository access: *Only select repositories* → `Sisyphusball` →
> Permissions: **Contents: Read-only** → Generate. `git clone`이 비밀번호를 물을 때
> 사용자 이름에 GitHub 아이디, 비밀번호에 이 토큰을 넣습니다.

## 5단계. Pi Developer Portal 등록

| 포털 항목 | 값 |
| --- | --- |
| Domain → App Hosting | Self Hosted |
| Domain → Your App's URL | `https://<주소>` |
| Privacy / TOS | `https://<주소>/privacy`, `https://<주소>/terms` |

**도메인 검증**: 포털이 보여 주는 validation key를 복사한 뒤, VM에서:

```bash
cd ~/Sisyphusball/deploy/azure
./set-validation-key.sh <포털에서 받은 키>
```

`https://<주소>/validation-key.txt`에 키가 보이면 포털에서 **Verify**를 누릅니다.

### Mainnet 추가하기 (Testnet은 그대로 두고)

Mainnet 앱은 Testnet 앱과 별개의 앱이라 **자기 도메인**이 따로 필요합니다
(예: GitHub Student Pack으로 받은 `sisyphusball.me`).

1. 도메인 DNS에 **A 레코드** `@` → VM의 공용 IP 를 추가합니다.
2. VM에서 한 번만:
   ```bash
   cd ~/Sisyphusball/deploy/azure
   git pull
   ./add-mainnet.sh sisyphusball.me
   ```
   지금까지의 주소·키·랭킹은 Testnet용(`TESTNET_DOMAIN`, `data-testnet/`)으로 옮겨지고,
   새 도메인은 빈 랭킹으로 시작합니다.
3. 포털의 Mainnet 앱에서 받은 키로 `./set-validation-key.sh <키>` 후 **Verify**.

---

### Carve the Mountain (Pi 결제) 켜기

유저가 1π를 내고 산에 글귀를 새기는 기능입니다. 앱의 **Server API Key**가 있어야 켜집니다 (없으면 버튼이 안 보임).
결제는 앱 지갑으로 들어가므로, 앱 지갑이 연결된 앱에서만 됩니다 (지금은 Testnet).

```bash
cd ~/Sisyphusball/deploy/azure
# Testnet 앱의 API Key (포털 → Testnet 앱 → API Key)
grep -q '^TESTNET_PI_API_KEY=' .env || echo 'TESTNET_PI_API_KEY=' >> .env
sed -i "s|^TESTNET_PI_API_KEY=.*|TESTNET_PI_API_KEY=<키>|" .env
sudo docker compose up -d
```
Mainnet 앱 지갑이 승인되면 같은 방법으로 `PI_API_KEY=<Mainnet 앱 키>`를 넣으면 Mainnet에서도 켜집니다.
새긴 글귀는 `data/carvings.json` (Testnet은 `data-testnet/carvings.json`)에 저장됩니다.

### Testnet 테스터에게 A2U 보내기 (Mainnet 앱 지갑 조건)

포털은 Mainnet 앱 지갑을 주기 전에 **Testnet 앱이 서로 다른 5명에게 App-to-User 송금**을 했는지 봅니다.

1. 포털의 **Testnet** 앱에서 지갑을 연결하고 Testnet faucet으로 test-Pi를 받아 둡니다. API Key도 발급합니다.
2. 테스터들이 Pi Browser로 Testnet 주소에서 로그인하고 Push Alone을 한 판씩 합니다 (랭킹에 올라가야 대상이 됩니다).
3. VM에서 (Testnet 값만! Mainnet 지갑 seed는 절대 넣지 않기):
   ```bash
   cd ~/Sisyphusball/deploy/azure
   printf 'PI_API_KEY=%s\nAPP_WALLET_SEED=%s\n' '<Testnet API Key>' '<Testnet 앱 지갑 S...>' > a2u.env
   ./pay-testers.sh --dry-run   # 누구에게 보낼지 확인
   ./pay-testers.sh             # 0.01 test-Pi씩 1번만 송금
   ```
   보낸 기록은 `data-testnet/a2u-ledger.json`에 남아 다시 실행해도 새로 온 사람에게만 보냅니다.
   결제 네트워크가 Mainnet이면 스크립트가 취소하고 멈춥니다.

---

## 운영 명령어 (VM 안, `~/Sisyphusball/deploy/azure`에서)

| 하고 싶은 것 | 명령어 |
| --- | --- |
| 새 버전으로 업데이트 (main 머지 → Actions 완료 후) | `./update.sh` |
| 로그 보기 | `sudo docker compose logs -f app` |
| 상태 확인 | `sudo docker compose ps` |
| 재시작 | `sudo docker compose restart` |
| 배포 스크립트 자체가 바뀌었을 때 | `git pull && ./update.sh` |

## 데이터와 백업

- 랭킹: `~/Sisyphusball/deploy/azure/data/scores.json` (Testnet은 `data-testnet/scores.json`)
- 자동 백업: 같은 폴더의 `data/backups/scores-YYYY-MM-DD.json`. 하루 1개, 최근 14개를 보관합니다.
- 백업으로 되돌리기:
  ```bash
  sudo docker compose stop app
  cp data/backups/scores-2026-11-03.json data/scores.json
  sudo docker compose start app
  ```
- 백업은 같은 VM 디스크에 있습니다. VM을 삭제하면 함께 사라지니, 가끔 내 컴퓨터로 받아 두면 안전합니다.
  ```bash
  scp -i sisyphusball-key.pem azureuser@<주소>:~/Sisyphusball/deploy/azure/data/scores.json .
  ```

## 문제 해결

| 증상 | 확인할 것 |
| --- | --- |
| `https://<주소>`가 안 열림 | VM 네트워킹에서 80, 443 포트가 열려 있는지. `sudo docker compose logs caddy` |
| 인증서 오류 | DNS 이름이 맞는지 (`.env`의 DOMAIN). 수정 후 `sudo docker compose up -d` |
| `pull access denied` | 2단계(패키지 Public)를 했는지, PR이 main에 머지되고 Actions가 끝났는지 |
| 게임은 열리는데 로그인 안 됨 | Pi Browser에서 열었는지 (일반 브라우저는 production에서 Guest가 막혀 있음) |
