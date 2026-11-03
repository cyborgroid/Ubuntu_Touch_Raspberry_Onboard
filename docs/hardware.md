# 하드웨어: Before → After를 실제 부품으로 옮기기

`design/Raspberry_Desktop_Before.png`(Flirc 케이스), `design/Raspberry_Desktop_After.png`(렌더링), `certification.md`를 바탕으로 정리했습니다. **케이스는 Flirc Raspberry Pi 5 Case 기반으로 확정했습니다.** Compute Module 5 맞춤 설계는 하지 않으므로 렌더링보다 두꺼워집니다. 치수와 런타임은 설계 출발점을 잡기 위한 추정치이며, 실측 전에 절삭 가공을 하면 안 됩니다.

## After 렌더링이 Pi 5와 맞지 않는 부분

Before 이미지는 실제 판매 제품인 **Flirc Raspberry Pi 3 Case(실버)**의 제품 사진으로, The Pi Hut 판매 사진과 픽셀 차이가 평균 약 0.25/255에 불과합니다. 이 케이스는 Pi 3 B+, 3, 2, B+용이라 Pi 5가 들어가지 않습니다. Pi 5에는 별도 제품인 Flirc Raspberry Pi 5 Case(94 × 66 × 28 mm)를 기준으로 삼아야 합니다.

After 이미지는 이 사진을 바탕으로 만든 합성 또는 생성 이미지로 보이며, 실제 제품 사진이 아닙니다. 화면 글자가 깨져 있고, Flirc 제품 목록에 터치스크린 케이스가 없습니다. 케이스를 설계할 때는 렌더링이 아니라 Pi 5 기계 도면을 기준으로 해야 합니다.

| 렌더링 | 실제 Raspberry Pi 5 | 조치 |
|---|---|---|
| 풀사이즈 HDMI 1개 | micro-HDMI 2개 | 케이스 개구부를 새로 설계. 데스크톱 모드에 micro-HDMI 케이블 필요 |
| 3.5mm 오디오 잭 | 없음 | 아래 "오디오" 참고 |
| 작은 전원 포트 | USB-C (PD) | 개구부 변경 |
| USB-A 2개 | USB-A 4개 (2단 2열) | 단자는 빠지지 않으므로 4개 개구부 필요 |
| 화면 내 지문 인식 | 해당 하드웨어 없음 | 셸에서 뺐습니다 |
| FLIRC 각인 | 타사 상표 | 판매하거나 공개할 제품에는 사용 금지. Cyborgroid로 교체 |

## 적층 구조

`certification.md`는 메인보드, 배터리, 화면이 "단자 높이 안에 딱 맞게" 들어간다고 했습니다. 하지만 배터리와 화면은 포트 영역의 위아래에 더해지므로 높이가 늘어납니다. 렌더링의 높이는 Before와 약 1%밖에 차이 나지 않아(이미지 높이 대비 0.357 대 0.354) 이 추가 층을 담을 공간이 없습니다.

| 층 (위→아래) | 추정 두께 |
|---|---|
| 터치 LCD와 커버 글래스 | 5–8 mm (제품별 확인 필요) |
| Flirc Pi 5 케이스 본체 | 28 mm (판매처 사양) |
| 절연 및 단열층 | 1–2 mm |
| Li-Po 셀과 BMS | 6–10 mm |
| **합계** | **약 40–48 mm** |

렌더링처럼 얇게 만들 수는 없습니다. 두께를 크게 줄이려면 USB 단자를 제거해야 하므로, 보드 개조 또는 Compute Module 5 기반 재설계가 필요합니다.

## 화면 크기

문서마다 크기가 다릅니다. 아키텍처 사양서는 4–7인치, `certification.md`는 4–5인치이고, 렌더링은 Pi 크기(85×56 mm)에 맞는 약 3.5–4인치입니다.

| 선택 | 외곽 크기 | 장단점 |
|---|---|---|
| 공식 Touch Display 2, 5인치 | 91.5 × 143.5 mm, 깊이 16 mm | 자동 인식, OS 설정 불필요. 다만 Pi보다 훨씬 길어 렌더링 형태가 아니고, 깊이 16 mm는 위 표의 3–5 mm보다 큼 |
| **Waveshare 4inch DSI LCD, 480×800 (채택)** | 텍스트 사양 없음, 구매 전 도면 확인 필요 | 드라이버가 이 OS에 포함(`vc4-kms-dsi-waveshare-panel,4_0_inch`). 전원과 통신을 DSI 케이블 하나로 처리. 세로형이라 터치폰 형태에 맞음 |
| Waveshare 3.5inch DSI LCD (E), 640×480 | 텍스트 사양 없음 | 더 작지만 제조사 전용 오버레이를 별도로 설치해야 함 |
| Waveshare 4-DSI-TOUCH-A, 480×800 | 108.3 × 65.1 mm | **사용 안 함.** 이름은 비슷하지만 이 OS의 오버레이에 해당 패널 값이 없고 GPIO 전원 배선이 필요 |

렌더링처럼 베젤 없이 상판을 꽉 채우는 기성 패널은 찾지 못했습니다. 위 오버레이 값은 공식 이미지의 `overlays/README`에서 확인했지만, 제조사 문서에 Ubuntu 절차는 없으므로 실물로 시험해야 합니다.

공식 패널은 세로형(720×1280)입니다. 렌더링처럼 가로로 쓰려면 Lomiri에서 회전 설정이 필요하며, 실기기에서 확인해야 합니다. Pi 5의 MIPI 커넥터는 22핀 미니 규격이라 22핀–15핀 변환 FFC가 필요합니다.

## 전원: 가장 위험한 부분

- **승압이 필수입니다.** Li-Po 단일 셀은 3.0–4.2 V이고 Pi 5는 5 V가 필요합니다. `certification.md`에 빠져 있는 승압 컨버터를 넣어야 합니다.
- **전류:** Pi 5의 권장 전원은 5 V 5 A(25 W)입니다. 3.7 V 셀에서 최대 부하 시 효율을 감안하면 7 A 이상이 흐르므로 셀의 방전 정격과 승압 컨버터를 이 기준으로 고르고, 부족하면 USB 포트 전류를 600 mA로 두어야 합니다. 스마트폰용 슬림 셀은 이 전류를 감당하지 못하는 경우가 많습니다.
- **`usb_max_current_enable=1`:** 5 A를 실제로 공급하지 못하면 켜지 마세요. 기본 설정에서 주석 처리해 두었습니다.
- **셀을 직접 납땜하지 마세요.** 보호회로(PCM)가 내장된 셀 또는 검증된 Pi용 UPS 모듈로 시작하는 것을 권합니다. `certification.md`의 "1:1 직접 땜질"은 합선 시 화재 위험이 있습니다.
- **연료 게이지가 있어야 잔량이 표시됩니다.** 셸은 `/sys/class/power_supply`에 배터리가 없으면 `--`로 표시하며, 값을 지어내지 않습니다. 렌더링의 78% 위젯을 쓰려면 리눅스 드라이버가 있는 I²C 게이지(예: MAX17048)와 기기 트리 설정이 필요합니다.
- **저전압 안전 종료:** 잔량 신호가 없으면 방전 시 전원이 그냥 끊어져 SD 카드가 손상될 수 있습니다.

런타임 추정: 케이스 바닥 면적에 7–8 mm 두께로 들어가는 셀은 약 3,000–4,000 mAh(11–15 Wh)입니다. 변환 손실과 소비전력(유휴 약 3–5 W, 부하 시 10 W 이상, 화면 별도)을 감안하면 **보통 사용 2–3시간, 부하 시 1시간 안팎**입니다.

## 발열

Pi 5는 부하가 걸리면 냉각이 필요합니다. Flirc 케이스는 알루미늄 몸체와 서멀 패드로 칩의 열을 빼내는 수동 냉각 구조입니다. 상판 위에 화면을 올리면 칩 접촉 경로는 남지만 윗면 방열이 막히고 패널이 함께 데워지므로, 측벽 방열을 보강하고 부하 테스트로 `vcgencmd measure_temp` 값을 확인해야 합니다. DSI 케이블은 몸체를 가공해 통과시켜야 합니다. Li-Po는 보통 충전 상한이 45 °C 부근이므로 SoC와 셀 사이에 단열층을 두세요.

## 무선

- **알루미늄 케이스는 Wi-Fi를 크게 약화시킵니다.** Pi 5의 내장 안테나는 기판 위에 있어 금속 안에 가두면 공간 인지 기능까지 함께 나빠집니다.
- **Pi 5에는 외장 안테나 커넥터가 없습니다.** 사양서의 SMA 안테나를 쓰려면 SMA 커넥터가 달린 USB Wi-Fi 어댑터가 필요하고, 이때 `/etc/cyborgroid/core.toml`의 `interface`를 해당 인터페이스(예: `wlan1`)로 바꿔야 합니다. 모니터 모드나 CSI는 쓰지 않으므로 일반 어댑터로 충분합니다.
- **셀룰러 모뎀이 없습니다.** Wi-Fi, 이더넷 또는 테더링이 없는 곳에서는 통신이 불가능합니다.

## 오디오: 사양서에 빠진 부품

전화가 핵심 기능인데 마이크와 스피커가 부품 목록에 없고, Pi 5에는 아날로그 오디오 출력도 없습니다. USB 오디오 동글, I²S 앰프·마이크 또는 블루투스 헤드셋 중 하나가 필요합니다. 이미지에는 PipeWire와 BlueZ가 들어 있어 USB와 블루투스 장치는 추가 설정 없이 인식될 것으로 예상하지만, 실기기에서 시험하지는 않았습니다.

## 제품으로 판매한다면

`certification.md`는 조립 가능성 검토이며 인증 문서가 아닙니다. 국내 판매에는 전파 적합성 평가(KC)와 리튬 배터리 안전 인증 등을 확인해야 합니다. 개인 제작이 아닌 판매를 계획한다면 시험 기관에 먼저 문의하세요.

## 참고 자료

- [Flirc Raspberry Pi 3B Case (제조사)](https://flirc.tv/raspberry-pi-case)
- [FLIRC Raspberry Pi 3 Case (The Pi Hut)](https://thepihut.com/products/flirc-raspberry-pi-3-b-case)
- [Flirc Aluminum Case for Raspberry Pi 5 (Adafruit)](https://www.adafruit.com/product/5847)
- [Waveshare 4inch DSI LCD 위키](https://waveshare.com/wiki/4inch_DSI_LCD)
- [Waveshare 4-DSI-TOUCH-A](https://www.waveshare.com/4-dsi-touch-a.htm)
- [Waveshare 3.5inch DSI LCD (E)](https://www.waveshare.com/3.5inch-dsi-lcd-e.htm)
- [Raspberry Pi Touch Display 2 문서](https://www.raspberrypi.com/documentation/accessories/touch-display-2.html)
- [USB Power Delivery on Raspberry Pi 5 백서](https://pip-assets.raspberrypi.com/categories/685-app-notes-guides-whitepapers/documents/RP-009856-WP-1-USB%20Power%20delivery%20on%20Raspberry%20Pi%205.pdf)
