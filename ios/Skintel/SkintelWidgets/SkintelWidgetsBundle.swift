import SwiftUI
import WidgetKit

@main
struct SkintelWidgetsBundle: WidgetBundle {
    var body: some Widget {
        AskSkintelWidget()
        ShelfWidget()
    }
}

/// Brand palette for the widgets. Each colour is a set in this extension's asset catalog
/// with a light and a dark appearance (the app itself is light-only; the Home Screen is not).
enum WidgetColor {
    static let background = Color("WidgetBackground")
    static let card = Color("WidgetCard")
    static let primary = Color("WidgetPrimary")
    static let ink = Color("WidgetInk")
    static let muted = Color("WidgetMuted")
    static let line = Color("WidgetLine")
    static let bubble = Color("WidgetBubble")
}
