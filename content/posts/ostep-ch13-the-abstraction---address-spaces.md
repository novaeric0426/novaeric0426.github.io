+++
date = '2025-12-29T10:00:00+09:00'
draft = false
title = '[OSTEP] Ch.13 - The Abstraction - Address Spaces'
description = "OSTEP 메모리 가상화 파트 - The Abstraction - Address Spaces 정리 노트"
tags = ["OS", "OSTEP", "Virtualization"]
categories = ["OS"]
series = ["OSTEP 정리"]
+++
## Crux (핵심 문제)
> 여러 프로세스가 물리 메모리를 공유하는 상황에서, OS는 각 프로세스에게 거대하고 사적인(private) 메모리 공간이 있다는 illusion을 어떻게 제공하는가?

## 배경 & 동기

**초기 시스템**: OS + 프로그램 하나가 메모리 전체를 독점. 간단하지만 멀티태스킹 불가.

**Multiprogramming 시대**: 여러 프로세스가 메모리에 동시 상주. 문제 발생:
- **보호(Protection)**: 프로세스 A가 B의 메모리를 읽거나 쓰면 안 된다.
- **효율성**: 프로세스 교체 시 전체 메모리를 디스크에 저장/복원하면 너무 느리다.

→ 해결책: 메모리 추상화 = **Address Space**

## Mechanism (어떻게 동작하는가)

### Address Space 구조

각 프로세스는 자신만의 Address Space를 갖는다 (실제론 가상이지만 프로세스는 독점이라 착각).

```
0KB   ┌─────────────┐
      │    Code     │  ← 정적 (크기 고정)
1KB   ├─────────────┤
      │    Heap     │  ↓ 아래로 성장 (malloc)
2KB   ├─────────────┤
      │   (free)    │
      │             │
15KB  ├─────────────┤
      │    Stack    │  ↑ 위로 성장 (함수 호출)
16KB  └─────────────┘
```

- **Code**: 프로그램 명령어. 정적이라 상단 고정.
- **Heap**: 동적 할당(malloc). 코드 아래에서 아래로 성장.
- **Stack**: 지역 변수, 함수 인자, 반환 주소. 하단에서 위로 성장.

> [!important]
> 프로그래머가 보는 모든 주소는 **Virtual Address**다.
> 실제 물리 주소는 OS와 하드웨어만 안다. 프로그램에서 포인터를 출력하면 나오는 값도 가상 주소.

```c
int *p = malloc(100e6);
printf("heap addr: %p\n", p);   // 가상 주소 출력됨
printf("stack addr: %p\n", &x); // 역시 가상 주소
```

### 메모리 가상화의 목표

| 목표 | 내용 |
|------|------|
| **Transparency** | 프로그램이 가상화 사실을 모른다. 자신이 메모리를 독점한다고 생각 |
| **Efficiency** | 시간적(느려지지 않게) + 공간적(불필요한 구조체 최소화) |
| **Protection** | 프로세스 간, 프로세스-OS 간 격리. 다른 공간 접근 불가 |

**Isolation 원칙**: 한 프로세스가 죽어도 다른 프로세스에 영향 없음. 각 프로세스는 자기만의 cocoon 안에.

## Policy (왜 이렇게 설계했는가)

**초기 방식 (디스크 swap)**: 프로세스 교체 시 전체 메모리를 디스크에 저장. 너무 느림.

**Address Space 방식**: 각 프로세스에 가상 주소 공간 부여 + OS+하드웨어가 실시간으로 가상↔물리 변환. 여러 프로세스가 메모리에 동시 상주 가능.

## 내 정리
결국 이 챕터는 **메모리 가상화의 핵심 개념인 Address Space를 소개**한다. 프로그램이 보는 메모리(가상)와 실제 메모리(물리)를 분리함으로써, 각 프로세스는 메모리 전체를 독점한다는 착각 속에서 동작할 수 있다. Transparency + Efficiency + Protection이 VM 설계의 3대 목표.

## 연결
- 이전: Ch.10 - Multiprocessor Scheduling
- 다음: Ch.14 - Interlude - Memory API
- 관련 개념: Virtual Address Space, Address Translation, Page Fault
