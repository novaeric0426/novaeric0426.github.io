+++
date = '2026-02-24T18:00:00+09:00'
draft = false
title = '[OSTEP 용어] Thread'
description = "OSTEP 핵심 용어 정리 - Thread"
tags = ["OS", "OSTEP", "OS 용어"]
categories = ["OS"]
series = ["OSTEP 정리"]
+++
## 정의
하나의 프로세스 안에 존재하는 독립적인 실행 흐름. 같은 주소 공간을 공유하되, 각자 독립된 레지스터 셋과 스택을 가진다.

## 동작 원리

- **공유되는 것**: Code 세그먼트, Heap, 전역 변수 (= 같은 주소 공간)
- **독립적인 것**: 레지스터 (PC 포함), Stack (Thread-local storage)

Thread 전환 시 **TCB(Thread Control Block)**에 레지스터 상태를 저장/복원한다. 주소 공간은 바꾸지 않으므로 Context Switch 비용이 Process 전환보다 낮다.

```
멀티스레드 주소 공간:
0KB ─ Code
     Heap
     (free)
     Stack (T2)
     (free)
     Stack (T1)
16KB
```

## 왜 중요한가

- **병렬화**: 멀티코어 활용, 대용량 연산을 여러 스레드로 분산
- **I/O 오버랩**: 한 스레드가 I/O 대기 중에 다른 스레드가 CPU 사용
- 하지만 **공유 주소 공간**이 Race Condition의 원인이 됨

## 관련
- 상위 개념: Process
- 관련: Context Switch, Race Condition, Critical Section, Lock (Mutex)
- 등장 챕터: Ch.26 - Concurrency - An Introduction, Ch.27 - Interlude - Thread API
