+++
date = '2025-12-27T18:00:00+09:00'
draft = false
title = '[OSTEP 용어] Critical Section'
description = "OSTEP 핵심 용어 정리 - Critical Section"
tags = ["OS", "OSTEP", "OS 용어"]
categories = ["OS"]
series = ["OSTEP 정리"]
+++
## 정의
공유 자원(변수, 자료구조 등)에 접근하는 코드 영역. **한 번에 하나의 스레드만** 실행되어야 한다.

## 동작 원리

```c
// Critical Section 예시
lock(&mutex);
balance = balance + 1;  // ← Critical Section
unlock(&mutex);
```

Lock (Mutex)로 진입/퇴출을 보호한다. 내부 코드가 마치 원자적으로 실행된 것처럼 보이게 한다.

## 왜 중요한가

Critical Section을 보호하지 않으면 Race Condition 발생. 보호하더라도 크기가 크거나 중첩되면 Deadlock 위험.

**설계 원칙**:
- Critical Section은 **최대한 짧게** 유지 (락 보유 시간 최소화)
- 락 안에서 외부 함수 호출 최소화 (락 순서 역전 방지)

## 관련
- 해결책: Lock (Mutex), Semaphore
- 관련: Race Condition, Deadlock, Atomic Operation
- 등장 챕터: Ch.26 - Concurrency - An Introduction, Ch.28 - Locks
