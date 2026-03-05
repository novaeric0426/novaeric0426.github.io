+++
date = '2026-02-14T18:00:00+09:00'
draft = false
title = '[OSTEP 용어] Superblock'
description = "OSTEP 핵심 용어 정리 - Superblock"
tags = ["OS", "OSTEP", "OS 용어"]
categories = ["OS"]
series = ["OSTEP 정리"]
+++
## 정의
파일 시스템 전체에 대한 메타데이터를 담은 특별한 블록. 파일 시스템을 마운트할 때 OS가 제일 먼저 읽는 구조체.

## 동작 원리

Superblock에 담긴 정보:
- 총 inode 수, 총 데이터 블록 수
- inode 테이블의 시작 위치
- 파일 시스템 타입을 식별하는 **매직 넘버**
- 블록 크기, 마운트 횟수 등

마운트 과정:
```
1. OS가 파티션의 첫 블록(또는 정해진 위치)에서 Superblock 읽기
2. inode 테이블, bitmap 위치 파악
3. 파일 시스템 트리에 볼륨 연결 (mount point 설정)
```

FFS부터는 **각 Cylinder/Block Group마다 Superblock 사본**을 유지 → 메인 Superblock 손상 시 복구 가능.

## 왜 중요한가

Superblock이 손상되면 파일 시스템 전체가 마운트 불가. 모든 구조의 위치 정보가 여기 있기 때문. FFS가 복사본을 두는 이유가 바로 이것.

## 관련
- 상위 개념: File System
- 관련: Inode, Journaling
- 등장 챕터: Ch.40 - File System Implementation, Ch.41 - Fast File System (FFS), Ch.42 - Crash Consistency FSCK and Journaling
