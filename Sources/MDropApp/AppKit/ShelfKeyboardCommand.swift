import AppKit
import Carbon

enum ShelfKeyboardCommand: Equatable {
    case commandBar
    case close
    case dismiss
    case actionMenu
    case toggleDetail
    case quickLook
    case delete
    case selectAll
    case copy
    case paste

    static func resolve(
        characters: String?,
        keyCode: UInt16? = nil,
        modifierFlags: NSEvent.ModifierFlags
    ) -> Self? {
        let relevantModifiers = modifierFlags.intersection([
            .command,
            .control,
            .option
        ])

        if let keyCode {
            switch keyCode {
            case UInt16(kVK_Escape):
                return .dismiss
            case UInt16(kVK_Tab):
                return .toggleDetail
            case UInt16(kVK_Space):
                return .quickLook
            case UInt16(kVK_Delete):
                return .delete
            case UInt16(kVK_Return), UInt16(kVK_ANSI_KeypadEnter):
                if relevantModifiers.isEmpty {
                    return .actionMenu
                }
            default:
                break
            }
        } else if let characters {
            switch characters {
            case "\u{1b}":
                return .dismiss
            case "\t":
                return .toggleDetail
            case " ":
                return .quickLook
            case "\u{7f}":
                return .delete
            case "\r", "\u{3}":
                if relevantModifiers.isEmpty {
                    return .actionMenu
                }
            default:
                break
            }
        }

        guard relevantModifiers == .command else { return nil }

        if let characters {
            switch characters.lowercased() {
            case "k":
                return .commandBar
            case "w":
                return .close
            case "a":
                return .selectAll
            case "c":
                return .copy
            case "v":
                return .paste
            default:
                if characters.unicodeScalars.allSatisfy(\.isASCII) {
                    return nil
                }
            }
        }

        switch keyCode {
        case UInt16(kVK_ANSI_K):
            return .commandBar
        case UInt16(kVK_ANSI_W):
            return .close
        case UInt16(kVK_ANSI_A):
            return .selectAll
        case UInt16(kVK_ANSI_C):
            return .copy
        case UInt16(kVK_ANSI_V):
            return .paste
        default:
            return nil
        }
    }

    var canHandleWhileEditingText: Bool {
        switch self {
        case .commandBar, .close, .dismiss:
            true
        case .actionMenu, .toggleDetail, .quickLook, .delete,
             .selectAll, .copy, .paste:
            false
        }
    }
}
