+++
date = '2026-01-26T10:00:00+09:00'
draft = false
title = '[OSTEP] Ch.27 - Interlude - Thread API'
description = "OSTEP 동시성 파트 - Interlude - Thread API 정리 노트"
tags = ["OS", "OSTEP", "Concurrency"]
categories = ["OS"]
series = ["OSTEP 정리"]
+++
## Crux (핵심 문제)
스레드를 생성하고 제어하기 위한 인터페이스는 어떻게 생겼나? 쓰기 쉬우면서도 강력한 API를 어떻게 설계하나?

## 배경 & 동기

Ch.26 - Concurrency - An Introduction에서 Thread의 개념과 Race Condition 문제를 배웠다. 이번 챕터는 POSIX Thread(pthread) API 레퍼런스 역할이다. Lock, Condition Variable은 이후 챕터에서 더 깊이 다루고, 여기서는 사용법 위주로 파악한다.

## Mechanism (어떻게 동작하는가)

### 1. 스레드 생성 — `pthread_create`

```c
int pthread_create(
    pthread_t        *thread,       // 스레드 식별자 (출력)
    const pthread_attr_t *attr,     // 속성 (NULL이면 기본값)
    void *(*start_routine)(void*),  // 진입 함수
    void             *arg           // 인자
);
```

- `attr`: 스택 크기, 스케줄링 우선순위 등. 보통 NULL
- `start_routine`: `void* → void*` 시그니처의 함수 포인터
- `arg`: 어떤 타입이든 `void*`로 포장해서 전달

```c
typedef struct { int a; int b; } myarg_t;

void *mythread(void *arg) {
    myarg_t *args = (myarg_t *) arg;
    printf("%d %d\n", args->a, args->b);
    return NULL;
}
```

> [!important]
> 스레드 함수에서 **스택 변수의 포인터를 반환하면 절대 안 된다.** 스레드가 종료되면 스택이 해제되므로, 반환된 포인터는 댕글링 포인터가 된다.

### 2. 스레드 완료 대기 — `pthread_join`

```c
int pthread_join(pthread_t thread, void **value_ptr);
```

- 지정한 스레드가 종료될 때까지 블록
- `value_ptr`: 스레드 반환값을 담을 포인터의 포인터 (필요 없으면 NULL)

```c
myret_t *rvals;
Pthread_join(p, (void **) &rvals);
printf("returned %d %d\n", rvals->x, rvals->y);
free(rvals);  // 힙에서 malloc한 것이므로 해제 필요
```

반환값을 스택이 아닌 **힙에 malloc**해야 안전하다.

### 3. 락 — `pthread_mutex`

```c
pthread_mutex_t lock = PTHREAD_MUTEX_INITIALIZER;

pthread_mutex_lock(&lock);
// critical section
pthread_mutex_unlock(&lock);
```

Lock (Mutex)을 통해 Critical Section을 보호한다. 초기화는 정적(`PTHREAD_MUTEX_INITIALIZER`) 또는 동적(`pthread_mutex_init()`)으로 가능.

> [!important]
> 락 초기화를 빠뜨리거나, lock/unlock 짝이 맞지 않으면 **Undefined Behavior** 또는 Deadlock.

### 4. 조건 변수 — `pthread_cond`

```c
pthread_cond_t cond = PTHREAD_COND_INITIALIZER;

// 대기 (락을 들고 호출해야 함 — 내부에서 해제 후 슬립, 깨어나면 재획득)
pthread_cond_wait(&cond, &mutex);

// 알림
pthread_cond_signal(&cond);
```

Condition Variable은 "어떤 조건이 될 때까지 잠재워라"는 패턴에 쓴다. 이후 Ch.30 - Condition Variables에서 상세히 다룸.

## Policy (왜 이렇게 설계했는가)

### void* 포인터를 쓰는 이유
범용성 — 어떤 타입의 인자/반환값도 `void*`로 포장하면 하나의 API로 처리 가능. 단, 타입 안전성은 개발자 책임.

### join이 필요 없는 경우
웹 서버처럼 장기 실행 스레드는 join을 하지 않는다. 메인 스레드가 요청을 받아 워커 스레드에 넘기고, 워커는 무한 루프로 동작.

> [!example]
> 단일 long long 값 전달: `void*`로 캐스팅해서 포인터 자체에 값을 실어 보낼 수도 있다. 구조체 포장 없이도 동작하지만, 이식성에 주의.

## 내 정리

결국 이 챕터는 **pthread API 사용법 레퍼런스**다. 핵심은 세 가지:
1. `create` / `join` — 스레드 라이프사이클
2. `mutex_lock` / `mutex_unlock` — 임계 구역 보호
3. `cond_wait` / `cond_signal` — 조건 동기화

진짜 "왜 필요한지, 어떻게 구현하는지"는 Ch.28~31에서 다룬다.

## 연결
- 이전: Ch.26 - Concurrency - An Introduction
- 다음: Ch.28 - Locks
- 관련 개념: Thread, Lock (Mutex), Condition Variable, Deadlock
