+++
date = '2026-02-26T18:00:00+09:00'
draft = false
title = '[OSTEP 용어] Time Sharing'
description = "OSTEP 핵심 용어 정리 - Time Sharing"
tags = ["OS", "OSTEP", "OS 용어"]
categories = ["OS"]
series = ["OSTEP 정리"]
+++
## 정의
하나의 자원(주로 CPU)을 여러 프로세스가 **시간적으로 번갈아 사용**하게 하는 기법. 각 프로세스는 짧은 시간 동안 CPU를 독점하고, 빠르게 교대하기 때문에 동시에 실행되는 것처럼 보인다.

## 동작 원리

```
시간 축:
[Process A] [Process B] [Process A] [Process C] [Process B] ...
   ──────────────────────────────────────────────────────────→ 시간
```

- **Time Slice (Quantum)**: 한 프로세스에게 주어지는 최대 실행 시간
  - 너무 짧으면: Context Switch 오버헤드가 커짐
  - 너무 길면: Response Time 나빠짐 (다음 차례까지 오래 기다림)

**Time Sharing을 가능하게 하는 것:**
1. 타이머 인터럽트 (주기적으로 OS로 제어 반환)
2. Context Switch (프로세스 교체)
3. Scheduling Policy (어떤 프로세스를 선택할지)

**Space Sharing과 비교:**
- Time Sharing: CPU를 시간적으로 나눔
- Space Sharing: 메모리를 공간적으로 나눔 (각 프로세스 Address Space)

## 왜 중요한가
Time Sharing이 없으면 한 번에 하나의 프로그램만 실행 가능하다. 멀티태스킹, 서버에서 다수 사용자 동시 접속, 배경 작업 실행 — 이 모든 것이 Time Sharing 덕분에 가능하다.

> 비용: 단일 프로세스의 실제 처리 속도는 낮아진다. CPU를 독점하면 더 빠르지만, Time Sharing이 없으면 상호 운용이 불가능하다.

## 관련
- 구현 메커니즘: Context Switch, Scheduling Policy
- 관련 개념: Process
- 등장 챕터: Ch.02 - Introduction to Operating Systems, Ch.04 - The Abstraction - The Process
