//
//  OnboardingView.swift
//  MetaWave
//
//  v2.4: ユーザビリティ改善 - オンボーディング画面
//

import SwiftUI
import Combine

struct OnboardingView: View {
    @State private var currentPage = 0
    @State private var showingMainApp = false
    @Environment(\.dismiss) private var dismiss
    
    let pages = [
        OnboardingPage(
            title: "MetaWaveへようこそ",
            subtitle: "あなたの感情と思考を深く理解するアプリです",
            imageName: "brain.head.profile",
            color: .blue
        ),
        OnboardingPage(
            title: "感情を記録",
            subtitle: "テキストや音声で感情を記録し、パターンを発見しましょう",
            imageName: "heart.text.square",
            color: .red
        ),
        OnboardingPage(
            title: "分析と洞察",
            subtitle: "AIがあなたの感情パターンを分析し、貴重な洞察を提供します",
            imageName: "chart.bar.doc.horizontal",
            color: .green
        ),
        OnboardingPage(
            title: "予測と改善",
            subtitle: "将来の感情を予測し、より良い選択ができるようサポートします",
            imageName: "crystal.ball",
            color: .purple
        )
    ]
    
    var body: some View {
        ZStack {
            // 背景グラデーション
            LinearGradient(
                gradient: Gradient(colors: [Color.blue.opacity(0.1), Color.purple.opacity(0.1)]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // ページコンテンツ
                TabView(selection: $currentPage) {
                    ForEach(0..<pages.count, id: \.self) { index in
                        OnboardingPageView(page: pages[index])
                            .tag(index)
                    }
                }
                .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
                .animation(.easeInOut, value: currentPage)
                
                // ページインジケーター
                HStack(spacing: 8) {
                    ForEach(0..<pages.count, id: \.self) { index in
                        Circle()
                            .fill(index == currentPage ? Color.blue : Color.gray.opacity(0.3))
                            .frame(width: 8, height: 8)
                            .animation(.easeInOut, value: currentPage)
                    }
                }
                .padding(.top, 20)
                
                // ナビゲーションボタン
                HStack {
                    if currentPage > 0 {
                        Button("戻る") {
                            withAnimation {
                                currentPage -= 1
                            }
                        }
                        .buttonStyle(SecondaryButtonStyle())
                    }
                    
                    Spacer()
                    
                    Button(currentPage == pages.count - 1 ? "始める" : "次へ") {
                        if currentPage == pages.count - 1 {
                            completeOnboarding()
                        } else {
                            withAnimation {
                                currentPage += 1
                            }
                        }
                    }
                    .buttonStyle(PrimaryButtonStyle())
                }
                .padding(.horizontal, 30)
                .padding(.top, 30)
                .padding(.bottom, 50)
            }
        }
        .fullScreenCover(isPresented: $showingMainApp) {
            ContentView()
        }
    }
    
    private func completeOnboarding() {
        UserDefaults.standard.set(true, forKey: "hasCompletedOnboarding")
        showingMainApp = true
    }
}

struct OnboardingPage {
    let title: String
    let subtitle: String
    let imageName: String
    let color: Color
}

struct OnboardingPageView: View {
    let page: OnboardingPage
    
    var body: some View {
        VStack(spacing: 40) {
            Spacer()
            
            // アイコン
            Image(systemName: page.imageName)
                .font(.system(size: 120))
                .foregroundColor(page.color)
                .accessibilityHidden(true)
            
            // テキストコンテンツ
            VStack(spacing: 16) {
                Text(page.title)
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .multilineTextAlignment(.center)
                    .accessibilityAddTraits(.isHeader)
                
                Text(page.subtitle)
                    .font(.title3)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .lineLimit(nil)
            }
            .padding(.horizontal, 30)
            
            Spacer()
        }
    }
}

// MARK: - Button Styles

struct PrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(Color.blue)
            .cornerRadius(12)
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

struct SecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundColor(.blue)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(Color.blue.opacity(0.1))
            .cornerRadius(12)
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

// MARK: - Onboarding Manager

class OnboardingManager: ObservableObject {
    @Published var shouldShowOnboarding: Bool
    
    init() {
        shouldShowOnboarding = !UserDefaults.standard.bool(forKey: "hasCompletedOnboarding")
    }
    
    func completeOnboarding() {
        UserDefaults.standard.set(true, forKey: "hasCompletedOnboarding")
        shouldShowOnboarding = false
    }
    
    func resetOnboarding() {
        UserDefaults.standard.set(false, forKey: "hasCompletedOnboarding")
        shouldShowOnboarding = true
    }
}

// MARK: - Preview

struct OnboardingView_Previews: PreviewProvider {
    static var previews: some View {
        OnboardingView()
    }
}
