# 하드웨어

기준은 `design/Raspberry_Desktop_After.png`입니다. 이 문서는 그 디자인을 실제 부품과 대조한 결과와, 결정이 남은 부분을 적습니다.

## After 디자인

Before(`design/Raspberry_Desktop_Before.png`)는 실제 판매 제품인 **Flirc Raspberry Pi 3 Case(실버)** 입니다. After는 이 케이스의 윗면 전체를 터치 화면으로 바꾼 생성 이미지입니다(오른쪽 아래에 생성 이미지 표식이 있고 화면 글자가 거울처럼 뒤집혀 있습니다).

| 부분 | After의 모습 | 실제 부품과의 관계 |
|---|---|---|
| 몸체 | Before와 같은 높이의 은색 금속 | Flirc Pi 3 케이스 그대로 |
| 옆면 단자 | 작은 전원 단자, 풀사이즈 HDMI, 3.5mm 잭 | **Raspberry Pi 3 배치.** Pi 5는 USB-C와 micro-HDMI 2개이고 잭이 없습니다 |
| 뒷면 단자 | 랜 포트, USB 4개 | Pi 3 배치. Pi 5도 같은 종류지만 위치가 다릅니다 |
| 윗면 | 테두리가 거의 없는 세로 화면, 비율 약 2:3 | 케이스 윗면에 맞는 기성 패널은 찾지 못했습니다 |
| 화면 내 지문 인식 | 하단 지문 아이콘 | 센서가 없습니다. 아이콘은 그대로 두고 누르면 화면을 잠급니다 |
| 배터리 78% | 첫 줄 오른쪽 위젯 | 잔량 측정 부품이 있어야 실제 값이 나옵니다. 없으면 `--` |

몸체 높이가 Before와 같으므로 **내장 배터리 공간이 없습니다.** After 그대로라면 전원은 외부에서 넣어야 합니다.

## 결정이 필요한 것: 기판

After의 단자는 Pi 3 것이고, 호환성은 메모리가 큰 Pi 5 쪽이 좋습니다. 둘을 동시에 만족하는 기성 조합은 없습니다.

| 선택 | 겉모습 | 호환성과 성능 | 비용과 난이도 |
|---|---|---|---|
| Pi 3B+ + Flirc Pi 3 케이스 | 단자까지 After와 동일 | 메모리 1GB. 일반 Ubuntu 화면은 시험에서 약 2.2GB를 사용하므로 표준 GNOME은 무리입니다. 공식 Pi Desktop 이미지도 쓰기 어렵고 가벼운 구성으로 바꿔야 합니다 | 저렴 |
| **Pi 5 + 맞춤 케이스 (권장)** | 내부 변환 케이블로 After처럼 제작 | 표준 GNOME을 그대로 사용 | 케이스 제작 필요 |

호환성이 프로젝트의 핵심이므로 Pi 5를 권합니다. 현재 소프트웨어와 시험은 Pi 5용 공식 이미지를 기준으로 합니다.

## 화면

| 후보 | 크기 | 비고 |
|---|---|---|
| Waveshare 3.5inch DSI LCD (E), 640×480 | 도면 확인 필요 | 비율 3:4로 After(2:3)에 가장 가깝습니다. 제조사 전용 오버레이가 필요하며 Ubuntu 절차는 제조사 문서에 없습니다 |
| Waveshare 4inch DSI LCD, 480×800 | 104.37 × 65.44 mm, 화면 87 × 52.44 mm | 드라이버가 Ubuntu에 들어 있고 전원도 케이블 하나로 공급됩니다. 케이스보다 약 10 mm 깁니다 |
| 공식 5인치 Touch Display 2, 720×1280 | 91.5 × 143.5 mm | 국내 구매, 자동 인식. After보다 훨씬 커서 그 모습이 나오지 않습니다 |

홈 화면은 화면 폭을 기준으로 비례해서 배치됩니다.

## 알아 둘 점

- **발열:** Pi 5는 부하가 걸리면 냉각이 필요합니다. 윗면이 화면이면 금속 몸체의 방열 경로가 줄어들어, 부하 시험으로 확인해야 합니다.
- **Wi-Fi:** 금속 케이스는 내장 안테나 신호를 약하게 만듭니다. Pi 5에는 외장 안테나 단자가 없어 필요하면 USB Wi-Fi를 씁니다.
- **셀룰러 모뎀:** 없습니다. Wi-Fi, 이더넷, 휴대폰 테더링이 없는 곳에서는 통신이 안 됩니다.
- **오디오:** Pi 5에는 이어폰 잭, 마이크, 스피커가 없습니다. USB 오디오나 블루투스 헤드셋이 필요합니다.
- **전원:** Pi 5는 5 V 5 A(25 W)를 권장합니다. 부족하면 USB 전류가 600 mA로 제한됩니다.
- **내장 배터리:** 리튬 셀 직접 납땜은 합선 시 화재 위험이 있습니다. 넣는다면 보호회로와 승압 회로가 갖춰진 검증된 모듈을 쓰세요.
- **상표:** FLIRC 각인, Ubuntu 로고, Chrome과 닮은 브라우저 아이콘은 개인 사용은 괜찮지만, 판매하거나 공개할 제품이라면 확인이 필요합니다.
- **판매:** `certification.md`는 조립 가능성 검토이며 인증 문서가 아닙니다. 국내 판매에는 전파 적합성 평가(KC)와 배터리 안전 인증 등을 확인해야 합니다.

## 참고 자료

- [Flirc Raspberry Pi 3B Case (제조사)](https://flirc.tv/raspberry-pi-case)
- [Waveshare 3.5inch DSI LCD (E)](https://www.waveshare.com/3.5inch-dsi-lcd-e.htm)
- [Waveshare 4inch DSI LCD](https://www.waveshare.com/4inch-dsi-lcd.htm)
- [공식 5인치 터치 디스플레이 2 (디바이스마트)](https://www.devicemart.co.kr/goods/view?no=15907263)
- [Raspberry Pi Touch Display 2 문서](https://www.raspberrypi.com/documentation/accessories/touch-display-2.html)
- [USB Power Delivery on Raspberry Pi 5 백서](https://pip-assets.raspberrypi.com/categories/685-app-notes-guides-whitepapers/documents/RP-009856-WP-1-USB%20Power%20delivery%20on%20Raspberry%20Pi%205.pdf)
