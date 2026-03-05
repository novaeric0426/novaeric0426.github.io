+++
date = '2026-01-15T10:00:00+09:00'
draft = false
title = '[OSTEP] Ch.20 - Paging - Smaller Tables'
description = "OSTEP 메모리 가상화 파트 - Paging - Smaller Tables 정리 노트"
tags = ["OS", "OSTEP", "Virtualization"]
categories = ["OS"]
series = ["OSTEP 정리"]
+++
## Crux (핵심 문제)
> Linear page table은 너무 크다. 32-bit에서 프로세스당 4MB, 100개 프로세스 → 400MB가 page table만으로! 어떻게 page table 크기를 줄이는가?

## 배경 & 동기

Ch.18의 두 번째 문제: page table 크기. 32-bit address space + 4KB page:
```
VPN = 20비트 → 2^20 ≈ 100만 개의 PTE
각 PTE = 4 bytes
→ page table = 4MB/프로세스
```
대부분의 페이지는 실제로 사용 안 하는데 PTE는 무조건 존재한다. 이걸 어떻게 줄이나?

## Mechanism (어떻게 동작하는가)

### 방법 1: 더 큰 Page Size

4KB → 16KB로 늘리면 page table 크기 1/4로 줄어듦. 하지만 **Internal Fragmentation** 증가.

### 방법 2: Hybrid (Segmentation + Paging)

각 세그먼트(code, heap, stack)마다 별도 page table. 세그먼트 내 실제 사용 범위만 page table 할당.

**문제**: 각 세그먼트 크기가 가변적 → external fragmentation 재발.

### 방법 3: Multi-Level Page Table (핵심!)

Page table 자체를 page 단위로 나눠서, **사용하는 부분의 page table만 메모리에 유지**.

**두 단계 구조 (2-level):**

```
가상 주소 (32-bit, 4KB page):
[Page Dir Index (10비트)] [Page Table Index (10비트)] [Offset (12비트)]
         ↓                         ↓
    Page Directory            Page Table
    (1024 entries)          (1024 entries)
    Page Dir Entry →→→→→→ Page Table Entry → Physical Frame
```

**Page Directory**:
- Page Table들의 위치를 저장
- 한 Page Table이 통째로 비어있으면 해당 Page Directory Entry를 invalid로 표시 → 그 Page Table 자체를 물리 메모리에 올릴 필요 없음

**예시: 32-bit, 4KB page, 2-level**
```
Page Directory: 1개, 4KB (1024 × 4bytes)
Page Tables: 프로세스가 실제로 사용하는 부분만
→ 희소한 address space에서 큰 절약
```

```
가상 주소 변환:
VPN = VA[31:12]
PDIndex = VPN[19:10]   // 상위 10비트 → Page Directory 인덱스
PTIndex = VPN[9:0]     // 하위 10비트 → Page Table 인덱스

PADDR of PTE = CR3[page_dir_base] + PDIndex
if PDE.Valid:
    PTE = load(PDE.pfn << 12 + PTIndex * sizeof(PTE))
    PhysAddr = PTE.pfn << 12 | Offset
```

**장점:**
- 사용하는 부분만 page table 할당 → 메모리 효율적
- Page table 각 부분이 page 단위 → 물리 메모리 어디에나 배치 가능

**단점:**
- 주소 변환 시 메모리 접근 횟수 증가 (2-level: 2회, 3-level: 3회)
- TLB hit이면 추가 접근 없음 → 실제론 성능 영향 적음

### 64-bit 시스템

64-bit는 너무 커서 단순 2-level도 부족. 실제 x86-64는 **4-level page table** 사용 (PGD → PUD → PMD → PTE). 하지만 실제로 사용되는 주소 공간은 48-bit 수준 (나머지는 미래 예약).

### 방법 4: Inverted Page Table

물리 프레임당 하나의 항목. "어떤 프로세스의 어떤 VPN이 이 PFN을 쓰는가?"를 저장.

```
Physical Frame 0: (PID=3, VPN=7)
Physical Frame 1: (PID=1, VPN=2)
Physical Frame 2: 비어있음
```

**장점**: 전체 page table 크기 = 물리 메모리 크기에 비례 (매우 작음)
**단점**: 검색이 느림 (VPN으로 검색 시 선형 탐색 필요). Hash로 보완.

## Policy (왜 이렇게 설계했는가)

**실제 OS 선택:**

| OS | Page Table 구조 |
|----|----------------|
| Linux x86-64 | 4-level page table (PGD/PUD/PMD/PTE) |
| Linux ARM64 | 최대 4-level (설정 가능) |
| 고전 MIPS | Software-managed TLB + 다양한 구조 가능 |

**Trade-off:**
- Level 수 ↑ → page table 크기 ↓, 변환 비용 ↑ (TLB miss 시)
- Level 수 ↓ → page table 크기 ↑, 변환 빠름

TLB가 대부분의 접근을 커버하므로, 실제로는 multi-level의 변환 비용 증가가 크지 않다.

> [!important]
> **Multi-level page table은 공간-시간 trade-off**: 공간을 절약하되,
> TLB miss 시 더 많은 메모리 접근이 필요하다. TLB가 이 비용을 희석한다.

## 내 정리
결국 이 챕터는 **Linear page table의 크기 문제를 Multi-level Page Table로 해결**하는 방법을 설명한다. page table을 page 단위로 나눠서 실제 사용하는 부분만 물리 메모리에 유지한다. 64-bit 시스템에선 4-level까지 사용한다. TLB가 있어서 실제 성능 영향은 작다.

## 연결
- 이전: Ch.19 - Paging - Faster Translations (TLBs)
- 다음: Ch.21 - Beyond Physical Memory - Mechanisms
- 관련 개념: Page Table, TLB, Virtual Address Space
