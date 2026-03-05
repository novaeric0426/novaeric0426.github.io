+++
date = '2026-01-24T18:00:00+09:00'
draft = false
title = '[OSTEP 용어] Page Table'
description = "OSTEP 핵심 용어 정리 - Page Table"
tags = ["OS", "OSTEP", "OS 용어"]
categories = ["OS"]
series = ["OSTEP 정리"]
+++
## 정의
가상 페이지 번호(VPN)에서 물리 프레임 번호(PFN)로의 매핑을 저장하는 per-process 자료구조. OS가 메모리에 유지하며, 하드웨어(MMU)가 주소 변환 시 참조한다.

## 동작 원리

**Linear Page Table (가장 단순):**
```
인덱스(VPN) → Page Table Entry(PTE)

PTE 내용:
[Valid | Protection | Present | Dirty | Ref | PFN...]

- Valid: 이 VPN이 유효한 매핑인지 (빈 공간은 0)
- Present: 현재 물리 메모리에 있는지 (0이면 swap됨 → Page Fault)
- Dirty: 수정됐는지 (swap 시 디스크 write 필요)
- Protection: R/W/X 권한
- PFN: 실제 물리 프레임 번호
```

**주소 변환:**
```
Virtual Address = [VPN] [Offset]

PTE = PageTable[VPN]
if PTE.Valid == 0: SEGFAULT
if PTE.Present == 0: PAGE FAULT
PhysAddr = PTE.PFN << page_shift | Offset
```

**크기 문제와 해결:**
- 32-bit, 4KB page → 4MB/프로세스 → 너무 큼
- **Multi-level Page Table**: 사용하는 부분만 할당
  - 2-level (x86-32): PD → PT
  - 4-level (x86-64): PGD → PUD → PMD → PTE
- **TLB**: 자주 쓰는 변환 캐싱 → page table 조회 빈도 줄임

## 왜 중요한가
Page Table 없이는 주소 변환이 불가능하다. 각 프로세스마다 독립적인 가상 주소 공간을 제공하는 핵심 자료구조. Page Table이 크거나 접근이 느리면 시스템 전체 성능이 저하된다.

## 관련
- 가속화: TLB
- 상위 개념: Virtual Address Space
- 관련 문제: Page Fault, Swapping
- 등장 챕터: Ch.18 - Introduction to Paging, Ch.19 - Paging - Faster Translations (TLBs), Ch.20 - Paging - Smaller Tables
