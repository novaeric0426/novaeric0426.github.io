+++
date = '2026-01-20T18:00:00+09:00'
draft = false
title = '[OSTEP 용어] PCB (Process Control Block)'
description = "OSTEP 핵심 용어 정리 - PCB (Process Control Block)"
tags = ["OS", "OSTEP", "OS 용어"]
categories = ["OS"]
series = ["OSTEP 정리"]
+++
## 정의
OS가 각 프로세스에 대해 유지하는 자료구조. 프로세스의 모든 상태 정보를 담고 있다. "프로세스의 주민등록증" 같은 것.

## 동작 원리

xv6에서의 `struct proc`:
```c
struct proc {
    char *mem;              // Address Space 시작 주소
    uint sz;                // 메모리 크기
    char *kstack;           // 커널 스택 (Context Switch 시 사용)
    enum proc_state state;  // RUNNING, READY, BLOCKED, ZOMBIE...
    int pid;                // Process ID
    struct proc *parent;    // 부모 프로세스 포인터
    struct context context; // 저장된 레지스터 (Context Switch용)
    struct trapframe *tf;   // 현재 인터럽트의 Trap Frame
    struct file *ofile[];   // 열린 파일 목록
    struct inode *cwd;      // 현재 디렉토리
};
```

**Process List**: 모든 PCB를 담은 링크드 리스트 (또는 해시 테이블).
OS는 이 리스트를 뒤져서 Ready/Blocked 프로세스를 관리.

**Context Switch 시 PCB 역할:**
1. 실행 중이던 프로세스의 레지스터를 PCB의 `context`에 저장
2. 다음 프로세스의 PCB에서 `context`를 복원
3. 복원된 PC로 점프해서 실행 재개

## 왜 중요한가
PCB가 없으면 Context Switch가 불가능하다. 프로세스를 잠시 멈추고 나중에 정확히 그 시점부터 재개하려면 모든 상태를 어딘가에 저장해야 한다. PCB가 바로 그 저장소.

## 관련
- 상위 개념: Process
- 관련 메커니즘: Context Switch
- 등장 챕터: Ch.04 - The Abstraction - The Process, Ch.06 - Mechanism - Limited Direct Execution
