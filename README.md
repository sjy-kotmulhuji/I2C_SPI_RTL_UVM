# SPI & I2C 통신 프로토콜 설계 및 UVM 검증

> SystemVerilog | UVM | Basys3 (Artix-7) | Vivado 2023.1  
> SPI / I2C Master·Slave RTL 설계, UVM 검증 환경 구축, FPGA 보드 동작 확인

---

## 📌 프로젝트 개요

SPI와 I2C 통신 프로토콜의 Master / Slave 모듈을 FSM 기반으로 설계하고, UVM 검증 환경을 구축하여 동작을 검증한 프로젝트입니다.  
최종적으로 두 프로토콜 모두 FPGA 두 보드 간 실제 동작을 확인했습니다.

| 항목 | 내용 |
|------|------|
| **프로토콜** | SPI, I2C |
| **설계 언어** | SystemVerilog |
| **검증 방법** | UVM (Universal Verification Methodology) |
| **툴** | Vivado 2023.1, VCS |
| **보드** | Basys3 (Xilinx Artix-7) × 2 |

---

## 📡 SPI (Serial Peripheral Interface)

### 개요

| 항목 | 내용 |
|------|------|
| **토폴로지** | 1 : N |
| **통신 방식** | Full-Duplex (동시 송수신 가능) |

### 신호선

| 신호 | 방향 | 설명 |
|------|------|------|
| SCLK | Master → Slave | Master가 생성하는 공유 클럭 |
| MOSI | Master → Slave | Master Out Slave In — Master → Slave 데이터 전송 |
| MISO | Slave → Master | Master In Slave Out — Slave → Master 데이터 전송 |
| SS | Master → Slave | Slave Select — 통신 대상 Slave 선택 |

### 동작 모드 (CPOL / CPHA)

| 모드 | CPOL | CPHA | 설명 |
|------|------|------|------|
| Mode 0 | 0 | 0 | IDLE Low, 첫 번째 엣지에서 샘플링 |
| Mode 1 | 0 | 1 | IDLE Low, 두 번째 엣지에서 샘플링 |
| Mode 2 | 1 | 0 | IDLE High, 첫 번째 엣지에서 샘플링 |
| Mode 3 | 1 | 1 | IDLE High, 두 번째 엣지에서 샘플링 |

- **CPOL (Clock Polarity)**: Low → IDLE 상태가 Low / High → IDLE 상태가 High
- **CPHA (Clock Phase)**: Low → 첫 번째 엣지에서 샘플링 / High → 두 번째 엣지에서 샘플링

---

### SPI Master FSM

| 상태 | 설명 |
|------|------|
| `IDLE` | 동작 전 기본 상태 |
| `START` | 통신 시작 상태 |
| `DATA` | 데이터 통신 상태 |
| `STOP` | 통신 종료 상태 |

---

### ✅ SPI UVM 검증

**검증 시나리오**

| 시나리오 | 내용 |
|----------|------|
| MOSI 동작 검증 | `m_tx_data` → `s_rx_data` 정상 전달 확인 |
| MISO 동작 검증 | `s_tx_data` → `m_rx_data` 정상 전달 확인 |

**검증 결과**
- Scoreboard 비교 통과: `m_tx_data ↔ s_rx_data`, `s_tx_data ↔ m_rx_data` 모두 일치
- Coverage 100% 달성 (Coverpoint: `m_tx_data`, `s_rx_data`, `s_tx_data`, `m_rx_data`)

### FPGA 동작 시연

- 좌: Slave 보드 / 우: Master 보드
- **Write**: Master의 8bit switch 값 → Slave가 수신 → FND에 표시
- **Read**: Slave의 8bit switch 값 → Master가 수신 → FND에 표시

---

## 🔗 I2C (Inter-Integrated Circuit)

### 개요

| 항목 | 내용 |
|------|------|
| **토폴로지** | N : N |
| **통신 방식** | Half-Duplex (동시 송수신 불가) |
| **구동 방식** | 오픈 드레인 + 외부 Pull-up 저항 |
| **용도** | 주로 저속 데이터 전송 |

모든 디바이스가 SCL, SDA 두 선에 공통 연결됩니다.

### 신호선

| 신호 | 방향 | 설명 |
|------|------|------|
| SCL | Master → Slave | Master가 생성하는 공유 클럭 |
| SDA | Master ↔ Slave | 양방향 데이터 전송 |

### 동작 순서 (Master 기준)

```
START
  → 7bit Slave 주소 + 1bit R/W 신호 전송
  → 해당 Slave로부터 ACK 수신
  → 8bit Data 송수신
  → ACK / NACK 신호 송수신
STOP
```

---

### I2C Master FSM

| 상태 | 설명 |
|------|------|
| `IDLE` | 동작 전 기본 상태 |
| `START` | 통신 시작 동작 |
| `WAIT_CMD` | Host 커맨드에 따라 다음 상태 결정 |
| `DATA` | 데이터 송수신 상태 |
| `DATA_ACK` | ACK/NACK 응답 송수신 상태 |
| `STOP` | 통신 종료 상태 |

### I2C Slave FSM

| 상태 | 설명 |
|------|------|
| `IDLE` | 동작 전 기본 상태 |
| `ADDR_RW` | Master가 보낸 주소값 + R/W 신호 수신 |
| `ADDR_ACK` | 해당 주소의 Slave가 ACK 응답 |
| `DATA` | 데이터 송수신 상태 |
| `DATA_ACK` | ACK 응답 상태 |

---

### ✅ I2C UVM 검증

**검증 시나리오**

| 시나리오 | 내용 |
|----------|------|
| Write 검증 | `m_tx_data` → `s_rx_data` 정상 전달 확인 |
| Read 검증 | `s_tx_data` → `m_rx_data` 정상 전달 확인 |

**검증 결과**
- Waveform 상 Write / Read 동작 모두 정상 확인
- Scoreboard Log: UVM 타이밍 오류로 인해 Fail 발생 → 파형은 정상이나 Scoreboard 비교 타이밍 불일치로 추정

### FPGA 동작 시연

- 좌: Slave 보드 / 우: Master 보드
- **Write**: Master의 switch 8개 (`sw[8:1]`) 데이터 → Slave가 수신 → LED 8개에 표시

---

## 🐛 Trouble Shooting

### 1. I2C Slave — FSM 동기화 클럭 오류

**문제**  
Slave FSM을 system clock 대신 SCL에 동기화시키려고 했음

**문제점**
- SCL은 Master가 생성한 클럭 → 글리치, 셋업/홀드 타임 문제 발생 가능
- Start/Stop 동작 감지 불가: Start/Stop은 SCL이 유지되는 동안 SDA 엣지로 감지해야 하는데, SCL 엣지에만 동작하면 이를 감지할 수 없음

**해결**  
system clock에 동기화하고, SCL과 SDA에 **Edge Detector**를 별도 설계하여 엣지/동작 감지

---

### 2. I2C Slave — Data 마지막 bit 통신 오류

**문제**  
Write 동작에서 마지막 8번째 bit 데이터를 수신하지 못하는 현상

**원인**  
`ADDR_RW` 상태에서 Write 동작 시 SCL 하강 엣지에서 `bit_cnt`를 증가시키도록 설계했으나,  
SCL이 IDLE 상태에서 High로 시작하므로 `ADDR_RW` 진입 시 즉시 하강 엣지가 감지되어 `bit_cnt`가 1 선행 증가

**해결**  
`bit_cnt` 증가 트리거를 SCL 하강 엣지 → **SCL 상승 엣지**로 변경

---

## 💬 느낀 점

- SPI, I2C, AXI 세 가지 통신 프로토콜을 직접 설계하면서 클럭 오차 없이 정확한 타이밍을 설계하는 것이 얼마나 중요한지 체감함
- UVM 설계 시 RTL 동작 타이밍과 UVM 환경의 타이밍이 어긋나 문제가 발생하는 경우가 많아, 검증 환경에서의 타이밍 이해의 중요성을 깨달음
