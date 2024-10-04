import Combine
import Foundation
import SwiftUI

func ?? <T>(lhs: Binding<T?>, rhs: T) -> Binding<T> {
    Binding(
        get: { lhs.wrappedValue ?? rhs },
        set: { lhs.wrappedValue = $0 }
    )
}

extension View {
    func alert(error: Binding<Error?>) -> some View {
        alert(isPresented: Binding<Bool>(
            get: { error.wrappedValue != nil },
            set: { if !$0 { error.wrappedValue = nil } }
        )) {
            Alert(
                title: Text("Error"),
                message: Text(error.wrappedValue?.localizedDescription ?? "An unknown error occurred."),
                dismissButton: .default(Text("Dismiss"))
            )
        }
    }
}

struct LoadingOverlayModifier: ViewModifier {
    var isLoading: Bool

    func body(content: Content) -> some View {
        content
            .overlay {
                if isLoading {
                    ProgressView("Loading…")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .ignoresSafeArea()
                        .background(Material.regular.opacity(0.85))
                }
            }
    }
}

struct RoundedCorner: Shape {
    var radius: CGFloat = .infinity
    var corners: UIRectCorner = .allCorners
    
    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(roundedRect: rect, byRoundingCorners: corners, cornerRadii: CGSize(width: radius, height: radius))
        return Path(path.cgPath)
    }
}

extension View {
    func loadingOverlay(_ isLoading: Bool) -> some View {
        modifier(LoadingOverlayModifier(isLoading: isLoading))
    }
    
    func cornerRadius(_ radius: CGFloat, corners: UIRectCorner) -> some View {
        clipShape(RoundedCorner(radius: radius, corners: corners))
    }
}

extension Collection {
    var nonEmpty: Self? {
        return isEmpty ? nil : self
    }
}

extension LinearGradient {
    static let background = LinearGradient(
        gradient: Gradient(colors: [Color.blue.opacity(0.6), Color.green.opacity(0.4)]),
        startPoint: .top,
        endPoint: .bottom
    )
}

extension String {
    var isEmptyOrWhitespace: Bool {
        return self.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}
