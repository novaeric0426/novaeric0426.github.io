+++
date = '2025-12-18T18:00:00+09:00'
draft = false
title = '[OSTEP 용어] Compare-and-Swap (CAS)'
description = "OSTEP 핵심 용어 정리 - Compare-and-Swap (CAS)"
tags = ["OS", "OSTEP", "OS 용어"]
categories = ["OS"]
series = ["OSTEP 정리"]
+++
## 정의
"현재 값이 내가 기대하는 값과 같을 때만 새 값으로 바꾼다"는 원자적 하드웨어 명령. x86에서는 `CMPXCHG` 명령어.

## 동작 원리

```c
// C로 표현한 의미론 (실제로는 하드웨어가 원자적으로 실행)
int CompareAndSwap(int *ptr, int expected, int new) {
    int actual = *ptr;
    if (actual == expected)
        *ptr = new;
    return actual;   // 이전 값 반환
}
```

**Lock 구현에 사용**:
```c
void lock(lock_t *lock) {
    while (CompareAndSwap(&lock->flag, 0, 1) == 1)
        ; // spin
}
```

**Test-And-Set보다 강력한 이유**: 기대값을 명시하므로, Lock-Free 자료구조에서 "누군가 먼저 바꿨나?"를 탐지할 수 있다.

## 왜 중요한가

CAS는 현대 동시성 알고리즘의 핵심:
- Lock-Free Stack, Queue 구현 가능
- Java의 `AtomicInteger.compareAndSet()`, C++의 `std::atomic::compare_exchange_strong()`
- 낙관적 동시성 제어(Optimistic Concurrency Control)의 기반

> ABA 문제: 값이 A→B→A로 바뀌었는데 CAS는 A만 보고 성공 처리 → 버전 태그(stamp)로 해결

## 관련
- 상위 개념: Atomic Operation
- 관련: Lock (Mutex), Spin Lock
- 등장 챕터: Ch.28 - Locks, Ch.32 - Common Concurrency Problems
