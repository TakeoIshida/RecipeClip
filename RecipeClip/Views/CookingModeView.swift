import SwiftUI
import UIKit

struct CookingModeView: View {
    @Environment(\.dismiss) private var dismiss
    let recipe: Recipe
    @State private var currentStep = 0
    @State private var showsIngredients = false

    private var steps: [CookingStep] { recipe.sortedCookingSteps }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                ProgressView(value: Double(currentStep + 1), total: Double(max(steps.count, 1)))
                    .tint(.accentColor)
                    .padding(.horizontal)

                TabView(selection: $currentStep) {
                    ForEach(Array(steps.enumerated()), id: \.element.id) { index, step in
                        ScrollView {
                            VStack(alignment: .leading, spacing: 24) {
                                Text(String.localizedStringWithFormat(String(localized: "cooking.step_progress"), index + 1, steps.count))
                                    .font(.headline)
                                    .foregroundStyle(.secondary)

                                Text(step.text)
                                    .font(.system(.title, design: .rounded, weight: .semibold))
                                    .lineSpacing(8)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .accessibilityLabel("手順\(index + 1)、\(step.text)")
                            }
                            .padding(24)
                        }
                        .tag(index)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))

                HStack(spacing: 12) {
                    Button {
                        withAnimation { currentStep -= 1 }
                    } label: {
                        Label("前へ", systemImage: "chevron.left")
                            .frame(maxWidth: .infinity, minHeight: 48)
                    }
                    .buttonStyle(.bordered)
                    .disabled(currentStep == 0)

                    if currentStep == steps.count - 1 {
                        Button {
                            dismiss()
                        } label: {
                            Label("できあがり", systemImage: "checkmark.circle.fill")
                                .frame(maxWidth: .infinity, minHeight: 48)
                        }
                        .buttonStyle(.borderedProminent)
                    } else {
                        Button {
                            withAnimation { currentStep += 1 }
                        } label: {
                            Label("次へ", systemImage: "chevron.right")
                                .labelStyle(.titleAndIcon)
                                .frame(maxWidth: .infinity, minHeight: 48)
                        }
                        .buttonStyle(.borderedProminent)
                    }
                }
                .padding()
                .background(.bar)
            }
            .navigationTitle(recipe.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("閉じる") { dismiss() }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showsIngredients = true
                    } label: {
                        Label("材料を確認", systemImage: "basket")
                    }
                }
            }
            .sheet(isPresented: $showsIngredients) {
                NavigationStack {
                    List(recipe.sortedIngredients) { ingredient in
                        HStack(alignment: .firstTextBaseline) {
                            Text(ingredient.name)
                            Spacer()
                            Text(ingredient.amount)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .overlay {
                        if recipe.sortedIngredients.isEmpty {
                            ContentUnavailableView("材料は未登録だよ", systemImage: "basket")
                        }
                    }
                    .navigationTitle("材料")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .confirmationAction) {
                            Button("閉じる") { showsIngredients = false }
                        }
                    }
                }
                .presentationDetents([.medium, .large])
            }
        }
        .onAppear { UIApplication.shared.isIdleTimerDisabled = true }
        .onDisappear { UIApplication.shared.isIdleTimerDisabled = false }
        .interactiveDismissDisabled()
    }
}
