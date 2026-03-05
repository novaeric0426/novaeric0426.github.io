+++
date = '2026-02-17T18:00:00+09:00'
draft = false
title = '[OSTEP 용어] Swapping'
description = "OSTEP 핵심 용어 정리 - Swapping"
tags = ["OS", "OSTEP", "OS 용어"]
categories = ["OS"]
series = ["OSTEP 정리"]
+++
## 정의
물리 메모리가 부족할 때, 당장 필요 없는 페이지를 디스크(swap space)로 내보내고(page out), 필요해질 때 다시 메모리로 가져오는(page in) 메커니즘.

## 동작 원리

**Swap Space**: 디스크의 일부를 페이지 임시 저장용으로 예약한 공간.

```
Physical Memory:    Swap Space (Disk):
┌──────────┐        ┌──────┬──────┬──────┐
│ Page A   │ ←→     │      │PgB   │PgC   │
│ (active) │        │(free)│(swap)│(swap)│
└──────────┘        └──────┴──────┴──────┘
```

**Page Out (Swap Out):**
1. 교체 정책으로 희생 페이지 선택 (LRU, Clock 등)
2. Dirty page라면 디스크에 쓰기
3. PTE의 Present bit = 0, disk address 기록
4. 물리 frame 해제 → 다른 용도로 사용

**Page In (Swap In = Page Fault 처리):**
1. Page Fault 발생 (Present bit = 0)
2. 디스크에서 페이지 읽기
3. 물리 frame에 적재
4. PTE 업데이트 (Present=1, PFN 설정)
5. 명령어 재실행

**Thrashing**: 프로세스의 Working Set이 물리 메모리보다 크면 끊임없이 swap in/out → 성능 급락.

## 왜 중요한가
Swapping 없이는 모든 프로세스의 모든 페이지가 항상 물리 메모리에 있어야 한다. 메모리 크기 = 동시 실행 가능 프로세스 총 메모리 사용량 제한 → 실용적이지 않음. Swapping으로 물리 메모리보다 훨씬 많은 프로세스를 실행할 수 있다.

## 관련
- 발생 트리거: Page Fault
- 관련 자료구조: Page Table
- 등장 챕터: Ch.21 - Beyond Physical Memory - Mechanisms, Ch.22 - Beyond Physical Memory - Policies
