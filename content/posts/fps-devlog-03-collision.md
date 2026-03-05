+++
date = '2026-02-06T18:00:00+09:00'
draft = false
title = 'FPS 개발일지 #03 — AABB 슬라이드 콜리전'
description = "축별 이동과 롤백으로 구현하는 AABB 충돌 처리. 벽에 부딪혀도 미끄러지듯 움직이는 슬라이드 콜리전."
tags = ["Odin", "Raylib", "FPS", "게임개발", "충돌처리"]
categories = ["Game Dev"]
series = ["FPS 개발일지"]
+++

## 문제

이전 글까지는 플레이어가 벽과 장애물을 그냥 통과했다. y=0 바닥 체크만 있었을 뿐, 진짜 충돌 처리가 없었다.

이번 글에서는 AABB(축 정렬 바운딩 박스) 기반의 슬라이드 콜리전을 구현한다.

## 왜 AABB인가

3D 충돌 처리에는 여러 방법이 있다:
- **구(Sphere)**: 가장 간단하지만 벽 근처에서 부정확
- **AABB**: 축 정렬 박스. 빠르고 구현이 간단
- **OBB/Convex Hull**: 정확하지만 복잡

FPS에서 플레이어는 보통 직립 캡슐이나 박스로 근사한다. AABB면 충분하다.

## 플레이어 AABB

```odin
PLAYER_RADIUS :: 0.3

get_player_bbox :: proc(position: Vec3, height: f32) -> rl.BoundingBox {
    return rl.BoundingBox{
        min = {position.x - PLAYER_RADIUS, position.y, position.z - PLAYER_RADIUS},
        max = {position.x + PLAYER_RADIUS, position.y + height, position.z + PLAYER_RADIUS},
    }
}
```

플레이어의 위치(`position.y`)가 발 위치이고, 거기서 `height`만큼 위로 뻗는 박스다. 앉으면 height가 줄어들어 AABB도 작아진다.

## 월드 AABB 헬퍼

벽과 장애물도 AABB로 표현한다.

```odin
get_wall_bbox :: proc(wall: ^Wall) -> rl.BoundingBox {
    half := Vec3{wall.size.x / 2, wall.size.y / 2, wall.size.z / 2}
    return rl.BoundingBox{
        min = wall.position - half,
        max = wall.position + half,
    }
}

get_obstacle_bbox :: proc(obs: ^Obstacle) -> rl.BoundingBox {
    switch obs.type {
    case .Box, .Ramp:
        half := Vec3{obs.size.x / 2, obs.size.y / 2, obs.size.z / 2}
        return rl.BoundingBox{min = obs.position - half, max = obs.position + half}
    case .Cylinder:
        r := obs.size.x
        h := obs.size.y
        return rl.BoundingBox{
            min = {obs.position.x - r, obs.position.y, obs.position.z - r},
            max = {obs.position.x + r, obs.position.y + h, obs.position.z + r},
        }
    }
    return rl.BoundingBox{}
}
```

실린더도 AABB로 근사한다. 정확한 원통 충돌 판정보다 훨씬 간단하고, 게임플레이에 큰 차이가 없다.

## 슬라이드 콜리전

핵심 아이디어는 **축별(axis-by-axis) 이동**이다.

```
1. X축으로 이동 → 충돌 체크 → 겹치면 X 롤백
2. Y축으로 이동 → 충돌 체크 → 겹치면 Y 롤백
3. Z축으로 이동 → 충돌 체크 → 겹치면 Z 롤백
```

이렇게 하면 벽에 대각선으로 부딪혀도 **막히지 않는 축 방향으로는 미끄러지듯 이동**한다. 이것이 "슬라이드" 콜리전이다.

```odin
apply_velocity :: proc(player: ^Player, world: ^World, dt: f32) {
    // X축
    player.position.x += player.velocity.x * dt
    if check_collision_world(get_player_bbox(player.position, player.current_height), world) {
        player.position.x -= player.velocity.x * dt
        player.velocity.x = 0
    }

    // Y축
    player.position.y += player.velocity.y * dt
    if check_collision_world(get_player_bbox(player.position, player.current_height), world) {
        player.position.y -= player.velocity.y * dt
        player.velocity.y = 0
    }

    // Z축
    player.position.z += player.velocity.z * dt
    if check_collision_world(get_player_bbox(player.position, player.current_height), world) {
        player.position.z -= player.velocity.z * dt
        player.velocity.z = 0
    }
}
```

각 축에서 이동 후 겹침이 발생하면 해당 축만 롤백하고 속도를 0으로 만든다. 단순하지만 효과적이다.

### 월드 전체 충돌 체크

```odin
check_collision_world :: proc(bbox: rl.BoundingBox, world: ^World) -> bool {
    for &wall in world.walls {
        if rl.CheckCollisionBoxes(bbox, get_wall_bbox(&wall)) do return true
    }
    for &obs in world.obstacles {
        if rl.CheckCollisionBoxes(bbox, get_obstacle_bbox(&obs)) do return true
    }
    return false
}
```

Raylib의 `CheckCollisionBoxes`가 두 AABB의 겹침을 판정한다. 벽과 장애물 전체를 순회하면서 하나라도 겹치면 `true`를 반환한다.

## 장애물 위에 올라서기

바닥만 y=0으로 체크하던 것을 장애물 위에도 올라설 수 있게 확장했다.

```odin
update_ground_check :: proc(player: ^Player, world: ^World) {
    ground_level: f32 = 0.0

    // 플레이어 발 아래 얇은 박스로 바닥 탐지
    feet_probe := rl.BoundingBox{
        min = {player.position.x - PLAYER_RADIUS, player.position.y - 0.05, player.position.z - PLAYER_RADIUS},
        max = {player.position.x + PLAYER_RADIUS, player.position.y, player.position.z + PLAYER_RADIUS},
    }

    obstacle_ground: f32 = ground_level
    for &obs in world.obstacles {
        bbox := get_obstacle_bbox(&obs)
        if rl.CheckCollisionBoxes(feet_probe, bbox) {
            top := bbox.max.y
            if top > obstacle_ground {
                obstacle_ground = top
            }
        }
    }

    if player.position.y <= obstacle_ground {
        player.position.y = obstacle_ground
        player.velocity.y = 0
        player.is_grounded = true
    } else {
        player.is_grounded = false
    }
}
```

발 바로 아래에 얇은 AABB(`feet_probe`)를 만들어서 장애물 윗면과 겹치는지 확인한다. 겹치는 장애물 중 가장 높은 윗면을 새 바닥으로 사용한다.

## 마치며

이 글에서 구현한 것:

- 플레이어/벽/장애물의 AABB 정의
- 축별 이동 + 롤백 기반 슬라이드 콜리전
- 장애물 위 착지 판정

이 AABB 헬퍼 함수들(`get_wall_bbox`, `get_obstacle_bbox`)은 나중에 히트스캔의 벽 차폐 판정에서도 재사용된다.

다음 글에서는 플레이어 HP, 데미지, 죽음/리스폰 시스템을 다룬다.

---

*이 시리즈의 전체 소스 코드는 [GitHub](https://github.com/novaeric0426/odin-fps)에서 확인할 수 있습니다.*
