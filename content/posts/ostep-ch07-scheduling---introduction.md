+++
date = '2025-12-20T10:00:00+09:00'
draft = false
title = '[OSTEP] Ch.07 - Scheduling - Introduction'
description = "OSTEP CPU 가상화 파트 - Scheduling - Introduction 정리 노트"
tags = ["OS", "OSTEP", "Virtualization"]
categories = ["OS"]
series = ["OSTEP 정리"]
+++
## Crux (핵심 문제)
> 어떤 기준으로 스케줄링 정책을 만들어야 하는가? 어떤 가정이 필요하고, 어떤 지표로 평가하는가? 가장 기본적인 스케줄링 알고리즘들의 trade-off는?

## 배경 & 동기

Ch.06에서 Context Switch 메커니즘을 배웠다. 이제 "다음에 어떤 프로세스를 실행할 것인가" — 스케줄링 **정책**을 다룬다. 스케줄링의 역사는 컴퓨터보다 오래됐다: 공장 조립 라인, 대기열 관리 등에서 이미 연구됐다.

## Mechanism (어떻게 동작하는가)

### 가정 (점진적으로 완화됨)

초기 가정 (나중에 하나씩 제거):
1. 모든 job은 같은 실행 시간을 가짐
2. 모든 job이 동시에 도착
3. 한번 시작하면 완료까지 실행 (non-preemptive)
4. 모든 job은 CPU만 사용 (I/O 없음)
5. 각 job의 실행 시간을 알 수 있음

### 스케줄링 지표

**Turnaround Time (반환 시간):**
```
T_turnaround = T_completion - T_arrival
```
성능 지표. 얼마나 빨리 job이 완료되는가.

**Response Time (응답 시간):**
```
T_response = T_firstrun - T_arrival
```
대화형 시스템에서 중요. 처음 실행될 때까지 얼마나 걸리는가.

**공평성(Fairness)**: 성능과 자주 충돌한다.

### 스케줄링 알고리즘들

#### FIFO (First In, First Out)
- 먼저 온 job을 먼저 실행
- **Convoy Effect**: 긴 job 뒤에 짧은 job들이 오래 기다리는 문제

```
A(100s) → B(10s) → C(10s)
평균 turnaround = (100 + 110 + 120) / 3 = 110초 → 나쁨
```

#### SJF (Shortest Job First)
- 짧은 job부터 실행 → Turnaround 최적화
- **단점**: 모든 job이 동시에 도착해야 optimal. 늦게 도착한 짧은 job은 긴 job을 기다려야 함

```
B(10s) → C(10s) → A(100s)
평균 turnaround = (10 + 20 + 120) / 3 = 50초 → 훨씬 좋음
```

#### STCF (Shortest Time-to-Completion First)
- SJF의 선점형(preemptive) 버전
- 새 job 도착 시 남은 시간이 가장 짧은 것부터 실행
- Turnaround 측면에서 optimal (주어진 가정 하에)

```
A 100초짜리 실행 중, t=10에 B, C(각 10초) 도착
→ B, C 먼저 실행 후 A 재개
평균 turnaround = (120-0 + 20-10 + 30-10) / 3 = 50초
```

#### Round Robin (RR)
- 각 job을 **time slice** 만큼만 실행하고 다음 job으로 교체
- Response time에 탁월하지만 Turnaround는 나쁨

```
A, B, C 각 5초, time slice = 1초
→ A B C A B C A B C A B C A B C
Response time: (0+1+2)/3 = 1초 (매우 좋음)
Turnaround: (13+14+15)/3 = 14초 (나쁨)
```

> [!important]
> **핵심 Trade-off:**
> - Turnaround 최적화 (SJF/STCF) ↔ Response time 최적화 (RR)
> - 공평(Fair) = Response time 좋음 ≠ Turnaround 좋음
> 케이크를 먹을 수도, 가질 수도 없다(You can't have your cake and eat it too).

### I/O 처리

I/O를 고려하면 스케줄러가 더 영리해진다:
- job이 I/O를 기다리는 동안 CPU를 다른 job에 넘김
- I/O가 완료되면 다시 Ready 상태로

```
A(I/O 포함) + B(CPU only):
나쁜 방식: A I/O 기다리는 동안 CPU 낭비
좋은 방식: A가 I/O 기다리는 동안 B 실행 → Overlap으로 CPU 활용도 ↑
```

## Policy (왜 이렇게 설계했는가)

| 알고리즘 | Turnaround | Response | 실용성 |
|---------|------------|----------|--------|
| FIFO    | 나쁨 (convoy) | 나쁨 | 단순 |
| SJF     | 좋음 | 나쁨 | 실행시간 알아야 함 |
| STCF    | 최적 | 나쁨 | 실행시간 알아야 함 |
| RR      | 나쁨 | 최적 | 현실적 |

**실용적 문제**: OS는 각 job의 실행 시간을 모른다. SJF/STCF는 이론적으로 좋지만 현실에서는 쓸 수 없다. → 이게 다음 챕터(MLFQ)의 동기.

## 내 정리
결국 이 챕터는 **스케줄링 정책의 기본 틀을 잡는다**. Turnaround와 Response time은 근본적으로 충돌한다. 짧은 job 먼저 실행하면 Turnaround 좋지만 긴 job이 굶주리고, 공평하게 돌리면 Response는 좋지만 Turnaround가 나빠진다. 그리고 가장 좋은 SJF/STCF는 현실에서 쓸 수 없다 — 미래를 모르니까. 이 딜레마를 해결하는 것이 MLFQ다.

## 연결
- 이전: Ch.06 - Mechanism - Limited Direct Execution
- 다음: Ch.08 - Scheduling - The Multi-Level Feedback Queue
- 관련 개념: Scheduling Policy, Context Switch, Process
