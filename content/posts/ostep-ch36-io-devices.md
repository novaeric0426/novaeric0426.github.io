+++
date = '2026-02-12T10:00:00+09:00'
draft = false
title = '[OSTEP] Ch.36 - I_O Devices'
description = "OSTEP 영속성 파트 - I_O Devices 정리 노트"
tags = ["OS", "OSTEP", "Persistence"]
categories = ["OS"]
series = ["OSTEP 정리"]
+++
## Crux (핵심 문제)
I/O 장치를 시스템에 어떻게 통합할 것인가? CPU를 낭비하지 않고 장치와 효율적으로 통신하는 방법은 무엇인가?

## 배경 & 동기

CPU와 메모리가 아무리 빨라도, I/O 없는 프로그램은 의미가 없다. 입력도 출력도 없으면 그냥 빠른 계산기에 불과하다. 그런데 문제는 **장치는 CPU에 비해 엄청나게 느리다**. 이 속도 차이를 어떻게 메우느냐가 이 챕터의 핵심이다.

## Mechanism (어떻게 동작하는가)

### 시스템 버스 계층

장치들은 빠른 것부터 순서대로 CPU에 가깝게 배치된다:

```
CPU ←→ Memory (가장 빠름, Memory Bus)
  ↓
GPU, NVMe (General I/O Bus, PCIe)
  ↓
Disk, Mouse, Keyboard (Peripheral Bus: SATA, USB)
```

왜 계층적인가? **물리적 이유**: 버스가 빠를수록 짧아야 하고, 비싸진다. 고성능 장치는 CPU 가까이, 저속 장치는 멀리.

### Canonical Device — 장치의 공통 구조

모든 장치는 두 부분으로 구성:
- **Interface (인터페이스)**: OS가 제어하는 레지스터 (Status, Command, Data)
- **Internals (내부)**: 마이크로컨트롤러, 메모리, 전용 칩 — OS는 몰라도 됨

```
┌─────────────────────────────────┐
│ Interface: [Status][Command][Data] │  ← OS가 읽고 쓰는 영역
├─────────────────────────────────┤
│ Internals: CPU, DRAM, 전용 칩    │  ← 장치가 자율적으로 처리
└─────────────────────────────────┘
```

### Canonical Protocol — 기본 통신 프로토콜

```c
while (STATUS == BUSY)
    ;  // 1. 장치가 비어있을 때까지 기다린다 (Polling)

Write data to DATA register    // 2. 데이터 전송
Write command to COMMAND register  // 3. 명령 전송

while (STATUS == BUSY)
    ;  // 4. 완료될 때까지 기다린다
```

문제: 1번과 4번에서 CPU가 **바쁜 대기(busy-waiting)** — 아무것도 안 하면서 루프만 돈다. CPU 낭비.

### Interrupt — Polling의 대안

Polling 대신 Interrupt를 쓰면 I/O와 연산을 **오버랩**할 수 있다:

```
[Polling 방식]
CPU:  P1─P1─P1─P1─P1─poll─poll─poll─poll─P1─P1
Disk:                  ←── 처리 중 ──────→

[Interrupt 방식]
CPU:  P1─P1─P1─P1─P1─P2─P2─P2─P2─P2─intr─P1─P1
Disk:                  ←── 처리 중 ──────→↑인터럽트
```

I/O 요청 → 프로세스 sleep → 다른 프로세스 실행 → 장치 완료 시 인터럽트 → OS 핸들러 → 원래 프로세스 깨움

> [!important]
> **Interrupt가 항상 좋은 건 아니다.** 장치가 매우 빠르면 (SSD, NVMe 등) 컨텍스트 스위치 오버헤드가 오히려 크다. 이럴 땐 Polling이 더 낫다. **두 방식을 섞은 Hybrid**: 처음엔 짧게 폴링 → 여전히 안 끝나면 Interrupt로 전환.

> [!important]
> **Livelock 문제**: 네트워크에서 패킷이 홍수처럼 쏟아지면 OS가 인터럽트만 처리하느라 정작 유저 프로세스가 못 돌아간다. 이런 경우 오히려 Polling이 흐름 제어에 유리.

### DMA — 데이터 이동의 CPU 해방

Programmed I/O(PIO): CPU가 직접 데이터를 장치 레지스터로 한 단어씩 복사 → CPU 낭비

**DMA(Direct Memory Access)**: 전용 DMA 컨트롤러에게 "이 메모리에서 저 장치로 이만큼 복사해"라고 지시만 하고 CPU는 딴 일 한다.

```
[PIO 방식]
CPU:  P1─c─c─c─P2─P2─P2─P2─P2─P1─P1
Disk:           ←── 처리 중 ──→

[DMA 방식]
CPU:  P1─P1─P1─P2─P2─P2─P2─P2─intr─P1
DMA:      ←c─c─c→
Disk:              ←── 처리 중 ──→
```

### 장치 통신 방법 2가지

| 방법 | 설명 |
|------|------|
| **Explicit I/O Instructions** | x86의 `in`/`out` 명령어. 특권 명령이라 OS만 실행 가능 |
| **Memory-mapped I/O** | 장치 레지스터를 메모리 주소처럼 접근. 별도 명령어 불필요 |

현재도 두 방식 모두 사용 중. 우열 없음.

### Device Driver — 장치 중립적 OS를 위한 추상화

다양한 장치(SCSI, SATA, USB...)마다 다른 프로토콜 → OS가 다 알면 OS 코드가 장치 종속적이 됨.

해결책: **Device Driver** — 장치별 세부사항을 캡슐화하는 소프트웨어 계층

```
Application
    ↓ POSIX API (open/read/write/close)
File System
    ↓ Generic Block Interface (블록 읽기/쓰기)
Generic Block Layer
    ↓ Device-specific Interface
Device Driver (SCSI, ATA, USB ...)
    ↓
실제 하드웨어
```

파일 시스템은 디스크가 SCSI인지 SATA인지 모른다. 그냥 블록 읽기/쓰기만 요청할 뿐.

> [!important]
> Linux 커널 코드의 **70% 이상이 Device Driver** 코드다. 드라이버는 주로 "아마추어"(전담 커널 개발자 아닌 장치 업체 엔지니어)가 짜기 때문에 버그도 훨씬 많다. OS 안정성의 주요 약점.

## Policy (왜 이렇게 설계했는가)

| 문제 | 해결책 | Trade-off |
|------|--------|-----------|
| CPU가 장치 기다리며 낭비 | Interrupt | 느린 장치엔 좋지만, 빠른 장치엔 오버헤드 |
| CPU가 데이터 복사에 낭비 | DMA | DMA 컨트롤러 추가 비용 |
| 장치마다 다른 인터페이스 | Device Driver | 드라이버 버그가 커널 버그가 됨 |
| 드라이버 버그로 커널 불안정 | 주소 공간 분리 (마이크로커널 방향) | 성능 저하 |

## 코드 & 실험

xv6 IDE 드라이버의 핵심 흐름:

```c
// 요청 큐에 추가하고 슬립
void ide_rw(struct buf *b) {
    acquire(&ide_lock);
    // ... 큐에 추가 ...
    if (ide_queue == b) ide_start_request(b);  // 큐가 비었으면 즉시 전송
    while ((b->flags & (B_VALID|B_DIRTY)) != B_VALID)
        sleep(b, &ide_lock);  // 완료까지 대기
    release(&ide_lock);
}

// 인터럽트 핸들러 — 완료 처리
void ide_intr() {
    acquire(&ide_lock);
    // READ면 데이터 읽기, 완료 플래그 설정
    wakeup(b);  // 자고 있던 프로세스 깨우기
    if (ide_queue = b->qnext)
        ide_start_request(ide_queue);  // 다음 요청 시작
    release(&ide_lock);
}
```

## 내 정리

결국 이 챕터는 **"장치는 느리다"는 현실** 때문에 생기는 문제들을 해결한다.
- CPU가 기다리는 낭비 → **Interrupt**로 오버랩
- CPU가 데이터 나르는 낭비 → **DMA**로 위임
- 장치마다 다른 인터페이스 → **Device Driver** 추상화

세 해결책 모두 같은 원칙: **"CPU를 잡아두지 마라, 더 중요한 일 하게 놔둬라"**

## 연결
- 이전: Ch.33 - Event-based Concurrency
- 다음: Ch.37 - Hard Disk Drives
- 관련 개념: Device Driver, DMA, Interrupt
