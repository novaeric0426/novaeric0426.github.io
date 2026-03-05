+++
date = '2025-12-25T10:00:00+09:00'
draft = false
title = '[OSTEP] Ch.09 - Scheduling - Proportional Share'
description = "OSTEP CPU 가상화 파트 - Scheduling - Proportional Share 정리 노트"
tags = ["OS", "OSTEP", "Virtualization"]
categories = ["OS"]
series = ["OSTEP 정리"]
+++
## Crux (핵심 문제)
> Turnaround나 Response time이 아니라, **각 job에게 원하는 CPU 비율을 보장**하는 스케줄러를 어떻게 만드는가?

## 배경 & 동기

지금까지 본 스케줄러들(FIFO, SJF, RR, MLFQ)은 모두 성능 지표(Turnaround/Response)를 최적화하려 했다. 다른 목표를 생각해보자: 각 프로세스에 **정해진 비율의 CPU를 보장**하는 것. 예: A는 75%, B는 25%. 이런 **비례 공유(Proportional Share)** 방식 = **공정 공유(Fair Share)** 방식.

Waldspurger & Weihl(1994)이 제안한 **Lottery Scheduling**이 대표적 예.

## Mechanism (어떻게 동작하는가)

### Lottery Scheduling

**핵심 아이디어**: 각 프로세스에 **티켓(tickets)**을 부여. CPU를 사용하고 싶을 때 복권 추첨. 티켓이 많을수록 당첨 확률 높음.

```
A: 75 tickets (0~74번)
B: 25 tickets (75~99번)
총 100 tickets

매 time slice마다 0~99 사이 랜덤 숫자 추첨
→ 0~74가 나오면 A 실행 (75% 확률)
→ 75~99가 나오면 B 실행 (25% 확률)
```

**구현 코드:**
```c
int counter = 0;
int winner = getrandom(0, totaltickets);  // 당첨 번호 추첨

node_t *current = head;
while (current) {
    counter += current->tickets;
    if (counter > winner) break;  // 당첨 프로세스 찾음
    current = current->next;
}
// current가 실행할 프로세스
```

**장점**: 구현 단순, 자료구조 최소화.

**단점**: 확률적이라 짧은 시간에는 목표 비율과 어긋날 수 있음.

### Ticket 조작 메커니즘

| 메커니즘 | 설명 |
|---------|------|
| **Ticket Currency** | 사용자가 자기 job들 사이에 자체 통화로 배분, OS가 글로벌 통화로 변환 |
| **Ticket Transfer** | client가 server에 티켓 임시 양도 → server가 빠르게 처리 가능 |
| **Ticket Inflation** | 신뢰할 수 있는 환경에서 필요 시 자신의 티켓 임시 증가 |

### Lottery의 공평성 분석

두 job이 각 100 tickets, 같은 실행시간 R일 때:
```
F = (첫 번째 완료 시간) / (두 번째 완료 시간)
→ R이 클수록 F가 1에 가까워짐 (공평해짐)
→ R이 작으면 F가 낮을 수 있음 (확률적 편차 때문)
```

### Stride Scheduling (결정론적 버전)

Lottery의 단점(확률적 불정확성)을 해결한 결정론적 공평 스케줄러.

**개념:**
- 각 job에 **stride** = 큰 수 ÷ tickets 로 계산
- 매 실행 시 pass value += stride
- 항상 pass value가 가장 낮은 job 실행

```
A: 100 tickets → stride = 10000/100 = 100
B:  50 tickets → stride = 10000/50  = 200
C: 250 tickets → stride = 10000/250 = 40

Pass(A)  Pass(B)  Pass(C)  Who runs?
  0        0        0       A (임의 선택)
100        0        0       B
100      200        0       C
100      200       40       C
100      200       80       C
100      200      120       A
200      200      120       C
200      200      160       C
200      200      200       → 모두 200 (완벽한 비율 달성)
```

**Stride vs Lottery:**

| 항목 | Lottery | Stride |
|------|---------|--------|
| 비율 정확도 | 확률적 | 결정론적 |
| 구현 복잡도 | 단순 | 약간 복잡 |
| 새 job 추가 | 자연스럽 | pass 초기값 문제 (0으로 하면 즉시 독점) |
| 상태 추적 | 최소 | pass value 유지 필요 |

> [!important]
> Lottery는 새 프로세스 추가가 쉽다. Stride는 새 프로세스의 초기 pass 값을 어떻게 설정하느냐가 까다롭다 — 0으로 설정하면 그 프로세스가 당분간 CPU를 독점하게 된다.

## Policy (왜 이렇게 설계했는가)

**언제 Proportional Share가 적합한가?**
- 가상화 환경(하이퍼바이저): VM별 CPU 비율 보장
- 데이터베이스/서버: 서비스별 CPU 배분 보장
- 멀티 사용자 환경: 사용자별 공평한 자원 배분

**현실적 한계:**
- 티켓 초기 배분 문제 — 얼마씩 줄 것인가? 정해진 답 없음
- Turnaround나 Response time 최적화와 목표가 다름 → MLFQ를 대체하지 않고 보완

> [!example]
> Linux의 CFS(Completely Fair Scheduler)는 이 아이디어를 발전시킨 것.
> `nice` 값으로 우선순위 조정 = 티켓 수 조정의 다른 형태.

## 내 정리
결국 이 챕터는 **스케줄링의 목표를 바꾼다**: 성능 최적화가 아니라 **비율 보장**. Lottery Scheduling은 랜덤성을 이용해 단순하게 구현하고, Stride Scheduling은 결정론적으로 정확한 비율을 보장한다. 현대 OS의 CFS나 VM 스케줄러에서 이 아이디어가 살아있다.

## 연결
- 이전: Ch.08 - Scheduling - The Multi-Level Feedback Queue
- 다음: Ch.10 - Multiprocessor Scheduling
- 관련 개념: Scheduling Policy, Time Sharing
