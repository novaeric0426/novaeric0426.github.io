+++
date = '2026-02-10T18:00:00+09:00'
draft = false
title = '[OSTEP 용어] Space Sharing'
description = "OSTEP 핵심 용어 정리 - Space Sharing"
tags = ["OS", "OSTEP", "OS 용어"]
categories = ["OS"]
series = ["OSTEP 정리"]
+++
## 정의
하나의 자원(주로 메모리)을 여러 프로세스가 **공간적으로 나눠 사용**하게 하는 기법. 각 프로세스는 전체 공간의 일부를 독점적으로 점유하며, 서로의 영역을 침범할 수 없다.

## 동작 원리

```
물리 메모리:
┌─────────────────┐ 0
│      OS         │
├─────────────────┤
│   Process A     │ ← A만의 공간
│   Address Space │
├─────────────────┤
│   Process B     │ ← B만의 공간
│   Address Space │
├─────────────────┤
│   Process C     │ ← C만의 공간
│   Address Space │
└─────────────────┘ MAX
```

각 프로세스는 자신의 Virtual Address Space를 가지며, OS와 하드웨어(Page Table, Segmentation)가 경계를 강제한다. 프로세스 A가 B의 메모리를 읽으려 하면 → 하드웨어가 차단 → Page Fault 또는 segfault.

### Time Sharing vs Space Sharing

| | Time Sharing | Space Sharing |
|---|---|---|
| 대상 자원 | CPU | 메모리 (디스크도 해당) |
| 분할 방식 | 시간적 (번갈아 사용) | 공간적 (동시에 각자 소유) |
| 동시성 | 가상적 (빠른 교대) | 실제 (동시에 존재) |
| 핵심 기술 | Context Switch, Scheduling Policy | Virtual Address Space, Page Table |

> [!important]
> CPU는 Time Sharing으로, 메모리는 Space Sharing으로 가상화한다.
> 이 두 축이 OS Virtualization 파트 전체를 구성한다.

디스크도 Space Sharing: 파일 시스템이 디스크 블록을 파일별로 나눠 할당한다 (Inode 참조).

## 왜 중요한가

Space Sharing이 없으면 프로세스 간 메모리 격리가 불가능하다. A 프로세스 버그가 B의 메모리를 덮어쓰고, 악성 프로그램이 OS 커널 메모리를 읽어 보안이 무너진다. Virtual Address Space 추상화가 이 격리를 보장한다.

## 관련
- 짝 개념: Time Sharing
- 구현 메커니즘: Virtual Address Space, Page Table, Segmentation
- 등장 챕터: Ch.02 - Introduction to Operating Systems, Ch.04 - The Abstraction - The Process, Ch.13 - The Abstraction - Address Spaces
