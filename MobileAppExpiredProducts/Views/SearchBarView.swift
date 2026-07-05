//
//  SearchBarView.swift
//  MobileAppExpiredProducts
//

import SwiftUI

/// Search bar from the design. It does not accept text input for now:
/// its only action is opening the camera scanner.
struct SearchBarView: View {
    let onCameraTap: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.primary)

            Text("Search or ask a question")
                .foregroundStyle(.secondary)

            Spacer()

            Image(systemName: "camera")
                .foregroundStyle(.primary)

            Image(systemName: "mic")
                .foregroundStyle(.primary)
        }
        .font(.system(size: 17))
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(.background, in: Capsule())
        .overlay(Capsule().strokeBorder(.quaternary))
        .contentShape(Capsule())
        .onTapGesture(perform: onCameraTap)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Scan a product with the camera")
        .accessibilityAddTraits(.isButton)
    }
}

/// Static filter chips shown under the search bar in the design.
struct FilterChipsView: View {
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                chip {
                    HStack(spacing: 4) {
                        Image(systemName: "mappin.and.ellipse")
                        Text("33463")
                        Image(systemName: "chevron.down")
                            .font(.caption2)
                    }
                }
                chip { Text("Video") }
                chip { Text("Deals") }
                chip { Text("Grocery") }
            }
        }
    }

    private func chip(@ViewBuilder content: () -> some View) -> some View {
        content()
            .font(.subheadline)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(.background, in: Capsule())
            .overlay(Capsule().strokeBorder(.quaternary))
    }
}

#Preview {
    VStack(spacing: 12) {
        SearchBarView(onCameraTap: {})
        FilterChipsView()
    }
    .padding()
    .background(Color(.systemGray6))
}
