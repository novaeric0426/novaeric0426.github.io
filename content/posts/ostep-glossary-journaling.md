+++
date = '2026-01-13T18:00:00+09:00'
draft = false
title = '[OSTEP 용어] Journaling'
description = "OSTEP 핵심 용어 정리 - Journaling"
tags = ["OS", "OSTEP", "OS 용어"]
categories = ["OS"]
series = ["OSTEP 정리"]
+++
## 정의
파일 시스템의 crash-consistency 문제를 해결하는 기법. 실제 디스크 구조를 업데이트하기 **전에** 먼저 "뭘 할 건지" 저널(journal, 로그)에 기록해두는 방식. DB의 write-ahead logging에서 차용.

## 동작 원리

### 기본 프로토콜 (Metadata Journaling, ordered mode)

```
1. Data Write         : 사용자 데이터를 최종 위치에 먼저 기록
2. Journal Meta Write : TxB + metadata(inode, bitmap) → 저널
3. Journal Commit     : TxE(트랜잭션 끝 마커) → 저널 (atomic)
4. Checkpoint         : metadata를 최종 위치에 기록
5. Free               : 저널 슈퍼블록에서 해당 트랜잭션 공간 반환
```

```
Journal: [TxB id=1] [I[v2]] [B[v2]] [TxE id=1]
                                     ↑ 이게 디스크에 쓰이면 "커밋 완료"
```

### 크래시 복구

- 커밋 전 크래시 → 저널에 TxE 없음 → 해당 트랜잭션 무시
- 커밋 후, checkpoint 전 크래시 → 재부팅 시 저널 replay (redo logging)

### 저널 모드 비교 (Linux ext3)

| 모드 | 저널 내용 | 속도 | 안전성 |
|------|-----------|------|--------|
| data | metadata + data | 느림 | 최고 |
| ordered (기본) | metadata만, data는 먼저 기록 | 보통 | 높음 |
| unordered | metadata만, data 순서 무보장 | 빠름 | 중간 |

## 왜 중요한가

fsck는 크래시 후 전체 디스크를 스캔하므로 TB 단위에서 수십 분. Journaling은 저널만 replay하면 되므로 초~분 단위 복구 가능. ext3/4, NTFS, XFS 등 현대 파일 시스템의 표준 기법.

> [!important]
> **핵심 원칙**: "가리킴을 받는 데이터를 먼저 쓰고, 그것을 가리키는 포인터를 나중에 써라"
> → Metadata journaling에서 data를 먼저 쓰는 이유

## 관련
- 상위 개념: File System
- 관련 문제: Crash-consistency problem
- 관련 개념: Copy-on-Write (COW는 Journaling 없이 crash consistency를 달성하는 대안)
- 등장 챕터: Ch.42 - Crash Consistency FSCK and Journaling, Ch.43 - Log-structured File System (LFS)
