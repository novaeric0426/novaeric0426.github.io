+++
date = '2026-02-27T18:00:00+09:00'
draft = false
title = 'FPS 개발일지 #10 — 직렬화 가능한 게임 상태'
description = "네트워크 전송을 위해 게임 상태를 POD 구조체로 추출하고, mem.copy 기반 직렬화를 구현한다."
tags = ["Odin", "Raylib", "FPS", "게임개발", "멀티플레이어", "직렬화", "네트워킹"]
categories = ["Game Dev"]
series = ["FPS 개발일지"]
+++

## 이번 글에서 다룰 것

멀티플레이어에서 서버는 매 틱마다 게임 상태를 클라이언트에 보내야 한다. 그런데 `Player`나 `Gun` 구조체에는 Raylib의 `Camera3D`, `Model` 같은 GPU 리소스가 포함되어 있다. 이런 필드는 네트워크로 보낼 수 없다.

이번 글에서는 네트워크 전송에 필요한 필드만 골라낸 **POD(Plain Old Data) 구조체**를 만들고, 게임 상태를 바이트 배열로 직렬화하는 시스템을 구현한다.

## 왜 POD 구조체가 필요한가

```
Player 구조체:
  position: Vec3     ← 네트워크로 보내야 함
  velocity: Vec3     ← 네트워크로 보내야 함
  camera:   Camera3D ← GPU 리소스, 보낼 수 없음
  config:   Player_Config ← 양쪽 다 동일, 보낼 필요 없음

Gun 구조체:
  model:    Model    ← GPU 리소스
  state:    Gun_State ← 보내야 함
  weapon_ammo: [..]  ← 보내야 함
```

포인터, 핸들, GPU 리소스를 제거하고 순수한 값 타입만 남긴 구조체가 POD다. `mem.copy`로 바이트 배열에 복사할 수 있어야 한다.

## Net 상태 구조체

```odin
Net_Player_State :: struct {
    position:       Vec3,
    velocity:       Vec3,
    yaw:            f32,
    pitch:          f32,
    move_state:     Move_State,
    is_grounded:    bool,
    current_height: f32,
    hp:             f32,
    is_alive:       bool,
    death_timer:    f32,
}

Net_Gun_State :: struct {
    state:          Gun_State,
    current_weapon: Weapon_Type,
    weapon_ammo:    [Weapon_Type]i32,
    weapon_reserve: [Weapon_Type]i32,
    switching:      bool,
    switch_timer:   f32,
    switch_target:  Weapon_Type,
    fire_timer:     f32,
}

Net_Target_State :: struct {
    position:         Vec3,
    hp:               f32,
    is_alive:         bool,
    current_waypoint: i32,
    patrol_direction: i32,
    ai_state:         Target_AI_State,
    return_target:    Vec3,
}
```

카메라, 모델, 설정값(config) 등은 빠져 있다. 클라이언트가 스냅샷을 받은 뒤 `sync_camera()`로 카메라를 재구성하면 된다.

## Game_Snapshot

```odin
MAX_TARGETS :: 16

Game_Snapshot :: struct {
    tick:         u32,
    player:       Net_Player_State,
    gun:          Net_Gun_State,
    targets:      [MAX_TARGETS]Net_Target_State,
    target_count: u8,
}
```

고정 크기 배열을 사용한다. 동적 배열(`[dynamic]`)은 포인터를 포함하므로 `mem.copy`로 직렬화할 수 없다. `target_count`로 실제 유효한 타겟 수를 기록한다.

## Extract / Apply 패턴

게임 상태와 네트워크 상태 사이의 변환은 extract/apply 함수 쌍으로 처리한다.

**Extract (Game → Net):**
```odin
extract_player_state :: proc(player: ^Player) -> Net_Player_State {
    return Net_Player_State{
        position       = player.position,
        velocity       = player.velocity,
        yaw            = player.yaw,
        pitch          = player.pitch,
        move_state     = player.move_state,
        is_grounded    = player.is_grounded,
        current_height = player.current_height,
        hp             = player.hp,
        is_alive       = player.is_alive,
        death_timer    = player.death_timer,
    }
}
```

**Apply (Net → Game):**
```odin
apply_player_state :: proc(player: ^Player, state: ^Net_Player_State) {
    player.position       = state.position
    player.velocity       = state.velocity
    player.yaw            = state.yaw
    player.pitch          = state.pitch
    player.move_state     = state.move_state
    player.is_grounded    = state.is_grounded
    player.current_height = state.current_height
    player.hp             = state.hp
    player.is_alive       = state.is_alive
    player.death_timer    = state.death_timer

    // 카메라는 position/yaw/pitch에서 재구성
    sync_camera(player)
}
```

`Gun`, `Target`도 동일한 패턴으로 extract/apply 함수를 작성했다.

## 스냅샷 캡처와 적용

```odin
capture_snapshot :: proc(game: ^Game_State, tick: u32) -> Game_Snapshot {
    snapshot: Game_Snapshot
    snapshot.tick = tick
    snapshot.player = extract_player_state(&game.player)
    snapshot.gun = extract_gun_state(&game.gun)

    count := min(len(game.targets), MAX_TARGETS)
    snapshot.target_count = u8(count)
    for i := 0; i < count; i += 1 {
        snapshot.targets[i] = extract_target_state(&game.targets[i])
    }
    return snapshot
}

apply_snapshot :: proc(game: ^Game_State, snapshot: ^Game_Snapshot) {
    apply_player_state(&game.player, &snapshot.player)
    apply_gun_state(&game.gun, &snapshot.gun)

    count := min(int(snapshot.target_count), len(game.targets))
    for i := 0; i < count; i += 1 {
        apply_target_state(&game.targets[i], &snapshot.targets[i])
    }
}
```

## 바이너리 직렬화

POD 구조체의 장점은 `mem.copy` 한 번으로 직렬화가 끝난다는 것이다.

```odin
SNAPSHOT_SIZE :: size_of(Game_Snapshot)

serialize_snapshot :: proc(snapshot: ^Game_Snapshot, buf: []u8) -> int {
    if len(buf) < SNAPSHOT_SIZE do return 0
    mem.copy(raw_data(buf), snapshot, SNAPSHOT_SIZE)
    return SNAPSHOT_SIZE
}

deserialize_snapshot :: proc(buf: []u8, snapshot: ^Game_Snapshot) -> bool {
    if len(buf) < SNAPSHOT_SIZE do return false
    mem.copy(snapshot, raw_data(buf), SNAPSHOT_SIZE)
    return true
}
```

별도의 직렬화 라이브러리 없이, 구조체 메모리를 그대로 복사한다. Odin의 구조체는 기본적으로 C와 동일한 메모리 레이아웃을 갖기 때문에 가능하다.

`Player_Input`도 같은 방식으로 직렬화한다. 클라이언트가 서버에 입력을 보낼 때 사용된다.

## 디버그 라운드트립 테스트

직렬화가 제대로 되는지 확인하기 위해 L 키로 라운드트립 테스트를 추가했다.

```odin
debug_snapshot_round_trip :: proc(game: ^Game_State) {
    snapshot := capture_snapshot(game, 0)

    buf: [SNAPSHOT_SIZE]u8
    written := serialize_snapshot(&snapshot, buf[:])

    restored: Game_Snapshot
    deserialize_snapshot(buf[:], &restored)

    apply_snapshot(game, &restored)
    fmt.printf("Snapshot round-trip OK, %d bytes\n", written)
}
```

캡처 → 직렬화 → 역직렬화 → 적용. 게임이 정상적으로 돌아가면 성공이다. 눈에 보이는 변화가 없어야 올바른 것이다.

## 마치며

이 글에서 구현한 것:

- `Net_Player_State`, `Net_Gun_State`, `Net_Target_State` POD 구조체
- `Game_Snapshot` — 고정 크기 배열, tick 번호 포함
- Extract/Apply 함수 쌍으로 게임 상태 ↔ 네트워크 상태 변환
- `mem.copy` 기반 바이너리 직렬화/역직렬화
- 라운드트립 디버그 테스트

이제 게임 상태를 바이트 배열로 변환해서 네트워크로 보낼 준비가 되었다.

---

*이 시리즈의 전체 소스 코드는 [GitHub](https://github.com/novaeric0426)에서 확인할 수 있습니다.*
