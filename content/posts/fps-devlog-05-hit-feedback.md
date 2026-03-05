+++
date = '2026-02-12T18:00:00+09:00'
draft = false
title = 'FPS 개발일지 #05 — 히트마커와 데미지 넘버'
description = "히트마커 X 오버레이와 플로팅 데미지 넘버로 사격 피드백을 강화한다."
tags = ["Odin", "Raylib", "FPS", "게임개발", "UI"]
categories = ["Game Dev"]
series = ["FPS 개발일지"]
+++

## 문제

총을 쏴서 타겟의 HP가 줄어들지만, 플레이어 입장에서 "맞았다"는 느낌이 전혀 없었다. 히트마커와 데미지 넘버를 추가한다.

## Fire_Result

히트 정보를 반환하도록 `update_gun`의 시그니처를 변경했다.

```odin
Fire_Result :: struct {
    hit:          bool,
    killed:       bool,
    hit_position: Vec3,
    damage:       f32,
}

update_gun :: proc(gun: ^Gun, player: ^Player, targets: []Target, world: ^World, dt: f32) -> Fire_Result {
    // ...
    result := fire_gun(gun, player, targets, world)
    if result.hit {
        gun.hitmarker_timer = HITMARKER_DURATION
        gun.hitmarker_is_kill = result.killed
    }
    return result
}
```

발사 함수가 히트 여부, 킬 여부, 히트 위치, 데미지를 담은 `Fire_Result`를 반환한다. 호출자는 이 결과를 보고 UI 피드백을 생성한다.

## 히트마커

크로스헤어 위에 X자 형태의 히트마커를 0.15초간 표시한다.

```odin
HITMARKER_DURATION :: 0.15

// draw_gun_ui 안에서
if gun.hitmarker_timer > 0 {
    alpha := u8(gun.hitmarker_timer / HITMARKER_DURATION * 255)
    color := gun.hitmarker_is_kill ? rl.Color{255, 0, 0, alpha} : rl.Color{255, 255, 255, alpha}

    cx := i32(WINDOW_WIDTH / 2)
    cy := i32(WINDOW_HEIGHT / 2)
    gap: i32 = 5
    len: i32 = 10

    // X 형태: 크로스헤어 주변 대각선 4개
    rl.DrawLine(cx - gap, cy - gap, cx - gap - len, cy - gap - len, color)
    rl.DrawLine(cx + gap, cy - gap, cx + gap + len, cy - gap - len, color)
    rl.DrawLine(cx - gap, cy + gap, cx - gap - len, cy + gap + len, color)
    rl.DrawLine(cx + gap, cy + gap, cx + gap + len, cy + gap + len, color)
}
```

일반 히트는 흰색, 킬은 빨간색이다. 타이머가 줄어들면서 알파 값이 함께 감소해 자연스럽게 페이드아웃된다.

## 데미지 넘버

맞은 위치에서 숫자가 떠오르며 사라지는 효과다.

```odin
DAMAGE_NUMBER_DURATION   :: 0.8
DAMAGE_NUMBER_RISE_SPEED :: 1.5

Damage_Number :: struct {
    position: Vec3,
    amount:   f32,
    lifetime: f32,
}
```

### 생성

```odin
// 히트 시 데미지 넘버 생성
if fire_result.hit {
    append(&game.damage_numbers, Damage_Number{
        position = fire_result.hit_position,
        amount   = fire_result.damage,
        lifetime = DAMAGE_NUMBER_DURATION,
    })
}
```

`fire_result`의 `hit_position`이 레이와 타겟 AABB의 교차점이다. 정확히 맞은 지점에서 숫자가 뜬다.

### 업데이트

```odin
update_damage_numbers :: proc(numbers: ^[dynamic]Damage_Number, dt: f32) {
    i := 0
    for i < len(numbers) {
        numbers[i].position.y += DAMAGE_NUMBER_RISE_SPEED * dt
        numbers[i].lifetime -= dt
        if numbers[i].lifetime <= 0 {
            ordered_remove(numbers, i)
        } else {
            i += 1
        }
    }
}
```

매 프레임 위로 떠오르고(`position.y += ...`), `lifetime`이 0이 되면 제거한다. `ordered_remove`로 순서를 유지하면서 삭제한다.

### 렌더링

```odin
draw_damage_numbers :: proc(numbers: []Damage_Number, camera: ^rl.Camera3D) {
    for &dn in numbers {
        alpha := u8(dn.lifetime / DAMAGE_NUMBER_DURATION * 255)
        screen_pos := rl.GetWorldToScreen(rl.Vector3{dn.position.x, dn.position.y, dn.position.z}, camera^)

        text := rl.TextFormat("%.0f", dn.amount)
        rl.DrawText(text, i32(screen_pos.x), i32(screen_pos.y), 20, rl.Color{255, 255, 0, alpha})
    }
}
```

3D 위치를 `GetWorldToScreen`으로 화면 좌표로 변환한 뒤, 2D 텍스트로 그린다. 남은 `lifetime`에 비례해 페이드아웃된다.

## 마치며

이 글에서 구현한 것:

- `Fire_Result` 구조체로 히트 정보 반환
- 히트마커 (흰색=히트, 빨간색=킬, 0.15초 페이드)
- 데미지 넘버 (노란색, 떠오르며 0.8초 페이드)

사운드는 아직 없다. 시각 피드백만으로도 사격의 "느낌"이 크게 달라진다.

다음 글에서는 AI 타겟에 패트롤 웨이포인트를 추가한다.

---

*이 시리즈의 전체 소스 코드는 [GitHub](https://github.com/novaeric0426)에서 확인할 수 있습니다.*
