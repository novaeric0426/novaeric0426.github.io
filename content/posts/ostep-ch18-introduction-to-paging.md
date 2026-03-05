+++
date = '2026-01-10T10:00:00+09:00'
draft = false
title = '[OSTEP] Ch.18 - Introduction to Paging'
description = "OSTEP 메모리 가상화 파트 - Introduction to Paging 정리 노트"
tags = ["OS", "OSTEP", "Virtualization"]
categories = ["OS"]
series = ["OSTEP 정리"]
+++
## Crux (핵심 문제)
> Segmentation의 External Fragmentation 문제를 해결하면서 유연하게 메모리를 가상화하려면? 고정 크기 단위로 나누면 어떻게 되는가?

## 배경 & 동기

공간 관리의 두 가지 접근법:
1. **가변 크기 단위**: Segmentation → External Fragmentation 문제
2. **고정 크기 단위**: **Paging** → 단편화 없음, 유연함

Paging = Address Space를 동일한 크기의 **Page**로 나눔. 물리 메모리도 동일한 크기의 **Frame**으로 나눔. Page를 임의의 Frame에 매핑.

## Mechanism (어떻게 동작하는가)

### 기본 구조

```
Virtual Address Space (64 bytes, page size = 16 bytes):
┌──────────┐ 0
│  Page 0  │
├──────────┤ 16
│  Page 1  │
├──────────┤ 32
│  Page 2  │
├──────────┤ 48
│  Page 3  │
└──────────┘ 64

Physical Memory (128 bytes, 8 frames):
Frame 0: OS 예약
Frame 3: ← Page 0 of Process
Frame 7: ← Page 1 of Process
Frame 5: ← Page 2 of Process
Frame 2: ← Page 3 of Process
(나머지는 free)
```

연속 배치 필요 없음! 각 Page는 임의의 Frame에 배치 가능 → External Fragmentation 없음.

### Page Table

각 프로세스마다 **Page Table** 유지: VPN → PFN 매핑 테이블.

```
VP 0 → PF 3
VP 1 → PF 7
VP 2 → PF 5
VP 3 → PF 2
```

Page Table은 메모리에 저장 (너무 커서 하드웨어에 못 넣음).
Per-process 자료구조 (프로세스마다 별도 page table 존재).

### 주소 변환 과정

가상 주소 = **VPN(Virtual Page Number)** + **Offset**

예: 64-byte address space, 16-byte pages → 6비트 주소:
```
[VPN(2비트)] [Offset(4비트)]
```

virtual address 21 변환:
```
21 = 010101 (2진수)
VPN = 01 = 1 (Page 1)
Offset = 0101 = 5
→ Page Table: VP1 → PF7
→ Physical Address = 7(PF) * 16(page size) + 5(offset) = 117
```

### Page Table Entry (PTE)

실제 PTE에는 PFN 외 여러 비트:

| 비트 | 의미 |
|------|------|
| **Valid bit** | 이 페이지가 유효한 매핑인지 (스택-힙 사이 빈 공간은 invalid) |
| **Protection bits** | R/W/X 권한 |
| **Present bit** | 현재 물리 메모리에 있는지 (없으면 디스크에 swap됨) |
| **Dirty bit** | 수정됐는지 (swap 시 디스크 쓰기 필요 여부 판단) |
| **Reference/Accessed bit** | 최근에 접근됐는지 (page replacement 정책에 사용) |
| **PFN** | 실제 물리 프레임 번호 |

> [!important]
> **Valid bit**이 핵심: sparse address space에서 사용 안 하는 수백만 페이지를
> invalid로 표시 → 물리 메모리 할당 불필요. 접근하면 segfault.

### Paging의 두 가지 문제

**1. 너무 느리다 (Too Slow)**

모든 메모리 접근에 page table 조회 필요 → 메모리 접근이 2배로 늘어남:
```
movl 21, %eax 실행 시:
1. Page Table 조회 (메모리 접근 1회)
2. 실제 데이터 접근 (메모리 접근 1회)
→ 2배 느려짐 → 해결: TLB (Ch.19)
```

**2. 너무 크다 (Too Big)**

32-bit address space + 4KB page:
```
VPN = 20비트 → 2^20 = 약 100만 개의 PTE
각 PTE = 4 bytes
Page Table 크기 = 4MB (프로세스당!)
100개 프로세스 → 400MB가 page table만으로
→ 해결: 고급 페이지 테이블 구조 (Ch.20)
```

## Policy (왜 이렇게 설계했는가)

**Paging의 장점:**
- External Fragmentation 없음 (고정 크기 단위)
- 유연성: 스택/힙 방향에 상관없이 어느 페이지나 임의 배치
- Free space 관리 단순: free frame list만 유지

**Paging의 비용:**
- 속도: 페이지 테이블 조회 추가
- 공간: 페이지 테이블 자체의 메모리 사용

→ 두 문제를 해결해야 Paging이 실용적 = TLB + Multi-level Page Table

## 내 정리
결국 이 챕터는 **외부 단편화 없이 유연하게 메모리를 가상화하는 Paging의 기본 개념**을 소개한다. 고정 크기 Page = 단편화 해결. 하지만 page table 조회 비용(느림)과 page table 크기(큼) 두 문제가 생긴다. 이걸 해결하는 게 다음 두 챕터(TLB, Advanced Page Tables)의 주제.

## 연결
- 이전: Ch.17 - Free Space Management
- 다음: Ch.19 - Paging - Faster Translations (TLBs)
- 관련 개념: Page Table, TLB, Page Fault, Virtual Address Space
