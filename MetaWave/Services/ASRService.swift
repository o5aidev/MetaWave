//
//  ASRService.swift
//  MetaWave
//
//  Miyabi仕様: 音声認識サービスプロトコル
//

import Foundation

/// 音声認識サービスプロトコル
protocol ASRService {
    /// 音声ファイルを文字起こし
    func transcribe(url: URL) async throws -> String
    
    /// 音声認識の可用性を確認
    func isAvailable() -> Bool
}

/// 音声認識エラー
enum ASRError: Error {
    case notAvailable
    case transcriptionFailed(String)
    case fileNotFound
    case permissionDenied
}
