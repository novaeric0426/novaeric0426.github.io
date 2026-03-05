+++
date = '2025-12-23T18:00:00+09:00'
draft = false
title = '[OSTEP 용어] Context Switch'
description = "OSTEP 핵심 용어 정리 - Context Switch"
tags = ["OS", "OSTEP", "OS 용어"]
categories = ["OS"]
series = ["OSTEP 정리"]
+++
## 정의
OS가 현재 실행 중인 프로세스를 멈추고 다른 프로세스를 실행하기 위해, 현재 프로세스의 CPU 상태(레지스터, PC 등)를 저장하고 다음 프로세스의 상태를 복원하는 과정.

## 동작 원리

Context Switch는 두 단계 저장/복원으로 이루어진다:

**1단계: 하드웨어가 처리 (타이머 인터럽트 시)**
- 유저 레벨 레지스터들을 현재 프로세스의 **커널 스택**에 저장
- 커널 모드로 전환, OS 코드 실행

**2단계: OS가 처리 (스케줄러 결정 후)**
```c
// xv6의 swtch() 함수 개념
void swtch(struct context **old, struct context *new) {
    // 현재 레지스터들을 old->context에 저장
    // new->context의 레지스터들을 CPU에 복원
    // new의 PC로 점프
}
```

**전체 흐름:**
```
Process A 실행
  ↓ 타이머 인터럽트
하드웨어: A의 user regs → A의 커널 스택
OS: A의 커널 regs → A의 PCB(context)
OS: B의 PCB(context) → 커널 레지스터 복원
하드웨어: B의 커널 스택 → B의 user regs
Process B 실행 재개
```

**비용:**
- 직접 비용: 레지스터 저장/복원 시간
- 간접 비용: TLB flush, CPU cache 오염 (다른 프로세스의 데이터로 채워짐)

## 왜 중요한가
Context Switch가 없으면 Time Sharing이 불가능하다. CPU 가상화의 핵심 메커니즘. 단, Context Switch가 너무 잦으면 오버헤드가 커진다 → time slice 길이 조정이 중요.

## 관련
- 상위 개념: Process, PCB (Process Control Block)
- 트리거: 타이머 인터럽트, System Call, I/O 블록
- 등장 챕터: Ch.04 - The Abstraction - The Process, Ch.06 - Mechanism - Limited Direct Execution
