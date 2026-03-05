+++
date = '2026-02-21T18:00:00+09:00'
draft = false
title = 'FPS 개발일지 #08 — Chase AI: 감지/추적/복귀 상태 머신'
description = "패트롤 AI에 플레이어 감지, 추적, 복귀 상태를 추가한다. 히스테리시스로 상태 떨림을 방지하는 방법까지."
tags = ["Odin", "Raylib", "FPS", "게임개발", "AI", "상태머신"]
categories = ["Game Dev"]
series = ["FPS 개발일지"]
+++

## 이번 글에서 다룰 것

패트롤만 하는 타겟은 맞고만 있을 뿐 위협이 되지 않는다. 플레이어를 감지하면 쫓아오고, 거리가 벌어지면 다시 패트롤로 돌아가는 Chase AI를 구현한다.

## 상태 머신 설계

```odin
Target_AI_State :: enum {
    Idle,    // 고정 타겟 (웨이포인트 없음)
    Patrol,  // 웨이포인트 패트롤
    Chase,   // 플레이어 추적
    Return,  // 패트롤 경로로 복귀
}
```

4개의 상태와 전이 규칙은 다음과 같다:

```
Idle (고정 타겟)
  └─ 아무 것도 안 함

Patrol ──[플레이어 감지]──→ Chase
  ↑                            │
  │                    [플레이어 이탈]
  │                            ↓
  └──[웨이포인트 도착]─── Return
```

## Target 구조체 확장

```odin
Target :: struct {
    // ... 기존 필드 ...

    ai_state:      Target_AI_State,
    detect_range:  f32,   // 감지 범위
    lose_range:    f32,   // 추적 해제 범위
    chase_speed:   f32,   // 추적 속도
    return_target: Vec3,  // 복귀할 웨이포인트 위치
}
```

생성 시 기본값:
```odin
ai_state     = .Patrol,
detect_range = 12.0,
lose_range   = 18.0,
chase_speed  = speed * 1.8,  // 패트롤보다 1.8배 빠름
```

## 히스테리시스 (Hysteresis)

감지 범위와 해제 범위가 같으면 문제가 생긴다.

```
detect_range = 15.0
lose_range   = 15.0

→ 플레이어가 15.0 부근에 서 있으면:
  프레임1: 거리 14.99 → Chase
  프레임2: 거리 15.01 → Return
  프레임3: 거리 14.98 → Chase
  ... (무한 반복)
```

이를 **상태 떨림(state flickering)**이라 한다. 해결 방법은 감지 범위와 해제 범위 사이에 간격을 두는 것이다.

```
detect_range = 12.0  (이 안에 들어오면 Chase)
lose_range   = 18.0  (이 밖으로 나가면 Return)
```

12~18 사이에 있으면 현재 상태가 유지된다. 이것이 히스테리시스다. 에어컨 온도 조절에서 "25도에 켜고 23도에 끈다"와 같은 원리다.

## 공통 이동 함수

Patrol, Chase, Return 모두 "목표 지점을 향해 이동"하는 동작이 공통이다. 이것을 하나의 함수로 뽑았다.

```odin
move_target_toward :: proc(target: ^Target, goal: Vec3, speed: f32, world: ^World, dt: f32) -> f32 {
    diff := Vec3{goal.x - target.position.x, 0, goal.z - target.position.z}
    dist := linalg.length(diff)
    if dist < 0.01 do return dist

    dir := diff / dist
    move_dist := speed * dt

    // 축별 이동 + 충돌 롤백
    target.position.x += dir.x * move_dist
    if check_target_collision_world(target, target.position, world) {
        target.position.x -= dir.x * move_dist
    }
    target.position.z += dir.z * move_dist
    if check_target_collision_world(target, target.position, world) {
        target.position.z -= dir.z * move_dist
    }

    return dist
}
```

XZ 평면 이동, 월드 충돌, 남은 거리 반환까지 하나로 처리한다.

## 상태별 로직

```odin
update_target :: proc(target: ^Target, world: ^World, player_pos: Vec3, dt: f32) {
    if !target.is_alive do return

    player_diff := Vec3{player_pos.x - target.position.x, 0, player_pos.z - target.position.z}
    player_dist := linalg.length(player_diff)

    switch target.ai_state {
    case .Idle:
        // 아무것도 안 함

    case .Patrol:
        // 감지 체크
        if target.detect_range > 0 && player_dist < target.detect_range {
            target.ai_state = .Chase
            return
        }
        // 웨이포인트 이동 (기존 패트롤 로직)
        // ...

    case .Chase:
        // 이탈 체크
        if player_dist > target.lose_range {
            nearest := find_nearest_waypoint(target)
            target.current_waypoint = nearest
            target.return_target = target.waypoints[nearest]
            target.ai_state = .Return
            return
        }
        // 플레이어를 향해 이동
        move_target_toward(target, player_pos, target.chase_speed, world, dt)

    case .Return:
        // 복귀 중에도 감지 체크
        if target.detect_range > 0 && player_dist < target.detect_range {
            target.ai_state = .Chase
            return
        }
        dist := move_target_toward(target, target.return_target, target.patrol_speed, world, dt)
        if dist < PATROL_ARRIVE_THRESHOLD {
            target.ai_state = .Patrol
        }
    }
}
```

핵심 포인트:
- **Chase → Return**: `lose_range` 밖으로 나가면 가장 가까운 웨이포인트를 찾아 복귀
- **Return → Patrol**: 웨이포인트에 도착하면 패트롤 재개
- **Return → Chase**: 복귀 중에도 플레이어가 다시 접근하면 바로 추적 전환

## 가장 가까운 웨이포인트 찾기

```odin
find_nearest_waypoint :: proc(target: ^Target) -> int {
    best_idx := 0
    best_dist: f32 = max(f32)
    for wp, i in target.waypoints {
        diff := Vec3{wp.x - target.position.x, 0, wp.z - target.position.z}
        d := linalg.length(diff)
        if d < best_dist {
            best_dist = d
            best_idx = i
        }
    }
    return best_idx
}
```

Chase가 끝났을 때 타겟이 패트롤 경로에서 벗어나 있을 수 있다. 가장 가까운 웨이포인트로 복귀하면 자연스럽게 패트롤을 재개한다.

## 시각 인디케이터

상태에 따라 머리 위 와이어 구 색이 바뀐다.

```odin
indicator_color: rl.Color
switch target.ai_state {
case .Chase:         indicator_color = rl.RED
case .Return:        indicator_color = rl.YELLOW
case .Idle, .Patrol: indicator_color = rl.SKYBLUE
}
rl.DrawSphereWires(indicator_pos, 0.15, 4, 4, indicator_color)
```

- 하늘색: 평화 (Idle/Patrol)
- 빨강: 추적 중 (Chase)
- 노랑: 복귀 중 (Return)

## 마치며

이 글에서 구현한 것:

- 4-상태 AI 상태 머신 (Idle/Patrol/Chase/Return)
- 히스테리시스로 상태 떨림 방지 (detect=12, lose=18)
- 공통 이동 함수 `move_target_toward`
- 가장 가까운 웨이포인트로 복귀
- 상태별 시각 인디케이터

이것으로 Phase 1(싱글플레이어 기반)이 완성되었다. 다음 글부터는 Phase 2로 넘어가 멀티플레이어 준비를 시작한다.

---

*이 시리즈의 전체 소스 코드는 [GitHub](https://github.com/novaeric0426)에서 확인할 수 있습니다.*
