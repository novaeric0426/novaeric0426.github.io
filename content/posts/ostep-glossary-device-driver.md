+++
date = '2026-01-03T18:00:00+09:00'
draft = false
title = '[OSTEP 용어] Device Driver'
description = "OSTEP 핵심 용어 정리 - Device Driver"
tags = ["OS", "OSTEP", "OS 용어"]
categories = ["OS"]
series = ["OSTEP 정리"]
+++
## 정의
특정 하드웨어 장치와 OS 커널 사이의 **중간 소프트웨어 계층**. OS의 나머지 부분이 장치 세부사항에 의존하지 않도록, 표준 인터페이스 뒤에 장치별 코드를 캡슐화한다.

## 동작 원리

OS는 스토리지 장치에 대한 **generic block interface**만 알면 된다:
```
read(block_addr, buffer)
write(block_addr, data)
```

Device Driver가 이 generic 요청을 해당 장치의 **레지스터 조작 & 프로토콜**로 변환한다.

```
File System
    ↓ (generic block R/W)
Block Layer (OS)
    ↓
Device Driver (장치별: ATA, SATA, NVMe, USB...)
    ↓
하드웨어 레지스터 (Status, Command, Data)
```

**드라이버 주요 역할:**
1. **초기화**: 장치 감지, 레지스터 설정
2. **I/O 발행**: Command 레지스터에 명령어 작성
3. **완료 처리**: Polling 또는 Interrupt 방식으로 완료 감지
4. **오류 처리**: Status 레지스터 확인, 재시도 로직

## 왜 중요한가

OS 소스 코드의 약 70%가 Device Driver라는 통계가 있을 정도로 드라이버는 OS의 핵심 구성요소다. 드라이버의 추상화 덕분에 파일 시스템은 HDD든 SSD든 NVMe든 동일한 인터페이스로 접근할 수 있다. 반면 드라이버 버그는 커널 공간에서 실행되므로 시스템 전체 crash를 유발할 수 있다.

## 관련
- 상위 개념: File System
- 하위/구현: DMA, Interrupt
- 등장 챕터: Ch.36 - I_O Devices, Ch.37 - Hard Disk Drives
