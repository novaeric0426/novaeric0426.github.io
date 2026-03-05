+++
date = '2026-01-22T18:00:00+09:00'
draft = false
title = '[OSTEP 용어] Page Fault'
description = "OSTEP 핵심 용어 정리 - Page Fault"
tags = ["OS", "OSTEP", "OS 용어"]
categories = ["OS"]
series = ["OSTEP 정리"]
+++
## 정의
프로세스가 접근하려는 가상 페이지가 현재 물리 메모리에 없을 때 발생하는 이벤트. 불법 접근이 아니라 합법적이지만 메모리에 없는 페이지를 디스크에서 가져와야 함을 OS에 알리는 신호.

## 동작 원리

**발생 조건:** PTE의 Present bit = 0 (페이지가 swap space나 파일 시스템에 있음)

**처리 흐름:**
```
1. 하드웨어: PTE.Present = 0 감지 → OS로 trap (PAGE_FAULT exception)
2. OS: page fault handler 실행
3. OS: PTE에서 disk address 읽기
4. OS: 물리 메모리에 빈 frame 찾기
   - 없으면: Page Replacement Policy로 희생 page 선택해서 swap out
5. OS: 디스크에서 페이지 읽기 (I/O) → 이 시간 동안 프로세스 BLOCKED
   → OS가 다른 프로세스 실행 (CPU 활용도 ↑)
6. I/O 완료: PTE 업데이트 (Present=1, PFN 설정)
7. 원래 명령어 재실행 → 이번엔 TLB hit
```

**Page Fault vs Segfault:**
- Page Fault: 합법적 접근인데 메모리에 없음 → OS가 처리, 프로그램 계속
- Segfault: 잘못된 접근 (invalid PTE, 권한 위반) → 프로세스 종료

**Demand Paging:**
프로세스 시작 시 모든 페이지를 미리 로드하지 않음. 실제 접근 시 Page Fault를 통해 그때그때 로드. 빠른 시작 + 실제 사용 페이지만 물리 메모리 사용.

## 왜 중요한가
Page Fault가 없으면 각 프로세스가 자신의 모든 페이지를 항상 물리 메모리에 유지해야 한다. Swap 불가 = 동시 실행 프로세스 수 급감 = 멀티태스킹 제한. Page Fault는 비싸지만(~ms), 덕분에 메모리보다 큰 address space와 다수의 동시 프로세스가 가능하다.

## 관련
- 처리 방법: Swapping
- 관련 자료구조: Page Table, TLB
- 등장 챕터: Ch.21 - Beyond Physical Memory - Mechanisms, Ch.22 - Beyond Physical Memory - Policies
