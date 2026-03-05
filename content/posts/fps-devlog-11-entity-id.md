+++
date = '2026-02-28T18:00:00+09:00'
draft = false
title = 'FPS 개발일지 #11 — 엔티티 ID 시스템'
description = "배열 인덱스 대신 고유 ID로 엔티티를 식별한다. 네트워크 동기화에서 안전한 엔티티 매칭의 기반."
tags = ["Odin", "Raylib", "FPS", "게임개발", "멀티플레이어", "엔티티"]
categories = ["Game Dev"]
series = ["FPS 개발일지"]
+++

## 이번 글에서 다룰 것

지금까지 타겟을 식별할 때 배열 인덱스를 사용했다. `targets[3]`이 맞았다면 인덱스 3을 기록하는 식이다. 로컬에서는 문제없지만, 네트워크 환경에서는 서버와 클라이언트의 배열 순서가 다를 수 있다.

이번 글에서는 각 엔티티에 고유 ID를 부여하는 시스템을 구현한다.

## 왜 인덱스가 위험한가

```
서버: targets = [A, B, C]  → 인덱스 2 = C
클라이언트: targets = [A, C, B]  → 인덱스 2 = B (잘못된 대상!)
```

엔티티가 추가/제거되면 인덱스가 밀린다. 서버가 "인덱스 2를 공격했다"고 보내도 클라이언트에서 인덱스 2가 같은 엔티티라는 보장이 없다. 고유 ID가 있으면 배열 순서에 관계없이 정확한 엔티티를 찾을 수 있다.

## Entity_ID 타입

```odin
Entity_ID :: distinct u32

INVALID_ENTITY :: Entity_ID(0)

next_entity_id: Entity_ID = 1

gen_entity_id :: proc() -> Entity_ID {
    id := next_entity_id
    next_entity_id += 1
    return id
}
```

`distinct u32`는 Odin의 고유 타입 기능이다. 일반 `u32`와 실수로 섞이는 것을 컴파일러가 방지해준다. ID 0은 "없음"을 뜻하는 무효값이고, 1부터 순차 할당한다.

## ID 부착

`Player`, `Target` 구조체에 `id` 필드를 추가했다.

```odin
Player :: struct {
    id: Entity_ID,
    // ... 기존 필드
}

Target :: struct {
    id: Entity_ID,
    // ... 기존 필드
}
```

생성 시 자동 할당:
```odin
create_player :: proc(spawn_position: Vec3, ...) -> Player {
    player := Player{
        id = gen_entity_id(),
        // ...
    }
    return player
}

create_target :: proc(position: Vec3, ...) -> Target {
    return Target{
        id = gen_entity_id(),
        // ...
    }
}
```

## ID 기반 검색

```odin
find_target_by_id :: proc(targets: []Target, id: Entity_ID) -> ^Target {
    for &t in targets {
        if t.id == id do return &t
    }
    return nil
}
```

현재 타겟 수가 16개 이하이므로 선형 검색으로 충분하다. 수백 개가 되면 해시맵으로 바꿀 수 있지만, 지금은 과한 최적화다.

## 네트워크 상태에 ID 포함

`Net_Player_State`와 `Net_Target_State`에도 ID를 추가했다.

```odin
Net_Player_State :: struct {
    id:       u32,   // Entity_ID는 distinct u32이므로 u32로 전송
    position: Vec3,
    // ...
}

Net_Target_State :: struct {
    id:       u32,
    position: Vec3,
    // ...
}
```

네트워크 구조체에서는 `distinct` 타입 대신 원시 `u32`를 사용한다. 직렬화 시 불필요한 타입 변환을 피하기 위해서다.

## 스냅샷 적용 개선

이전에는 인덱스 순서대로 적용했다:

```odin
// Before: 인덱스 기반 — 순서가 틀리면 잘못된 타겟에 적용
for i := 0; i < count; i += 1 {
    apply_target_state(&game.targets[i], &snapshot.targets[i])
}
```

이제는 ID로 매칭한다:

```odin
// After: ID 기반 — 배열 순서 무관
for i := 0; i < count; i += 1 {
    net_target := &snapshot.targets[i]
    target := find_target_by_id(game.targets[:], Entity_ID(net_target.id))
    if target != nil {
        apply_target_state(target, net_target)
    }
}
```

서버와 클라이언트의 배열 순서가 달라도 ID가 같은 엔티티에 정확히 상태가 적용된다.

## 히트 이벤트에 ID 활용

`Fire_Result`에도 `target_id`를 추가했다.

```odin
Fire_Result :: struct {
    hit:          bool,
    killed:       bool,
    hit_position: Vec3,
    damage:       f32,
    target_id:    Entity_ID,  // 새로 추가
}
```

히트스캔 결과에 "어떤 타겟을 맞혔는가"를 인덱스가 아닌 ID로 기록한다. 이후 서버가 히트 이벤트를 클라이언트에 전달할 때 이 ID를 사용하게 된다.

## 마치며

이 글에서 구현한 것:

- `Entity_ID` — `distinct u32` 고유 타입, 자동 순차 할당
- `Player`, `Target`에 ID 필드 추가
- `find_target_by_id` — ID 기반 엔티티 검색
- 스냅샷 적용 시 인덱스 → ID 매칭으로 변경
- `Fire_Result`에 `target_id` 추가

작은 변경이지만, 네트워크 환경에서 엔티티를 안전하게 식별하기 위한 필수 기반이다.

---

*이 시리즈의 전체 소스 코드는 [GitHub](https://github.com/novaeric0426/odin-fps)에서 확인할 수 있습니다.*
