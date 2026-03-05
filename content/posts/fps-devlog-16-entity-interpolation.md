+++
date = '2026-03-03T18:00:00+09:00'
draft = false
title = 'FPS 개발일지 #16 — 엔티티 보간'
description = "60Hz 스냅샷 사이를 보간해서 다른 플레이어와 AI 타겟을 부드럽게 렌더링한다."
tags = ["Odin", "Raylib", "FPS", "게임개발", "멀티플레이어", "네트워킹", "보간"]
categories = ["Game Dev"]
series = ["FPS 개발일지"]
+++

## 이번 글에서 다룰 것

자기 캐릭터는 예측 덕분에 부드럽게 움직인다. 하지만 다른 플레이어와 AI 타겟은 서버 스냅샷이 도착할 때마다 위치가 "텔레포트"된다. 60Hz 스냅샷이면 16ms마다 한 번씩 툭툭 끊기는 것이다.

**엔티티 보간(Entity Interpolation)**은 두 스냅샷 사이를 선형 보간(lerp)해서 매 프레임 부드러운 위치를 계산하는 기법이다.

## 보간의 원리

```
스냅샷 도착 타이밍: ──┬────────────────┬────────────────┬──
                     t=0             t=16ms          t=32ms

렌더링 프레임:       ─┬──┬──┬──┬──┬──┬──┬──┬──┬──┬──┬──
                     0  2  5  8  11 14 16 19 22 ...

보간:  alpha=0.0 → 0.125 → 0.3125 → ... → 1.0 → 0.0(리셋)
       prev 위치에서 curr 위치를 향해 매 프레임 부드럽게 이동
```

두 개의 스냅샷(prev, curr)을 버퍼링하고, `alpha`를 0에서 1까지 올리면서 `lerp(prev, curr, alpha)`로 중간 위치를 계산한다. 새 스냅샷이 도착하면 curr → prev로 시프트하고 alpha를 0으로 리셋한다.

## 보간 상태 구조체

```odin
Interp_Player :: struct {
    prev_position:       Vec3,
    prev_yaw:            f32,
    prev_pitch:          f32,
    prev_current_height: f32,
    curr_position:       Vec3,
    curr_yaw:            f32,
    curr_pitch:          f32,
    curr_current_height: f32,
    has_prev:            bool,
}

Interp_Target :: struct {
    prev_position: Vec3,
    curr_position: Vec3,
    has_prev:      bool,
}

Interp_State :: struct {
    players: [MAX_PLAYERS]Interp_Player,
    targets: [MAX_TARGETS]Interp_Target,
    alpha:   f32,  // 0.0 ~ 1.0
}
```

플레이어는 위치, 회전, 높이(앉기/서기)를 보간한다. 타겟은 위치만 보간한다.

## 스냅샷 수신 시 업데이트

```odin
update_interp_from_snapshot :: proc(interp: ^Interp_State, snapshot: ^Game_Snapshot, local_index: int) {
    for i := 0; i < MAX_PLAYERS; i += 1 {
        if i == local_index do continue  // 로컬 플레이어는 예측 사용
        ip := &interp.players[i]
        np := &snapshot.players[i]

        if !np.is_active {
            ip.has_prev = false
            continue
        }

        // curr → prev 시프트
        if ip.has_prev {
            ip.prev_position       = ip.curr_position
            ip.prev_yaw            = ip.curr_yaw
            ip.prev_pitch          = ip.curr_pitch
            ip.prev_current_height = ip.curr_current_height
        }

        // 새 curr 로드
        ip.curr_position       = np.position
        ip.curr_yaw            = np.yaw
        ip.curr_pitch          = np.pitch
        ip.curr_current_height = np.current_height

        // 첫 스냅샷: prev = curr (제로에서 lerp 방지)
        if !ip.has_prev {
            ip.prev_position       = ip.curr_position
            ip.prev_yaw            = ip.curr_yaw
            ip.prev_pitch          = ip.curr_pitch
            ip.prev_current_height = ip.curr_current_height
            ip.has_prev = true
        }
    }

    // 타겟도 동일한 패턴
    // ...

    interp.alpha = 0.0  // 리셋
}
```

`has_prev = false`인 첫 스냅샷에서는 prev와 curr을 같은 값으로 초기화한다. 그렇지 않으면 제로(0, 0, 0)에서 실제 위치까지 한 번 날아가는 현상이 발생한다.

## alpha 진행

```odin
advance_interp :: proc(interp: ^Interp_State, dt: f32) {
    interp.alpha += dt / TICK_DT
    if interp.alpha > 1.0 {
        interp.alpha = 1.0
    }
}
```

`dt / TICK_DT`로 정규화한다. 한 틱(16.67ms) 동안 alpha가 0에서 1까지 올라간다. 다음 스냅샷이 도착하면 0으로 리셋된다.

alpha가 1.0을 넘으면 클램프한다. 외삽(extrapolation)은 하지 않는다. 스냅샷이 늦으면 마지막 위치에서 멈춘다.

## 보간된 값 읽기

```odin
get_interp_player :: proc(interp: ^Interp_State, slot: int) -> (position: Vec3, yaw: f32, pitch: f32, height: f32) {
    ip := &interp.players[slot]
    if !ip.has_prev {
        return ip.curr_position, ip.curr_yaw, ip.curr_pitch, ip.curr_current_height
    }

    t := interp.alpha
    position = Vec3{
        lerp(ip.prev_position.x, ip.curr_position.x, t),
        lerp(ip.prev_position.y, ip.curr_position.y, t),
        lerp(ip.prev_position.z, ip.curr_position.z, t),
    }
    yaw    = lerp_angle(ip.prev_yaw, ip.curr_yaw, t)
    pitch  = lerp(ip.prev_pitch, ip.curr_pitch, t)
    height = lerp(ip.prev_current_height, ip.curr_current_height, t)
    return
}
```

## 각도 보간: lerp_angle

일반 lerp로 yaw를 보간하면 359° → 1°일 때 358°를 돌아간다. 최단 경로로 보간해야 한다.

```odin
lerp_angle :: proc(a, b, t: f32) -> f32 {
    diff := b - a
    for diff > 180.0  do diff -= 360.0
    for diff < -180.0 do diff += 360.0
    return a + diff * t
}
```

차이를 [-180, 180] 범위로 래핑하면 항상 최단 방향으로 보간된다.

## 렌더링 적용

**다른 플레이어:**
```odin
for i := 0; i < MAX_PLAYERS; i += 1 {
    if i == local_index do continue
    pos, _, _, height := get_interp_player(&interp, i)
    draw_other_player_interp(&game.players[i], i, pos, height)
}
```

보간된 위치/높이를 명시적으로 전달하는 `draw_other_player_interp` 함수를 추가했다. 게임 로직의 실제 위치(`player.position`)는 건드리지 않는다.

**AI 타겟:**
```odin
// 타겟 위치를 임시로 보간 값으로 교체
count := min(len(game.targets), MAX_TARGETS)
saved_positions: [MAX_TARGETS]Vec3
for i := 0; i < count; i += 1 {
    saved_positions[i] = game.targets[i].position
    game.targets[i].position = get_interp_target_position(&interp, i)
}
draw_targets(game.targets[:], &player.camera)
// 복원
for i := 0; i < count; i += 1 {
    game.targets[i].position = saved_positions[i]
}
```

타겟은 기존 `draw_targets` 함수를 그대로 사용하되, 그리기 전에 위치를 보간 값으로 교체하고 그린 뒤 복원한다. 게임 로직에는 영향을 주지 않는다.

## 보간 범위

보간 대상:
- 다른 플레이어 (위치, yaw, pitch, 높이)
- AI 타겟 (위치)

보간 하지 않는 것:
- 로컬 플레이어 (예측 사용)
- 로컬 모드 (보간 불필요)
- 총기 상태, HP 등 비연속 값

## 마치며

이 글에서 구현한 것:

- `Interp_State` — prev/curr 스냅샷 버퍼, alpha 보간 비율
- 스냅샷 도착 시 curr → prev 시프트, alpha 리셋
- `lerp_angle` — yaw 360→0 래핑 처리
- 다른 플레이어: `draw_other_player_interp`로 보간 위치 렌더링
- AI 타겟: 위치 교체 → 그리기 → 복원 패턴

이것으로 Phase 3(네트워킹)이 완성되었다. 권위 서버, 멀티플레이어 슬롯, 클라이언트 예측, 엔티티 보간 — 네트워크 게임의 핵심 기법을 모두 구현했다. 다음 글에서는 플레이어끼리 총을 쏘는 PvP 전투를 추가한다.

---

*이 시리즈의 전체 소스 코드는 [GitHub](https://github.com/novaeric0426)에서 확인할 수 있습니다.*
