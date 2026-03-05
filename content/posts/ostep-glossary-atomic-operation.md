+++
date = '2025-12-13T18:00:00+09:00'
draft = false
title = '[OSTEP 용어] Atomic Operation'
description = "OSTEP 핵심 용어 정리 - Atomic Operation"
tags = ["OS", "OSTEP", "OS 용어"]
categories = ["OS"]
series = ["OSTEP 정리"]
+++
## 정의
중간에 인터럽트나 다른 스레드의 개입 없이 **불가분적으로(all-or-nothing)** 실행되는 연산. 실행 도중 관찰 가능한 중간 상태가 없다.

## 동작 원리

일반 연산(`counter++`)은 여러 CPU 명령으로 이루어져 있어 중간에 끊길 수 있다. 원자 연산은 하드웨어가 단일 명령으로 보장한다:

| 원자 연산 | 설명 |
|-----------|------|
| Test-And-Set | 읽기 + 쓰기 원자적으로 |
| Compare-and-Swap (CAS) | 기대값 일치 시에만 쓰기 |
| Fetch-And-Add | 읽기 + 증가 원자적으로 |
| Load-Linked / Store-Conditional | 조건부 쓰기 (RISC 계열) |

```c
// CAS 예시 — x86: LOCK CMPXCHG 명령
int CompareAndSwap(int *ptr, int expected, int new) {
    int actual = *ptr;
    if (actual == expected) *ptr = new;
    return actual;
}
```

## 왜 중요한가

원자 연산이 없으면 Lock (Mutex)을 만들 수 없다. Lock 자체가 "락 변수를 원자적으로 체크하고 설정"하는 것이기 때문.

또한 Lock-Free 자료구조(CAS 기반 큐 등)의 기반이 된다.

## 관련
- 관련: Lock (Mutex), Spin Lock, Compare-and-Swap (CAS), Race Condition, Critical Section
- 등장 챕터: Ch.26 - Concurrency - An Introduction, Ch.28 - Locks
