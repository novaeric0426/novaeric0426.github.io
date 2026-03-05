+++
date = '2026-01-31T18:00:00+09:00'
draft = false
title = '[OSTEP 용어] Race Condition'
description = "OSTEP 핵심 용어 정리 - Race Condition"
tags = ["OS", "OSTEP", "OS 용어"]
categories = ["OS"]
series = ["OSTEP 정리"]
+++
## 정의
여러 스레드가 공유 자원에 동시에 접근할 때, 실행 순서에 따라 결과가 달라지는 비결정적 상황. "타이밍에 따라 결과가 바뀐다"면 Race Condition이다.

## 동작 원리

`counter++`는 어셈블리에서 3개 명령이다:
```
mov [counter], %eax   # 메모리 → 레지스터 (load)
add $1, %eax          # 증가
mov %eax, [counter]   # 레지스터 → 메모리 (store)
```

인터럽트가 `add`와 `store` 사이에 끼어들면:
- Thread 1: load(50) → add(51) → [인터럽트]
- Thread 2: load(50) → add(51) → store(51)
- Thread 1 재개: store(51) ← 이미 51인데 또 51 저장

결과: 두 번 증가했는데 50→51 (52가 되어야 함).

## 왜 중요한가

Race Condition은:
- 재현이 극히 어렵다 (타이밍 의존)
- 수천 번 실행 중 한 번만 터질 수 있음
- Assertion으로 잡기도 어려움

→ **예방**이 최선. Critical Section을 Lock (Mutex)으로 보호.

## 관련
- 해결책: Lock (Mutex), Atomic Operation, Semaphore
- 관련: Critical Section, Deadlock, Thread
- 등장 챕터: Ch.26 - Concurrency - An Introduction
