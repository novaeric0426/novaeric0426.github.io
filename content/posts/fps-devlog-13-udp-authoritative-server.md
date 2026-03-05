+++
date = '2026-03-01T19:00:00+09:00'
draft = false
title = 'FPS 개발일지 #13 — UDP 네트워킹과 권위 서버'
description = "UDP 소켓 통신, 패킷 프로토콜, 전용 서버/클라이언트 구조를 구현한다. 권위 서버 아키텍처의 기본."
tags = ["Odin", "Raylib", "FPS", "게임개발", "멀티플레이어", "네트워킹", "UDP", "서버"]
categories = ["Game Dev"]
series = ["FPS 개발일지"]
+++

## 이번 글에서 다룰 것

Phase 2에서 입력 분리, 직렬화, 엔티티 ID, 고정 타임스텝을 준비했다. 이제 실제로 네트워크를 연결할 차례다. 이번 글에서는 UDP 소켓 통신, 패킷 프로토콜, 전용 서버와 클라이언트 구조를 구현한다.

## 왜 UDP인가

게임 네트워킹에서 TCP와 UDP의 차이:

- **TCP**: 신뢰성 보장, 순서 보장, 재전송. 하지만 하나의 패킷이 유실되면 뒤의 패킷이 모두 대기한다(Head-of-line blocking).
- **UDP**: 비신뢰성, 순서 없음, 재전송 없음. 대신 유실된 패킷 때문에 다른 패킷이 지연되지 않는다.

FPS 게임에서는 매 틱마다 전체 게임 상태(스냅샷)를 보낸다. 이전 스냅샷이 유실되어도 최신 스냅샷이 도착하면 된다. 오래된 데이터를 재전송받는 것보다 새로운 데이터를 빨리 받는 것이 중요하다. 그래서 UDP를 사용한다.

## 권위 서버 (Authoritative Server)

```
클라이언트: 입력 수집 → [UDP] → 서버
서버:       입력 수신 → 시뮬레이션 → 스냅샷 생성 → [UDP] → 클라이언트
클라이언트: 스냅샷 수신 → 렌더링
```

**서버만 게임 로직을 실행한다.** 클라이언트는 입력을 보내고 결과를 받아 그리기만 한다. 이것이 권위 서버 모델이다.

장점은 치트 방지다. 클라이언트가 "나는 지금 저 위치에 있다"고 거짓말해도 서버는 무시한다. 서버가 계산한 위치만이 진실이다.

단점은 지연(latency)이다. 입력이 서버를 거쳐야 화면에 반영되므로 RTT(왕복 시간)만큼 지연이 발생한다. 이는 다음 글(#15)에서 클라이언트 사이드 예측으로 해결한다.

## 세 가지 실행 모드

CLI 인자로 실행 모드를 결정한다.

```odin
Net_Mode :: enum {
    Local,   // 싱글플레이어 (기본)
    Server,  // 전용 서버 (헤드리스)
    Client,  // 클라이언트 (서버에 접속)
}

parse_cli_args :: proc() -> (Net_Mode, string) {
    args := os.args
    for i := 1; i < len(args); i += 1 {
        if args[i] == "--server" {
            return .Server, ""
        }
        if args[i] == "--connect" {
            addr := "127.0.0.1"
            if i + 1 < len(args) {
                addr = args[i + 1]
            }
            return .Client, addr
        }
    }
    return .Local, ""
}
```

실행 예시:
```bash
./fps-game              # 로컬 싱글플레이어
./fps-game --server     # 전용 서버
./fps-game --connect 127.0.0.1       # 클라이언트
./fps-game --connect 192.168.1.100:27015  # 원격 서버에 접속
```

## 패킷 프로토콜

모든 패킷은 9바이트 헤더 + 가변 페이로드로 구성된다.

```odin
Packet_Type :: enum u8 {
    Connect,     // 접속 요청/응답
    Disconnect,  // 연결 해제
    Input,       // 클라이언트 → 서버: 입력
    Snapshot,    // 서버 → 클라이언트: 게임 상태
}

Packet_Header :: struct #packed {
    packet_type: Packet_Type,  // 1 byte
    sequence:    u32,           // 4 bytes
    client_id:   u32,           // 4 bytes
}
```

`#packed`는 Odin에서 패딩 없이 필드를 빈틈없이 배치하라는 지시자다. 네트워크 프로토콜에서는 바이트 단위로 정확한 크기가 필요하므로 반드시 사용해야 한다.

## 패킷 송수신

```odin
send_packet :: proc(
    socket: net.UDP_Socket,
    to: net.Endpoint,
    ptype: Packet_Type,
    sequence: u32,
    client_id: u32,
    payload: []u8,
) -> bool {
    total := HEADER_SIZE + len(payload)
    if total > MAX_PACKET_SIZE do return false

    buf: [MAX_PACKET_SIZE]u8

    header := Packet_Header{
        packet_type = ptype,
        sequence    = sequence,
        client_id   = client_id,
    }
    mem.copy(&buf[0], &header, HEADER_SIZE)

    if len(payload) > 0 {
        mem.copy(&buf[HEADER_SIZE], raw_data(payload), len(payload))
    }

    _, err := net.send_udp(socket, buf[:total], to)
    return err == nil
}
```

수신도 같은 패턴이다. 버퍼에서 헤더를 먼저 읽고, 나머지가 페이로드다. 논블로킹 모드에서 데이터가 없으면 `false`를 반환한다.

## 헤드리스 서버

서버는 윈도우 없이 돌아간다. Raylib의 `InitWindow`를 호출하지 않으므로 GL 컨텍스트가 없다. 이 말은 `LoadModel`, `UnloadModel` 같은 GPU 관련 함수를 호출할 수 없다는 뜻이다.

```odin
create_gun_headless :: proc() -> Gun {
    // 모델 로딩 없이 무기 설정만 초기화
    return Gun{
        has_model      = false,
        state          = .Idle,
        weapons        = weapons,
        current_weapon = .Rifle,
        weapon_ammo    = weapon_ammo,
        weapon_reserve = weapon_reserve,
        // ...
    }
}

unload_gun :: proc(gun: ^Gun) {
    if gun.has_model {
        rl.UnloadModel(gun.model)
    }
}
```

`has_model` 플래그로 GPU 리소스 유무를 구분한다. 서버에서 `UnloadModel`을 호출하면 크래시가 발생하므로 반드시 체크해야 한다.

## 서버 틱 루프

```odin
run_server :: proc() {
    sock, _ := net.make_bound_udp_socket(net.IP4_Any, DEFAULT_PORT)
    defer net.close(sock)
    net.set_blocking(sock, false)

    server: Server_State
    server.socket = sock
    server.game = create_game_state_headless()

    tick_duration := time.Second / time.Duration(TICK_RATE)
    last_tick := time.tick_now()

    for {
        now := time.tick_now()
        elapsed := time.tick_diff(last_tick, now)

        if elapsed >= tick_duration {
            last_tick = now

            // 1. 모든 대기 패킷 수신
            server_recv_packets(&server)
            // 2. 시뮬레이션
            input := server_get_primary_input(&server)
            simulate_tick(&server.game, &input)
            // 3. 스냅샷 브로드캐스트
            server_broadcast_snapshot(&server)
        } else {
            time.sleep(tick_duration - elapsed)
        }
    }
}
```

타이밍에서 주의할 점: `tick_duration`을 `time.Second / time.Duration(TICK_RATE)`로 정수 나눗셈한다. 부동소수점으로 변환하면(`f64(time.Second) * (1.0/60.0)`) 정밀도 문제로 틱이 58~62Hz로 흔들린다.

## 클라이언트 접속 흐름

```
클라이언트                     서버
    │                            │
    │──── Connect (id=0) ───────→│
    │                            │ 빈 슬롯 찾기
    │                            │ client.id = 슬롯+1
    │←─── Connect (id=1) ───────│
    │                            │
    │──── Input (id=1) ─────────→│ 입력 저장
    │←─── Snapshot ─────────────│ 매 틱
    │                            │
    │──── Disconnect (id=1) ────→│ 슬롯 해제
```

## 클라이언트: 입력 전송과 스냅샷 수신

```odin
// 클라이언트는 simulate_tick을 호출하지 않는다
if !game.is_paused {
    input := collect_player_input()
    send_client_input(&client_net, &input)
    update_damage_numbers(&game.damage_numbers, frame_dt)
}

// 서버 스냅샷 수신 → 게임 상태 덮어쓰기
snapshot: Game_Snapshot
if recv_server_snapshot(&client_net, &snapshot) {
    apply_snapshot(&game, &snapshot)
}
```

핵심: **클라이언트는 `simulate_tick`을 호출하지 않는다.** 입력을 보내고 결과를 받을 뿐이다. 시뮬레이션은 서버만 한다.

## 입력 리던던시

UDP는 패킷 유실이 발생할 수 있다. `IsKeyPressed`(일회성 입력)가 담긴 패킷이 유실되면 점프나 재장전이 씹힌다.

```odin
PRESS_REDUNDANCY :: 3  // pressed 이벤트를 3프레임 연속 전송

send_client_input :: proc(state: ^Client_Net_State, input: ^Player_Input) {
    // 새 pressed 이벤트 감지 시 카운터 시작
    if input.jump do state.pending_jump = PRESS_REDUNDANCY

    // 카운터가 남아있으면 true로 유지해서 전송
    sent_input := input^
    if state.pending_jump > 0 {
        sent_input.jump = true
        state.pending_jump -= 1
    }
    // ...
}
```

3프레임 연속으로 보내면 3패킷 모두 유실될 확률은 매우 낮다. 서버 측에서는 pressed 입력을 틱당 한 번만 처리하고 초기화하므로 중복 실행되지 않는다.

## 히트 이벤트 전송

서버에서 히트스캔이 명중하면 `Net_Hit_Event`에 기록하고 스냅샷에 포함시킨다.

```odin
Net_Hit_Event :: struct {
    position: Vec3,
    damage:   f32,
}
```

클라이언트는 스냅샷에서 히트 이벤트를 꺼내 데미지 넘버를 생성한다. 히트 판정 자체는 서버에서만 일어나고, 클라이언트는 시각 피드백만 표시한다.

## 마치며

이 글에서 구현한 것:

- Odin `core:net`으로 UDP 소켓 통신
- `Packet_Header` (#packed, 9바이트) + 4종 패킷 타입
- CLI 인자로 Local/Server/Client 모드 분기
- 헤드리스 전용 서버 (60Hz 틱 루프, GL 컨텍스트 없음)
- 클라이언트: 입력 전송 + 스냅샷 수신 (시뮬레이션 없음)
- 입력 리던던시 (pressed 이벤트 3프레임 반복)
- 히트 이벤트 서버→클라이언트 전달

이것으로 1:1 접속이 동작한다. 다음 글에서는 여러 플레이어가 동시에 접속할 수 있도록 확장한다.

---

*이 시리즈의 전체 소스 코드는 [GitHub](https://github.com/novaeric0426/odin-fps)에서 확인할 수 있습니다.*
