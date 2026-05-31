# SPI / I2C 통신 프로토콜 설계 및 UVM 검증

> SPI, I2C 통신 프로토콜 Master/Slave 모듈 설계 및 UVM 기반 기능 검증 (SystemVerilog)

---

## 📌 프로젝트 개요

- SPI, I2C 통신 프로토콜의 **Master / Slave 모듈** RTL 설계
- **UVM** 환경 구축을 통한 각 프로토콜 동작 기능 검증
- FPGA 보드에 연결해 실제 동작 확인

---

## 🛠️ 개발 환경

- Language: SystemVerilog
- Tool: Vivado (Simulation), VCS
- Verification: UVM (Universal Verification Methodology)

---

## 📡 SPI (Serial Peripheral Interface)

### 개요

| 항목 | 내용 |
|------|------|
| 연결 구조 | 1 : N |
| 통신 방식 | Full-Duplex (동시 송수신 가능) |

### 신호선

| 신호 | 방향 | 설명 |
|------|------|------|
| `SCLK` | Master → Slave | Master가 생성하는 클락, Slave와 공유 |
| `MOSI` | Master → Slave | Master Out Slave In — Master가 Slave에 데이터 전송 |
| `MISO` | Slave → Master | Slave Out Master In — Slave가 Master에 데이터 전송 |
| `SS` | Master → Slave | Slave Select — 통신할 Slave 선택 신호 |

### 동작 모드 (CPOL / CPHA)

| 모드 | CPOL | CPHA | IDLE 상태 | 샘플링 엣지 |
|------|:----:|:----:|----------|-----------|
| Mode 0 | 0 | 0 | Low | 첫 번째 엣지 |
| Mode 1 | 0 | 1 | Low | 두 번째 엣지 |
| Mode 2 | 1 | 0 | High | 첫 번째 엣지 |
| Mode 3 | 1 | 1 | High | 두 번째 엣지 |

- **CPOL** : Clock Polarity — IDLE 상태의 클락 레벨
- **CPHA** : Clock Phase — 데이터 샘플링 엣지 선택

### Master FSM

| 상태 | 설명 |
|------|------|
| `IDLE` | 동작 전 기본 상태 |
| `START` | 통신 시작 상태 |
| `DATA` | 데이터 통신이 이루어지는 상태 |
| `STOP` | 통신을 끝내는 단계 |

### UVM 검증

**검증 시나리오**

| 시나리오 | 내용 |
|---------|------|
| MOSI 동작 검증 | Master의 `tx_data`가 Slave의 `rx_data`로 정상 전송되는지 확인 |
| MISO 동작 검증 | Slave의 `tx_data`가 Master의 `rx_data`로 정상 전송되는지 확인 |

**Coverage**

| Coverpoint | 항목 |
|-----------|------|
| `m_tx_data` | Master 송신 데이터 |
| `s_rx_data` | Slave 수신 데이터 |
| `s_tx_data` | Slave 송신 데이터 |
| `m_rx_data` | Master 수신 데이터 |

### FPGA 동작 시연

- **구성** : 좌측 Slave 보드 / 우측 Master 보드
- **Write** : Master의 8bit 스위치 값을 Slave가 받아 FND에 표현
- **Read** : Slave의 8bit 스위치 값을 Master가 받아 FND에 표현

---

## 🔗 I2C (Inter-Integrated Circuit)

### 개요

| 항목 | 내용 |
|------|------|
| 연결 구조 | N : N |
| 통신 방식 | Half-Duplex (동시 송수신 불가) |
| 신호선 구동 | 오픈 드레인 방식 + 외부 Pull-up 저항 |
| 주 용도 | 저속 데이터 전송 |

### 신호선

| 신호 | 방향 | 설명 |
|------|------|------|
| `SCL` | Master → Slave | Master가 생성하는 클락, 모든 디바이스와 공유 |
| `SDA` | Master ↔ Slave | Master/Slave 간 양방향 데이터 전송 |

### 동작 흐름 (Master 기준)

```
START
  → 7bit Slave 주소 + 1bit R/W 신호 전송 (SDA)
  → 해당 Slave로부터 ACK 수신
  → 8bit Data 송수신 (SDA)
  → ACK / NACK 송수신
STOP
```

### Master FSM

| 상태 | 설명 |
|------|------|
| `IDLE` | 동작 전 기본 상태 |
| `START` | 통신 시작 동작 |
| `WAIT_CMD` | Host의 커맨드 신호에 따라 다음 상태 결정 |
| `DATA` | 데이터 통신이 이루어지는 상태 |
| `DATA_ACK` | 데이터 통신에 대한 ACK 응답 송수신 |
| `STOP` | 통신을 끝내는 단계 |

### Slave FSM

| 상태 | 설명 |
|------|------|
| `IDLE` | 동작 전 기본 상태 |
| `ADDR_RW` | Master가 Slave 주소 + R/W 신호를 전송하는 상태 |
| `ADDR_ACK` | 해당 주소의 Slave가 ACK 응답하는 상태 |
| `DATA` | 데이터 통신이 이루어지는 상태 |
| `DATA_ACK` | 통신에 대한 ACK 응답 상태 |

### UVM 검증

**검증 시나리오**

| 시나리오 | 내용 |
|---------|------|
| Write 검증 | Master의 `tx_data`가 Slave의 `rx_data`로 정상 전송되는지 확인 |
| Read 검증 | Slave의 `tx_data`가 Master의 `rx_data`로 정상 전송되는지 확인 |

> ⚠️ 파형 상으로는 Read/Write 동작 모두 정상이나, UVM Log에서 Fail 발생
> 원인: UVM Monitor의 타이밍 오류로 추정

### FPGA 동작 시연

- **구성** : 좌측 Slave 보드 / 우측 Master 보드
- **Write** : Master의 스위치 8개(`sw[8:1]`) 값을 Slave가 받아 LED 8개에 표현

---

## 🐛 Trouble Shooting

### 1. I2C Slave FSM 동기화 클락 오류

**문제**
Slave FSM을 system clk 대신 SCL에 동기화하려 했으나 정상 동작 안 됨

**원인**
- SCL은 Master가 생성하는 클락이므로 글리치, 셋업/홀드 타임 문제 발생 가능
- Start/Stop 동작은 SCL이 유지되는 동안 SDA 엣지가 발생하는데, SCL에 동기화하면 이를 감지 불가

**해결**
system clk에 동기화하고, SCL과 SDA에 대한 **Edge Detector**를 설계해 엣지 및 동작 감지

---

### 2. I2C Data 마지막 비트 통신 오류

**문제**
Write 동작에서 마지막 8번째 비트 데이터를 수신하지 못하는 상황

**원인**
- `ADDR_RW` 상태에서 Write 동작 시 SCL 하강 엣지에서 `bit_cnt` 증가하도록 구현
- SCL이 IDLE 상태에서 High로 시작하므로 `ADDR_RW` 진입 시 하강 엣지를 먼저 인식해 `bit_cnt`가 1 증가

**해결**
SCL **상승 엣지**에서 `bit_cnt` 증가하도록 수정
