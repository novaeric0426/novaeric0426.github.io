+++
date = '2026-02-05T18:00:00+09:00'
draft = false
title = '[OSTEP 용어] Segmentation'
description = "OSTEP 핵심 용어 정리 - Segmentation"
tags = ["OS", "OSTEP", "OS 용어"]
categories = ["OS"]
series = ["OSTEP 정리"]
+++
## 정의
프로세스 Address Space를 논리적 세그먼트(Code, Heap, Stack)로 나누고, 각 세그먼트에 독립적인 base/bounds 레지스터 쌍을 부여하는 메모리 가상화 기법.

## 동작 원리

**각 세그먼트 독립 배치:**
```
Segment  Base   Size  Grows Positive?  Protection
Code     32KB   2KB   Yes              Read-Execute
Heap     34KB   3KB   Yes              Read-Write
Stack    28KB   2KB   No (↑방향)       Read-Write
```

**가상 주소 변환:**
```
Virtual Address = [Seg(2비트)] [Offset(나머지)]
↓
Seg bits로 레지스터 선택
Physical = Base[Seg] + Offset
if Offset >= Bounds[Seg]: PROTECTION_FAULT
```

**장점:**
- Base/Bounds 대비 물리 메모리 낭비 감소 (세그먼트 사이 빈 공간 없음)
- 코드 공유: Read-only 세그먼트를 여러 프로세스가 공유 가능

**단점: External Fragmentation (외부 단편화)**
```
시간이 지나면:
[Used:8KB] [Free:4KB] [Used:12KB] [Free:6KB] [Used:8KB]
→ 총 10KB 비어있지만 15KB 요청 불가 (연속 공간 없음)
```

**"segmentation fault" 용어의 기원:**
세그먼트 경계를 넘는 접근 → OS가 exception 발생. 오늘날 Segmentation을 안 쓰는 시스템에서도 관용적으로 사용됨.

## 왜 중요한가
Base/Bounds의 낭비 문제를 개선했지만, 외부 단편화라는 새 문제를 도입한다. 가변 크기 세그먼트 = 근본적인 단편화 문제. 이를 해결하기 위해 **Paging**(고정 크기)이 등장한다. Segmentation은 역사적으로 중요하고, 개념은 여전히 일부 시스템에서 활용된다(x86의 유산적 지원).

## 관련
- 전 단계: Base/Bounds Address Translation
- 다음 단계: Page Table (Paging)
- 핵심 문제: External Fragmentation
- 등장 챕터: Ch.16 - Segmentation, Ch.17 - Free Space Management
