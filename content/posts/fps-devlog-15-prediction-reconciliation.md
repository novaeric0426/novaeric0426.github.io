+++
date = '2026-03-02T19:00:00+09:00'
draft = false
title = 'FPS 개발일지 #15 — 클라이언트 사이드 예측과 서버 보정'
description = "입력 지연 없는 즉각적 이동을 위한 클라이언트 사이드 예측, 서버 스냅샷과의 보정(reconciliation)을 구현한다."
tags = ["Odin", "Raylib", "FPS", "게임개발", "멀티플레이어", "네트워킹", "예측", "보정"]
categories = ["Game Dev"]
series = ["FPS 개발일지"]
+++

## 이번 글에서 다룰 것

권위 서버 모델에서는 입력이 서버를 왕복해야 화면에 반영된다. RTT가 50ms라면 키를 누른 뒤 50ms 후에야 캐릭터가 움직인다. FPS에서 이 지연은 치명적이다.

**클라이언트 사이드 예측(Client-Side Prediction)**은 서버 응답을 기다리지 않고 입력을 즉시 로컬에서 시뮬레이션하는 기법이다. **서버 보정(Reconciliation)**은 서버 응답이 도착했을 때 예측 결과를 교정하는 과정이다.

## 예측의 원리

```
클라이언트가 하는 일:
1. 입력 수집
2. 입력을 서버에 전송 + 로컬 버퍼에 저장
3. 입력으로 즉시 로컬 시뮬레이션 (update_player)
4. 화면에 반영 → 즉각적 반응!
```

서버와 클라이언트가 같은 `update_player` 함수를 사용하므로, 같은 입력에 같은 결과가 나온다. 대부분의 경우 예측이 정확하다.

## 보정의 원리

예측이 항상 맞지는 않다. 다른 플레이어와 충돌하거나, 서버에서 추가 검증이 있거나, 패킷 순서가 바뀌면 서버 결과와 클라이언트 예측이 달라진다.

```
보정 과정:
1. 서버 스냅샷 도착 (acked_seq = 42 — "42번 입력까지 반영됨")
2. 플레이어 위치를 서버 값으로 스냅
3. 버퍼에서 42번 이후 입력(43, 44, 45...)을 꺼내 다시 시뮬레이션
4. 최종 위치 = 서버 기반 + 미처리 입력 재적용
```

서버가 "여기까지 처리했다"고 알려주면, 그 지점부터 아직 서버가 모르는 입력을 다시 재생(replay)한다.

## 입력 시퀀스 번호

예측/보정의 핵심은 "어떤 입력이 서버에 반영되었는가"를 아는 것이다. 이를 위해 입력에 시퀀스 번호를 부여한다.

```odin
Player_Input :: struct {
    sequence: u32,   // 새로 추가
    mouse_delta: Vec2,
    move_forward: bool,
    // ...
}
```

클라이언트가 입력을 보낼 때마다 시퀀스를 1씩 증가시킨다. 서버는 마지막으로 처리한 시퀀스를 스냅샷에 포함시켜 돌려보낸다.

```odin
// 서버 측
Client_Info :: struct {
    last_input_seq: u32,  // 이 클라이언트에서 받은 최신 시퀀스
    // ...
}

Game_Snapshot :: struct {
    ack_input_seq: [MAX_PLAYERS]u32,  // 플레이어별 ack
    // ...
}
```

## 예측 버퍼

```odin
PREDICTION_BUFFER_SIZE :: 128

Stored_Input :: struct {
    sequence: u32,
    input:    Player_Input,
}

Prediction_State :: struct {
    buffer:     [PREDICTION_BUFFER_SIZE]Stored_Input,
    head:       int,    // 다음 쓰기 위치 (순환)
    count:      int,
    last_acked: u32,
}
```

128개 입력을 링 버퍼에 저장한다. 60Hz 틱이면 약 2초치다. 서버 ack가 올 때까지 보관하고, ack된 입력은 재생할 필요 없으므로 자연스럽게 덮어씌워진다.

## 클라이언트 루프 변경

```odin
// 매 프레임
input := collect_player_input()

game.tick_accumulator += frame_dt
for game.tick_accumulator >= TICK_DT && ticks < MAX_TICKS_PER_FRAME {
    player := &game.players[local_index]

    if player.is_active && player.is_alive {
        // 즉시 로컬 시뮬레이션 (예측)
        update_player(player, &input, &game.world, TICK_DT)
    }

    // 서버에 입력 전송
    send_client_input(&client_net, &input)

    // 버퍼에 저장
    store_input(&prediction, input, client_net.sequence)

    // pressed 이벤트 클리어 (첫 틱만)
    input.jump = false
    // ...

    game.tick_accumulator -= TICK_DT
}
```

이전에는 클라이언트가 `simulate_tick`을 호출하지 않았다. 이제 로컬 플레이어에 대해서만 `update_player`를 실행한다. 총기/AI/히트 판정은 여전히 서버에서만 처리한다.

## 스냅샷 수신 시 보정

```odin
if recv_server_snapshot(&client_net, &snapshot) {
    acked_seq := snapshot.ack_input_seq[local_index]

    if server_alive && server_active {
        // 이동은 예측이 처리하므로 스냅샷에서 제외
        apply_snapshot(&game, &snapshot, local_index, skip_local_movement = true)

        // 보정: 서버 위치로 스냅 → 미ack 입력 재생
        reconcile(&prediction, &game.players[local_index],
                  &snapshot.players[local_index], acked_seq, &game.world)
        sync_camera(&game.players[local_index])
    } else {
        // 죽었거나 비활성 → 예측 없이 서버 상태 그대로
        apply_snapshot(&game, &snapshot, local_index, skip_local_movement = false)
        reset_prediction(&prediction)
    }
}
```

`skip_local_movement = true`일 때 로컬 플레이어의 위치/속도/방향은 스냅샷에서 적용하지 않는다. HP, 사망 상태, 총기 상태는 서버에서 받는다.

## reconcile 함수

```odin
reconcile :: proc(
    state: ^Prediction_State,
    player: ^Player,
    server_player: ^Net_Player_State,
    acked_seq: u32,
    world: ^World,
) {
    // 1. 서버 위치로 스냅
    player.position       = server_player.position
    player.velocity       = server_player.velocity
    player.yaw            = server_player.yaw
    player.pitch          = server_player.pitch
    player.move_state     = server_player.move_state
    player.is_grounded    = server_player.is_grounded
    player.current_height = server_player.current_height

    state.last_acked = acked_seq

    // 2. 죽었으면 재생 없이 종료
    if !server_player.is_alive || !server_player.is_active {
        reset_prediction(state)
        return
    }

    // 3. acked_seq 이후의 입력을 재생
    start := (state.head - state.count + PREDICTION_BUFFER_SIZE) % PREDICTION_BUFFER_SIZE
    for i := 0; i < state.count; i += 1 {
        idx := (start + i) % PREDICTION_BUFFER_SIZE
        stored := &state.buffer[idx]
        if stored.sequence > acked_seq {
            update_player(player, &stored.input, world, TICK_DT)
        }
    }
}
```

서버가 42번까지 처리했으면, 43~45번 입력을 서버 위치 위에서 다시 실행한다. 결과적으로 플레이어는 "서버가 알고 있는 위치 + 아직 서버가 모르는 입력"의 위치에 있게 된다.

## 리스폰 처리

죽었다가 살아나면 예측 버퍼를 리셋해야 한다. 죽기 전의 입력을 리스폰 후 위치에 재생하면 엉뚱한 곳으로 이동한다.

```odin
// 죽었다가 살아남 감지
if server_alive && !was_alive {
    reset_prediction(&prediction)
}
was_alive = server_alive
```

## 예측 범위

이 구현에서 클라이언트가 예측하는 것:
- 이동 (위치, 속도, 방향, 앉기/서기)

서버에서만 처리하는 것:
- 총기 (발사, 재장전, 무기 교체)
- AI 타겟
- 히트 판정 / 데미지
- HP / 사망 / 리스폰

총기 예측은 구현이 복잡하고(히트 판정 결과가 달라질 수 있음), 사격 지연은 이동 지연만큼 체감되지 않으므로 서버 권위로 남겨두었다.

## 마치며

이 글에서 구현한 것:

- `Player_Input.sequence` — 입력 시퀀스 번호
- `Prediction_State` — 128개 링 버퍼
- 클라이언트: `update_player` 즉시 실행 (예측)
- 스냅샷 수신 시 `reconcile()` — 서버 스냅 → 미ack 입력 재생
- `skip_local_movement` — 로컬 플레이어 이동은 예측이 담당
- 리스폰 시 예측 버퍼 리셋

입력 → 화면 반영이 즉각적이 되었다. 네트워크 지연이 있어도 자기 캐릭터는 로컬과 똑같이 반응한다.

---

*이 시리즈의 전체 소스 코드는 [GitHub](https://github.com/novaeric0426)에서 확인할 수 있습니다.*
