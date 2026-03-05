+++
date = '2025-12-09T18:00:00+09:00'
draft = false
title = '[OSTEP 용어] Address Space'
description = "OSTEP 핵심 용어 정리 - Address Space"
tags = ["OS", "OSTEP", "OS 용어"]
categories = ["OS"]
series = ["OSTEP 정리"]
+++
## 정의
OS가 각 프로세스에게 제공하는 **메모리 추상화**. 프로세스는 자신만의 거대하고 독점적인 메모리 공간이 있다고 착각하지만, 실제로는 여러 프로세스가 물리 메모리를 공유하고 있다.

> 추상화 관점에서는 "Address Space", 가상화 구현 관점에서는 Virtual Address Space — 같은 대상을 다른 층위로 부르는 것.

## 동작 원리

### 내부 구조

```
가상 주소 0 ┌───────────┐
            │   Code    │  프로그램 명령어 (정적, 크기 고정)
            ├───────────┤
            │   Heap    │  ↓ 동적 할당 (malloc), 아래로 성장
            │           │
            │  (빈 공간) │  sparse — 실제 물리 메모리 미할당
            │           │
            │   Stack   │  ↑ 함수 호출, 위로 성장
가상 주소 max└───────────┘
```

프로그래머가 보는 모든 포인터 주소는 **가상 주소(Virtual Address)**다. 실제 물리 위치는 OS와 MMU만 안다.

### 메모리 가상화의 3대 목표

| 목표 | 의미 |
|------|------|
| **Transparency** | 프로세스는 가상화 사실을 모른다. 자신이 메모리 전체를 독점한다고 착각 |
| **Efficiency** | 변환 오버헤드 최소화 (TLB 활용), 불필요한 메모리 낭비 없이 |
| **Protection** | 프로세스 간 격리. A가 B의 주소를 읽거나 쓸 수 없음 |

### Address Space가 없던 시절

초기 OS는 한 번에 하나의 프로세스만 메모리에 올렸다. 멀티태스킹을 하려면 프로세스를 통째로 디스크에 swap out/in — 너무 느려서 실용적이지 않았다. Address Space 추상화 덕분에 여러 프로세스가 동시에 메모리에 상주할 수 있게 됐다.

## 왜 중요한가

Address Space가 없으면:
- 프로세스가 다른 프로세스의 메모리를 직접 읽고 쓸 수 있다 → 보안·안정성 붕괴
- 프로그램이 물리 주소를 직접 계산해야 한다 → 재배치 불가, 이식성 없음
- OS 자체 메모리도 프로세스가 덮어쓸 수 있다

Address Space는 Space Sharing의 핵심 구현체다 — 물리 메모리를 프로세스별로 공간 분할하는 것.

## 관련
- 가상화 구현: Virtual Address Space, Address Translation
- 격리 메커니즘: Page Table, Segmentation
- 상위 개념: Space Sharing
- 등장 챕터: Ch.13 - The Abstraction - Address Spaces, Ch.15 - Mechanism - Address Translation
