+++
date = '2026-01-19T10:00:00+09:00'
draft = false
title = '[OSTEP] Ch.22 - Beyond Physical Memory - Policies'
description = "OSTEP 메모리 가상화 파트 - Beyond Physical Memory - Policies 정리 노트"
tags = ["OS", "OSTEP", "Virtualization"]
categories = ["OS"]
series = ["OSTEP 정리"]
+++
## Crux (핵심 문제)
> 물리 메모리가 가득 찼을 때 어떤 페이지를 내보낼 것인가? 잘못 고르면 성능이 디스크 속도로 떨어진다.

## 배경 & 동기

**AMAT (Average Memory Access Time) 공식:**
```
AMAT = T_memory + (P_miss × T_disk)
T_memory ≈ 100ns, T_disk ≈ 10ms

miss rate 10%: AMAT = 100ns + 0.1 × 10ms ≈ 1ms (10,000배 느림)
miss rate 0.1%: AMAT ≈ 10μs (100배 느림)
```

디스크 접근 비용이 압도적으로 비싸서 miss rate를 조금만 낮춰도 큰 차이. 좋은 Replacement Policy가 필수.

## Mechanism (어떻게 동작하는가)

### Optimal Policy (이론적 기준)

**Belady's Optimal (MIN)**: 미래에 가장 오랫동안 사용되지 않을 페이지를 내보낸다.

```
접근 순서: 0, 1, 2, 0, 1, 3, 0, 3, 1, 2, 1
Cache size: 3

Access  Hit/Miss  Evict  Cache
0       Miss             {0}
1       Miss             {0,1}
2       Miss             {0,1,2}
0       Hit              {0,1,2}
1       Hit              {0,1,2}
3       Miss      2      {0,1,3}  ← 2가 가장 멀리 사용됨
0       Hit              {0,1,3}
3       Hit              {0,1,3}
1       Hit              {0,1,3}
2       Miss      3      {0,1,2}  ← 3이 가장 멀리 사용됨
1       Hit              {0,1,2}

Hit rate: 6/11 = 54.5%
```

**문제**: 미래를 모름 → 현실에서 구현 불가. 비교 기준으로만 사용.

### FIFO

먼저 들어온 페이지를 먼저 내보냄. 구현 단순하지만 성능 나쁨.

> [!important]
> **Belady's Anomaly**: FIFO는 캐시 크기를 늘려도 hit rate가 오히려 떨어지는 이상한 경우가 있다. LRU는 이 현상이 없다(Stack Property).

### LRU (Least Recently Used)

가장 오래 전에 사용된 페이지를 내보냄. **시간적 지역성**을 활용: 최근에 사용된 것은 곧 다시 사용될 가능성이 높다.

```
접근 순서: 0, 1, 2, 0, 1, 3, 0, 3, 1, 2, 1
Cache size: 3

Access  Hit/Miss  Evict(LRU)  Cache(MRU→LRU)
0       Miss                   {0}
1       Miss                   {1,0}
2       Miss                   {2,1,0}
0       Hit                    {0,2,1}
1       Hit                    {1,0,2}
3       Miss      2            {3,1,0}
0       Hit                    {0,3,1}
3       Hit                    {3,0,1}
1       Hit                    {1,3,0}
2       Miss      0            {2,1,3}
1       Hit                    {1,2,3}

Hit rate: 6/11 = 54.5% (optimal과 동일!)
```

**문제**: 완벽한 LRU 구현은 비쌈. 모든 접근마다 timestamp 갱신 필요.

**LRU의 한계 (Cyclic Sequential Workload)**:
```
캐시 크기 4, 페이지 0~4를 순환 접근:
0,1,2,3,4,0,1,2,3,4,...
→ LRU는 항상 miss! (매번 oldest = 다음에 필요한 것)
```

### Clock Algorithm (Approximate LRU)

완벽한 LRU는 비싸므로 **Reference Bit**으로 근사하는 Clock 알고리즘.

```
각 페이지에 Reference Bit (0 or 1):
- 페이지 접근 시 하드웨어가 ref bit = 1로 설정
- Clock hand가 페이지를 순환하면서:
  - ref bit = 1: 0으로 초기화하고 지나침 (최근에 사용됨)
  - ref bit = 0: 이 페이지 내보냄 (두 번 기회를 놓침)
```

```
    ┌─────────────────────────────┐
    │  [P0,ref=1] [P1,ref=0] ...  │
    │           ↑                 │
    │      clock hand             │
    └─────────────────────────────┘

P1의 ref=0 → 내보냄
P0의 ref=1 → ref=0으로 초기화하고 통과
```

**Clock은 LRU의 훌륭한 근사**: 하드웨어 reference bit 지원만 있으면 됨. 실제 OS에서 널리 사용.

### Dirty Bit 고려

내보낼 때:
- **Clean page** (dirty=0): 디스크에 이미 있는 복사본과 동일 → 그냥 버림 (디스크 쓰기 불필요)
- **Dirty page** (dirty=1): 디스크에 써야 함 → 더 비쌈

OS는 Clean page를 선호해서 먼저 내보낸다.

### Thrashing

프로세스의 Working Set > 물리 메모리 → 끊임없이 Page Fault 발생 → 디스크만 돌아감

```
Working Set: 자주 사용하는 페이지들의 집합
물리 메모리 < Working Set → Thrashing
```

**대응:**
- 일부 프로세스를 아예 종료/swap out해서 메모리 확보
- Working Set을 모니터링해 메모리 과부하 방지

## Policy (왜 이렇게 설계했는가)

| 정책 | 특징 | 실용성 |
|------|------|--------|
| Optimal (MIN) | 최고 성능 | 구현 불가 (미래 필요) |
| FIFO | 단순 | Belady's anomaly |
| LRU | 지역성 활용, 좋은 성능 | 완전 구현 비쌈 |
| Clock | LRU 근사, ref bit 사용 | 실제 OS에서 사용 |

> [!important]
> 실제 Linux: **Clock 변형 (Second Chance) + LRU list** 조합 사용.
> Active list (최근 사용) / Inactive list (오래된 것) 두 리스트 유지.

## 내 정리
결국 이 챕터는 **어떤 페이지를 내보낼지 결정하는 Replacement Policy**를 다룬다. Optimal은 이론적 기준, LRU는 지역성을 활용한 좋은 근사, Clock은 LRU의 실용적 구현. miss rate를 낮추는 게 핵심 — 디스크 접근 비용이 압도적으로 크기 때문이다.

## 연결
- 이전: Ch.21 - Beyond Physical Memory - Mechanisms
- 다음: Ch.23 - Complete Virtual Memory Systems
- 관련 개념: Page Fault, Swapping, Page Table, TLB
