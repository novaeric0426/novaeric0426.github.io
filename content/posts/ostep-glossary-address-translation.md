+++
date = '2025-12-11T18:00:00+09:00'
draft = false
title = '[OSTEP 용어] Address Translation'
description = "OSTEP 핵심 용어 정리 - Address Translation"
tags = ["OS", "OSTEP", "OS 용어"]
categories = ["OS"]
series = ["OSTEP 정리"]
+++
## 정의
프로세스가 생성한 가상 주소(Virtual Address)를 실제 데이터가 있는 물리 주소(Physical Address)로 변환하는 과정. 하드웨어(MMU)가 매 메모리 접근마다 수행한다.

## 동작 원리

**가상 주소 구조:**
```
Paging 방식:
[VPN (Virtual Page Number)] [Offset]

Segmentation 방식:
[Segment Number] [Offset]
```

**변환 과정 (Paging 기준):**
```
1. TLB 확인: TLB[VPN] 있으면 즉시 PFN 반환 (TLB Hit)
2. TLB Miss: Page Table[VPN] 조회 → PFN 획득
3. Physical Address = PFN × page_size + Offset
```

**진화 과정:**

| 방식 | 메커니즘 | 특징 |
|------|---------|------|
| Base/Bounds | physical = virtual + base | 단순하지만 낭비 |
| Segmentation | segment 레지스터 per segment | 외부 단편화 |
| Paging | Page Table | 단편화 없음, 느림 |
| Paging + TLB | Page Table + 캐시 | 실용적 |
| Multi-level PT + TLB | 계층적 PT + 캐시 | 현재 표준 |

**누가 변환하는가:**
- Hardware-managed TLB: 하드웨어가 page table 탐색 (x86)
- Software-managed TLB: TLB miss 시 OS가 처리 (MIPS)

## 왜 중요한가
Address Translation 없이는 가상 메모리가 불가능하다. 각 프로세스에게 독립적인 주소 공간을 제공하는 핵심 메커니즘. 효율적인 변환(TLB)이 없으면 가상 메모리로 인한 성능 저하가 너무 크다.

## 관련
- 핵심 자료구조: Page Table, TLB
- 상위 개념: Virtual Address Space
- 등장 챕터: Ch.15 - Mechanism - Address Translation, Ch.18 - Introduction to Paging, Ch.19 - Paging - Faster Translations (TLBs)
