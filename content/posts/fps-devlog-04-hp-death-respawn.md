+++
date = '2026-02-10T18:00:00+09:00'
draft = false
title = 'FPS 개발일지 #04 — 플레이어 HP, 데미지, 죽음과 리스폰'
description = "체력 시스템, 데미지 처리, 사망/리스폰 로직 구현. 죽으면 2초 뒤 자동으로 되살아나는 리스폰 시스템."
tags = ["Odin", "Raylib", "FPS", "게임개발"]
categories = ["Game Dev"]
series = ["FPS 개발일지"]
+++

## 이번 글에서 다룰 것

총을 쏘고 맞출 수 있게 됐으니, 이제 플레이어도 맞으면 죽어야 한다. HP 시스템, 데미지 처리, 사망 상태, 자동 리스폰을 구현한다.

## Player 구조체 확장

```odin
Player :: struct {
    // ... 기존 필드들 ...

    // HP & Death
    hp:             f32,
    max_hp:         f32,
    is_alive:       bool,
    death_timer:    f32,
    spawn_position: Vec3,
}
```

추가된 필드는 5개다:
- `hp` / `max_hp`: 현재/최대 체력 (100)
- `is_alive`: 생존 상태
- `death_timer`: 리스폰까지 남은 시간
- `spawn_position`: 처음 스폰 위치를 저장해두고, 리스폰할 때 사용

## 데미지 → 사망

```odin
damage_player :: proc(player: ^Player, amount: f32) {
    if !player.is_alive do return
    player.hp -= amount
    if player.hp <= 0 {
        player.hp = 0
        kill_player(player)
    }
}

kill_player :: proc(player: ^Player) {
    player.is_alive = false
    player.death_timer = RESPAWN_DELAY  // 2.0초
    player.velocity = {0, 0, 0}
}
```

이미 죽어있으면 데미지를 무시한다. HP가 0 이하로 떨어지면 `kill_player`로 사망 처리하고, 속도를 0으로 만든다.

## 자동 리스폰

```odin
RESPAWN_DELAY :: 2.0

update_player_death :: proc(player: ^Player, dt: f32) {
    if player.is_alive do return
    player.death_timer -= dt
    if player.death_timer <= 0 {
        respawn_player(player)
    }
}

respawn_player :: proc(player: ^Player) {
    player.position = player.spawn_position
    player.velocity = {0, 0, 0}
    player.hp = player.max_hp
    player.is_alive = true
    player.death_timer = 0
    player.yaw = 0
    player.pitch = 0
    player.move_state = .Walking
    player.is_grounded = false
    player.current_height = player.config.height_standing
    sync_camera(player)
}
```

사망 후 `death_timer`가 매 프레임 감소하다가 0이 되면 `respawn_player`가 호출된다. 리스폰은 모든 상태를 초기값으로 되돌린다 — 위치, 속도, 체력, 카메라 방향까지.

## 게임 루프에서의 처리 순서

```odin
// 매 프레임
update_player_death(&game.player, dt)  // 죽은 상태면 타이머 감소

if game.player.is_alive {
    update_player(&game.player, &game.world, dt)
    update_gun(&game.gun, &game.player, game.targets[:], &game.world, dt)
}
```

사망 상태에서는 이동과 사격이 모두 무시된다. `update_player_death`만 돌면서 리스폰 타이머를 카운트다운한다.

## 사망 화면 UI

```odin
if !game.player.is_alive {
    rl.DrawRectangle(0, 0, WINDOW_WIDTH, WINDOW_HEIGHT, rl.Color{200, 0, 0, 80})
    rl.DrawText("YOU DIED", WINDOW_WIDTH/2 - 100, WINDOW_HEIGHT/2 - 30, 40, rl.RED)
    timer_text := rl.TextFormat("Respawning in %.1f...", game.player.death_timer)
    rl.DrawText(timer_text, WINDOW_WIDTH/2 - 90, WINDOW_HEIGHT/2 + 20, 20, rl.WHITE)
}
```

죽으면 화면에 빨간 오버레이와 "YOU DIED" 텍스트, 리스폰 카운트다운을 표시한다.

## HP 바 UI

화면 하단에 체력 바를 그린다.

```odin
hp_ratio := game.player.hp / game.player.max_hp
bar_color: rl.Color
if hp_ratio > 0.6       do bar_color = rl.GREEN
else if hp_ratio > 0.3  do bar_color = rl.YELLOW
else                     do bar_color = rl.RED
```

체력 비율에 따라 색이 변한다: 초록(60% 이상) → 노랑(30% 이상) → 빨강.

## 마치며

이 글에서 구현한 것:

- HP 시스템 (100 HP)
- 데미지 처리 (중복 데미지 방지)
- 사망 상태 (이동/사격 불가)
- 2초 자동 리스폰 (전체 상태 초기화)
- 사망 화면 UI + HP 바

다음 글에서는 히트마커와 데미지 넘버로 사격 피드백을 강화한다.

---

*이 시리즈의 전체 소스 코드는 [GitHub](https://github.com/novaeric0426/odin-fps)에서 확인할 수 있습니다.*
