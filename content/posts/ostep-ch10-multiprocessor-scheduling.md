+++
date = '2025-12-27T10:00:00+09:00'
draft = false
title = '[OSTEP] Ch.10 - Multiprocessor Scheduling'
description = "OSTEP CPU 가상화 파트 - Multiprocessor Scheduling 정리 노트"
tags = ["OS", "OSTEP", "Virtualization"]
categories = ["OS"]
series = ["OSTEP 정리"]
+++
## Crux (핵심 문제)
> 여러 CPU가 있을 때 어떻게 job을 스케줄링하는가? 단일 CPU 스케줄러를 그냥 확장하면 되는가, 아니면 새로운 문제가 생기는가?

## 배경 & 동기

멀티코어 프로세서가 일반화됐다. 단일 코어를 더 빠르게 만드는 데 한계가 왔기 때문 (전력 문제). 그런데 멀티 CPU는 단순히 CPU를 더 붙이면 된다는 게 아니다 — **캐시와 메모리 공유**에서 새로운 문제가 생긴다.

> [!important]
> 이 챕터는 Concurrency(2부) 개념을 일부 요구하는 "Advanced" 챕터다.
> Lock, 동기화 개념을 먼저 접하면 더 잘 이해된다.

## Mechanism (어떻게 동작하는가)

### 핵심 문제: Cache Coherence (캐시 일관성)

단일 CPU:
```
CPU → [Cache] → Main Memory
캐시 hit → 빠름, miss → 느림 (수십~수백 ns)
Temporal/Spatial Locality 덕분에 캐시 효율적
```

다중 CPU의 문제:
```
CPU 1 → [Cache 1] ─┐
                    ├── Main Memory
CPU 2 → [Cache 2] ─┘
```

시나리오:
1. CPU 1이 주소 A에서 값 D를 읽어 캐시에 저장
2. CPU 1이 A를 D'로 수정 (캐시에만 반영, 메인 메모리는 나중에)
3. OS가 해당 프로세스를 CPU 2로 옮김
4. CPU 2가 주소 A를 읽으면? → 메인 메모리의 낡은 값 D를 읽는다! **버그**

**해결책: Bus Snooping**
- 각 캐시가 메모리 버스를 감시(snooping)
- 다른 CPU가 자신의 캐시에 있는 주소를 수정하면 → 무효화(Invalidate) 또는 업데이트

### Cache Affinity (캐시 친화성)

프로세스가 CPU 1에서 실행되면 → CPU 1의 캐시에 해당 프로세스 데이터가 채워짐.
→ 다음 실행 때도 CPU 1에서 실행하면 캐시 hit rate ↑, 성능 ↑.
다른 CPU에서 실행하면 캐시를 다시 채워야 함 (Cold start).

**따라서:** 멀티 CPU 스케줄러는 **같은 CPU에서 실행하는 것을 선호**해야 함.

### 동기화 문제

여러 CPU가 공유 자료구조(ex: 프로세스 큐)에 동시 접근할 때 락이 필요하다.

```c
// 락 없이 공유 리스트 접근 시 버그 발생
int List_Pop() {
    Node_t *tmp = head;
    int value = head->value;
    head = head->next;  // CPU 1, 2가 동시에 여기 실행하면?
    free(tmp);
    return value;
}
// → 같은 노드를 두 번 제거하거나, 메모리를 두 번 해제하는 버그
```

락을 써야 하지만, 락도 성능 문제를 일으킨다 (경합이 심하면 느려짐).

### Single Queue Multiprocessor Scheduling (SQMS)

가장 단순한 방식: 단일 큐를 모든 CPU가 공유.

```
Queue: A → B → C → D → E → NULL

CPU 0: A  E  D  C  B  A  ...
CPU 1: B  A  E  D  C  B  ...
CPU 2: C  B  A  E  D  C  ...
CPU 3: D  C  B  A  E  D  ...
```

**문제:**
1. **Scalability**: 단일 큐에 락이 있어서 CPU 수 늘어날수록 락 경합 심화
2. **Cache Affinity 나쁨**: 같은 job이 매번 다른 CPU에서 실행됨

**개선**: 일부 job은 같은 CPU에 고정(affinity 보장), 나머지는 load balancing.

### Multi-Queue Multiprocessor Scheduling (MQMS)

CPU마다 별도의 큐를 유지.

```
CPU 0: Q0 → A → C
CPU 1: Q1 → B → D
```

**장점:**
- 락 경합 없음 (큐가 분리됨)
- Cache Affinity 자연스럽게 보장

**단점: Load Imbalance**

```
A가 끝나면:
CPU 0: Q0 → C (한 job만)
CPU 1: Q1 → B → D (두 job)
→ CPU 0이 idle, CPU 1은 바쁨 → 불균형
```

**해결책: Migration (이주)**

```
CPU 1에서 D를 CPU 0으로 이주:
CPU 0: Q0 → C → D
CPU 1: Q1 → B
```

**Work Stealing**: 바쁜 CPU에서 한가한 CPU로 job을 도둑질.

| 방식 | SQMS | MQMS |
|------|------|------|
| 구현 복잡도 | 단순 | 복잡 |
| Scalability | 나쁨 | 좋음 |
| Cache Affinity | 나쁨 | 좋음 |
| Load Balance | 자동 | 별도 필요 |

## Policy (왜 이렇게 설계했는가)

**Linux의 실제 접근:**
- O(1) Scheduler (구버전): SQMS 계열
- CFS (현재): MQMS 기반 + Work Stealing으로 load balancing

**실무 교훈:**
- CPU 수가 적으면 SQMS도 충분
- CPU 수가 많아질수록 MQMS가 필요
- Cache Affinity와 Load Balance는 항상 충돌 → 주기적 migration으로 균형

> [!question]
> Migration을 얼마나 자주 해야 하는가? 너무 자주 → 캐시 낭비, 너무 가끔 → 불균형. 이것도 voo-doo constant 문제.

## 내 정리
결국 이 챕터는 **CPU가 여러 개일 때 생기는 새로운 문제들 — Cache Coherence, Cache Affinity, 동기화 — 을 다룬다**. 단일 큐(SQMS)는 단순하지만 확장성 없고, 멀티 큐(MQMS)는 확장성 좋지만 로드 밸런싱이 어렵다. 실제 OS는 두 방식을 섞어 쓰며, 근본적으로 "Cache Affinity ↔ Load Balance" 트레이드오프를 관리한다.

## 연결
- 이전: Ch.09 - Scheduling - Proportional Share
- 다음: Ch.13 - The Abstraction - Address Spaces
- 관련 개념: Scheduling Policy, Context Switch, Time Sharing
