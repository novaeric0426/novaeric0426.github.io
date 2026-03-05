+++
date = '2026-02-21T18:00:00+09:00'
draft = false
title = '[OSTEP 용어] TLB'
description = "OSTEP 핵심 용어 정리 - TLB"
tags = ["OS", "OSTEP", "OS 용어"]
categories = ["OS"]
series = ["OSTEP 정리"]
+++
## 정의
최근의 가상↔물리 주소 변환 결과를 캐싱하는 MMU 내 하드웨어 캐시. 매번 page table을 조회하는 대신 TLB에서 빠르게 변환 결과를 얻는다. "address-translation cache"가 더 정확한 이름.

## 동작 원리

```
메모리 접근 시:
1. VPN으로 TLB 검색
2. TLB Hit → PFN 즉시 반환 (매우 빠름 ~ 1ns)
3. TLB Miss → Page Table 조회 (메모리 접근 추가, ~수십ns~수백μs)
           → TLB에 새 항목 삽입 → 재시도 (이번엔 Hit)
```

**TLB 항목 구조:**
```
VPN | PFN | Valid | Protection | ASID
```

**ASID (Address Space Identifier):**
Context Switch 시 TLB를 flush하면 성능 손실. ASID로 각 항목에 프로세스 ID 기록 → 다른 프로세스 항목과 구분 → flush 불필요.

**TLB 성능의 핵심 = 지역성(Locality):**
- 시간적 지역성: 같은 페이지 반복 접근 → Hit
- 공간적 지역성: 같은 페이지 내 연속 접근 → Hit
- 배열 순회처럼 지역성 좋은 코드 = TLB 친화적

**TLB Miss 처리:**
- Hardware-managed (x86): 하드웨어가 page table 탐색
- Software-managed (MIPS): OS에 trap, OS가 page table 탐색 후 TLB 삽입

## 왜 중요한가
TLB가 없으면 모든 메모리 접근이 2배 이상 느려진다. TLB는 가상 메모리를 실용적으로 만드는 핵심 하드웨어. Hit rate가 높으면 페이지 테이블 구조 복잡성(multi-level 등)의 비용이 희석된다.

> TLB reach = TLB 항목 수 × Page 크기 = TLB Hit으로 커버 가능한 최대 메모리

## 관련
- 상위 개념: Page Table, Virtual Address Space
- 관련 챕터: Ch.19 - Paging - Faster Translations (TLBs)
