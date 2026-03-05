+++
date = '2025-12-11T10:00:00+09:00'
draft = false
title = '[OSTEP] Ch.02 - Introduction to Operating Systems'
description = "OSTEP 가상화 파트 - Introduction to Operating Systems 정리 노트"
tags = ["OS", "OSTEP", "Virtualization"]
categories = ["OS"]
series = ["OSTEP 정리"]
+++
## Crux (핵심 문제)
> OS는 어떻게 물리 자원(CPU, 메모리, 디스크)을 가상화해서 여러 프로그램이 동시에 실행되는 것처럼 보이게 하는가? 그 과정에서 효율성, 보안, 사용 편의성을 어떻게 동시에 달성하는가?

## 배경 & 동기

프로그램은 실행되는 동안 단순히 명령어를 순서대로 실행한다(Von Neumann 모델). 그런데 실제 우리가 쓰는 컴퓨터는 수십 개의 프로그램이 "동시에" 돌아간다. 단일 CPU가 이걸 어떻게 하는가? — 이게 이 책 전체의 핵심 질문이다.

OS는 이 문제를 **Virtualization(가상화)**으로 푼다: 물리 자원을 더 강력하고 쓰기 쉬운 가상 형태로 바꿔준다. 그래서 OS를 **virtual machine**이라고 부르기도 한다.

## Mechanism (어떻게 동작하는가)

### CPU 가상화
CPU 하나를 여러 프로그램이 쓰는 것처럼 보이게 하는 핵심 기술: **Time Sharing**.

```c
// cpu.c — 무한 루프 프로그램 4개를 동시에 실행하면?
while (1) {
    Spin(1);
    printf("%s\n", str);
}
```

```
prompt> ./cpu A & ./cpu B & ./cpu C & ./cpu D &
A B D C A B D C ...  ← CPU 하나인데 4개가 동시에 돌아가는 것처럼 보임
```

OS가 프로세스를 빠르게 교대로 실행하기 때문에 illusion이 생긴다.

### 메모리 가상화
각 프로세스는 자기만의 메모리 공간(Address Space)을 가진다고 착각한다.

```c
// mem.c — 같은 주소인데 값이 다르다?
int *p = malloc(sizeof(int));
printf("(%d) addr of p: %x\n", getpid(), (int) p);
*p = 0;
while (1) {
    (*p)++;
    printf("(%d) p: %d\n", getpid(), *p);
}
```

두 프로세스가 같은 가상 주소를 사용해도, OS+하드웨어가 각자 다른 물리 주소로 매핑해줘서 서로 간섭하지 않는다.

### OS의 세 가지 역할
1. **Virtualizer** — 자원을 가상화해서 쓰기 쉽게 만든다
2. **Standard Library** — 수백 개의 System Call로 프로그램에 서비스 제공
3. **Resource Manager** — CPU, 메모리, 디스크를 효율적/공정하게 분배

## Policy (왜 이렇게 설계했는가)

| 관점 | 내용 |
|------|------|
| **Mechanism** | "어떻게" — Context Switch, Trap 등 구체적 구현 방법 |
| **Policy** | "무엇을" — 어떤 프로세스를 언제 실행할지 결정 |

> [!important]
> **Mechanism vs Policy** 하는 것은 OS 설계의 핵심 원칙이다.
> Policy를 바꿔도 Mechanism은 그대로 유지할 수 있다 → 모듈성(Modularity).

**Trade-off의 예:**
- Time sharing → CPU 이용률 ↑, 단일 프로세스 속도 ↓
- 메모리 가상화 → 편의성 ↑, 하드웨어 지원 필요

## 내 정리
결국 이 챕터는 **OS가 무엇인지 큰 그림을 잡기** 위해 **가상화라는 핵심 개념을 세 자원(CPU, Memory, Disk)에 적용해 보여준다**. OS는 단순한 관리자가 아니라, 물리 자원을 마술처럼 늘려서 다수의 프로그램이 공존하게 해주는 추상화 레이어다.

> [!important]
> **Virtualization + Concurrency + Persistence** — 이 세 가지가 OSTEP 전체의 뼈대다.

## 연결
- 이전: (없음 — 시작)
- 다음: Ch.04 - The Abstraction - The Process
- 관련 개념: Process, System Call, Time Sharing
