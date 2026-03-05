+++
date = '2026-02-28T18:00:00+09:00'
draft = false
title = '[OSTEP 용어] Trap'
description = "OSTEP 핵심 용어 정리 - Trap"
tags = ["OS", "OSTEP", "OS 용어"]
categories = ["OS"]
series = ["OSTEP 정리"]
+++
## 정의
User Mode에서 Kernel Mode로 전환하는 하드웨어 메커니즘. System Call, 예외(Exception), Interrupt 모두 Trap을 통해 OS로 진입한다.

## 동작 원리

**Trap 발생 시 하드웨어가 하는 일:**
1. 현재 PC, flags, 레지스터들을 **커널 스택**에 저장 (나중에 복귀 위해)
2. CPU 모드를 Kernel Mode로 전환
3. **Trap Table**에서 해당 이벤트의 핸들러 주소를 찾아 점프

**Trap Table:**
- OS가 부팅 시 하드웨어에 등록하는 "이벤트 → 핸들러" 매핑
- 등록 명령어 자체가 특권 명령어 (유저 프로세스는 변경 불가)
- 내용: system call handler, 타이머 인터럽트 핸들러, 하드디스크 인터럽트 핸들러...

**return-from-trap:**
- OS 처리 후 사용자 프로그램으로 복귀
- 저장해뒀던 레지스터/PC를 복원하고 User Mode로 전환

**Trap의 세 가지 유형:**

| 유형 | 원인 | 예 |
|------|------|-----|
| System Call | 프로그램이 의도적으로 | `read()`, `fork()` |
| Exception | 프로그램 오류 | division by zero, segfault |
| Interrupt | 외부 하드웨어 이벤트 | 타이머, 디스크 I/O 완료 |

```
부팅 시: OS가 trap table 설정
  ↓
실행 중: 프로그램이 trap 명령어 실행
  ↓
하드웨어: 레지스터 저장 + 커널 모드로 전환 + 핸들러로 점프
  ↓
OS: 요청 처리
  ↓
return-from-trap: 레지스터 복원 + 유저 모드로 전환
```

## 왜 중요한가
Trap이 없으면 User Mode와 Kernel Mode를 안전하게 넘나들 수 없다. 프로그램이 임의의 커널 주소로 점프할 수 있다면 OS 전체가 뚫린다. Trap은 "허가된 진입점만" 사용하게 강제함으로써 보안을 지킨다.

## 관련
- 사용 맥락: System Call
- 관련 개념: User Mode, Interrupt
- 등장 챕터: Ch.06 - Mechanism - Limited Direct Execution
