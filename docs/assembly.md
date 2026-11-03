# 실물 동작과 조립 순서

개인용 시제품 기준입니다. **케이스를 가공하기 전에 책상 위에서 모든 기능을 먼저 확인합니다.** 알루미늄 가공과 배터리 내장은 되돌리기 어려우므로 마지막에 합니다.

| 단계 | 하는 일 | 다음으로 넘어가는 조건 |
|---|---|---|
| 1 | 모니터로 부팅 | Ubuntu 데스크톱이 뜸 |
| 2 | 터치 패널 연결 | 패널에 Lomiri가 뜨고 터치가 맞음 |
| 3 | Wi-Fi, VPN, 오디오 | 대시보드 값이 실제 상태와 일치 |
| 4 | 케이스 조립 | 부하 시험에서 온도와 Wi-Fi가 허용 범위 |
| 5 | 배터리 | 안전 조건 충족 |

## 부품

**1–3단계에 필요한 것**

| 부품 | 메모 |
|---|---|
| Raspberry Pi 5 (8GB 권장) | Lomiri와 GNOME을 함께 담은 이미지라 메모리가 넉넉한 쪽이 좋습니다 |
| 공식 27W USB-C 전원 어댑터 | 시험 중 전원 문제를 배제하기 위해 |
| microSD 64GB 이상, A2 등급 | |
| micro-HDMI → HDMI 케이블과 모니터 | |
| USB 키보드 | 초기 설정용 |
| [Waveshare 4inch DSI LCD](https://waveshare.com/wiki/4inch_DSI_LCD) | 480×800. 이름이 비슷한 4-DSI-TOUCH-A와 혼동 주의. Pi 5용 22핀 DSI 케이블이 들어 있는지 확인 |
| USB 오디오 어댑터와 마이크 달린 이어폰 | Pi 5에는 3.5mm 잭이 없습니다 |

**4단계:** [Flirc Raspberry Pi 5 Case](https://thepihut.com/products/flirc-raspberry-pi-5-case), 양면테이프 또는 패널 고정재, 캡톤 테이프, 줄과 드릴. Wi-Fi가 약하면 SMA 안테나형 USB Wi-Fi 어댑터.

**5단계:** 보호회로가 있는 배터리 모듈. 먼저 아래 5단계를 읽어 주세요.

## 1단계: 모니터로 부팅

이미지를 microSD에 굽습니다. 가장 안전한 방법은 Raspberry Pi Imager에서 "Use custom"으로 `build/cyborgroid-pi5-*.img.xz`를 고르는 것입니다. `dd`를 쓴다면 대상을 잘못 고를 경우 디스크가 지워지니, 카드를 꽂기 전후의 `lsblk`를 비교해 장치 이름을 확인하세요.

```bash
xz -dc build/cyborgroid-pi5-YYYYMMDD.img.xz | sudo dd of=/dev/sdX bs=4M conv=fsync status=progress
```

Pi 5에 카드, 모니터, 키보드, 전원 순서로 연결합니다. 첫 부팅은 파티션 확장과 스냅 초기화로 몇 분 걸립니다. Ubuntu 데스크톱이 뜨면 터미널에서 다음을 확인합니다.

```bash
cat ~/initial-password.txt   # 기기별 초기 비밀번호
passwd                       # 바로 변경
rm ~/initial-password.txt
cyborgroid-core query mode   # desktop 이 나와야 함
systemctl --failed
```

## 2단계: 터치 패널 연결

1. `sudo poweroff` 후 전원과 모니터를 뺍니다. 전원이 켜진 채 케이블을 꽂으면 안 됩니다.
2. DSI 케이블을 Pi 5의 22핀 **DSI1** 포트(제조사 권장)와 패널에 연결합니다. 케이블 방향은 [제조사 위키](https://waveshare.com/wiki/4inch_DSI_LCD)의 Pi 5 사진을 따르세요. 전원도 이 케이블로 공급되어 GPIO 배선은 필요 없습니다.
3. 전원을 넣으면 패널에 Lomiri가 떠야 합니다. 터치 위치와 화면 방향을 확인합니다.

| 증상 | 조치 |
|---|---|
| 패널이 켜지지 않음 | 케이블 방향과 DSI 포트 확인. `/boot/firmware/config.txt`의 `[pi5]` 설정 확인 |
| 화면은 나오는데 터치가 어긋남 | 오버레이 끝에 `,invx`, `,invy`, `,swapxy`를 붙여 시험 |
| 포트가 DSI0 | 오버레이 끝에 `,dsi0` 추가 |
| Lomiri 대신 GNOME이 뜸 | Lomiri가 30초 안에 종료되어 대체된 것입니다. `journalctl _UID=1000 \| grep session:`으로 확인 |

부트 파티션은 FAT이라 다른 컴퓨터에서도 `config.txt`를 고칠 수 있습니다. 전원이 들어간 상태에서 HDMI를 꽂으면 Ubuntu로, 뽑으면 Lomiri로 전환되는지도 확인합니다. 전환 시 열린 앱은 닫힙니다.

UI 크기는 `/etc/cyborgroid/session.conf`의 `GRID_UNIT_PX`로 조절합니다.

## 3단계: Wi-Fi, VPN, 오디오

**Wi-Fi:** Lomiri 설정 또는 Ubuntu 설정에서 연결합니다. Cyborgroid 앱의 수신량과 레이더 값이 움직이면 코어 엔진이 실제 Wi-Fi를 읽고 있는 것입니다.

**VPN:** WireGuard 서버는 직접 준비해야 합니다. 준비되면 부트 파티션에 `cyborgroid/wg0.conf`를 넣고 부팅합니다. 파일은 시스템으로 옮겨지고 부트 파티션에서 삭제됩니다.

```ini
[Interface]
PrivateKey = <이 기기의 개인키>
Address = 10.0.0.2/24
DNS = 10.0.0.1

[Peer]
PublicKey = <서버 공개키>
Endpoint = 203.0.113.10:51820
AllowedIPs = 0.0.0.0/0, ::/0
PersistentKeepalive = 25
```

- **`Endpoint`는 반드시 IP 주소여야 합니다.** 도메인은 터널이 뜨기 전에 조회할 수 없어 킬스위치가 차단 상태로 남습니다.
- **이 파일을 넣는 순간 킬스위치가 켜집니다.** 터널이 끊기면 인터넷도 끊기는 것이 정상입니다. 호텔이나 카페의 로그인 페이지도 열리지 않습니다.
- 해제: `sudo /usr/lib/cyborgroid/wireguard-killswitch.sh down`. 재부팅 후에도 끄려면 `/etc/wireguard/wg0.conf`를 다른 곳으로 옮깁니다.

**오디오와 통화:** USB 오디오를 꽂아 소리와 마이크를 확인합니다. 통화는 터미널에서 `baresip`으로 시험합니다. 양쪽 모두 VPN에 연결한 뒤 상대의 VPN IP로 거는 SIP 통화이며, 일반 전화번호로는 걸 수 없습니다.

## 4단계: 케이스 조립

1. **케이스 없이 측정:** 패널을 연결한 채 온도와 Wi-Fi 신호를 기록해 둡니다.
2. **가공 없이 임시 조립:** 제조사 안내대로 서멀 패드와 나사로 Pi 5를 넣고, 케이블을 임시로 뺀 뒤 부하 시험을 합니다.

   ```bash
   for i in 1 2 3 4; do timeout 600 yes >/dev/null & done
   watch -n 10 'cat /sys/class/thermal/thermal_zone0/temp'   # 값/1000 = °C
   vcgencmd get_throttled                                      # 0x0 이 정상
   ```

3. **Wi-Fi 비교:** 케이스 안에서 신호가 크게 떨어지면 USB Wi-Fi로 바꾸고 `/etc/cyborgroid/core.toml`의 `interface`를 수정합니다.
4. **패널 실측:** 패널 외곽과 두께, 커넥터 위치를 자로 재고, 도면을 그린 뒤 가공합니다. 케이스 상판은 약 94 × 66 mm입니다.
5. **케이블 통로 가공:** Pi 5의 DSI1 포트 위치에 맞춰 슬롯을 냅니다. 쇳가루는 기판에 닿으면 합선되므로 **Pi를 뺀 상태에서** 가공하고 세척합니다. 모서리는 줄로 다듬고 캡톤 테이프를 둘러 케이블 손상을 막습니다.
6. **패널 고정:** 분리가 가능하도록 양면테이프로 시작합니다. 케이블을 급하게 꺾지 않습니다.
7. **재시험:** 2번 부하 시험을 반복합니다. 화면이 윗면 방열을 막으므로 온도가 오릅니다. `get_throttled`가 `0x0`이 아니거나 패널이 뜨거우면 측벽 방열을 보강합니다.

## 5단계: 전원

**먼저 내장 배터리 없이 외장 USB-C 보조배터리로 들고 다니며 씁니다.** 납땜이 없어 안전하고, 실사용 소비전력을 측정해 배터리 사양을 정할 수 있습니다. 5 V 3 A 출력이어도 동작하지만 경고가 표시될 수 있고 USB 전류가 600 mA로 제한됩니다.

내장은 소비전력을 측정한 뒤 진행합니다.

- 셀을 직접 납땜하지 말고 보호회로와 충전 회로, 5 V 승압이 갖춰진 검증된 모듈을 씁니다.
- SoC와 셀 사이에 단열층을 두고, 셀이 눌리거나 금속 모서리에 닿지 않게 합니다.
- 부풀거나 뜨거워진 셀은 즉시 사용을 중단합니다.
- 충전 중에는 자리를 비우지 마세요.

두께와 사용 시간 추정은 [hardware.md](hardware.md)를 참고하세요.

## 실물에서 처음 확인할 항목

아래는 QEMU로 시험할 수 없어 실제로 해 봐야 알 수 있습니다.

- Pi 5 펌웨어를 포함한 실제 부팅
- 이 패널과 오버레이의 Ubuntu 26.04 호환성, 터치 방향
- Lomiri와 GNOME의 V3D GPU 동작
- HDMI 연결과 분리에 따른 자동 전환
- 실제 Wi-Fi 스캔과 레이더 표시
- 오디오 장치와 통화
