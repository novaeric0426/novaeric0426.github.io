+++
date = '2026-02-01T18:00:00+09:00'
draft = false
title = 'FPS 개발일지 #01 — Odin + Raylib으로 3D FPS 만들기'
description = "Odin 언어와 Raylib을 선택한 이유, 프로젝트 초기 세팅, 1인칭 카메라와 이동 시스템 구현까지의 기록."
tags = ["Odin", "Raylib", "FPS", "게임개발"]
categories = ["Game Dev"]
series = ["FPS 개발일지"]
+++

## 들어가며

멀티플레이어 FPS 게임을 처음부터 만들어보기로 했다. 엔진 없이, 프로그래밍 언어와 그래픽 라이브러리만으로.

이 시리즈는 그 과정을 처음부터 기록한다. 첫 번째 글에서는 기술 스택을 고른 이유와, 3D 공간에서 걸어다닐 수 있는 FPS 컨트롤러를 만든 과정을 다룬다.

## 기술 스택: 왜 Odin + Raylib인가

### Odin

[Odin](https://odin-lang.org/)은 시스템 프로그래밍 언어다. C의 단순함을 유지하면서 현대적인 편의성을 갖추고 있다.

게임 개발에서 Odin을 선택한 이유:

- **Raylib이 vendor 패키지로 내장** — 별도 바인딩 설치 없이 `import rl "vendor:raylib"`만으로 바로 사용 가능
- **C 수준의 성능**, 하지만 메모리 안전성과 가독성은 훨씬 나음
- **빌드가 빠르다** — `odin build ./src -out:fps-game` 한 줄이면 끝
- **패키지 매니저 없이** 표준 라이브러리만으로 네트워킹(`core:net`)까지 가능

### Raylib

[Raylib](https://www.raylib.com/)는 게임 프로그래밍 교육용으로 시작된 C 라이브러리지만, 실제 프로젝트에도 충분히 쓸 수 있다.

- 3D 렌더링, 모델 로딩, 입력 처리, 오디오까지 올인원
- API가 직관적 — `BeginMode3D()`, `DrawCube()` 같은 함수명을 보면 바로 이해됨
- 의존성이 거의 없어서 크로스 플랫폼 빌드가 간단

## 프로젝트 구조

```
fps-game/
├── src/
│   ├── main.odin      # 진입점, 게임 루프
│   ├── player.odin     # FPS 컨트롤러
│   └── world.odin      # 환경 (바닥, 벽, 장애물)
├── assets/
│   └── ak47.glb        # 총기 모델
└── .gitignore
```

처음부터 파일을 역할별로 분리했다. `main.odin`은 게임 루프와 상태 관리, `player.odin`은 플레이어 이동과 카메라, `world.odin`은 맵 환경을 담당한다.

## 게임 루프

Odin + Raylib의 기본 게임 루프는 이렇게 생겼다:

```odin
main :: proc() {
    rl.InitWindow(1280, 720, "Odin + Raylib 3D FPS Controller")
    defer rl.CloseWindow()

    rl.SetTargetFPS(60)
    rl.DisableCursor()

    game := create_game_state()

    for !rl.WindowShouldClose() {
        dt := rl.GetFrameTime()

        if !game.is_paused {
            update_player(&game.player, dt)
        }

        rl.BeginDrawing()
        rl.ClearBackground(rl.RAYWHITE)

        rl.BeginMode3D(game.player.camera)
        draw_world(&game.world)
        rl.EndMode3D()

        draw_ui(&game)
        rl.EndDrawing()
    }
}
```

`defer`를 사용해 윈도우 정리를 보장하는 부분이 Odin다운 점이다. `rl.DisableCursor()`로 마우스 커서를 숨기고 FPS 시점의 마우스 입력을 받는다.

## FPS 컨트롤러 구현

### Player 구조체

```odin
Player :: struct {
    position:       Vec3,
    velocity:       Vec3,
    yaw:            f32,      // 좌우 회전 (degrees)
    pitch:          f32,      // 상하 회전 (degrees)
    move_state:     Move_State,
    is_grounded:    bool,
    current_height: f32,
    head_bob_timer: f32,
    head_bob_offset: f32,
    camera:         rl.Camera3D,
    config:         Player_Config,
}

Move_State :: enum {
    Walking,
    Sprinting,
    Crouching,
    In_Air,
}
```

이동 상태를 enum으로 분리한 것이 핵심이다. 각 상태마다 이동 속도, 카메라 높이가 다르고, 나중에 애니메이션이나 사운드를 연결할 때도 상태 기반으로 처리할 수 있다.

### 카메라 회전 (마우스 룩)

```odin
mouse_delta := rl.GetMouseDelta()
player.yaw   -= mouse_delta.x * config.mouse_sensitivity * rl.RAD2DEG
player.pitch -= mouse_delta.y * config.mouse_sensitivity * rl.RAD2DEG
player.pitch  = clamp(player.pitch, -89.0, 89.0)
```

`yaw`와 `pitch`를 별도로 관리하고, pitch를 -89~89도로 클램프해서 카메라가 뒤집히는 것을 방지한다. 짐벌락 문제가 없는 단순한 FPS 카메라에서는 오일러 각도면 충분하다.

### WASD 이동

```odin
// 카메라 방향 기준 이동 벡터 계산
forward := Vec3{math.sin(yaw_rad), 0, math.cos(yaw_rad)}
right   := Vec3{math.cos(yaw_rad), 0, -math.sin(yaw_rad)}

move_dir: Vec3
if rl.IsKeyDown(.W) do move_dir += forward
if rl.IsKeyDown(.S) do move_dir -= forward
if rl.IsKeyDown(.D) do move_dir += right
if rl.IsKeyDown(.A) do move_dir -= right
```

이동은 카메라의 yaw 각도를 기준으로 forward/right 벡터를 계산한다. Y 성분을 0으로 고정해서 "위를 쳐다보면서 전진해도 공중으로 날아가지 않는" 일반적인 FPS 이동을 구현했다.

### 스프린트, 앉기, 점프

```odin
Player_Config :: struct {
    walk_speed:      f32,   // 5.0
    sprint_speed:    f32,   // 9.0
    crouch_speed:    f32,   // 2.5
    jump_force:      f32,   // 8.0
    gravity:         f32,   // 20.0
    // ...
}
```

모든 이동 파라미터를 `Player_Config` 구조체에 분리했다. 하드코딩 대신 설정값을 모아두면 나중에 밸런스 조정이 편하다.

- **Shift**: 스프린트 (9.0 속도)
- **Ctrl**: 앉기 (2.5 속도, 카메라 높이 1.0으로 낮아짐)
- **Space**: 점프 (y 속도에 jump_force 적용, 착지 판정 후에만 가능)

### 헤드밥 (Head Bob)

걸을 때 카메라가 미세하게 상하로 흔들리는 효과다. `sin()` 함수로 주기적인 움직임을 만들고, 이동 속도에 비례해서 흔들림 빈도를 조절한다.

```odin
if is_moving && player.is_grounded {
    player.head_bob_timer += speed * dt * config.head_bob_speed
    player.head_bob_offset = math.sin(player.head_bob_timer) * config.head_bob_amount
} else {
    player.head_bob_offset = linalg.lerp(player.head_bob_offset, f32(0), 10 * dt)
}
```

이동을 멈추면 `lerp`로 부드럽게 원래 위치로 돌아온다. 작은 디테일이지만 FPS의 몰입감에 큰 영향을 준다.

## 월드 환경

`world.odin`에서 바닥, 벽, 장애물을 정의했다.

```odin
World :: struct {
    floor_size:  f32,
    floor_color: rl.Color,
    walls:       [dynamic]Wall,
    obstacles:   [dynamic]Obstacle,
}
```

이 시점에서는 아직 충돌 처리가 없다. 벽을 통과할 수 있고, 바닥 아래로 떨어지지 않는 건 단순한 y=0 체크뿐이다. 충돌은 다음 포스트에서 다룬다.

## 빌드 & 실행

```bash
odin build ./src -out:fps-game && ./fps-game
```

이 한 줄이면 빌드부터 실행까지 완료된다. 외부 빌드 시스템이 필요 없다는 것도 Odin의 장점이다.

## 마치며

이 글에서 구현한 것:

- Odin + Raylib 프로젝트 세팅
- 게임 루프 (입력 → 업데이트 → 렌더링)
- FPS 카메라 (마우스 룩, pitch 클램프)
- WASD 이동 (카메라 방향 기준)
- 스프린트 / 앉기 / 점프
- 헤드밥 효과
- 기본 월드 환경 (바닥, 벽, 장애물)

다음 글에서는 총기 시스템과 히트스캔 구현을 다룬다.

---

*이 시리즈의 전체 소스 코드는 [GitHub](https://github.com/novaeric0426/odin-fps)에서 확인할 수 있습니다.*
