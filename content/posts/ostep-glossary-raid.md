+++
date = '2026-01-29T18:00:00+09:00'
draft = false
title = '[OSTEP 용어] RAID'
description = "OSTEP 핵심 용어 정리 - RAID"
tags = ["OS", "OSTEP", "OS 용어"]
categories = ["OS"]
series = ["OSTEP 정리"]
+++
## 정의
여러 개의 물리 디스크를 묶어 **하나의 논리 디스크처럼** 보이게 하는 기술. 성능(Parallelism)과 신뢰성(Redundancy)을 동시에 높이는 것이 목표.

## 동작 원리

RAID는 호스트에게 단일 블록 디바이스 인터페이스를 제공하고, 내부적으로 스트라이핑·미러링·패리티로 데이터를 분산 저장한다.

### 주요 RAID 레벨

| 레벨 | 방식 | 성능 | 신뢰성 | 공간 효율 |
|------|------|------|--------|-----------|
| RAID-0 | 스트라이핑만 (패리티 없음) | 최고 | 없음 | 100% |
| RAID-1 | 미러링 | Read 2배, Write 동일 | 높음 | 50% |
| RAID-4 | 스트라이핑 + 전용 패리티 디스크 | Read 빠름, Write 병목 | 1 디스크 장애 허용 | (N-1)/N |
| RAID-5 | 스트라이핑 + 분산 패리티 | 균형 | 1 디스크 장애 허용 | (N-1)/N |

**Small-Write Problem (RAID-4/5)**:
단일 블록 write → 해당 스트라이프의 old data + old parity 읽기 → 새 패리티 계산 → data + parity 쓰기 = 4번의 I/O. 소규모 쓰기가 많은 워크로드에서 성능 저하.

**RAID Failure Model:**
- 전통적 fail-stop 모델: 디스크 전체가 한 번에 실패
- 현대적 fail-partial 모델: Ch.45 - Data Integrity and Protection 참조

## 왜 중요한가

단일 디스크의 용량·성능·신뢰성 한계를 넘기 위한 표준 기법. 서버, 클라우드 스토리지, NAS 등 거의 모든 대용량 저장 시스템에서 RAID 또는 유사 개념을 사용한다. LFS, ZFS 등 현대 파일 시스템도 RAID-awareness를 고려하고 설계된다.

## 관련
- 상위 개념: File System
- 관련: Inode, Journaling, Copy-on-Write
- 등장 챕터: Ch.38 - RAIDs, Ch.45 - Data Integrity and Protection
