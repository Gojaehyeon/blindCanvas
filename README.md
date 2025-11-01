# 🕊️ Pidgin — 그림과 대화를 잇는 맥OS 전용 AI 도구

> **Pidgin**은 실시간으로 화면을 캡처해 GPT에게 그림을 보여주고,  
> AI가 그 그림을 구조적으로 혹은 시적으로 해석해주는 macOS 앱입니다.  
> 손으로 사고하고, 선으로 대화하는 창작자를 위한 도구입니다.

---

## ✨ 개요

Pidgin은 **지정한 화면 영역을 실시간으로 캡처**하고,  
**이미지 + 텍스트를 GPT-4o에 전송**해 **AI의 해석을 즉시 받아볼 수 있는** 창작 보조 도구입니다.

불필요한 인터페이스 없이, **키보드 중심의 빠르고 집중된 흐름**으로 설계되었습니다.

---

## 🎨 주요 기능

| 기능 | 설명 |
|------|------|
| 🖼️ **화면 영역 캡처** | OBS처럼 캡처 영역을 지정하고 고정하여 실시간으로 그림을 캡처 |
| ⌨️ **단축키 기반 작동** | `Enter`로 프레임 고정 또는 *구조 해석*, `Space`로 *시적 해석*, `ESC`로 프레임 재조정 |
| ✍️ **텍스트 입력 결합** | 사용자가 입력한 문장을 함께 전송하여 문맥 기반 해석 가능 |
| 🧠 **GPT-4o 멀티모달 분석** | 이미지와 텍스트를 함께 GPT에 전송해 구조적·시적 해석 결과 제공 |
| 🔊 **음성 출력 (TTS)** | GPT의 응답을 즉시 음성으로 재생 (`AVSpeechSynthesizer`) |
| 🪞 **미니멀 오버레이 UI** | 투명한 프레임 오버레이 + 하단 입력창, 전체화면 캡처 시 자동 숨김 |

---

## 🧩 시스템 구조

Pidgin
├─ App/
│ ├─ AppDelegate.swift # AppKit 수명주기 및 단축키 관리
│ ├─ PidginApp.swift # SwiftUI 진입점
│ └─ AppState.swift # 전역 상태 관리 (ObservableObject)
├─ Features/
│ ├─ Capture/ # 영역 지정 및 프레임 추출 기능
│ ├─ Analysis/ # GPT 응답 처리 및 표시
│ ├─ Prompt/ # 구조/시적 모드 프롬프트 빌더
│ └─ Settings/ # 환경 설정 (TTS, 캡처 품질 등)
├─ Services/
│ ├─ ScreenCaptureService.swift # ScreenCaptureKit 래퍼
│ ├─ GPTClient.swift # OpenAI API (이미지+텍스트)
│ ├─ TextToSpeech.swift # 음성 재생 기능
│ └─ HotkeyCenter.swift # 단축키 입력 처리
├─ UIComponents/ # 공통 UI 구성요소 (버튼, 오버레이 등)
├─ Config/
│ ├─ Secrets.swift # 내장 API 키
│ ├─ BuildConfig.xcconfig
│ └─ InfoPlist.strings
└─ Resources/
├─ Assets.xcassets
└─ Sounds/


---

## ⚙️ 기술 스택

| 영역 | 사용 기술 |
|------|------------|
| **UI** | SwiftUI + AppKit (하이브리드 구조) |
| **화면 캡처** | ScreenCaptureKit (`SCStream`) |
| **AI 분석** | OpenAI GPT-4o (멀티모달 입력 지원) |
| **음성 출력** | AVFoundation (`AVSpeechSynthesizer`) |
| **단축키 처리** | NSEvent / Carbon |
| **상태 관리** | ObservableObject (MVVM 구조) |
| **로그** | os.Logger 기반 단일 로깅 |

---

## 🧠 작동 흐름

Idle
└─(드래그)→ Selecting
Selecting
├─(Enter)→ Locked (프레임 고정 및 실시간 캡처 시작)
└─(ESC)→ Idle
Locked
├─(Space)→ Requesting (시적 해석)
├─(Enter)→ Requesting (구조 해석)
└─(ESC)→ Selecting
Requesting
├─(성공)→ 음성 재생 + 결과 표시
└─(실패)→ 오류 토스트 + Locked 상태 유지


---

## 🚀 시작하기

### 1. 요구사항
- macOS **13.0 (Ventura)** 이상  
- Xcode **15 이상**  
- 개발자 팀 서명 필요 (App Sandbox 활성화)  
- **화면 기록 권한** 필요  
  - 시스템 설정 → 개인정보 보호 및 보안 → 화면 기록 → *Pidgin* 허용

### 2. 빌드 단계

```bash
git clone https://github.com/yourname/pidgin.git
cd pidgin
open Pidgin.xcodeproj

Xcode에서 Signing Team 설정

Config/Secrets.swift 파일을 수정하여 API 키 입력:

enum Secrets {
    static let openAIKey = "sk-여기에_키_입력"
}

🧰 단축키
동작	키
프레임 고정 / 구조 해석 요청	Enter
시적 해석 요청	Space
프레임 재조정	ESC
텍스트 입력창 포커스	입력창 클릭
응답 다시 읽기	동일 단축키 재입력

🔊 음성 출력 (TTS)

Pidgin은 GPT의 응답을 자동으로 음성으로 읽어줍니다.
아래 항목을 설정에서 조정할 수 있습니다.

음성 종류 (.voice, .locale)

속도 (rate)

피치 (pitchMultiplier)

🔒 보안 및 개인정보

Pidgin은 사용자 데이터를 서버에 저장하지 않습니다.

각 요청은 한 장의 캡처 이미지만 전송합니다.

API 키는 개발 단계에서는 앱 내부에 고정됩니다.

⚠️ 실제 배포 시에는 서버 프록시나 키 관리 서버를 사용하는 것이 안전합니다.

📄 라이선스

MIT License © 2025 Jahyeon Ko
본 소프트웨어는 “있는 그대로(as is)” 제공되며,
명시적이거나 묵시적인 어떤 형태의 보증도 포함하지 않습니다.