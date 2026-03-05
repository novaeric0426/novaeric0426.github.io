+++
date = '2026-01-01T10:00:00+09:00'
draft = false
title = '[OSTEP] Ch.14 - Interlude - Memory API'
description = "OSTEP 메모리 가상화 파트 - Interlude - Memory API 정리 노트"
tags = ["OS", "OSTEP", "Virtualization"]
categories = ["OS"]
series = ["OSTEP 정리"]
+++
## Crux (핵심 문제)
> C 프로그램에서 메모리를 올바르게 할당하고 관리하려면? 어떤 인터페이스를 쓰고, 어떤 실수를 피해야 하는가?

## 배경 & 동기

프로세스에는 두 종류의 메모리가 있다. 하나는 스택 — 컴파일러가 자동으로 관리. 다른 하나는 힙 — 프로그래머가 직접 `malloc`/`free`로 관리해야 한다. 이 "직접 관리"가 수많은 버그의 원천이다.

## Mechanism (어떻게 동작하는가)

### 두 가지 메모리 유형

| 종류 | 관리 주체 | 생명주기 | 예 |
|------|-----------|----------|-----|
| **Stack** | 컴파일러 (자동) | 함수 범위 | 지역 변수, 함수 인자 |
| **Heap** | 프로그래머 (수동) | 명시적 해제까지 | `malloc()`으로 할당한 것 |

```c
void func() {
    int x;              // Stack: 함수 종료 시 자동 해제
    int *y = malloc(4); // Heap: 명시적 free() 필요
}
```

### 핵심 API

**`malloc(size)`**: 힙에서 size 바이트 할당, 포인터 반환. 실패 시 NULL.
```c
int *arr = (int *) malloc(10 * sizeof(int));
double *d = (double *) malloc(sizeof(double));
char *s = (char *) malloc(strlen(src) + 1); // +1은 null 종료 문자
```

**`free(ptr)`**: 이전에 malloc한 메모리 해제. 크기는 라이브러리가 추적.
```c
free(arr); // arr이 가리키는 블록 해제
```

**기타 유용한 함수:**
- `calloc(n, size)`: 할당 + 0으로 초기화 → 미초기화 버그 방지
- `realloc(ptr, new_size)`: 기존 블록 크기 변경 (새 메모리에 복사 후 반환)

### 하부 시스템 콜

`malloc`/`free`는 **라이브러리 함수**이지 시스템 콜이 아니다. 내부적으로:
- `brk(addr)`: 힙의 끝(break) 위치를 변경해 힙 크기 조정
- `mmap()`: 익명 메모리 영역 생성 (큰 할당에 사용)

이들을 직접 부르면 안 됨 — malloc 라이브러리가 관리하는 영역 망가짐.

## Policy (왜 이렇게 설계했는가)

### 흔한 메모리 버그들

> [!important]
> 컴파일러가 통과시켜도 런타임에 발생하는 버그들!

**1. 할당 안 하고 사용 (Segfault)**
```c
char *dst;            // 초기화 안 됨
strcpy(dst, "hello"); // segfault!
// 해결: dst = malloc(strlen("hello") + 1);
```

**2. 충분하지 않게 할당 (Buffer Overflow)**
```c
char *dst = malloc(strlen(src)); // null 문자 공간 부족!
strcpy(dst, src);                 // 1바이트 오버플로우 → 보안 취약점
```

**3. 초기화 안 하고 읽기 (Uninitialized Read)**
```c
int *p = malloc(sizeof(int));
printf("%d\n", *p); // 쓰레기 값 읽힘 (calloc 쓰면 방지)
```

**4. 메모리 누수 (Memory Leak)**
```c
// 반복문에서 malloc하고 free 안 하면 메모리가 점점 고갈
// 장기 실행 프로그램(서버, OS)에서 치명적
```

**5. 해제 후 사용 (Dangling Pointer)**
```c
free(p);
printf("%d\n", *p); // undefined behavior
```

**6. 이중 해제 (Double Free)**
```c
free(p);
free(p); // undefined behavior, 힙 손상
```

**7. 잘못된 포인터로 free**
```c
free(p + 1); // malloc이 반환한 포인터가 아님 → 위험
```

> [!example]
> **디버깅 도구**: `valgrind --leak-check=yes ./program`
> 메모리 오류를 런타임에 감지해준다. C 프로그래머의 필수품.

### 프로세스 종료 시 메모리 정리

프로세스가 종료되면 OS가 모든 메모리(힙, 스택, 코드)를 회수한다.
단기 프로그램은 `free()` 안 해도 누수 없음. **하지만 장기 실행 서버는 반드시 필요**.

## 내 정리
결국 이 챕터는 **C 프로그래머가 힙 메모리를 다루는 API와 그 함정들**을 정리한다. `malloc`/`free`는 라이브러리 레벨이지 시스템 콜이 아니다. 수많은 버그(누수, 오버플로우, dangling pointer)가 이 수동 관리에서 비롯되며, valgrind 같은 도구로 탐지할 수 있다.

## 연결
- 이전: Ch.13 - The Abstraction - Address Spaces
- 다음: Ch.15 - Mechanism - Address Translation
- 관련 개념: Virtual Address Space
