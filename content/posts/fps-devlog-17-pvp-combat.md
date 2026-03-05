+++
date = '2026-03-04T18:00:00+09:00'
draft = false
title = 'FPS 개발일지 #17 — PvP 전투: 플레이어 간 히트스캔'
description = "히트스캔 시스템을 확장해서 플레이어끼리 총을 쏘고 죽일 수 있게 한다. Hit_Type으로 타겟과 플레이어 히트를 구분한다."
tags = ["Odin", "Raylib", "FPS", "게임개발", "멀티플레이어", "PvP", "히트스캔"]
categories = ["Game Dev"]
series = ["FPS 개발일지"]
+++

## 이번 글에서 다룰 것

지금까지 총은 AI 타겟만 맞출 수 있었다. 이번에는 히트스캔을 확장해서 다른 플레이어도 맞출 수 있게 한다. 가장 가까운 대상이 타겟이든 플레이어든 상관없이 명중 판정하고, 벽 차폐도 동일하게 적용한다.

## Hit_Type 구분

```odin
Hit_Type :: enum {
    None,
    Target,   // AI 타겟 명중
    Player,   // 다른 플레이어 명중
}
```

기존 `Fire_Result`에 히트 대상 종류와 피격 플레이어 인덱스를 추가했다.

```odin
Fire_Result :: struct {
    hit:          bool,
    killed:       bool,
    hit_position: Vec3,
    damage:       f32,
    target_id:    Entity_ID,
    hit_type:     Hit_Type,      // 새로 추가
    victim_index: int,           // 새로 추가 (Player 히트 시)
}
```

## fire_single_ray 확장

기존에는 AI 타겟만 검사했다. 이제 타겟과 플레이어를 모두 검사하고, 가장 가까운 대상을 선택한다.

```odin
fire_single_ray :: proc(
    ray: rl.Ray,
    targets: []Target,
    players: []Player,
    shooter_index: int,    // 자기 자신은 제외
    world: ^World,
    damage: f32,
) -> Fire_Result {
    result: Fire_Result

    closest_dist: f32 = 999999.0
    closest_hit_type: Hit_Type = .None
    closest_target_idx: int = -1
    closest_player_idx: int = -1
    closest_hit_point: Vec3

    // 1. AI 타겟 검사
    for i := 0; i < len(targets); i += 1 {
        if !targets[i].is_alive do continue
        bbox := get_target_bounding_box(&targets[i])
        collision := rl.GetRayCollisionBox(ray, bbox)

        if collision.hit && collision.distance < closest_dist {
            closest_dist = collision.distance
            closest_target_idx = i
            closest_player_idx = -1
            closest_hit_point = Vec3{collision.point.x, collision.point.y, collision.point.z}
            closest_hit_type = .Target
        }
    }

    // 2. 다른 플레이어 검사
    for i := 0; i < len(players); i += 1 {
        if i == shooter_index do continue   // 자기 자신 제외
        if !players[i].is_active do continue
        if !players[i].is_alive do continue

        bbox := get_player_bbox(players[i].position, players[i].current_height)
        collision := rl.GetRayCollisionBox(ray, bbox)

        if collision.hit && collision.distance < closest_dist {
            closest_dist = collision.distance
            closest_target_idx = -1
            closest_player_idx = i
            closest_hit_point = Vec3{collision.point.x, collision.point.y, collision.point.z}
            closest_hit_type = .Player
        }
    }

    // 3. 벽 차폐 검사 (가장 가까운 히트 대상 기준)
    if closest_hit_type != .None {
        wall_dist := get_closest_world_hit(ray, world)
        if wall_dist < closest_dist {
            return result  // 벽이 더 가까움 → 미명중
        }

        result.hit = true
        result.hit_position = closest_hit_point
        result.damage = damage
        result.hit_type = closest_hit_type

        if closest_hit_type == .Target {
            damage_target(&targets[closest_target_idx], damage)
            result.killed = !targets[closest_target_idx].is_alive
            result.target_id = targets[closest_target_idx].id
        } else if closest_hit_type == .Player {
            damage_player(&players[closest_player_idx], damage)
            result.killed = !players[closest_player_idx].is_alive
            result.victim_index = closest_player_idx
        }
    }

    return result
}
```

핵심 포인트:

- **자기 자신 제외**: `shooter_index`와 같은 인덱스는 건너뛴다. 자기 히트박스에 자기 총알이 맞으면 안 된다.
- **비활성/사망 제외**: `is_active`와 `is_alive` 모두 확인한다.
- **가장 가까운 대상 선택**: 타겟이든 플레이어든 거리가 가장 가까운 것이 명중 대상이다. 타겟 뒤에 플레이어가 있으면 타겟만 맞는다.
- **벽 차폐는 한 번만**: 가장 가까운 히트 대상과 벽 사이의 거리를 비교한다. 기존과 동일한 로직이다.

## 플레이어 히트박스

플레이어의 AABB는 `get_player_bbox`로 계산한다. `current_height`를 사용하므로 앉으면 히트박스가 줄어든다.

```odin
get_player_bbox :: proc(position: Vec3, height: f32) -> rl.BoundingBox {
    return rl.BoundingBox{
        min = {position.x - PLAYER_RADIUS, position.y, position.z - PLAYER_RADIUS},
        max = {position.x + PLAYER_RADIUS, position.y + height, position.z + PLAYER_RADIUS},
    }
}
```

## 시그니처 변경

`update_gun`과 `fire_gun`에 `players`와 `shooter_index`가 추가되었다.

```odin
// Before
update_gun :: proc(gun: ^Gun, input: ^Player_Input, player: ^Player,
                   targets: []Target, world: ^World, dt: f32)

// After
update_gun :: proc(gun: ^Gun, input: ^Player_Input, player: ^Player,
                   targets: []Target, players: []Player, shooter_index: int,
                   world: ^World, dt: f32)
```

`simulate_tick`에서 호출할 때 루프 인덱스 `i`를 `shooter_index`로 넘긴다.

```odin
for i := 0; i < MAX_PLAYERS; i += 1 {
    if !game.players[i].is_active do continue
    if !game.players[i].is_alive do continue

    update_player(&game.players[i], &inputs[i], &game.world, TICK_DT)
    multi_result := update_gun(&game.guns[i], &inputs[i], &game.players[i],
                               game.targets[:], game.players[:], i, &game.world, TICK_DT)
    // ...
}
```

## 클라이언트 총기 모델 초기화 수정

PvP에서 아무 슬롯이나 로컬 플레이어가 될 수 있다. 기존에는 슬롯 0만 총기 모델을 로드했지만, 이제 모든 슬롯에 모델을 로드한다.

```odin
// Before
game.players[0] = create_player(SPAWN_POINTS[0])
game.guns[0] = create_gun(model_path)

// After
for i := 0; i < MAX_PLAYERS; i += 1 {
    game.players[i] = create_player(SPAWN_POINTS[i])
    game.guns[i] = create_gun(model_path)
}
// 로컬 모드에서는 슬롯 0만 활성
for i := 1; i < MAX_PLAYERS; i += 1 {
    game.players[i].is_active = false
}
```

`draw_gun`에도 가드를 추가했다.

```odin
draw_gun :: proc(gun: ^Gun, camera: ^rl.Camera3D) {
    if !gun.has_model do return
    // ...
}
```

## 히트 피드백

서버에서 PvP 히트가 발생하면 `Net_Hit_Event`에 기록되고 스냅샷으로 전달된다. 클라이언트는 기존과 동일하게 데미지 넘버를 표시한다. 히트마커(흰색 X = 명중, 빨간 X = 킬)도 그대로 동작한다.

타겟을 맞추든 플레이어를 맞추든 시각 피드백은 동일하다. `Hit_Type`에 따라 다른 피드백(킬 로그, 킬피드 등)을 추가하는 것은 향후 작업이다.

## 마치며

이 글에서 구현한 것:

- `Hit_Type` enum (None/Target/Player)
- `fire_single_ray`가 타겟 + 플레이어를 모두 검사, 가장 가까운 대상 선택
- `shooter_index`로 자기 자신 제외
- 플레이어 AABB 히트박스 (`get_player_bbox`)
- 벽 차폐는 기존과 동일하게 가장 가까운 히트 기준으로 한 번 검사
- 모든 슬롯에 총기 모델 초기화

이것으로 FPS 개발일지 시리즈가 일단락된다. 싱글플레이어 기초부터 시작해서 UDP 네트워킹, 권위 서버, 클라이언트 예측, 엔티티 보간, 그리고 PvP 전투까지 구현했다. 아직 플레이어 간 충돌, 스코어보드, 서버 사이드 히트 검증 등 남은 과제가 있지만, 멀티플레이어 FPS의 핵심 구조는 완성되었다.

---

*이 시리즈의 전체 소스 코드는 [GitHub](https://github.com/novaeric0426)에서 확인할 수 있습니다.*
