+++
date = '2026-01-12T10:00:00+09:00'
draft = false
title = '[OSTEP] Ch.19 - Paging - Faster Translations (TLBs)'
description = "OSTEP 메모리 가상화 파트 - Paging - Faster Translations (TLBs) 정리 노트"
tags = ["OS", "OSTEP", "Virtualization"]
categories = ["OS"]
series = ["OSTEP 정리"]
+++
## Crux (핵심 문제)
> Paging은 모든 메모리 접근마다 page table을 조회해서 느리다. 어떻게 주소 변환을 빠르게 만드는가?

## 배경 & 동기

Ch.18의 문제: 모든 메모리 접근 = 실제 데이터 접근 + page table 조회 → 2배 느림. 해결책은 하드웨어 캐시 — **TLB (Translation Lookaside Buffer)**: 최근 가상↔물리 주소 변환 결과를 캐싱하는 칩 내 하드웨어.

> TLB는 이름이 좀 이상하다(Translation Lookaside Buffer). 더 정확한 이름은 **address-translation cache**. 역사적 이유로 TLB라고 불림.

## Mechanism (어떻게 동작하는가)

### TLB 동작 알고리즘

```c
VPN = (VirtualAddress & VPN_MASK) >> SHIFT;
(Success, TlbEntry) = TLB_Lookup(VPN);

if (Success == True) {  // TLB Hit
    if (CanAccess(TlbEntry.ProtectBits))
        PhysAddr = (TlbEntry.PFN << SHIFT) | Offset;
        Register = AccessMemory(PhysAddr);  // 메모리 1회 접근
    else
        RaiseException(PROTECTION_FAULT);
} else {                // TLB Miss
    PTEAddr = PTBR + (VPN * sizeof(PTE));
    PTE = AccessMemory(PTEAddr);           // 메모리 1회 (page table)
    if (PTE.Valid == False)
        RaiseException(SEGMENTATION_FAULT);
    else if (!CanAccess(PTE.ProtectBits))
        RaiseException(PROTECTION_FAULT);
    else {
        TLB_Insert(VPN, PTE.PFN, PTE.ProtectBits);  // TLB에 캐싱
        RetryInstruction();  // 다시 실행 → 이번엔 TLB Hit
    }
}
```

**TLB Hit**: 메모리 접근 1회 (빠름 — 나노초 단위)
**TLB Miss**: 메모리 접근 2회 이상 (느림 — page table까지 조회)

> [!important]
> TLB가 실질적으로 가상 메모리를 가능하게 한다. Hit rate만 높으면
> 메모리 접근은 거의 물리 메모리 속도로 동작한다.

### Locality와 TLB 성능

TLB가 효과적인 이유: 프로그램은 **지역성(Locality)**을 가진다.
- **시간적 지역성**: 최근 접근한 주소를 곧 다시 접근
- **공간적 지역성**: 최근 접근한 주소 근처를 곧 접근

```c
// 배열 순회 — 공간적 지역성 우수
int sum = 0;
for (int i = 0; i < 10; i++)
    sum += a[i];

// 첫 번째 a[0] 접근 시 TLB miss
// a[1]~a[9]는 같은 page에 있으면 TLB hit!
// Page size가 클수록 한 miss로 더 많은 항목 커버
```

### TLB 항목 구조

```
VPN | PFN | Valid | Protection | dirty | ref | ASID(선택)
```

**ASID (Address Space Identifier)**: Context Switch 시 TLB를 flush하는 대신 각 항목에 프로세스 ID를 기록. 다른 프로세스의 항목과 구분.

### TLB Miss 처리: Hardware vs Software

**Hardware-managed TLB (예: x86)**:
- Page Table 위치를 하드웨어가 알고 있음 (CR3 레지스터)
- Miss 시 하드웨어가 직접 page table 탐색 (OS 개입 없음)
- 빠르지만 OS 유연성 낮음

**Software-managed TLB (예: MIPS)**:
- TLB miss → OS로 trap
- OS가 page table 탐색 후 TLB에 직접 삽입
- 느리지만 OS가 page table 구조를 자유롭게 설계 가능

### Context Switch와 TLB

**문제**: 프로세스 A의 TLB 항목이 프로세스 B에서 잘못 사용될 수 있음.

**해결 1: TLB Flush**
Context switch 시 TLB 전체 무효화. 단순하지만 miss rate ↑

**해결 2: ASID**
각 TLB 항목에 ASID 기록 → 같은 VPN이어도 ASID 다르면 다른 프로세스 항목 → flush 불필요

## Policy (왜 이렇게 설계했는가)

**TLB 성능 결정 요소:**

| 요소 | 영향 |
|------|------|
| TLB 크기 (항목 수) | 클수록 hit rate ↑ |
| Page 크기 | 클수록 한 항목으로 커버 범위 ↑ (TLB reach 증가) |
| 프로그램 Locality | Locality 좋으면 hit rate ↑ |
| ASID 지원 | Context switch 비용 감소 |

**TLB Reach** = TLB 항목 수 × Page 크기
= 프로그램이 TLB hit으로 접근 가능한 최대 메모리 크기

> [!important]
> Page 크기를 키우면 Internal Fragmentation이 증가한다.
> TLB Reach와 단편화 사이의 Trade-off.
> 일부 시스템은 **Superpages**(huge pages, 2MB/1GB)로 이를 선택적으로 활용.

## 내 정리
결국 이 챕터는 **Paging의 속도 문제를 하드웨어 캐시(TLB)로 해결**하는 방법을 설명한다. 대부분의 접근은 TLB Hit이 되어 page table 조회 없이 빠르게 변환된다. Locality가 좋은 프로그램일수록 TLB hit rate가 높다. Context Switch 시 ASID로 TLB flush 비용을 줄일 수 있다.

## 연결
- 이전: Ch.18 - Introduction to Paging
- 다음: Ch.20 - Paging - Smaller Tables
- 관련 개념: TLB, Page Table, Page Fault, Address Translation
