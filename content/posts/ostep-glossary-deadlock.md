+++
date = '2026-01-01T18:00:00+09:00'
draft = false
title = '[OSTEP 용어] Deadlock'
description = "OSTEP 핵심 용어 정리 - Deadlock"
tags = ["OS", "OSTEP", "OS 용어"]
categories = ["OS"]
series = ["OSTEP 정리"]
+++
## 정의
둘 이상의 스레드가 서로 상대방이 보유한 자원(락)을 기다리며 영원히 진행하지 못하는 상태.

## 동작 원리

```c
// Thread 1       Thread 2
lock(L1);         lock(L2);
lock(L2); ←      lock(L1); ←
// 서로를 기다리며 무한 대기
```

**Deadlock 의존성 그래프** — 사이클이 있으면 Deadlock:
```
Thread 1 → [holds L1] → [wants L2] → Thread 2 → [holds L2] → [wants L1] → Thread 1
```

### 발생 4가지 필요 조건 (Coffman Conditions)
모두 동시에 성립할 때만 Deadlock 발생:
1. **Mutual Exclusion** — 자원을 독점 보유
2. **Hold-and-Wait** — 자원을 들고 다른 자원을 기다림
3. **No Preemption** — 자원을 강제로 빼앗을 수 없음
4. **Circular Wait** — 원형 대기 체인

## 예방 전략

| 전략 | 깨는 조건 | 방법 |
|------|-----------|------|
| 락 순서 고정 | Circular Wait | 항상 L1→L2 순서 |
| 한 번에 획득 | Hold-and-Wait | 메타-락으로 원자적 획득 |
| trylock | No Preemption | 실패 시 가진 락 해제 후 재시도 |
| Lock-Free | Mutual Exclusion | CAS 기반 알고리즘 |

> [!important]
> 가장 실용적인 예방법: **락 획득 순서를 전역적으로 일관되게 유지**. 락 주소(포인터)로 순서를 결정하는 기법도 유용.

## 왜 중요한가

대규모 소프트웨어에서 Deadlock은 재현 어렵고 탐지도 어렵다. 예방하지 못하면 ThreadSanitizer 같은 도구나 Deadlock Detection 알고리즘(그래프 순환 탐색)에 의존해야 한다.

## 관련
- 관련: Lock (Mutex), Race Condition, Critical Section, Semaphore
- 등장 챕터: Ch.32 - Common Concurrency Problems, Ch.28 - Locks
