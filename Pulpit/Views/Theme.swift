import PulpitKit
import SwiftUI
import UIKit

// MARK: - Palette
//
// The palette is drawn from temple interiors: cream marble and ivory plaster for the ground,
// brass and gold leaf for the accent, celestial-window blue for the quiet secondary, and walnut
// for depth in the dark. Every colour is dynamic, so chapel mode and system dark mode read as
// the same rooms after sunset rather than a different building.

extension Color {
    /// Brass railing gold — the app's accent. Dark enough to read as text on cream in light
    /// mode; lifted toward gold leaf in the dark, where the deeper brass would go muddy.
    static let templeGold = Color(uiColor: UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 0.78, green: 0.65, blue: 0.42, alpha: 1.0)
            : UIColor(red: 0.52, green: 0.40, blue: 0.17, alpha: 1.0)
    })

    /// Stained-glass blue, for secondary emphasis where gold would shout.
    static let celestialBlue = Color(uiColor: UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 0.51, green: 0.66, blue: 0.84, alpha: 1.0)
            : UIColor(red: 0.20, green: 0.37, blue: 0.55, alpha: 1.0)
    })

    /// The screen's ground: warm ivory in the light, walnut-black in the dark. Sits *behind*
    /// lists and cards the way stone flooring sits behind furniture.
    static let templeCanvas = Color(uiColor: UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 0.09, green: 0.08, blue: 0.07, alpha: 1.0)
            : UIColor(red: 0.96, green: 0.94, blue: 0.89, alpha: 1.0)
    })

    /// Card and row fill: cream marble on the ivory ground, a step of warm walnut in the dark.
    static let templeCard = Color(uiColor: UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 0.15, green: 0.14, blue: 0.12, alpha: 1.0)
            : UIColor(red: 1.00, green: 0.99, blue: 0.965, alpha: 1.0)
    })

    /// A hairline for card edges — visible enough to draw the shape, quiet enough to not
    /// become a grid.
    static let templeHairline = Color(uiColor: UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 0.78, green: 0.65, blue: 0.42, alpha: 0.22)
            : UIColor(red: 0.52, green: 0.40, blue: 0.17, alpha: 0.18)
    })
}

// MARK: - Canvas

/// Puts a view's scrolling content on the warm canvas instead of the system grey.
///
/// One modifier rather than two lines at every call site, so the treatment can't drift apart
/// screen by screen.
private struct TempleCanvasModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .scrollContentBackground(.hidden)
            .background(Color.templeCanvas)
    }
}

extension View {
    func templeCanvas() -> some View {
        modifier(TempleCanvasModifier())
    }
}

// MARK: - Ornament

/// A thin gold rule with a diamond at its centre — the one piece of pure ornament in the app,
/// borrowed from the inlay lines in temple flooring. Used sparingly: it marks an ending, not
/// every join.
struct TempleDivider: View {
    var body: some View {
        HStack(spacing: 10) {
            line
            Image(systemName: "diamond.fill")
                .font(.system(size: 5))
            line
        }
        .foregroundStyle(Color.templeGold.opacity(0.55))
        .accessibilityHidden(true)
    }

    private var line: some View {
        Rectangle()
            .fill(Color.templeGold.opacity(0.35))
            .frame(height: 1)
    }
}

// MARK: - Program phases

/// Where an item sits in the arc of the meeting, for the small-caps headers between conducting
/// cards. Derived from the item's kind, so a reordered program regroups itself.
enum ProgramPhase: String {
    case opening = "Opening"
    case business = "Ward Business"
    case ordinances = "Ordinances"
    case sacrament = "The Sacrament"
    case program = "Program"
    case closing = "Closing"
}

extension ItemKind {
    var phase: ProgramPhase {
        switch self {
        case .welcome, .recognitions, .announcements, .openingHymn, .invocation:
            .opening
        case .wardBusiness, .release, .sustaining, .ordinationProposal, .newMemberWelcome,
             .movingInRecord, .stakeBusiness:
            .business
        case .babyBlessing, .confirmation:
            .ordinances
        case .sacramentHymn, .sacrament:
            .sacrament
        case .speaker, .intermediateHymn, .musicalNumber, .testimonyInvitation, .presentation,
             .custom:
            .program
        case .closingHymn, .benediction:
            .closing
        }
    }
}
