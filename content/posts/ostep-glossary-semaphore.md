+++
date = '2026-02-07T18:00:00+09:00'
draft = false
title = '[OSTEP 용어] Semaphore'
description = "OSTEP 핵심 용어 정리 - Semaphore"
tags = ["OS", "OSTEP", "OS 용어"]
categories = ["OS"]
series = ["OSTEP 정리"]
+++
## 정의
Dijkstra가 설계한 동기화 원시 타입. 정수 값을 가지며, `wait()`와 `post()` 두 연산만으로 Lock (Mutex)과 Condition Variable 역할을 모두 수행할 수 있다.

## 동작 원리

```c
sem_t s;
sem_init(&s, 0, N);  // 초깃값 N으로 초기화

// wait (P, down, probeer)
sem_wait(&s):
    s.value -= 1
    if s.value < 0: sleep  // 음수면 대기 큐로

// post (V, up, verhoog)
sem_post(&s):
    s.value += 1
    if waiting: wake one   // 대기자 깨우기
```

| 초깃값 | 역할 | 용도 |
|--------|------|------|
| 1 | Binary Semaphore | Lock (Mutual Exclusion) |
| 0 | Ordering | 이벤트 순서 동기화 (join 패턴) |
| N | Counting Semaphore | N개 리소스 동시 허용 |

**음수 값의 의미**: `|s.value|` = 현재 대기 중인 스레드 수

## 왜 중요한가

단일 원시 타입으로 락과 조건 동기화를 모두 표현 가능. 특히 "개수 제한"이 있는 자원 관리(Connection Pool, Rate Limiter)에 세마포어가 자연스럽다.

Producer-Consumer에서:
- `empty = N`: 빈 슬롯 수
- `full = 0`: 채워진 슬롯 수

> [!important]
> Producer-Consumer에서 `mutex`와 `empty`/`full`의 wait 순서가 중요하다. mutex를 먼저 잡고 empty/full을 기다리면 **Deadlock**!

## 관련
- 유사: Lock (Mutex), Condition Variable
- 등장 챕터: Ch.31 - Semaphores
