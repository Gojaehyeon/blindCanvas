//
//  PromptBuilder.swift
//  pidgin
//
//  Created by go on 11/1/25.
//

import Foundation

enum PromptBuilder {
    /// 시적 해석 프롬프트 생성
    static func poeticPrompt(userInput: String? = nil) -> String {
        var prompt = """
        이 이미지를 시적으로 해석해주세요. 
        그림의 감정, 분위기, 색채, 그리고 시적인 언어로 표현되는 내면의 이야기를 풀어주세요.
        감정적이고 예술적인 관점에서 이미지를 바라봐주세요.
        """
        
        if let input = userInput, !input.isEmpty {
            prompt += "\n\n사용자 요청: \(input)"
        }
        
        return prompt
    }
    
    /// 구조적 해석 프롬프트 생성
    static func structuralPrompt(userInput: String? = nil) -> String {
        var prompt = """
        이 이미지를 구조적으로 분석해주세요.
        구성 요소, 레이아웃, 색상 배치, 형태와 선, 공간 관계 등을 객관적으로 설명해주세요.
        기술적이고 분석적인 관점에서 이미지를 바라봐주세요.
        """
        
        if let input = userInput, !input.isEmpty {
            prompt += "\n\n사용자 요청: \(input)"
        }
        
        return prompt
    }
    
    /// 전맹 시각장애인을 위한 그림 해설 프롬프트 생성
    static func blindUserPrompt(userText: String) -> String {
        let prompt = """
        당신은 전맹 시각장애인을 위한 그림 해설을 생성한다.
        
        이 그림은 '\(userText)'를 그리는 과정 중의 장면이다. 현재 보이는 내용만 해설한다.
        입력으로는 'image'와 'userText'가 주어진다.
        
        [규칙]
        - 평서형 문장으로 150토큰 이내로 생성.
        - 사진에 사람의 손이나 분홍색 실이 있다면, 손과 실은 해석에서 제외하고 해설에서도 언급하지 않는다.
        - 시적 표현 없이 생성한다.
        - 색상과 배경은 절대 언급하지 않는다.
        - 비유가 필요할 경우 '\(userText)'와 관련된 표현만 사용한다.
        - 모든 드로잉 요소(점, 선, 면)의 위치와 형태(모양, 방향, 두께, 밀도, 질감 등)를 시각장애인도 이해할 수 있도록 자세하게 설명한다.
        - 출력은 해설 문장만 포함하며, 다른 형식·표기·설명은 넣지 않는다.
        """
        return prompt
    }
    
    /// 분석 모드에 따라 적절한 프롬프트 반환
    static func prompt(for mode: AppState.AnalysisMode, userInput: String? = nil) -> String {
        switch mode {
        case .poetic:
            return poeticPrompt(userInput: userInput)
        case .structural:
            return structuralPrompt(userInput: userInput)
        }
    }
}

