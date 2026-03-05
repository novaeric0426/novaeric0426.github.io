+++
date = '2026-03-02T18:00:00+09:00'
draft = false
title = 'FPS 개발일지 #14 — 멀티플레이어 플레이어 슬롯'
description = "단일 플레이어 구조를 MAX_PLAYERS 배열로 확장한다. 접속/해제 시 슬롯 할당, 다른 플레이어 렌더링까지."
tags = ["Odin", "Raylib", "FPS", "게임개발", "멀티플레이어", "네트워킹"]
categories = ["Game Dev"]
series = ["FPS 개발일지"]
+++

## 이번 글에서 다룰 것

이전 글에서 구현한 서버는 첫 번째 접속자의 입력만 처리했다. 이번에는 최대 4명이 동시에 접속할 수 있도록 확장한다. 각 클라이언트에 플레이어 슬롯을 할당하고, 다른 플레이어를 캡슐로 렌더링한다.

## Game_State 구조 변경

```odin
// Before: 단일 플레이어
Game_State :: struct {
    player: Player,
    gun:    Gun,
    // ...
}

// After: MAX_PLAYERS 배열
Game_State :: struct {
    players:      [MAX_PLAYERS]Player,
    guns:         [MAX_PLAYERS]Gun,
    player_count: int,
    // ...
}
```

`[dynamic]`이 아닌 고정 크기 배열을 사용한다. 최대 4명이고, `Game_Snapshot`의 `[MAX_PLAYERS]` 배열과 1:1 대응되어야 하기 때문이다.

## 멀티플레이어 상수

```odin
MAX_PLAYERS :: 4

SPAWN_POINTS := [MAX_PLAYERS]Vec3{
    {0, 2, 10},
    {0, 2, -10},
    {10, 2, 0},
    {-10, 2, 0},
}

PLAYER_COLORS := [MAX_PLAYERS]rl.Color{
    rl.BLUE,
    rl.RED,
    rl.GREEN,
    rl.YELLOW,
}
```

각 슬롯에 고유한 스폰 위치와 색상을 부여한다.

## is_active 플래그

```odin
Player :: struct {
    is_active: bool,  // 이 슬롯이 사용 중인가
    // ...
}
```

빈 슬롯과 사용 중인 슬롯을 구분한다. `simulate_tick`에서 비활성 슬롯은 건너뛴다.

## 서버: 접속 시 슬롯 할당

```odin
Client_Info :: struct {
    endpoint:     net.Endpoint,
    id:           u32,
    connected:    bool,
    last_input:   Player_Input,
    sequence:     u32,
    player_index: int,  // Game_State.players 인덱스
}

server_handle_connect :: proc(server: ^Server_State, from: net.Endpoint) {
    // 빈 슬롯 찾기
    for &client, i in server.clients {
        if !client.connected {
            client.connected = true
            client.endpoint = from
            client.id = u32(i + 1)
            client.player_index = i

            // 이 슬롯에 플레이어/총기 생성
            server.game.players[i] = create_player(SPAWN_POINTS[i])
            server.game.guns[i] = create_gun_headless()
            server.game.player_count += 1

            send_packet(server.socket, from, .Connect, 0, client.id, nil)
            return
        }
    }
    // 빈 슬롯 없으면 거부
}
```

`client_id`는 1부터 시작한다 (0은 "미접속" 상태). `player_index`는 0부터. 클라이언트 ID와 슬롯 인덱스의 관계는 `player_index = client_id - 1`.

## 서버: 해제 시 슬롯 비활성화

```odin
server_handle_disconnect :: proc(server: ^Server_State, client_id: u32) {
    for &client in server.clients {
        if client.connected && client.id == client_id {
            server.game.players[client.player_index].is_active = false
            server.game.player_count -= 1
            client.connected = false
            client.id = 0
            return
        }
    }
}
```

플레이어를 삭제하지 않고 `is_active = false`로 비활성화한다. 배열에서 제거하면 인덱스가 밀리기 때문이다.

## simulate_tick 확장

```odin
simulate_tick :: proc(game: ^Game_State, inputs: ^[MAX_PLAYERS]Player_Input) {
    game.tick += 1

    // 모든 활성 플레이어의 사망 타이머 갱신
    for i := 0; i < MAX_PLAYERS; i += 1 {
        if !game.players[i].is_active do continue
        update_player_death(&game.players[i], TICK_DT)
    }

    // AI: 가장 가까운 활성 플레이어 추적
    update_targets_multiplayer(game.targets[:], &game.world, game.players[:], TICK_DT)

    // 모든 활성+생존 플레이어 시뮬레이션
    for i := 0; i < MAX_PLAYERS; i += 1 {
        if !game.players[i].is_active do continue
        if !game.players[i].is_alive do continue

        update_player(&game.players[i], &inputs[i], &game.world, TICK_DT)
        multi_result := update_gun(&game.guns[i], &inputs[i], &game.players[i],
                                   game.targets[:], &game.world, TICK_DT)
        // 히트 처리 ...
    }
}
```

시그니처가 `^Player_Input`에서 `^[MAX_PLAYERS]Player_Input`으로 바뀌었다. 서버는 각 클라이언트의 입력을 해당 슬롯 인덱스에 배치한다.

## AI: 가장 가까운 플레이어 추적

```odin
update_targets_multiplayer :: proc(targets: []Target, world: ^World, players: []Player, dt: f32) {
    for &target in targets {
        if !target.is_alive do continue

        // 가장 가까운 활성 플레이어 찾기
        best_pos := Vec3{}
        best_dist: f32 = max(f32)
        found := false

        for &p in players {
            if !p.is_active || !p.is_alive do continue
            diff := Vec3{p.position.x - target.position.x, 0, p.position.z - target.position.z}
            d := linalg.length(diff)
            if d < best_dist {
                best_dist = d
                best_pos = p.position
                found = true
            }
        }

        if found {
            update_target(&target, world, best_pos, dt)
        } else {
            update_target(&target, world, Vec3{99999, 0, 99999}, dt)
        }
    }
}
```

싱글플레이어에서는 `player_pos` 하나를 받았지만, 멀티에서는 모든 활성 플레이어를 순회해서 가장 가까운 플레이어를 찾는다.

## 클라이언트: 다른 플레이어 렌더링

클라이언트는 자기 슬롯을 1인칭 카메라로 보고, 다른 플레이어는 색이 칠해진 캡슐로 렌더링한다.

```odin
local_index := int(client_net.client_id) - 1

// 자기 시점 카메라 사용
rl.BeginMode3D(game.players[local_index].camera)

// 다른 플레이어를 캡슐로 렌더링
for i := 0; i < MAX_PLAYERS; i += 1 {
    if i == local_index do continue
    draw_other_player(&game.players[i], i)
}
```

```odin
draw_other_player :: proc(player: ^Player, slot: int) {
    if !player.is_active || !player.is_alive do return

    color := PLAYER_COLORS[slot % MAX_PLAYERS]
    pos := rl.Vector3{player.position.x, player.position.y, player.position.z}

    // 몸통: 원기둥
    rl.DrawCylinder(pos, PLAYER_RADIUS, PLAYER_RADIUS, player.current_height * 0.8, 8, color)
    rl.DrawCylinderWires(pos, PLAYER_RADIUS, PLAYER_RADIUS, player.current_height * 0.8, 8, rl.BLACK)

    // 머리: 구
    head_pos := rl.Vector3{pos.x, pos.y + player.current_height * 0.8 + 0.2, pos.z}
    rl.DrawSphere(head_pos, 0.25, color)
    rl.DrawSphereWires(head_pos, 0.25, 6, 6, rl.BLACK)
}
```

## 스냅샷: 모든 슬롯 전송

```odin
Game_Snapshot :: struct {
    tick:         u32,
    player_count: u8,
    players:      [MAX_PLAYERS]Net_Player_State,
    guns:         [MAX_PLAYERS]Net_Gun_State,
    targets:      [MAX_TARGETS]Net_Target_State,
    target_count: u8,
    // ...
}
```

4명분의 플레이어/총기 상태를 항상 포함한다. 비활성 슬롯은 `is_active = false`로 전송되므로 클라이언트가 알아서 무시한다.

## 함정: config/fov 초기화

네트워크로 전송되지 않는 필드가 문제를 일으켰다. `Player_Config`(이동 속도, FOV 등)과 `camera.fovy`는 스냅샷에 포함되지 않는다. 로컬에서 `create_player`로 생성한 슬롯은 정상이지만, 원격 슬롯은 `apply_player_state`로만 초기화되므로 config가 제로 값이다.

`camera.fovy = 0`이면 3D 렌더링이 완전히 깨진다 — 하얀 화면만 보인다.

```odin
apply_player_state :: proc(player: ^Player, state: ^Net_Player_State) {
    // ... 필드 복사 ...

    // config/camera가 초기화되지 않았으면 기본값 설정
    if player.config.fov == 0 {
        player.config = DEFAULT_PLAYER_CONFIG
    }
    if player.camera.fovy == 0 {
        player.camera.fovy = player.config.fov
        player.camera.projection = .PERSPECTIVE
        player.camera.up = {0, 1, 0}
    }

    sync_camera(player)
}
```

**교훈: 네트워크 상태에 포함되지 않는 필드는 수신 측에서 반드시 기본값을 보장해야 한다.**

## 마치며

이 글에서 구현한 것:

- `Game_State`를 `[MAX_PLAYERS]` 배열 구조로 확장
- `is_active` 플래그로 슬롯 활성화/비활성화
- 서버: 접속 시 슬롯 할당 + 플레이어 생성, 해제 시 비활성화
- `simulate_tick`이 모든 활성 플레이어를 독립적으로 시뮬레이션
- `update_targets_multiplayer`: AI가 가장 가까운 플레이어를 추적
- 클라이언트: `local_index`로 자기 시점 결정, 다른 플레이어는 캡슐 렌더링
- 스냅샷에 4명분 상태 포함

이제 여러 명이 동시에 접속해서 같은 월드에서 뛰어다닐 수 있다. 하지만 입력이 서버를 거쳐야 하므로 자기 캐릭터도 느리게 반응한다. 다음 글에서 이 문제를 해결한다.

---

*이 시리즈의 전체 소스 코드는 [GitHub](https://github.com/novaeric0426/odin-fps)에서 확인할 수 있습니다.*
