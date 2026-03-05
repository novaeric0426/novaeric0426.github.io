+++
date = '2026-01-27T18:00:00+09:00'
draft = false
title = '[OSTEP 용어] Process'
description = "OSTEP 핵심 용어 정리 - Process"
tags = ["OS", "OSTEP", "OS 용어"]
categories = ["OS"]
series = ["OSTEP 정리"]
+++
## 정의
실행 중인 프로그램. 디스크에 죽어있는 바이트(프로그램)를 OS가 메모리에 올려 실행하는 순간 Process가 된다. OS가 사용자에게 제공하는 가장 근본적인 추상화.

## 동작 원리

Process의 Machine State (프로세스를 완전히 표현하는 요소):
- **Address Space**: 코드, 데이터, 스택, 힙이 들어있는 메모리 영역
- **Registers**: PC(다음 실행할 명령어 주소), SP(스택 포인터), 범용 레지스터
- **I/O 정보**: 열린 파일 목록 등

**Process 생성 과정:**
1. 프로그램을 디스크에서 메모리(Address Space)로 로드
2. 스택 할당 + `argc`/`argv` 초기화
3. 힙 공간 준비
4. 표준 입출력 파일 디스크립터 연결
5. `main()`으로 점프

**Process States:**
```
New → Ready ⇆ Running → Terminated
              ↓↑
           Blocked (I/O 대기)
```

OS는 Process List(PCB들의 집합)를 통해 모든 프로세스를 추적.

## 왜 중요한가
Process 추상화 없이는 프로그램마다 직접 하드웨어를 관리해야 한다. Process 덕분에 각 프로그램은 자기가 CPU와 메모리를 독점한다고 착각할 수 있다 (Isolation). 이게 멀티태스킹의 기반.

## 관련
- 상위 개념: Time Sharing, Virtualization
- 하위/구현: PCB (Process Control Block), Context Switch
- 등장 챕터: Ch.04 - The Abstraction - The Process, Ch.05 - Interlude - Process API
