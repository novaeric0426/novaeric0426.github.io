+++
date = '2025-12-16T18:00:00+09:00'
draft = false
title = '[OSTEP 용어] Buffer Cache'
description = "OSTEP 핵심 용어 정리 - Buffer Cache"
tags = ["OS", "OSTEP", "OS 용어"]
categories = ["OS"]
series = ["OSTEP 정리"]
+++
## 정의
파일 시스템이 디스크 블록을 메모리에 캐싱하는 구조. 한 번 읽은 디스크 블록을 메모리에 보관하여 같은 블록을 다시 요청하면 디스크 접근 없이 메모리에서 바로 반환한다.

## 동작 원리

```
read(file, offset)
    ↓
Buffer Cache에 해당 블록 있음? (cache hit)
    Yes → 메모리에서 바로 반환 (디스크 I/O 없음)
    No  → 디스크에서 블록 읽기 → 캐시에 저장 → 반환 (cache miss)
```

**Write 시 동작 (Write-back):**
- 쓰기도 즉시 디스크에 가지 않고 캐시의 dirty 블록에만 반영
- 주기적으로(또는 fsync 시) dirty 블록을 디스크에 flush
- → 성능은 높지만 전원 장애 시 손실 위험 → Journaling이 필요한 이유

**LFS와의 관계:**
LFS 챕터에서 "메모리가 커질수록 read는 캐시에서 처리되고, 디스크 트래픽은 점점 write 위주가 된다"는 관찰이 핵심 동기가 되었다. Buffer Cache 효율이 높아질수록 write 최적화의 중요성이 커진다.

**교체 정책 (Replacement Policy):**
- LRU (Least Recently Used): 가장 오래 안 쓴 블록 교체
- 현대 OS는 LRU 변형이나 Clock 알고리즘 사용
- 파일 시스템은 sequential scan 같은 워크로드에서 LRU가 역효과(thrashing)를 낼 수 있어 hint 제공 가능

## 왜 중요한가

디스크 접근은 메모리 접근보다 수천 배 느리다. Buffer Cache는 이 속도 차이를 메꾸는 핵심 메커니즘으로, 대부분의 파일 접근 성능은 Buffer Cache hit rate에 좌우된다. OS가 free memory를 Buffer Cache로 최대한 활용하는 이유가 바로 이것이다.

## 관련
- 상위 개념: File System
- 관련: Journaling, Swapping
- 등장 챕터: Ch.40 - File System Implementation, Ch.43 - Log-structured File System (LFS)
