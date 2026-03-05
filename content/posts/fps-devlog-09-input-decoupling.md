+++
date = '2026-02-23T18:00:00+09:00'
draft = false
title = 'FPS 개발일지 #09 — 입력/시뮬레이션/렌더링 분리'
description = "멀티플레이어를 위해 Raylib 직접 호출을 걷어내고, 입력 → 시뮬레이션 → 렌더링 파이프라인으로 분리한다."
tags = ["Odin", "Raylib", "FPS", "게임개발", "멀티플레이어", "리팩토링"]
categories = ["Game Dev"]
series = ["FPS 개발일지"]
+++

## 이번 글에서 다룰 것

Phase 1까지의 코드는 `update_player` 안에서 `rl.IsKeyDown(.W)` 같은 Raylib 입력 함수를 직접 호출했다. 싱글플레이어에서는 문제없지만, 멀티플레이어에서는 서버가 클라이언트의 입력을 받아 시뮬레이션해야 한다. 서버에는 키보드가 없다.

이번 글에서는 **입력 수집 → 시뮬레이션 → 렌더링** 세 단계를 명확히 분리한다.

## 왜 분리해야 하는가

싱글플레이어 구조:
```
update_player() {
    if rl.IsKeyDown(.W) { ... }  // 입력 + 시뮬레이션 혼합
}
```

멀티플레이어 구조:
```
클라이언트: 입력 수집 → 네트워크로 전송
서버:       입력 수신 → 시뮬레이션 실행 → 결과 전송
클라이언트: 결과 수신 → 렌더링
```

서버는 Raylib 윈도우 없이 돌아가므로 `rl.IsKeyDown()`을 호출할 수 없다. 입력을 데이터로 추상화해야 한다.

## Player_Input 구조체

```odin
Player_Input :: struct {
    // Camera
    mouse_delta:     Vec2,
    // Movement
    move_forward:    bool,
    move_back:       bool,
    move_right:      bool,
    move_left:       bool,
    jump:            bool,   // pressed (일회성)
    sprint:          bool,   // held (지속)
    crouch:          bool,   // held
    // Combat
    fire:            bool,   // held
    reload:          bool,   // pressed
    switch_weapon_1: bool,   // pressed
    switch_weapon_2: bool,   // pressed
    switch_weapon_3: bool,   // pressed
    weapon_scroll:   f32,
}
```

pressed(일회성)와 held(지속)를 구분하는 것이 중요하다. 점프나 재장전은 한 번만 발동해야 하고, 이동이나 사격은 누르고 있는 동안 계속 적용되어야 한다.

## 입력 수집 함수

```odin
collect_player_input :: proc() -> Player_Input {
    return Player_Input{
        mouse_delta     = Vec2{rl.GetMouseDelta().x, rl.GetMouseDelta().y},
        move_forward    = rl.IsKeyDown(.W),
        move_back       = rl.IsKeyDown(.S),
        move_right      = rl.IsKeyDown(.D),
        move_left       = rl.IsKeyDown(.A),
        jump            = rl.IsKeyPressed(.SPACE),
        sprint          = rl.IsKeyDown(.LEFT_SHIFT),
        crouch          = rl.IsKeyDown(.LEFT_CONTROL),
        fire            = rl.IsMouseButtonDown(.LEFT),
        reload          = rl.IsKeyPressed(.R),
        switch_weapon_1 = rl.IsKeyPressed(.ONE),
        switch_weapon_2 = rl.IsKeyPressed(.TWO),
        switch_weapon_3 = rl.IsKeyPressed(.THREE),
        weapon_scroll   = rl.GetMouseWheelMove(),
    }
}
```

Raylib 호출은 이 함수 안에만 존재한다. 이후 모든 게임 로직은 `Player_Input` 구조체만 참조한다.

## 시뮬레이션 함수 시그니처 변경

모든 함수가 `^Player_Input`을 파라미터로 받도록 수정했다.

**Before:**
```odin
update_player :: proc(player: ^Player, world: ^World, dt: f32)
update_gun :: proc(gun: ^Gun, player: ^Player, targets: []Target, world: ^World, dt: f32)
```

**After:**
```odin
update_player :: proc(player: ^Player, input: ^Player_Input, world: ^World, dt: f32)
update_gun :: proc(gun: ^Gun, input: ^Player_Input, player: ^Player, targets: []Target, world: ^World, dt: f32)
```

내부 함수도 마찬가지다:
```odin
update_camera_look :: proc(player: ^Player, mouse_delta: Vec2)
update_move_state  :: proc(player: ^Player, input: ^Player_Input)
update_movement    :: proc(player: ^Player, input: ^Player_Input, dt: f32)
update_head_bob    :: proc(player: ^Player, input: ^Player_Input, dt: f32)
has_movement_input :: proc(input: ^Player_Input) -> bool
```

## 총기 입력 분리

총기 시스템에서도 Raylib 직접 호출을 모두 제거했다.

```odin
// Before
if rl.IsKeyPressed(.ONE)   do switch_weapon(gun, .Pistol)
if rl.IsMouseButtonDown(.LEFT) && ammo^ > 0 { ... }

// After
if input.switch_weapon_1 do switch_weapon(gun, .Pistol)
if input.fire && ammo^ > 0 { ... }
```

무기 스크롤, 재장전도 동일하게 `input` 필드로 교체했다.

## 메인 루프 변경

```odin
// Before
update_player(&game.player, &game.world, dt)
multi_result := update_gun(&game.gun, &game.player, ...)

// After
input := collect_player_input()
update_player(&game.player, &input, &game.world, dt)
multi_result := update_gun(&game.gun, &input, &game.player, ...)
```

한 줄이 추가됐을 뿐이지만, 이제 입력과 시뮬레이션이 완전히 분리되었다. 서버에서는 `collect_player_input()` 대신 네트워크에서 받은 입력을 넣으면 된다.

## 마치며

이 글에서 변경한 것:

- `Player_Input` 구조체로 입력 추상화
- `collect_player_input()`에서만 Raylib 입력 함수 호출
- `update_player`, `update_gun` 등 모든 시뮬레이션 함수가 `^Player_Input` 수신
- 메인 루프: 입력 수집 → 시뮬레이션 → 렌더링 3단계 분리

코드의 동작은 달라진 것이 없다. 플레이어 입장에서는 아무 차이도 느끼지 못한다. 하지만 이 리팩토링이 이후 네트워킹 구현의 전제 조건이 된다.

---

*이 시리즈의 전체 소스 코드는 [GitHub](https://github.com/novaeric0426/odin-fps)에서 확인할 수 있습니다.*
