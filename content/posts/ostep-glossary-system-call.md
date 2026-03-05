+++
date = '2026-02-19T18:00:00+09:00'
draft = false
title = '[OSTEP 용어] System Call'
description = "OSTEP 핵심 용어 정리 - System Call"
tags = ["OS", "OSTEP", "OS 용어"]
categories = ["OS"]
series = ["OSTEP 정리"]
+++
## 정의
User Mode에서 실행 중인 프로세스가 Kernel Mode의 기능(I/O, 메모리 할당, 프로세스 생성 등)을 요청하기 위한 공식적이고 제어된 인터페이스.

## 동작 원리

```
User Process              OS (Kernel)
──────────                ──────────
read() 호출
  ↓
trap 명령어 실행 ───────→
                          레지스터를 커널 스택에 저장
                          커널 모드 전환
                          trap table에서 handler 찾기
                          system call number 확인
                          실제 작업 수행 (디스크 읽기 등)
                          return-from-trap
  ←─────────────────────
유저 모드 복귀
read() 반환값 사용
```

**System Call은 왜 일반 함수 호출처럼 보이는가?**
실제로는 C 라이브러리 함수가 감싸고 있다. 내부적으로:
1. 인자들을 레지스터/스택의 약속된 위치에 배치
2. 시스템 콜 번호를 특정 레지스터에 설정
3. `trap` 명령어 실행 (x86: `int 0x80`, 현대: `syscall`)
4. OS가 처리 후 return-from-trap
5. 반환값 추출

**주요 System Call 예:**
| 분류 | System Call |
|------|------------|
| 프로세스 | `fork()`, `exec()`, `wait()`, `exit()` |
| 파일 I/O | `open()`, `read()`, `write()`, `close()` |
| 메모리 | `mmap()`, `brk()` |
| 통신 | `pipe()`, `socket()` |

## 왜 중요한가
System Call이 없으면 두 가지 중 하나다: 프로세스에 모든 권한을 줘서 시스템이 위험해지거나, 아무것도 못 하게 제한해서 쓸모없어진다. System Call은 이 둘 사이의 균형점 — **안전하게 통제된 권한 상승**.

## 관련
- 메커니즘: Trap, PCB (Process Control Block)
- 관련 챕터: Ch.06 - Mechanism - Limited Direct Execution, Ch.05 - Interlude - Process API
