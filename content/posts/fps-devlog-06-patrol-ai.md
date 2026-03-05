+++
date = '2026-02-15T18:00:00+09:00'
draft = false
title = 'FPS 개발일지 #06 — AI 타겟 패트롤 시스템'
description = "웨이포인트 기반 핑퐁 패트롤 AI 구현. 고정된 더미 타겟에서 움직이는 타겟으로."
tags = ["Odin", "Raylib", "FPS", "게임개발", "AI"]
categories = ["Game Dev"]
series = ["FPS 개발일지"]
+++

## 문제

지금까지 타겟은 제자리에 서 있는 더미(dummy)였다. 사격 연습이 되긴 하지만 재미가 없다. 웨이포인트를 따라 이동하는 패트롤 AI를 구현한다.

## Target 구조체 확장

```odin
Target :: struct {
    position: Vec3,
    size:     Vec3,
    hp:       f32,
    max_hp:   f32,
    is_alive: bool,
    color:    rl.Color,
    // 패트롤 필드
    waypoints:        []Vec3,
    current_waypoint: int,
    patrol_speed:     f32,
    patrol_direction: i32,  // +1: 정방향, -1: 역방향 (핑퐁)
}
```

`waypoints`가 비어 있으면 기존처럼 고정 타겟으로 동작한다. 패트롤 타겟과 고정 타겟이 같은 타입으로 공존할 수 있다.

## 패트롤 타겟 생성

```odin
create_patrol_target :: proc(
    waypoints: []Vec3,
    size: Vec3 = {1, 2, 1},
    hp: f32 = 100.0,
    color: rl.Color = rl.RED,
    speed: f32 = 2.5,
) -> Target {
    start_pos := waypoints[0] if len(waypoints) > 0 else Vec3{}
    return Target{
        position         = start_pos,
        size             = size,
        hp               = hp,
        max_hp           = hp,
        is_alive         = true,
        color            = color,
        waypoints        = waypoints,
        current_waypoint = 1 if len(waypoints) > 1 else 0,
        patrol_speed     = speed,
        patrol_direction = 1,
    }
}
```

첫 번째 웨이포인트에서 시작하고, 두 번째 웨이포인트를 향해 이동한다.

## 핑퐁 패트롤

웨이포인트 끝에 도달하면 방향을 반대로 바꾸는 핑퐁(ping-pong) 방식이다.

```
[0] → [1] → [2] → [1] → [0] → [1] → ...
```

```odin
PATROL_ARRIVE_THRESHOLD :: 0.2

update_target :: proc(target: ^Target, world: ^World, dt: f32) {
    if len(target.waypoints) == 0 || !target.is_alive do return

    goal := target.waypoints[target.current_waypoint]
    diff := Vec3{goal.x - target.position.x, 0, goal.z - target.position.z}
    dist := linalg.length(diff)

    if dist < PATROL_ARRIVE_THRESHOLD {
        // 다음 웨이포인트로 (핑퐁)
        next := target.current_waypoint + int(target.patrol_direction)
        if next >= len(target.waypoints) {
            target.patrol_direction = -1
            next = target.current_waypoint - 1
        } else if next < 0 {
            target.patrol_direction = 1
            next = target.current_waypoint + 1
        }
        target.current_waypoint = next
        return
    }

    dir := diff / dist
    move_dist := target.patrol_speed * dt
    // 축별 이동 + 충돌 체크 (아래에서 설명)
}
```

이동은 XZ 평면에서만 한다. Y 성분을 무시해서 높이 변화 없이 수평으로만 움직인다.

## 타겟의 충돌 처리

타겟도 벽을 통과하면 안 된다. 플레이어와 같은 축별 이동 + 롤백 방식을 사용하되, 약간 작은 AABB(epsilon 축소)를 사용한다.

```odin
check_target_collision_world :: proc(target: ^Target, pos: Vec3, world: ^World) -> bool {
    EPSILON :: 0.01
    half := Vec3{
        target.size.x / 2 - EPSILON,
        target.size.y / 2 - EPSILON,
        target.size.z / 2 - EPSILON,
    }
    bbox := rl.BoundingBox{
        min = pos - half,
        max = pos + half,
    }
    for &wall in world.walls {
        if rl.CheckCollisionBoxes(bbox, get_wall_bbox(&wall)) do return true
    }
    for &obs in world.obstacles {
        if rl.CheckCollisionBoxes(bbox, get_obstacle_bbox(&obs)) do return true
    }
    return false
}
```

`EPSILON`으로 AABB를 살짝 줄인 이유는 벽에 정확히 맞닿았을 때 부동소수점 오차로 충돌이 감지되는 것을 방지하기 위해서다.

## 시각적 인디케이터

패트롤 타겟 머리 위에 와이어 구를 표시해서 고정 타겟과 구분한다.

```odin
if len(target.waypoints) > 0 {
    indicator_pos := rl.Vector3{
        target.position.x,
        target.position.y + target.size.y / 2 + 0.7,
        target.position.z,
    }
    rl.DrawSphereWires(indicator_pos, 0.15, 4, 4, rl.SKYBLUE)
}
```

## 마치며

이 글에서 구현한 것:

- 웨이포인트 기반 핑퐁 패트롤
- XZ 평면 이동 (Y축 무시)
- 타겟 월드 충돌 처리 (epsilon AABB)
- 패트롤 인디케이터

고정 타겟과 패트롤 타겟이 같은 `Target` 구조체를 공유하므로, 기존 코드(데미지, 히트스캔 등)를 수정할 필요가 없다.

다음 글에서는 무기 전환 시스템(권총/소총/샷건)을 다룬다.

---

*이 시리즈의 전체 소스 코드는 [GitHub](https://github.com/novaeric0426/odin-fps)에서 확인할 수 있습니다.*
