+++
date = '2026-01-03T10:00:00+09:00'
draft = false
title = '[OSTEP] Ch.15 - Mechanism - Address Translation'
description = "OSTEP 메모리 가상화 파트 - Mechanism - Address Translation 정리 노트"
tags = ["OS", "OSTEP", "Virtualization"]
categories = ["OS"]
series = ["OSTEP 정리"]
+++
## Crux (핵심 문제)
> 메모리 가상화를 효율적이고 유연하게 구현하려면? 어떻게 프로그램이 생성한 가상 주소를 실제 물리 주소로 변환하면서 보호도 달성하는가?

## 배경 & 동기

CPU 가상화에서 LDE를 배웠듯이, 메모리 가상화에서도 같은 전략: **하드웨어가 대부분 처리하되, OS는 핵심 지점에서 개입**. 매 메모리 접근마다 하드웨어가 가상 주소를 물리 주소로 변환한다 — 이를 **Address Translation**이라 한다.

## Mechanism (어떻게 동작하는가)

### 초기 접근: Base and Bounds (Dynamic Relocation)

가장 단순한 하드웨어 지원: CPU 안에 두 개의 레지스터.

```
base register  = 프로세스 Address Space의 시작 물리 주소
bounds register = Address Space의 크기
```

**주소 변환 공식:**
```
physical address = virtual address + base
```

**예시:**
```
프로그램이 virtual address 128을 접근
base = 32KB (32768)
→ physical address = 128 + 32768 = 32896
```

**경계 검사:**
```
if (virtual address < 0 || virtual address >= bounds)
    raise PROTECTION_FAULT  // 프로세스 강제 종료
```

**동작 흐름:**
```
OS @ 부팅: interrupt handler, system call handler 등록
OS @ 프로세스 생성:
  - 메모리에서 free slot 찾기
  - base, bounds 레지스터 설정
  - return-from-trap으로 프로세스 시작

하드웨어 @ 실행 중:
  - 매 메모리 접근마다 물리 주소 = VA + base 계산
  - bounds 초과 시 OS에 trap

OS @ Context Switch:
  - 현재 프로세스의 base/bounds를 PCB에 저장
  - 다음 프로세스의 base/bounds 복원
```

### MMU (Memory Management Unit)

하드웨어에서 주소 변환을 담당하는 칩 내 유닛.
Base/Bounds 레지스터가 여기에 있다. 나중에 TLB, Page Table 지원도 여기에.

### Base and Bounds의 한계

```
Virtual Address Space (16KB):
0KB  [Code]
1KB  [Heap]
2KB
...
14KB
15KB [Stack]
16KB

→ 물리 메모리에서도 16KB를 통째로 차지
   중간의 빈 공간도 물리 메모리 낭비!
```

> [!important]
> Base and Bounds는 **내부 단편화(Internal Fragmentation)** 문제 — Address Space 내 비어있는 영역도 물리 메모리를 차지한다.
> 이게 Segmentation이 등장하는 이유.

## Policy (왜 이렇게 설계했는가)

**OS의 역할:**
1. 프로세스 생성 시 free memory slot 찾기 (free list 관리)
2. Context switch 시 base/bounds 저장/복원
3. 비정상 접근 시 예외 처리 (프로세스 종료)
4. 프로세스 종료 시 메모리 반환 (free list에 추가)

**하드웨어의 역할:**
1. 매 메모리 접근마다 VA → PA 변환 (base + VA)
2. Bounds 초과 여부 검사
3. 위반 시 OS로 trap

**Trade-off:**
- 장점: 단순하고 빠름. 보호(Protection) 제공.
- 단점: 내부 단편화. 전체 Address Space가 물리 메모리에 연속으로 올라와야 함. 유연성 부족.

## 내 정리
결국 이 챕터는 **가장 단순한 메모리 가상화 메커니즘인 Base and Bounds**를 설명한다. 가상 주소에 base를 더하면 물리 주소가 된다. bounds로 접근 범위를 제한해 보호한다. 하지만 주소 공간 내 빈 공간도 물리 메모리를 낭비하는 문제가 있어서, Segmentation으로 발전한다.

## 연결
- 이전: Ch.14 - Interlude - Memory API
- 다음: Ch.16 - Segmentation
- 관련 개념: Virtual Address Space, Address Translation, Page Table
