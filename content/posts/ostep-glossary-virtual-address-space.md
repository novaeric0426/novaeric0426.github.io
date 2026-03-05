+++
date = '2026-03-05T18:00:00+09:00'
draft = false
title = '[OSTEP 용어] Virtual Address Space'
description = "OSTEP 핵심 용어 정리 - Virtual Address Space"
tags = ["OS", "OSTEP", "OS 용어"]
categories = ["OS"]
series = ["OSTEP 정리"]
+++
## 정의
OS가 각 프로세스에게 제공하는 메모리 추상화. 프로세스는 자신만의 거대한 연속 메모리가 있다고 착각하지만, 실제로는 OS+하드웨어가 가상 주소를 물리 주소로 변환한다.

## 동작 원리

**Address Space 내부 구조:**
```
0 ┌─────────┐
  │  Code   │  (정적 — 프로그램 명령어)
  ├─────────┤
  │  Heap   │  ↓ (malloc으로 성장)
  │         │
  │  (free) │  ← sparse area (실제 물리 메모리 없음)
  │         │
  │  Stack  │  ↑ (함수 호출로 성장)
  └─────────┘ max
```

**핵심 특성:**
- 프로그래머가 보는 주소는 모두 **가상 주소**
- 실제 물리 주소는 OS와 MMU만 앎
- 여러 프로세스가 같은 가상 주소를 갖더라도 서로 다른 물리 주소에 매핑

**목표:**
1. **Transparency**: 프로그램은 가상화를 모름
2. **Efficiency**: TLB, Hardware 지원으로 빠르게
3. **Protection**: 다른 프로세스 메모리 접근 불가

## 왜 중요한가
Virtual Address Space 없이는 모든 프로그램이 물리 주소를 직접 다뤄야 한다. 한 프로세스가 다른 프로세스 메모리를 덮어쓸 수 있어 Isolation 불가능. Address Space 덕분에 프로세스 간 완벽한 격리와 멀티태스킹이 가능하다.

## 관련
- 구현 메커니즘: Address Translation, Page Table, TLB
- 등장 챕터: Ch.13 - The Abstraction - Address Spaces, Ch.15 - Mechanism - Address Translation, Ch.18 - Introduction to Paging
