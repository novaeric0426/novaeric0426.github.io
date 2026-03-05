+++
date = '2026-01-08T18:00:00+09:00'
draft = false
title = '[OSTEP 용어] Inode'
description = "OSTEP 핵심 용어 정리 - Inode"
tags = ["OS", "OSTEP", "OS 용어"]
categories = ["OS"]
series = ["OSTEP 정리"]
+++
## 정의
파일 하나당 하나씩 존재하는 메타데이터 구조체. 파일의 크기, 권한, 소유자, 타임스탬프, 그리고 **실제 데이터 블록의 위치(포인터들)**를 담고 있다. 파일의 "설명서"라고 보면 된다.

## 동작 원리

inode는 inode table에 배열로 저장되며, **inode number(i-number)**로 인덱싱된다.

```
inode 위치 = inode_table_start + (inumber × sizeof(inode))
```

내부 구조:
```
크기(bytes), 권한, 소유자, UID/GID
atime, mtime, ctime
→ 데이터 블록 포인터:
  direct[0..11]     → 직접 데이터 블록 12개
  indirect          → 포인터 배열 블록 1개 (4KB/4B = 1024 포인터)
  double_indirect   → 2단계 간접
  triple_indirect   → 3단계 간접
```

4KB 블록 기준 최대 파일 크기:
- Direct 12 = 48KB
- Indirect 1 = ~4MB
- Double indirect = ~4GB

## 왜 중요한가

inode가 없으면 파일의 데이터가 디스크 어디에 있는지 알 수가 없다. 파일 접근의 시작점은 항상 inode다. `open()`이 경로를 탐색해서 최종적으로 얻는 것이 inode이고, 이후 모든 read/write는 inode를 거쳐서 데이터 블록을 찾는다.

## 관련
- 상위 개념: File System
- 관련: Superblock, Page Table (가상↔물리 주소 매핑과 유사한 역할)
- 등장 챕터: Ch.39 - Files and Directories, Ch.40 - File System Implementation, Ch.41 - Fast File System (FFS), Ch.42 - Crash Consistency FSCK and Journaling, Ch.43 - Log-structured File System (LFS), Ch.45 - Data Integrity and Protection
