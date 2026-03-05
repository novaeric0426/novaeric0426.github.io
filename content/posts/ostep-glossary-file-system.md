+++
date = '2026-01-06T18:00:00+09:00'
draft = false
title = '[OSTEP 용어] File System'
description = "OSTEP 핵심 용어 정리 - File System"
tags = ["OS", "OSTEP", "OS 용어"]
categories = ["OS"]
series = ["OSTEP 정리"]
+++
## 정의
영속적 저장소(HDD, SSD 등)에 파일과 디렉터리를 저장하고 관리하는 OS의 소프트웨어 계층. 하드웨어적 도움 없이 순수 소프트웨어로 구현된다는 점에서 CPU/메모리 가상화와 다르다.

## 동작 원리

두 가지 핵심 측면:

**1. 자료구조**: 디스크에 어떤 구조를 올리는가
```
[Superblock] [inode bitmap] [data bitmap] [inode table] [Data Region]
```
- **Superblock**: 전체 파일시스템 메타데이터 (inode 수, 블록 수, 위치 등)
- **Bitmap**: inode/데이터 블록의 할당 여부 추적
- **inode table**: 파일 메타데이터 배열
- **Data region**: 실제 파일/디렉터리 데이터

**2. 접근 방법**: open/read/write 시 어떤 순서로 디스크를 읽고 쓰는가
- `open("/foo/bar")`: root inode → root data → foo inode → foo data → bar inode
- `write()`: data bitmap read → write → inode read → data write → inode write

## 왜 중요한가

파일 시스템이 없으면 모든 데이터를 raw 블록 주소로 관리해야 한다. 사용자에게 파일/디렉터리라는 편리한 추상화를 제공하고, 영속성(크래시 후에도 데이터 유지)을 보장한다.

## 관련
- 핵심 구조: Inode, Superblock, Journaling, Buffer Cache, Copy-on-Write
- 등장 챕터: Ch.39 - Files and Directories, Ch.40 - File System Implementation, Ch.41 - Fast File System (FFS), Ch.42 - Crash Consistency FSCK and Journaling, Ch.43 - Log-structured File System (LFS), Ch.44 - Flash-based SSDs, Ch.45 - Data Integrity and Protection
