+++
date = '2026-01-15T18:00:00+09:00'
draft = false
title = '[OSTEP 용어] Lock (Mutex)'
description = "OSTEP 핵심 용어 정리 - Lock (Mutex)"
tags = ["OS", "OSTEP", "OS 용어"]
categories = ["OS"]
series = ["OSTEP 정리"]
+++
## 정의
Critical Section에 한 번에 하나의 스레드만 진입하도록 보장하는 동기화 원시 타입. Mutex는 Mutual Exclusion의 약자.

## 동작 원리

Lock은 두 가지 상태만 가진다: **available(해제됨)** / **held(보유됨)**

```c
pthread_mutex_t lock = PTHREAD_MUTEX_INITIALIZER;

pthread_mutex_lock(&lock);   // 잠금: 다른 스레드 진입 차단
// critical section
pthread_mutex_unlock(&lock); // 해제: 대기 스레드 중 하나 깨움
```

내부 구현은 하드웨어 원자 명령 위에 쌓인다:
- **Test-And-Set**: 가장 단순한 Spin Lock
- **Compare-And-Swap**: 더 범용적인 원자 연산
- **futex** (Linux): 경합 없으면 userspace에서, 있으면 커널로

## 왜 중요한가

Lock 없이는 Race Condition이 발생한다. 하지만 Lock도 올바르게 쓰지 않으면:
- **Deadlock**: 서로 다른 락을 역순으로 잡을 때
- **Starvation**: Spin Lock에서 특정 스레드가 영원히 못 잡을 때
- **성능 저하**: 불필요하게 큰 Critical Section

**평가 기준**:
1. Correctness (Mutual Exclusion 보장)
2. Fairness (Starvation 없음)
3. Performance (오버헤드 낮음)

## 관련
- 구현: Spin Lock, Compare-and-Swap (CAS), Atomic Operation
- 관련: Critical Section, Race Condition, Deadlock, Semaphore, Condition Variable
- 등장 챕터: Ch.28 - Locks, Ch.27 - Interlude - Thread API, Ch.29 - Lock-based Concurrent Data Structures
