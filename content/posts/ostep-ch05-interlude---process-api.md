+++
date = '2025-12-15T10:00:00+09:00'
draft = false
title = '[OSTEP] Ch.05 - Interlude - Process API'
description = "OSTEP CPU 가상화 파트 - Interlude - Process API 정리 노트"
tags = ["OS", "OSTEP", "Virtualization"]
categories = ["OS"]
series = ["OSTEP 정리"]
+++
## Crux (핵심 문제)
> OS는 프로세스 생성과 제어를 위해 어떤 인터페이스를 제공해야 하는가? 강력하면서도 단순하게 설계하려면?

## 배경 & 동기

Ch.04에서 프로세스가 무엇인지 알았다. 이제 실제로 Unix에서 프로세스를 어떻게 만들고 제어하는지 — API 레벨 — 을 다룬다. Unix의 프로세스 생성 방식은 상당히 독특하다: `fork()` + `exec()` 조합.

## Mechanism (어떻게 동작하는가)

### `fork()` — 자식 프로세스 생성

```c
int rc = fork();
if (rc < 0) {      // fork 실패
    exit(1);
} else if (rc == 0) {
    printf("child (pid:%d)\n", getpid());  // 자식: rc = 0
} else {
    printf("parent of %d\n", rc);          // 부모: rc = 자식 PID
}
```

`fork()`의 핵심:
- 부모 프로세스의 **완전한 복사본**을 만든다 (메모리, 레지스터, PC 등)
- 부모에게는 자식의 PID를, 자식에게는 0을 반환해서 둘을 구분
- 부모와 자식 중 **누가 먼저 실행될지는 스케줄러가 결정** → 비결정적

> [!important]
> `fork()` 이후 부모/자식의 실행 순서는 보장되지 않는다.
> 이 비결정성이 나중에 Concurrency 문제의 근원이 된다.

### `wait()` — 자식 종료 대기

```c
int rc_wait = wait(NULL);  // 자식이 끝날 때까지 부모를 블록
```

`wait()`을 쓰면 부모가 먼저 실행되더라도 자식이 끝날 때까지 기다린다 → 실행 순서를 결정적으로 만들 수 있다.

### `exec()` — 다른 프로그램 실행

```c
char *myargs[3];
myargs[0] = strdup("wc");    // 실행할 프로그램
myargs[1] = strdup("p3.c");  // 인자
myargs[2] = NULL;
execvp(myargs[0], myargs);   // 이 프로세스를 wc로 완전히 교체
printf("이 줄은 절대 출력 안 됨");  // exec 성공 시 여기 오지 않는다
```

`exec()`의 핵심:
- 현재 프로세스의 코드/데이터를 **새 프로그램으로 완전 교체**
- 프로세스는 그대로(PID 유지), 내용만 바뀜
- 성공하면 절대 돌아오지 않는다

### `fork()` + `exec()` 조합의 미학

Shell이 명령어를 실행하는 방식:
```
shell → fork() → 자식 프로세스 생성
                → exec(명령어) → 자식이 명령어로 변신해 실행
부모(shell)는 wait()으로 기다리다가 자식 종료 후 다음 명령 받음
```

이 분리 덕분에 `fork()` 후 `exec()` 전에 **환경을 세팅**할 수 있다:
- 입출력 리다이렉션 (`>`, `<`)
- 파이프 (`|`)
- 환경변수 변경

> [!example]
> `wc p3.c > newfile.txt` 실행 시:
> 1. fork()
> 2. 자식: stdout을 newfile.txt로 리다이렉트 (close/open)
> 3. 자식: exec("wc", "p3.c")
> → `exec()` 이후에도 파일 디스크립터 설정은 유지됨

## Policy (왜 이렇게 설계했는가)

**왜 fork()와 exec()를 합치지 않고 분리했는가?**

만약 `spawn(program)`처럼 하나로 합쳤다면, fork~exec 사이에 환경을 조작할 수 없다. Unix의 강력한 파이프라인/리다이렉션은 이 분리 덕분에 가능하다.

**왜 fork()는 복사를 하는가? (Copy-on-Write)**
실제로는 메모리를 즉시 복사하지 않고, 쓰기가 발생할 때만 복사한다 → 성능 최적화.

## 코드 & 실험

| 시스템 콜 | 역할 |
|-----------|------|
| `fork()` | 현재 프로세스 복사본 생성 |
| `wait()`/`waitpid()` | 자식 종료 대기 |
| `exec()` 계열 | 현재 프로세스를 다른 프로그램으로 교체 |
| `getpid()` | 현재 프로세스의 PID 반환 |
| `kill()` | 프로세스에 시그널 전송 |

## 내 정리
결국 이 챕터는 **Unix 프로세스 API의 핵심 3총사(fork/exec/wait)** 를 설명한다. fork는 복사, exec는 변신, wait는 동기화. 이 세 가지를 분리한 덕분에 shell의 리다이렉션/파이프 같은 강력한 기능이 가능해진다. "왜 분리했는가?"를 이해하는 게 핵심.

## 연결
- 이전: Ch.04 - The Abstraction - The Process
- 다음: Ch.06 - Mechanism - Limited Direct Execution
- 관련 개념: Process, System Call, PCB (Process Control Block)
