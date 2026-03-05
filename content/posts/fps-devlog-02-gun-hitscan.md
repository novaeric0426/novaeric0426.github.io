+++
date = '2026-02-05T18:00:00+09:00'
draft = false
title = 'FPS 개발일지 #02 — 총기 시스템과 히트스캔 구현'
description = "3D 모델 로딩, 카메라 기반 총기 배치, 히트스캔 레이캐스팅, 그리고 총기 회전 버그 수정까지."
tags = ["Odin", "Raylib", "FPS", "게임개발", "히트스캔"]
categories = ["Game Dev"]
series = ["FPS 개발일지"]
+++

## 이번 글에서 다룰 것

FPS 컨트롤러 위에 총기 시스템을 얹는다. 모델을 로딩해서 화면 오른쪽 하단에 배치하고, 클릭하면 히트스캔 방식으로 사격하는 것까지가 목표다.

## 총기 모델 로딩

Raylib은 `.glb` (glTF binary) 포맷을 바로 로딩할 수 있다.

```odin
create_gun :: proc(model_path: cstring) -> Gun {
    model := rl.LoadModel(model_path)

    if model.meshCount == 0 {
        fmt.println("WARNING: Gun model failed to load from:", model_path)
    } else {
        fmt.println("Gun model loaded:", model.meshCount, "meshes")
    }

    return Gun {
        model           = model,
        offset_position = {0.1, -0.05, 0.1},
        offset_rotation = {0, 90, 0},
        scale           = 0.5,
        state           = .Idle,
        fire_rate       = 10.0,
        // ...
    }
}
```

`offset_position`은 카메라 기준 상대 좌표다. x=오른쪽, y=아래, z=앞. 이 값을 조절해서 일반적인 FPS 게임처럼 화면 우하단에 총이 보이도록 한다.

## 카메라 기준 총기 배치

총기 모델은 월드 좌표가 아니라 **카메라 좌표계**에 따라 위치해야 한다. 카메라가 움직이고 회전하면 총도 함께 움직여야 하니까.

```odin
draw_gun :: proc(gun: ^Gun, camera: ^rl.Camera3D) {
    // 카메라 기저 벡터 계산
    forward := linalg.normalize(camera.target - camera.position)
    right   := linalg.normalize(linalg.cross(forward, Vec3{0, 1, 0}))
    up      := linalg.cross(right, forward)

    offset := gun.offset_position
    offset.x += gun.current_sway.x
    offset.y += gun.current_sway.y - gun.current_recoil.x * 0.02

    // 카메라 기저 벡터로 월드 좌표 변환
    gun_pos := camera.position +
               right   * offset.x +
               up      * offset.y +
               forward * offset.z
```

`forward`, `right`, `up` 세 벡터가 카메라의 로컬 좌표축이 된다. 오프셋을 이 축에 곱해서 월드 좌표로 변환한다.

## 총기 회전 버그와 수정

초기 구현에서는 카메라 방향으로부터 오일러 각도(yaw, pitch)를 역산해서 총기 모델에 적용했다.

```odin
// 버그가 있던 코드
yaw   := math.atan2(forward.x, forward.z)
pitch := -math.asin(forward.y)

transform := translate(gun_pos) *
             rotate(yaw + offset_rot.y, Y_AXIS) *
             rotate(pitch + offset_rot.x, right) *
             scale(...)
```

이 방식은 특정 각도에서 총이 뒤틀리는 문제가 있었다. 오일러 각도 분해 자체가 불안정하기 때문이다.

**수정**: 카메라 기저 벡터를 직접 회전 행렬로 조립하는 방식으로 변경했다.

```odin
// 수정된 코드: 기저 벡터로 직접 회전 행렬 구성
cam_rot := linalg.Matrix4f32{
    right.x,    up.x,    -forward.x,   0,
    right.y,    up.y,    -forward.y,   0,
    right.z,    up.z,    -forward.z,   0,
    0,          0,        0,            1,
}

// 모델 자체의 오프셋 회전 (glb 파일의 방향 보정)
offset_rot := rotate(gun.offset_rotation.y * DEG2RAD, Y) *
              rotate(gun.offset_rotation.x * DEG2RAD, X) *
              rotate(gun.offset_rotation.z * DEG2RAD, Z)

transform := translate(gun_pos) * cam_rot * offset_rot * scale(...)
```

핵심은 **오일러 각도 분해를 하지 않는 것**이다. 카메라의 right/up/forward 벡터가 이미 완전한 회전 정보를 담고 있으므로, 이것을 열(column)로 배치하면 바로 회전 행렬이 된다. `-forward`를 사용하는 이유는 뷰 공간에서 카메라가 -Z 방향을 바라보기 때문이다.

## 히트스캔 (Hitscan)

히트스캔은 총알이 날아가는 것을 시뮬레이션하지 않고, **발사 즉시 레이캐스트**로 맞았는지 판정하는 방식이다. CS나 VALORANT 같은 게임에서 사용한다.

```odin
fire_gun :: proc(gun: ^Gun, player: ^Player, targets: []Target, world: ^World) {
    gun.ammo -= 1

    // 카메라에서 정면으로 레이 발사
    ray := rl.Ray{
        position  = player.camera.position,
        direction = linalg.normalize(player.camera.target - player.camera.position),
    }

    // 모든 타겟의 AABB와 교차 검사
    closest_dist: f32 = 999999.0
    closest_idx: int = -1

    for i := 0; i < len(targets); i += 1 {
        if !targets[i].is_alive do continue

        bbox := get_target_bbox(&targets[i])
        collision := rl.GetRayCollisionBox(ray, bbox)

        if collision.hit && collision.distance < closest_dist {
            closest_dist = collision.distance
            closest_idx = i
        }
    }

    // 벽 차폐 체크
    if closest_idx >= 0 {
        wall_dist := get_closest_world_hit(ray, world)
        if wall_dist < closest_dist {
            return  // 벽이 더 가까움 → 맞지 않음
        }
        damage_target(&targets[closest_idx], gun.damage)
    }
}
```

흐름은 간단하다:

1. 카메라 위치에서 정면 방향으로 `Ray`를 만든다
2. 모든 살아있는 타겟의 AABB(축 정렬 바운딩 박스)와 교차 검사
3. 가장 가까운 타겟을 찾는다
4. **벽 차폐 체크**: 타겟보다 가까운 벽이 있으면 사격이 차단됨
5. 차폐되지 않았으면 데미지 적용

### 벽 차폐 (Wall Occlusion)

```odin
get_closest_world_hit :: proc(ray: rl.Ray, world: ^World) -> f32 {
    closest: f32 = 999999.0
    for &wall in world.walls {
        c := rl.GetRayCollisionBox(ray, get_wall_bbox(&wall))
        if c.hit && c.distance < closest do closest = c.distance
    }
    for &obs in world.obstacles {
        c := rl.GetRayCollisionBox(ray, get_obstacle_bbox(&obs))
        if c.hit && c.distance < closest do closest = c.distance
    }
    return closest
}
```

벽과 장애물 전체를 한 번 더 레이캐스트해서 가장 가까운 월드 히트 거리를 구한다. 이 거리가 타겟까지의 거리보다 짧으면 "벽 뒤에 있는 타겟"이므로 데미지를 적용하지 않는다.

## 반동과 스웨이

### 반동 (Recoil)

발사할 때마다 카메라가 위로 튀어오르는 효과다.

```odin
// 발사 시
player.pitch += gun.recoil_amount.x
player.yaw   += rand_range(-gun.recoil_amount.y, gun.recoil_amount.y)

// 매 프레임 회복
gun.current_recoil.x = lerp(gun.current_recoil.x, 0, gun.recoil_recovery * dt)
```

pitch(상하)는 고정량, yaw(좌우)는 랜덤 범위로 흔들린다. `recoil_recovery`로 시간이 지나면 자연스럽게 원래 위치로 돌아온다.

### 스웨이 (Weapon Sway)

마우스를 움직이면 총기 모델이 살짝 따라오는 관성 효과다.

```odin
mouse_delta := rl.GetMouseDelta()
target_sway := Vec2{-mouse_delta.x * gun.sway_amount, -mouse_delta.y * gun.sway_amount}
gun.current_sway.x = lerp(gun.current_sway.x, target_sway.x, gun.sway_smooth * dt)
gun.current_sway.y = lerp(gun.current_sway.y, target_sway.y, gun.sway_smooth * dt)
```

마우스 이동의 반대 방향으로 오프셋을 주고, `lerp`로 부드럽게 따라오게 한다.

## 마치며

이 글에서 구현한 것:

- glb 모델 로딩 및 카메라 기반 배치
- 카메라 기저 벡터 기반 총기 회전 (오일러 각도 분해 버그 수정)
- 히트스캔 레이캐스팅
- 벽 차폐 처리
- 반동 및 무기 스웨이

다음 글에서는 월드 충돌 처리(AABB 슬라이드 콜리전)를 다룬다.

---

*이 시리즈의 전체 소스 코드는 [GitHub](https://github.com/novaeric0426/odin-fps)에서 확인할 수 있습니다.*
