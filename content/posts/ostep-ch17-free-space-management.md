+++
date = '2026-01-08T10:00:00+09:00'
draft = false
title = '[OSTEP] Ch.17 - Free Space Management'
description = "OSTEP 메모리 가상화 파트 - Free Space Management 정리 노트"
tags = ["OS", "OSTEP", "Virtualization"]
categories = ["OS"]
series = ["OSTEP 정리"]
+++
## Crux (핵심 문제)
> 가변 크기 요청들을 어떻게 빈 공간에서 만족시키는가? External Fragmentation을 어떻게 줄이는가? 시간/공간 오버헤드는 어떻게 되는가?

## 배경 & 동기

Paging처럼 고정 크기 단위라면 free space 관리는 쉽다 — 그냥 비어있는 슬롯 반환하면 끝. 문제는 **가변 크기** 할당 시: malloc 라이브러리(힙 관리)나 OS(Segmentation 시 물리 메모리 관리)에서 발생하는 **External Fragmentation**.

```
free(10) used(10) free(10)  ← 총 20 free지만 15 요청은 못 들어줌
```

## Mechanism (어떻게 동작하는가)

### 기본 자료구조: Free List

빈 공간들을 연결 리스트로 관리.

```
Head → [addr:0, len:10] → [addr:20, len:10] → NULL
```

**할당 시**: 요청 크기를 담을 수 있는 노드 찾아서 분할(Splitting).
**해제 시**: 인접한 빈 블록과 합치기(Coalescing).

### 헤더(Header)

실제로 malloc 라이브러리는 각 블록 앞에 **헤더**를 숨겨둔다:
```c
typedef struct {
    int size;
    int magic; // 무결성 검사용
} header_t;

// 사용자가 ptr을 free() 할 때:
// 실제 블록 시작 = ptr - sizeof(header_t)
// size는 헤더에서 읽음
```

### Free Space 관리 전략

| 전략 | 동작 | 장단점 |
|------|------|--------|
| **Best Fit** | 딱 맞는 가장 작은 빈 공간 | 단편화 최소화, 전체 탐색 필요 |
| **Worst Fit** | 가장 큰 빈 공간 | 큰 빈 공간 보존, 성능 나쁨 |
| **First Fit** | 처음 맞는 공간 | 빠름, 앞쪽에 단편화 집중 |
| **Next Fit** | 마지막으로 찾은 위치부터 탐색 | First fit보다 단편화 분산 |

> [!important]
> 1000가지 알고리즘이 있다는 건, 완벽한 해법이 없다는 뜻이다.
> (If 1000 solutions exist, no great one does — OSTEP 팁)
> 근본 해결책은 가변 크기 할당 자체를 피하는 것 = Paging.

### 고급 할당 기법

**Buddy System (버디 시스템):**
```
2^k 크기만 할당. 요청 시 맞는 크기의 2^n을 찾아서 반으로 나눔.
해제 시 같은 크기의 인접(buddy) 블록과 합침 → Coalescing이 쉬움.
```

예시: 64KB 풀에서 7KB 요청:
```
64 → 32+32 → 32+16+16 → 32+16+8+8
→ 8KB 블록 반환 (7KB + 1KB 내부 단편화 감수)
```

**Slab Allocator:**
자주 할당/해제되는 고정 크기 객체(예: inode, process struct)를 위한 전용 캐시. OS 커널에서 흔히 사용.

## Policy (왜 이렇게 설계했는가)

**External vs Internal Fragmentation:**
- External: 빈 공간이 흩어져서 큰 요청 못 들어줌 (가변 크기 때 발생)
- Internal: 블록 내 낭비 공간 (고정 크기 or Buddy system에서 발생)

**현실의 malloc:**
glibc의 `dlmalloc`, jemalloc, tcmalloc 등은 위 기법들을 조합하고, 쓰레드 친화적 설계까지 더한 복잡한 구현체다.

> [!question]
> 최적의 free space 관리 알고리즘은? 워크로드에 따라 다르다. 단기/장기 실행, 할당 크기 분포, 해제 패턴에 따라 성능이 크게 달라진다.

## 내 정리
결국 이 챕터는 **가변 크기 메모리 할당의 근본 문제인 External Fragmentation과 이를 줄이는 전략들**을 다룬다. Best/Worst/First/Next Fit, Buddy System, Slab Allocator 등 다양한 기법이 있지만 완벽한 해답은 없다. 이 문제의 진짜 해결책은 고정 크기(Paging)로 가는 것이다.

## 연결
- 이전: Ch.16 - Segmentation
- 다음: Ch.18 - Introduction to Paging
- 관련 개념: Segmentation
