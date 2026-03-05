+++
date = '2026-02-19T18:00:00+09:00'
draft = false
title = 'FPS 개발일지 #07 — 무기 전환 시스템 (권총/소총/샷건)'
description = "3종 무기의 설계, Weapon_Config 기반 스탯 관리, 샷건 멀티 펠릿, 무기 전환 딜레이 구현."
tags = ["Odin", "Raylib", "FPS", "게임개발", "무기"]
categories = ["Game Dev"]
series = ["FPS 개발일지"]
+++

## 이번 글에서 다룰 것

지금까지 하나의 총만 있었다. 이번에 권총(Pistol), 소총(Rifle), 샷건(Shotgun) 3종 무기와 전환 시스템을 구현한다.

## 설계: 데이터 주도 무기 시스템

무기마다 별도 구조체나 클래스를 만드는 대신, **하나의 Config 테이블**로 모든 무기를 정의한다.

```odin
Weapon_Type :: enum {
    Pistol,
    Rifle,
    Shotgun,
}

Weapon_Config :: struct {
    fire_rate:       f32,
    max_ammo:        i32,
    reserve_ammo:    i32,
    damage:          f32,
    recoil_amount:   Vec2,
    recoil_recovery: f32,
    pellet_count:    i32,   // 샷건: 한 발에 여러 펠릿
    spread:          f32,   // 샷건: 펠릿 확산 (라디안)
    switch_time:     f32,   // 무기 전환 딜레이
}
```

`pellet_count`와 `spread`가 핵심이다. 권총과 소총은 `pellet_count=1, spread=0`이고, 샷건만 `pellet_count=8, spread=0.06`이다. 같은 발사 로직으로 모든 무기를 처리할 수 있다.

## 무기별 스탯

```odin
weapons := [Weapon_Type]Weapon_Config{
    .Pistol = {
        fire_rate = 5.0,   max_ammo = 12,  reserve_ammo = 999,
        damage = 20.0,     recoil_amount = {2.0, 0.1},
        recoil_recovery = 10.0,
        pellet_count = 1,  spread = 0.0,   switch_time = 0.3,
    },
    .Rifle = {
        fire_rate = 10.0,  max_ammo = 30,  reserve_ammo = 90,
        damage = 15.0,     recoil_amount = {1.5, 0.3},
        recoil_recovery = 8.0,
        pellet_count = 1,  spread = 0.0,   switch_time = 0.4,
    },
    .Shotgun = {
        fire_rate = 1.5,   max_ammo = 8,   reserve_ammo = 32,
        damage = 8.0,      recoil_amount = {4.0, 0.5},
        recoil_recovery = 6.0,
        pellet_count = 8,  spread = 0.06,  switch_time = 0.5,
    },
}
```

권총은 단발 고데미지, 소총은 연사, 샷건은 근거리 8펠릿이다. 무기 밸런싱은 이 테이블만 수정하면 된다.

## Gun 구조체 변경

단일 무기에서 복수 무기를 관리하도록 바꿨다.

```odin
Gun :: struct {
    model:          rl.Model,
    // ...

    // 무기 시스템
    weapons:        [Weapon_Type]Weapon_Config,
    current_weapon: Weapon_Type,
    weapon_ammo:    [Weapon_Type]i32,    // 무기별 현재 탄약
    weapon_reserve: [Weapon_Type]i32,    // 무기별 예비 탄약

    // 무기 전환
    switching:      bool,
    switch_timer:   f32,
    switch_target:  Weapon_Type,

    state:          Gun_State,  // Idle, Firing, Reloading, Switching
    // ...
}
```

`weapon_ammo`와 `weapon_reserve`를 `[Weapon_Type]` 배열로 관리한다. 소총에서 샷건으로 바꿔도 소총의 탄약 상태가 유지된다.

## 무기 전환

```odin
switch_weapon :: proc(gun: ^Gun, target: Weapon_Type) {
    if target == gun.current_weapon do return
    if gun.switching do return

    gun.switching = true
    gun.switch_timer = gun.weapons[target].switch_time
    gun.switch_target = target
    gun.state = .Switching
}
```

같은 무기로의 전환이나 이미 전환 중일 때는 무시한다. 전환 딜레이(`switch_time`) 동안 사격이 불가능하다.

### 입력 처리

```odin
// 숫자키
if rl.IsKeyPressed(.ONE)   do switch_weapon(gun, .Pistol)
if rl.IsKeyPressed(.TWO)   do switch_weapon(gun, .Rifle)
if rl.IsKeyPressed(.THREE) do switch_weapon(gun, .Shotgun)

// 마우스 휠
wheel := rl.GetMouseWheelMove()
if wheel != 0 {
    current := int(gun.current_weapon)
    next := (current + (wheel > 0 ? 1 : -1) + 3) % 3
    switch_weapon(gun, Weapon_Type(next))
}
```

## 샷건: 멀티 펠릿

샷건의 핵심은 한 번 발사에 여러 레이를 쏘는 것이다.

```odin
Multi_Fire_Result :: struct {
    hits: [dynamic]Fire_Result,
}
```

`pellet_count`만큼 반복하면서, 각 펠릿마다 `spread` 범위 내에서 랜덤 방향으로 레이를 발사한다.

```odin
// 각 펠릿에 랜덤 확산 적용
spread_x := rand.float32_range(-config.spread, config.spread)
spread_y := rand.float32_range(-config.spread, config.spread)
pellet_dir := linalg.normalize(base_dir + right * spread_x + up * spread_y)
```

기본 발사 방향(`base_dir`)에 right/up 방향으로 랜덤 오프셋을 더한다. 결과적으로 원뿔(cone) 형태로 펠릿이 퍼진다.

거리에 따른 데미지 감소(falloff)는 없다. 멀리 있으면 순수하게 기하학적으로 펠릿이 빗나가서 맞는 수가 줄어드는 것이 "사실상의" 거리 감소다.

## 마치며

이 글에서 구현한 것:

- `Weapon_Config` 기반 데이터 주도 무기 시스템
- 3종 무기 (Pistol/Rifle/Shotgun)
- 무기별 독립 탄약 관리
- 무기 전환 딜레이 (`.Switching` 상태)
- 샷건 멀티 펠릿 (랜덤 원뿔 확산)
- 1/2/3 키 + 마우스 휠 전환

다음 글에서는 패트롤 AI에 플레이어 추적(Chase) 기능을 추가한다.

---

*이 시리즈의 전체 소스 코드는 [GitHub](https://github.com/novaeric0426/odin-fps)에서 확인할 수 있습니다.*
