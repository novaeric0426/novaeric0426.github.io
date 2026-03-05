+++
date = '2025-12-20T18:00:00+09:00'
draft = false
title = '[OSTEP 용어] Condition Variable'
description = "OSTEP 핵심 용어 정리 - Condition Variable"
tags = ["OS", "OSTEP", "OS 용어"]
categories = ["OS"]
series = ["OSTEP 정리"]
+++
## 정의
스레드가 특정 조건이 참이 될 때까지 잠들고, 다른 스레드가 조건을 충족시키면 깨워주는 동기화 원시 타입. Lock (Mutex)이 "누가 들어가냐"라면, CV는 "언제 들어가냐"를 제어한다.

## 동작 원리

```c
pthread_cond_t cv  = PTHREAD_COND_INITIALIZER;
pthread_mutex_t mu = PTHREAD_MUTEX_INITIALIZER;

// 대기
pthread_mutex_lock(&mu);
while (!condition)                    // 항상 while로 재확인
    pthread_cond_wait(&cv, &mu);     // 락 해제 + 슬립 (원자적)
// condition이 참인 상태로 락 보유하며 복귀
pthread_mutex_unlock(&mu);

// 신호
pthread_mutex_lock(&mu);
condition = true;
pthread_cond_signal(&cv);            // 대기자 하나 깨움
pthread_mutex_unlock(&mu);
```

**`wait()`의 원자성**: 락을 해제하고 잠드는 것이 원자적으로 일어나야 한다. 그렇지 않으면 "락 해제 직후 / 슬립 직전"에 신호를 놓치는 Race Condition 발생.

## 왜 중요한가

- **CPU 낭비 없는 대기**: `while (done == 0);` spin 대신 잠드는 것
- **Producer-Consumer 패턴**: 버퍼 상태에 따라 생산자/소비자를 재울 수 있음
- **`while` 필수**: Spurious Wakeup(이유 없는 깨어남), 여러 대기자 처리

## 관련
- 상위: Lock (Mutex)
- 유사: Semaphore (CV를 대신 쓸 수 있지만, 목적이 다름)
- 등장 챕터: Ch.30 - Condition Variables, Ch.27 - Interlude - Thread API
