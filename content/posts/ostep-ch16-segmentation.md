+++
date = '2026-01-05T10:00:00+09:00'
draft = false
title = '[OSTEP] Ch.16 - Segmentation'
description = "OSTEP 메모리 가상화 파트 - Segmentation 정리 노트"
tags = ["OS", "OSTEP", "Virtualization"]
categories = ["OS"]
series = ["OSTEP 정리"]
+++
## Crux (핵심 문제)
> Base/Bounds는 Address Space 전체를 물리 메모리에 올려야 해서 낭비가 크다. 스택과 힙 사이의 빈 공간을 효율적으로 처리하려면?

## 배경 & 동기

Base/Bounds의 문제:
```
Virtual Address Space (16KB):
Code(1KB) | Heap(1KB) | ~~~빈공간(13KB)~~~ | Stack(1KB)

물리 메모리에서: 16KB 전체 차지 → 13KB 낭비!
```

프로그램은 Code, Heap, Stack만 실제로 쓴다. 그 사이 빈 공간을 왜 물리 메모리에 올려야 하나? → Segmentation: **논리 세그먼트별로 따로 배치**.

## Mechanism (어떻게 동작하는가)

### Segmentation의 핵심 아이디어

Address Space를 논리적 세그먼트(Code, Heap, Stack)로 나누고, 각 세그먼트에 **개별 base/bounds 레지스터 쌍** 부여.

```
Segment  Base   Size
Code     32KB   2KB
Heap     34KB   3KB
Stack    28KB   2KB (grows negative)
```

각 세그먼트는 물리 메모리 어디에든 독립적으로 배치 가능 → 빈 공간 낭비 없음.

### 주소 변환

**방법 1: 상위 비트로 세그먼트 구분 (Explicit)**

14비트 가상 주소 예시:
```
[Seg(2비트)] [Offset(12비트)]
  00 = Code
  01 = Heap
  11 = Stack
```

변환 예시 (virtual address 4200 → Heap):
```
4200 in binary: 01 0000 0110 1000
→ Segment = 01 (Heap), Offset = 0000 0110 1000 = 104
→ Physical = Heap.base + Offset = 34KB + 104 = 34920
```

경계 검사:
```c
Segment = (VA & SEG_MASK) >> SEG_SHIFT;
Offset  = VA & OFFSET_MASK;
if (Offset >= Bounds[Segment])
    RaiseException(PROTECTION_FAULT);
PhysAddr = Base[Segment] + Offset;
```

**Stack의 특이점**: 아래로 성장(grows negative)
Stack virtual address 15KB 변환:
```
11 1100 0000 0000
→ Segment = 11 (Stack), Offset = 3KB
→ Negative offset = 3KB - 4KB(max) = -1KB
→ Physical = 28KB + (-1KB) = 27KB
```

### 추가 하드웨어 지원

| 정보 | 용도 |
|------|------|
| **Grows Positive?** | Stack은 0, 나머지는 1 |
| **Protection bits** | Read/Write/Execute 권한 |

**코드 공유(Code Sharing)**: Code 세그먼트를 Read-Execute only로 표시 → 여러 프로세스가 같은 물리 코드를 공유 가능. 메모리 절약.

## Policy (왜 이렇게 설계했는가)

### Segmentation의 문제: External Fragmentation (외부 단편화)

시간이 지나면 물리 메모리가 다양한 크기의 구멍으로 가득 찬다.

```
물리 메모리:
[Used 8KB] [Free 4KB] [Used 12KB] [Free 6KB] [Used 8KB]

→ 새 15KB 세그먼트 배치하려면? 남은 공간 = 10KB지만 연속되지 않아서 불가!
```

**해결 시도들:**
- **Compaction**: 세그먼트를 물리 메모리에서 옮겨서 빈 공간 합침 → 매우 비쌈
- **Best-fit / Worst-fit / First-fit**: 빈 공간 관리 알고리즘 → 완화만 가능, 근본 해결 불가

> [!important]
> 외부 단편화는 세그먼트 크기가 가변적이기 때문에 본질적으로 발생한다.
> 근본 해결책은 **고정 크기로 나누는 것** = Paging이 등장하는 이유.

**Context Switch 시**: 모든 세그먼트 레지스터(base/bounds)를 PCB에 저장/복원.

**Heap 성장**: `malloc()`으로 힙이 넘칠 때 OS에 `sbrk()` 시스템 콜로 세그먼트 크기 확장 요청.

### Segmentation의 또 다른 한계

- 힙 전체가 논리적으로 하나의 세그먼트 → sparse한 힙도 전부 물리 메모리 필요
- 세그먼트 수 고정 (code, heap, stack) → 유연성 부족

> [!example]
> "Segmentation fault" 용어의 기원:
> 세그먼트 밖의 주소에 접근하면 발생하는 하드웨어 fault. 오늘날은 segmentation을 안 쓰는 시스템에서도 이 용어가 관행적으로 남아있다.

## 내 정리
결국 이 챕터는 **Base/Bounds의 낭비를 줄이기 위해 논리 세그먼트별로 메모리를 따로 배치하는 Segmentation**을 설명한다. 빈 공간 낭비는 줄었지만 외부 단편화라는 새 문제가 생겼다. 가변 크기 세그먼트는 근본적으로 이 문제를 안고 간다 → Paging의 등장.

## 연결
- 이전: Ch.15 - Mechanism - Address Translation
- 다음: Ch.17 - Free Space Management
- 관련 개념: Virtual Address Space, Address Translation, Segmentation
