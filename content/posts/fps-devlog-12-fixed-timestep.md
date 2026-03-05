+++
date = '2026-03-01T18:00:00+09:00'
draft = false
title = 'FPS 개발일지 #12 — 고정 타임스텝 시뮬레이션'
description = "프레임 의존적이던 게임 루프를 60Hz 고정 타임스텝으로 전환한다. 서버와 동일한 틱 레이트로 시뮬레이션하기 위한 기반."
tags = ["Odin", "Raylib", "FPS", "게임개발", "멀티플레이어", "게임루프", "타임스텝"]
categories = ["Game Dev"]
series = ["FPS 개발일지"]
+++

## 이번 글에서 다룰 것

지금까지 게임 루프는 `dt = rl.GetFrameTime()`을 사용했다. 60fps에서는 `dt ≈ 0.0167`, 120fps에서는 `dt ≈ 0.0083`. 물리 시뮬레이션이 프레임 레이트에 따라 미세하게 달라진다.

멀티플레이어에서는 서버와 클라이언트가 **정확히 같은 시뮬레이션 결과**를 내야 한다. 이를 위해 고정 타임스텝(fixed timestep)을 도입한다.

## 가변 vs 고정 타임스텝

**가변 타임스텝 (기존):**
```
프레임1: dt = 0.018 → simulate(0.018)
프레임2: dt = 0.015 → simulate(0.015)
프레임3: dt = 0.020 → simulate(0.020)
```

매 프레임 `dt`가 다르다. 같은 입력이라도 `dt`에 따라 결과가 미세하게 달라질 수 있다.

**고정 타임스텝:**
```
TICK_DT = 1/60 = 0.01667

프레임1: dt = 0.018 → accumulator = 0.018 → simulate(TICK_DT) 1회, 남은 0.0013
프레임2: dt = 0.015 → accumulator = 0.0163 → 0회 (아직 부족)
프레임3: dt = 0.020 → accumulator = 0.0363 → simulate(TICK_DT) 2회, 남은 0.003
```

시뮬레이션은 항상 `TICK_DT = 1/60`초 단위로만 실행된다. 프레임 레이트가 변해도 시뮬레이션 결과는 동일하다.

## 어큐뮬레이터 패턴

핵심 아이디어는 간단하다. 렌더링과 시뮬레이션의 타이밍을 분리하는 것이다.

```
매 프레임:
  accumulator += frame_dt        // 렌더링 시간 누적
  while accumulator >= TICK_DT:  // 틱 단위로 시뮬레이션
    simulate(TICK_DT)
    accumulator -= TICK_DT
```

누적된 시간이 한 틱 분량 이상이면 시뮬레이션을 실행하고, 남은 시간은 다음 프레임으로 이월한다. 이렇게 하면:

- 렌더링은 가변 프레임 레이트 (모니터 주사율에 맞춤)
- 시뮬레이션은 고정 60Hz (서버와 동일)

## 상수 정의

```odin
TICK_RATE :: 60
TICK_DT   :: 1.0 / f32(TICK_RATE)
MAX_TICKS_PER_FRAME :: 5
```

`MAX_TICKS_PER_FRAME`은 안전장치다. 프레임이 극단적으로 느려지면(예: 0.5초 걸린 프레임) 어큐뮬레이터에 30틱 분량이 쌓인다. 한 프레임에서 30번 시뮬레이션을 돌리면 더 느려지는 악순환에 빠진다. 최대 5틱으로 제한하면 시뮬레이션이 약간 느려질 수는 있어도 프레임이 멈추지는 않는다.

## simulate_tick 함수

기존의 업데이트 로직을 `simulate_tick`으로 묶었다.

```odin
simulate_tick :: proc(game: ^Game_State, input: ^Player_Input) {
    update_player_death(&game.player, TICK_DT)
    update_targets(game.targets[:], &game.world, game.player.position, TICK_DT)

    if game.player.is_alive {
        update_player(&game.player, input, &game.world, TICK_DT)
        multi_result := update_gun(&game.gun, input, &game.player,
                                   game.targets[:], &game.world, TICK_DT)

        for &hit in multi_result.hits {
            if hit.hit {
                append(&game.damage_numbers, Damage_Number{
                    position = hit.hit_position,
                    amount   = hit.damage,
                    lifetime = DAMAGE_NUMBER_DURATION,
                })
            }
        }
        delete(multi_result.hits)
    }

    update_damage_numbers(&game.damage_numbers, TICK_DT)
}
```

모든 `dt` 파라미터가 `TICK_DT`로 통일되었다. 이 함수는 이후 서버에서도 동일하게 호출된다.

## 메인 루프 변경

```odin
Game_State :: struct {
    // ...
    tick_accumulator: f32,  // 새로 추가
}

// 메인 루프
for !rl.WindowShouldClose() {
    frame_dt := rl.GetFrameTime()

    if !game.is_paused {
        game.tick_accumulator += frame_dt

        // 입력은 프레임당 한 번만 수집
        input := collect_player_input()

        ticks := 0
        for game.tick_accumulator >= TICK_DT && ticks < MAX_TICKS_PER_FRAME {
            simulate_tick(&game, &input)
            game.tick_accumulator -= TICK_DT
            ticks += 1

            // pressed 입력은 첫 틱에서만 적용
            input.jump = false
            input.reload = false
            input.switch_weapon_1 = false
            input.switch_weapon_2 = false
            input.switch_weapon_3 = false
            input.weapon_scroll = 0
        }
    }

    // 렌더링 ...
}
```

## pressed 입력 클리어

한 프레임에서 여러 틱이 실행될 수 있다. `IsKeyPressed`는 프레임 단위로 한 번만 true를 반환하므로, 첫 번째 틱에서 점프를 처리한 뒤 나머지 틱에서는 false로 초기화해야 한다. 그렇지 않으면 한 번의 스페이스바로 여러 번 점프하는 버그가 발생한다.

held 입력(이동, 사격, 스프린트)은 클리어하지 않는다. 누르고 있는 동안 모든 틱에서 적용되어야 하기 때문이다.

## VSync 전환

```odin
// Before
rl.SetTargetFPS(60)

// After
rl.SetConfigFlags({.VSYNC_HINT})
```

`SetTargetFPS(60)`는 소프트웨어 프레임 제한이다. 시뮬레이션이 고정 타임스텝으로 돌아가므로 렌더링 속도를 인위적으로 제한할 필요가 없다. VSync로 전환하면 모니터 주사율에 맞춰 렌더링하되, 시뮬레이션은 항상 정확히 60Hz로 유지된다.

## 마치며

이 글에서 구현한 것:

- `TICK_RATE = 60`, `TICK_DT = 1/60` 고정 타임스텝
- 어큐뮬레이터 패턴으로 렌더링/시뮬레이션 타이밍 분리
- `simulate_tick()` — 한 틱의 전체 게임 로직
- pressed 입력은 첫 틱에서만, held 입력은 모든 틱에서 적용
- `MAX_TICKS_PER_FRAME = 5` 안전장치
- VSync 전환

이것으로 Phase 2(멀티플레이어 준비)가 완성되었다. 입력 분리, 직렬화, 엔티티 ID, 고정 타임스텝 — 이 네 가지가 갖춰지면 네트워킹 구현을 시작할 수 있다. 다음 글부터는 Phase 3, 실제 UDP 네트워킹을 다룬다.

---

*이 시리즈의 전체 소스 코드는 [GitHub](https://github.com/novaeric0426/odin-fps)에서 확인할 수 있습니다.*
