# Cyborgroid

표준 Ubuntu를 터치폰 환경에 맞추고, 겉모습은 Ubuntu Touch의 디자인 양식을 따른 기기입니다.

**핵심은 호환성입니다.** 새로운 OS도, 정품 Ubuntu Touch도 아닙니다. 공식 Ubuntu 26.04 Desktop에 GNOME 확장 기능 하나를 더한 것이라, 일반 Ubuntu 앱과 업데이트, 로그인, 화면 키보드가 그대로 동작합니다.

| 연결 상태 | 화면 |
|---|---|
| 기기만 들고 쓸 때 | `design/Raspberry_Desktop_After.png`의 터치 홈 화면 |
| 모니터를 꽂았을 때 | 일반 Ubuntu 데스크톱. 열린 앱은 닫히지 않습니다 |

현재 상태와 안 되는 기능은 [docs/status.md](docs/status.md)를 먼저 읽어 주세요. **아직 실제 라즈베리파이에서 켜 본 적이 없습니다.**

## 문서

- [docs/status.md](docs/status.md): 확인된 것, 안 되는 것, 사양서와 다른 점
- [docs/hardware.md](docs/hardware.md): After 디자인과 실제 부품, 아직 남은 결정
- [docs/assembly.md](docs/assembly.md): SD 카드 굽기와 설치
- 원래 구상: [아키텍처 사양서](raspberry_pi_5_touchphone_desktop_architecture.md), [브랜드](Brand_Naming.md), [조립 검토](certification.md)

## 구성

| 폴더 | 내용 |
|---|---|
| `os/overlay/usr/share/gnome-shell/extensions/cyborgroid-touch@cyborgroid/` | 터치 환경의 전부: 홈 화면, 가장자리 제스처, 모드 전환 |
| `core/` | Rust 데몬. 트래픽 기록, Wi-Fi 스캔, 상태 제공 |
| `shell/` | C# Avalonia 앱. 대시보드와 레이더. 홈 화면의 `토큰` 아이콘으로 열립니다 |
| `os/` | SD 카드 이미지 빌드, 시스템 설정, 시험 |
| `design/` | Before/After 이미지 |

## 바로 실행해 보기

기기 없이 세 가지 방법이 있습니다.

| 명령 | 무엇이 뜨나 | 시간 |
|---|---|---|
| `./run.sh` | 대시보드와 레이더 앱. 이 PC의 실제 Wi-Fi를 읽습니다 | 수십 초 |
| `os/test/preview-touch.sh` | 실제 GNOME 50으로 터치 환경을 돌려 `build/preview/`에 화면을 저장 | 약 2분 |
| `os/run-vm.sh` | 완성된 이미지를 창으로 부팅 | 첫 부팅 수 분 이상 |

## 이미지 빌드

Ubuntu 24.04 이상의 x86-64 PC에서 실행합니다. Rust(`aarch64-unknown-linux-musl` 타깃 포함), .NET 10 SDK, Docker, 디스크 여유 공간 약 30GB가 필요합니다.

```bash
rustup target add aarch64-unknown-linux-musl
os/build-image.sh
```

결과는 `build/cyborgroid-pi5-날짜.img.xz`입니다. 공식 Ubuntu Desktop for Raspberry Pi 이미지를 내려받아 체크섬을 확인한 뒤 그 위에 구성합니다. Docker를 privileged 모드로 쓰며, 빌드하는 동안 호스트에 arm64 에뮬레이션을 임시로 등록했다가 끝나면 해제합니다.

## 시험

```bash
(cd core && cargo test)                    # 코어 엔진 단위 테스트

docker run --rm --cap-add NET_ADMIN --cap-add SYS_ADMIN \
  --security-opt apparmor=unconfined -v "$PWD/os:/os:ro" \
  ubuntu:26.04 /os/test/test-killswitch.sh # 킬스위치: 실제 패킷과 WireGuard 터널

os/test/preview-touch.sh 480x640           # 터치 환경, 실제 터치 입력

SKIP_COMPRESS=1 os/build-image.sh
IMG=$(ls build/cyborgroid-pi5-*.img)
os/test/boot-test.sh "$IMG"                # 이미지 부팅, 아이콘, 한글, 전환, 잠금
FIRSTRUN=1 os/test/boot-test.sh "$IMG"     # 첫 설정 화면
SEED_WG=1 os/test/boot-test.sh "$IMG"      # VPN 설정을 넣은 부팅
```

부팅 시험의 기록과 화면은 `build/boot-test*/`에 저장됩니다. QEMU에는 Pi 5 모델이 없어서 일반 `virt` 보드로 돌리므로, Pi 펌웨어와 화면, Wi-Fi 칩은 시험하지 못합니다.

## 설정

| 파일 또는 키 | 내용 |
|---|---|
| `org.gnome.shell.extensions.cyborgroid-touch mode-override` | `auto`(모니터 연결 여부를 따름), `touch`, `desktop` |
| `/etc/cyborgroid/core.toml` | 사용할 Wi-Fi 인터페이스, 토큰 비율, 스캔 주기 |
| `/etc/cyborgroid/killswitch.conf` | 킬스위치 설정, LAN 허용 여부 |
| 부트 파티션의 `cyborgroid/` | `wg0.conf`(VPN), `*.nmconnection`(Wi-Fi)을 넣으면 부팅 때 가져오고 원본을 지웁니다 |

터치 모드로 들어갈 때 바꾼 Ubuntu 설정은 저장해 두었다가, 모니터 연결이나 확장 기능을 끌 때 그대로 되돌립니다.
