+++
date = '2026-02-12T18:00:00+09:00'
draft = false
title = '[OSTEP 용어] Spin Lock'
description = "OSTEP 핵심 용어 정리 - Spin Lock"
tags = ["OS", "OSTEP", "OS 용어"]
categories = ["OS"]
series = ["OSTEP 정리"]
+++
## 정의
Lock을 얻을 때까지 CPU를 점유하며 바쁘게 루프를 돌며 기다리는 가장 단순한 Lock 구현체.

## 동작 원리

```c
// Test-And-Set 기반 Spin Lock
void lock(lock_t *lock) {
    while (TestAndSet(&lock->flag, 1) == 1)
        ; // spin — 계속 확인
}
void unlock(lock_t *lock) {
    lock->flag = 0;
}
```

`TestAndSet`이 원자적으로 "현재 값 읽기 + 새 값 쓰기"를 수행하기 때문에, 동시에 두 스레드가 Lock을 잡는 것이 불가능하다.

## 왜 중요한가

**장점**:
- 구현 단순
- 멀티코어에서 Lock 보유 시간이 짧을 때 효율적
- 컨텍스트 스위치 오버헤드 없음

**단점**:
- 단일 CPU에서 Lock holder가 실행될 수 없는데도 spinner가 CPU를 차지 → 낭비
- Fairness 없음 (Starvation 가능)

→ 실제 OS/라이브러리는 Spin + Sleep 하이브리드(futex)를 사용한다.

## 관련
- 상위 개념: Lock (Mutex)
- 관련: Atomic Operation, Compare-and-Swap (CAS)
- 등장 챕터: Ch.28 - Locks
