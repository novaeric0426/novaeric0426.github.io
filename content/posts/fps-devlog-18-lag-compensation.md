+++
date = '2026-03-15T18:00:00+09:00'
draft = false
title = 'FPS 개발일지 #18 — 서버 사이드 렉 보상'
description = "네트워크 지연 환경에서도 공정한 히트 판정을 위해 서버가 과거 시점으로 되감아 레이캐스트하는 렉 보상을 구현한다."
tags = ["Odin", "Raylib", "FPS", "게임개발", "멀티플레이어", "네트워킹", "렉보상", "서버"]
categories = ["Game Dev"]
series = ["FPS 개발일지"]
+++

## 이번 글에서 다룰 것

PvP 전투를 구현했지만 한 가지 문제가 남아 있다. 네트워크 지연 때문에 클라이언트가 보는 화면과 서버의 실제 상태가 다르다. 클라이언트 화면에서는 정확히 머리에 조준했는데, 서버에서는 상대가 이미 다른 위치로 이동한 상태다. 결과: 미명중.

**렉 보상(Lag Compensation)**은 서버가 클라이언트의 시점으로 시간을 되감아 히트 판정을 하는 기법이다. Source 엔진(Counter-Strike, TF2)에서 사용하는 방식과 동일한 원리다.

## 문제 상황

```
시간 →  t=100       t=102       t=104

서버:   적 위치 A → 적 위치 B → 적 위치 C (현재)

클라이언트:         적 위치 A를 보고 사격 (t=102에 입력, 하지만 보고 있는 건 t=100의 상태)
                    ↓
서버 수신 (t=104):  현재 위치 C 기준으로 판정 → 미명중!
```

클라이언트는 항상 과거 상태를 보고 있다. 엔티티 보간 때문에 한 틱 뒤, 거기에 네트워크 지연까지 더해지면 수 틱 뒤의 세계를 보는 것이다. 클라이언트가 "여기 맞았다"고 보낸 시점에서 서버는 이미 다른 상태다.

## 해결: 서버가 되감는다

```
서버 수신 (t=104):
  1. 클라이언트가 "나는 t=100 시점을 보고 쐈다" (client_view_tick=100)
  2. 월드 히스토리에서 t=100 프레임 조회
  3. 모든 엔티티를 t=100 위치로 되감기
  4. 되감긴 위치로 레이캐스트 → 명중!
  5. 위치 복원 (t=104로 되돌림)
```

클라이언트가 화면에서 본 그대로 판정한다. "내가 조준한 곳에 적이 있었으면 맞은 것이다."

## client_view_tick

클라이언트가 "어느 시점을 보고 있는가"를 서버에 알려줘야 한다.

```odin
Player_Input :: struct {
    sequence:         u32,
    client_view_tick: u32,   // 새로 추가 — 마지막으로 받은 스냅샷의 tick
    mouse_delta:      Vec2,
    // ...
}
```

클라이언트는 스냅샷을 받을 때마다 틱 번호를 기록하고, 입력을 보낼 때 함께 전송한다.

```odin
// 스냅샷 수신 시
state.last_snapshot_tick = snapshot.tick

// 입력 전송 시
sent_input.client_view_tick = state.last_snapshot_tick
```

## 월드 히스토리

서버는 매 틱의 엔티티 위치를 링 버퍼에 기록한다.

```odin
HISTORY_SIZE :: 64       // ~1초 (60Hz)
MAX_REWIND_TICKS :: 12   // 200ms 상한

World_Frame :: struct {
    tick:              u32,
    player_positions:  [MAX_PLAYERS]Vec3,
    player_heights:    [MAX_PLAYERS]f32,
    player_is_active:  [MAX_PLAYERS]bool,
    player_is_alive:   [MAX_PLAYERS]bool,
    target_positions:  [MAX_TARGETS]Vec3,
    target_is_alive:   [MAX_TARGETS]bool,
    target_count:      int,
}

World_History :: struct {
    frames: [HISTORY_SIZE]World_Frame,
    head:   int,
    count:  int,
}
```

64프레임 × 16.67ms ≈ 1초치를 보관한다. 대부분의 네트워크 환경에서 충분하다.

레이캐스트에 필요한 것은 위치뿐이다. HP, 속도, 상태 등은 저장하지 않는다.

## 기록

서버의 `simulate_tick` 직후에 현재 프레임을 기록한다.

```odin
// 서버 틱 루프
simulate_tick(&server.game, &inputs, &server.history)
record_world_frame(&server.history, &server.game, server.game.tick)
```

```odin
record_world_frame :: proc(history: ^World_History, game: ^Game_State, tick: u32) {
    frame := &history.frames[history.head]
    frame.tick = tick

    for i := 0; i < MAX_PLAYERS; i += 1 {
        frame.player_positions[i] = game.players[i].position
        frame.player_heights[i] = game.players[i].current_height
        frame.player_is_active[i] = game.players[i].is_active
        frame.player_is_alive[i] = game.players[i].is_alive
    }

    count := min(len(game.targets), MAX_TARGETS)
    frame.target_count = count
    for i := 0; i < count; i += 1 {
        frame.target_positions[i] = game.targets[i].position
        frame.target_is_alive[i] = game.targets[i].is_alive
    }

    history.head = (history.head + 1) % HISTORY_SIZE
    if history.count < HISTORY_SIZE {
        history.count += 1
    }
}
```

## 되감기와 복원

레이캐스트 전에 위치를 되감고, 끝나면 복원하는 save/restore 패턴을 사용한다.

```odin
save_positions :: proc(game: ^Game_State) -> Saved_Positions {
    saved: Saved_Positions
    for i := 0; i < MAX_PLAYERS; i += 1 {
        saved.player_positions[i] = game.players[i].position
        saved.player_heights[i] = game.players[i].current_height
    }
    count := min(len(game.targets), MAX_TARGETS)
    for i := 0; i < count; i += 1 {
        saved.target_positions[i] = game.targets[i].position
    }
    return saved
}

rewind_positions :: proc(game: ^Game_State, frame: ^World_Frame, shooter_index: int) {
    for i := 0; i < MAX_PLAYERS; i += 1 {
        if i == shooter_index do continue  // 사격자 본인은 되감지 않음
        game.players[i].position = frame.player_positions[i]
        game.players[i].current_height = frame.player_heights[i]
    }
    count := min(len(game.targets), frame.target_count)
    for i := 0; i < count; i += 1 {
        game.targets[i].position = frame.target_positions[i]
    }
}

restore_positions :: proc(game: ^Game_State, saved: ^Saved_Positions) {
    // save_positions의 역순
    // ...
}
```

`shooter_index`는 되감기에서 제외한다. 자기 자신의 위치는 현재 시점 그대로여야 한다 — 레이의 시작점이기 때문이다.

## simulate_tick 통합

```odin
simulate_tick :: proc(game: ^Game_State, inputs: ^[MAX_PLAYERS]Player_Input, history: ^World_History = nil) {
    // ...
    for i := 0; i < MAX_PLAYERS; i += 1 {
        // ...
        update_player(&game.players[i], &inputs[i], &game.world, TICK_DT)

        // 렉 보상: 사격 중이고 client_view_tick이 있으면 되감기
        rewound := false
        saved: Saved_Positions
        if history != nil && inputs[i].fire && inputs[i].client_view_tick > 0 {
            rewind_ticks := calc_rewind_ticks(game.tick, inputs[i].client_view_tick)
            if rewind_ticks > 0 {
                frame := get_world_frame(history, inputs[i].client_view_tick)
                if frame != nil {
                    saved = save_positions(game)
                    rewind_positions(game, frame, i)
                    rewound = true
                }
            }
        }

        // 레이캐스트 (되감긴 위치 기준)
        multi_result := update_gun(&game.guns[i], &inputs[i], &game.players[i],
                                   game.targets[:], game.players[:], i, &game.world, TICK_DT)

        // 복원
        if rewound {
            restore_positions(game, &saved)
        }

        // 히트 처리 ...
    }
}
```

핵심 흐름: **이동 → (되감기) → 사격 → (복원) → 히트 처리**. 되감기는 사격 입력이 있을 때만 발생하고, 레이캐스트가 끝나면 즉시 복원한다.

`history` 파라미터는 옵션이다. 로컬 모드에서는 `nil`을 넘기면 되감기가 발생하지 않는다.

## 되감기 상한

```odin
MAX_REWIND_TICKS :: 12   // 200ms

calc_rewind_ticks :: proc(current_tick: u32, client_view_tick: u32) -> u32 {
    if client_view_tick == 0 || client_view_tick >= current_tick do return 0
    diff := current_tick - client_view_tick
    return min(diff, MAX_REWIND_TICKS)
}
```

12틱 × 16.67ms ≈ 200ms. 이 이상 되감는 것은 허용하지 않는다. 핑이 200ms를 넘는 플레이어는 그만큼 불이익을 받지만, 핑이 낮은 플레이어가 과거로 너무 많이 돌아간 히트에 맞는 것을 방지한다.

## 되감기 않는 것들

위치만 되감고, **HP와 alive 상태는 현재 시점을 유지한다**. 이미 죽은 플레이어를 과거로 되감아 다시 맞추는 것을 방지하기 위해서다. 사격 시점에는 살아있었더라도 현재 시점에서 이미 죽었으면 미명중 처리된다.

## 마치며

이 글에서 구현한 것:

- `Player_Input.client_view_tick` — 클라이언트가 보고 있던 시점
- `World_History` — 64프레임 링 버퍼, 매 틱 위치 기록
- `rewind_positions` / `restore_positions` — save/restore 패턴
- `simulate_tick` 안에서 사격 시 되감기 → 레이캐스트 → 복원
- `MAX_REWIND_TICKS = 12` (200ms 상한)
- 사격자 본인은 되감기 제외, HP/alive는 현재 시점 유지

이것으로 진짜 FPS 개발일지 시리즈가 마무리된다. 렉 보상까지 갖추면 네트워크 지연이 있어도 "내가 조준한 곳에 맞는다"는 직관이 유지된다. 클라이언트 예측이 이동의 즉각성을 보장하고, 렉 보상이 사격의 공정성을 보장한다 — 멀티플레이어 FPS의 두 기둥이 모두 완성되었다.

---

*이 시리즈의 전체 소스 코드는 [GitHub](https://github.com/novaeric0426/odin-fps)에서 확인할 수 있습니다.*
