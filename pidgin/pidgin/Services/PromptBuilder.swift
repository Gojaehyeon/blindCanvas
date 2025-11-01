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

