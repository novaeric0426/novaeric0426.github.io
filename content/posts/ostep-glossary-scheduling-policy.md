+++
date = '2026-02-03T18:00:00+09:00'
draft = false
title = '[OSTEP 용어] Scheduling Policy'
description = "OSTEP 핵심 용어 정리 - Scheduling Policy"
tags = ["OS", "OSTEP", "OS 용어"]
categories = ["OS"]
series = ["OSTEP 정리"]
+++
## 정의
여러 프로세스가 CPU를 쓰려 할 때 "다음에 어떤 프로세스를 실행할 것인가"를 결정하는 알고리즘. Mechanism(Context Switch)과 분리된 고수준 결정.

## 동작 원리

**평가 지표:**

| 지표 | 정의 | 중요한 상황 |
|------|------|------------|
| Turnaround Time | 완료 - 도착 시간 | Batch 작업 |
| Response Time | 첫 실행 - 도착 시간 | Interactive 작업 |
| Fairness | 모든 job이 공평하게 CPU를 받는지 | 다중 사용자 |
| Throughput | 단위 시간당 완료된 job 수 | 서버 환경 |

**주요 알고리즘 비교:**

| 알고리즘 | Turnaround | Response | 단점 |
|---------|------------|----------|------|
| FIFO | 나쁨 (convoy) | 나쁨 | 짧은 job이 긴 job 뒤에 막힘 |
| SJF | 좋음 | 나쁨 | 실행시간 알아야 함, non-preemptive |
| STCF | 최적 | 나쁨 | 실행시간 알아야 함 |
| RR | 나쁨 | 최적 | Turnaround 희생 |
| MLFQ | 좋음 | 좋음 | 복잡, voo-doo constants |
| Lottery | 비율 보장 | 확률적 | 단기 부정확 |
| Stride | 비율 보장 | 결정론적 | 새 job 추가 시 pass 초기화 문제 |

**핵심 Trade-off:**
- Turnaround 최적화 → 짧은 job 우선 (SJF 계열) → 긴 job 불공평
- Response 최적화 → 공평하게 돌아가며 실행 (RR) → Turnaround 나빠짐

## 왜 중요한가
스케줄링 정책이 없으면 OS는 자원을 낭비하거나, 특정 프로세스가 CPU를 독점하거나, 사용자 경험이 나빠진다. 어떤 목표(성능 vs 공평성 vs 응답성)를 우선시하느냐에 따라 최적 정책이 달라진다.

## 관련
- 구현 메커니즘: Context Switch
- 관련 개념: Time Sharing, Process
- 등장 챕터: Ch.07 - Scheduling - Introduction, Ch.08 - Scheduling - The Multi-Level Feedback Queue, Ch.09 - Scheduling - Proportional Share, Ch.10 - Multiprocessor Scheduling
