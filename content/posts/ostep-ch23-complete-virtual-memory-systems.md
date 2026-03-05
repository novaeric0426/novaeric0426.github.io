+++
date = '2026-01-22T10:00:00+09:00'
draft = false
title = '[OSTEP] Ch.23 - Complete Virtual Memory Systems'
description = "OSTEP 메모리 가상화 파트 - Complete Virtual Memory Systems 정리 노트"
tags = ["OS", "OSTEP", "Virtualization"]
categories = ["OS"]
series = ["OSTEP 정리"]
+++
## Crux (핵심 문제)
> 지금까지 배운 TLB, Page Table, Swap 등 개별 개념들이 실제 VM 시스템에서 어떻게 합쳐지는가? 완전한 VM 시스템에는 어떤 추가 기능이 필요한가?

## 배경 & 동기

지금까지 VM의 구성 요소를 하나씩 배웠다. 이 챕터는 두 실제 시스템 — **VAX/VMS** (1970년대 DEC)와 **Linux** — 을 통해 모든 개념이 어떻게 통합되는지 본다. 이론이 현실에서 어떻게 구현되는지 확인하는 챕터.

## Mechanism (어떻게 동작하는가)

### VAX/VMS

**아키텍처 특징:**
- 32-bit virtual address space
- Page size: **512 bytes** (역사적 이유로 매우 작음)
- Paging + Segmentation 하이브리드 구조

**Address Space 레이아웃:**
```
0           2^30        2^31         2^32
┌─────────────┬──────────┬────────────┐
│ User (P0)   │ User (P1)│ System (S) │
│ Code/Heap↓  │ Stack↑   │ OS code/data│
└─────────────┴──────────┴────────────┘
```
- P0/P1: 프로세스별 공간 (각자 page table 보유)
- S: 모든 프로세스가 공유하는 커널 공간

**Page 0 = Invalid**: null pointer 역참조를 감지하기 위해 의도적으로 접근 불가.

**커널이 각 user address space에 매핑되는 이유:**
1. 시스템 콜 시 user → kernel 데이터 복사가 쉬움
2. Page table을 kernel virtual memory에 저장 가능 → page table도 swap 가능

**Small Page Size 문제 해결:**
- P0/P1 각각 별도 page table → 스택-힙 사이 빈 공간은 page table 불필요
- User page table을 kernel virtual memory에 저장 → 메모리 압박 시 page table도 swap out 가능

**Page Replacement: Segmented FIFO**
- 각 프로세스에 **RSS (Resident Set Size)** 제한
- RSS 초과 시 per-process FIFO에서 clean page는 global clean list로, dirty page는 dirty list로
- 다른 프로세스가 free page 필요 시 clean list에서 가져감
- 원래 프로세스가 다시 그 페이지 필요하면 list에서 회수 (디스크 I/O 없이!)

**두 가지 Lazy 최적화 (VAX/VMS 최초 도입, 현재 모든 OS에서 사용):**

**1. Demand Zeroing**
```
naive: 페이지 추가 요청 → 즉시 물리 메모리 찾아서 0으로 초기화
demand-zero: 페이지 요청 → PTE에 "demand-zero" 표시만 (물리 할당 안 함)
→ 실제 접근 시 trap → OS: 그때 물리 메모리 찾아서 0으로 초기화 후 매핑
→ 안 쓰는 페이지는 실제로 물리 메모리 안 씀
```

**2. Copy-on-Write (COW)**
```
fork() 시:
naive: 부모 address space 전체를 자식에게 복사 → 느림
COW: 페이지를 복사하지 않고 공유 + Read-Only로 표시
→ 읽기만 하면 복사 없이 공유
→ 쓰기 발생 시 trap → 그때 실제로 복사 (수정할 때만 비용 발생)
```

> [!important]
> COW는 `fork()` + `exec()`에서 특히 강력:
> fork() 후 바로 exec()를 호출하면 복사한 메모리가 버려짐.
> COW로 fork()를 거의 공짜로 만들 수 있다.

**Clustering (Write I/O 효율화):**
작은 page(512B)를 하나씩 swap하면 I/O 비효율. VMS는 dirty page를 모아서 한 번에 큰 I/O로 write.

### Linux Virtual Memory

**3가지 주요 특징:**

**1. Kernel을 모든 process address space에 매핑**
(VMS와 동일 이유) 단, 커널 공간은 user mode에서 접근 불가 (보호 비트).

**2. 4-level Page Table (x86-64)**
```
48-bit virtual address:
[PGD(9)] [PUD(9)] [PMD(9)] [PTE(9)] [Offset(12)]

CR3 → PGD → PUD → PMD → PTE → Physical Frame
```
실제 사용 주소 48-bit (256TB 가상 주소 공간).

**3. Page Replacement: 2-list LRU**
```
Active List  (자주 접근한 페이지)
Inactive List (최근에 접근 안 한 페이지)

→ Inactive List에서 evict
→ Active에서 접근 없으면 Inactive로 이동
→ Inactive에서 접근하면 Active로 복귀
```

**Linux의 추가 최적화들:**
- **Huge Pages (2MB/1GB)**: TLB reach 증가, 대규모 서버에서 유용
- **Memory-mapped files**: `mmap()`으로 파일을 address space에 매핑
- **Page Cache**: 파일 시스템 I/O도 VM 시스템으로 캐싱

## Policy (왜 이렇게 설계했는가)

**VAX/VMS에서 Linux까지 공통으로 살아남은 아이디어들:**
1. Demand Paging (필요할 때만 물리 메모리 할당)
2. Copy-on-Write
3. Kernel의 process address space 매핑
4. 페이지를 모아서 I/O 효율화 (Clustering)

**완전한 VM 시스템의 요소:**

| 요소 | 역할 |
|------|------|
| Page Table (multi-level) | 가상↔물리 주소 매핑 |
| TLB | 변환 속도 |
| Swap Space + Page Fault Handler | 물리 메모리 초과 지원 |
| Page Replacement Policy | 내보낼 페이지 선택 |
| Demand Zeroing / COW | Lazy 최적화 |
| Protection Bits | 보호와 공유 |

> [!example]
> Null pointer dereference → Page 0 접근 → Invalid PTE → Page Fault → OS: segfault 신호 발송.
> 이 전체 흐름이 VM 시스템의 보호 메커니즘.

## 내 정리
결국 이 챕터는 **지금까지 배운 VM 개념들이 실제 시스템에서 어떻게 통합되는지** 보여준다. VAX/VMS는 작은 page size 문제를 기발한 소프트웨어 기법(Segmented FIFO, Demand Zeroing, COW)으로 해결했다. Linux는 이를 계승하면서 4-level page table, Huge Pages, 2-list LRU로 현대 요구에 맞게 발전시켰다. Demand Zeroing과 COW는 가장 중요한 유산.

## 연결
- 이전: Ch.22 - Beyond Physical Memory - Policies
- 다음: Ch.26 - Concurrency - An Introduction (Part 2 시작)
- 관련 개념: Page Table, TLB, Page Fault, Swapping, Virtual Address Space
