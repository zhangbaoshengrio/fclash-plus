//
//  TrayMenu.swift
//  tray_manager
//
//  Created by Lijy91 on 2022/5/8.
//

import AppKit

class ClickableMenuItemView: NSView {
    private var label: String
    private var onAction: () -> Void

    init(label: String, onAction: @escaping () -> Void) {
        self.label = label
        self.onAction = onAction
        super.init(frame: NSRect(x: 0, y: 0, width: 200, height: 22))
        autoresizingMask = [.width]
    }

    required init?(coder: NSCoder) { fatalError() }

    override var isFlipped: Bool { return true }

    func update(label: String, onAction: @escaping () -> Void) {
        self.label = label
        self.onAction = onAction
        needsDisplay = true
    }

    override func draw(_ dirtyRect: NSRect) {
        let highlighted = enclosingMenuItem?.isHighlighted ?? false
        let font = NSFont.menuFont(ofSize: 0)

        if highlighted {
            NSColor.selectedMenuItemColor.setFill()
            NSBezierPath(roundedRect: bounds.insetBy(dx: 4, dy: 1), xRadius: 4, yRadius: 4).fill()
        }

        let textColor = highlighted ? NSColor.selectedMenuItemTextColor : NSColor.labelColor
        let textHeight = font.ascender - font.descender
        let y = (bounds.height - textHeight) / 2

        NSAttributedString(string: label, attributes: [.font: font, .foregroundColor: textColor])
            .draw(at: NSPoint(x: 17, y: y))
    }

    override func mouseUp(with event: NSEvent) {
        onAction()
        needsDisplay = true
    }
}

class RightAlignedMenuItemView: NSView {
    private var leftText: String
    private var rightText: String
    private var isChecked: Bool
    private var onAction: (() -> Void)?

    init(
        leftText: String,
        rightText: String,
        isChecked: Bool = false,
        onAction: (() -> Void)? = nil
    ) {
        self.leftText = leftText
        self.rightText = rightText
        self.isChecked = isChecked
        self.onAction = onAction
        super.init(frame: NSRect(x: 0, y: 0, width: 200, height: 22))
        autoresizingMask = [.width]
    }

    required init?(coder: NSCoder) { fatalError() }

    override var isFlipped: Bool { return true }

    func update(
        leftText: String,
        rightText: String,
        isChecked: Bool,
        onAction: (() -> Void)?
    ) {
        self.leftText = leftText
        self.rightText = rightText
        self.isChecked = isChecked
        self.onAction = onAction
        needsDisplay = true
    }

    private static func delayBadgeColor(for rightText: String) -> NSColor? {
        if rightText == "fail" {
            return NSColor.systemRed
        }
        if rightText.hasSuffix("ms"),
           let value = Int(rightText.dropLast(2)),
           value > 0 {
            if value < 200 { return NSColor.systemGreen }
            if value < 500 { return NSColor.systemOrange }
            return NSColor.systemRed
        }
        return nil
    }

    override func draw(_ dirtyRect: NSRect) {
        let highlighted = enclosingMenuItem?.isHighlighted ?? false
        let font = NSFont.menuFont(ofSize: 0)

        if highlighted {
            NSColor.selectedMenuItemColor.setFill()
            NSBezierPath(roundedRect: bounds.insetBy(dx: 4, dy: 1), xRadius: 4, yRadius: 4).fill()
        }

        let textColor = highlighted ? NSColor.selectedMenuItemTextColor : NSColor.labelColor
        let defaultRightTextColor = highlighted ? NSColor.selectedMenuItemTextColor : NSColor.secondaryLabelColor
        let textHeight = font.ascender - font.descender
        let y = (bounds.height - textHeight) / 2

        if isChecked {
            NSAttributedString(
                string: "✓",
                attributes: [.font: font, .foregroundColor: textColor]
            ).draw(at: NSPoint(x: 6, y: y))
        }

        NSAttributedString(string: leftText, attributes: [.font: font, .foregroundColor: textColor])
            .draw(at: NSPoint(x: 17, y: y))

        let rightSize = NSAttributedString(string: rightText, attributes: [.font: font]).size()
        let rightX = bounds.width - rightSize.width - 20

        let badgeColor = Self.delayBadgeColor(for: rightText)
        let rightTextColor: NSColor
        if let color = badgeColor {
            let hPad: CGFloat = 6
            let vPad: CGFloat = 2
            let badgeRect = NSRect(
                x: rightX - hPad,
                y: y - vPad,
                width: rightSize.width + hPad * 2,
                height: textHeight + vPad * 2
            )
            color.setFill()
            NSBezierPath(roundedRect: badgeRect, xRadius: 4, yRadius: 4).fill()
            rightTextColor = NSColor.white
        } else {
            rightTextColor = defaultRightTextColor
        }

        NSAttributedString(
            string: rightText,
            attributes: [.font: font, .foregroundColor: rightTextColor]
        ).draw(at: NSPoint(x: rightX, y: y))
    }

    override func mouseUp(with event: NSEvent) {
        guard let action = onAction else {
            super.mouseUp(with: event)
            return
        }
        enclosingMenuItem?.menu?.cancelTracking()
        action()
        needsDisplay = true
    }
}

public class TrayMenu: NSMenu, NSMenuDelegate {
    public var onMenuItemClick:((NSMenuItem) -> Void)?

    public override init(title: String) {
        super.init(title: title)
    }

    required init(coder: NSCoder) {
        super.init(coder: coder)
    }

    public init(_ args: [String: Any]) {
        super.init(title: "")
        populate(items: args["items"] as! [NSDictionary])
        self.delegate = self
    }

    private func populate(items: [NSDictionary]) {
        for item in items {
            let menuItem = buildMenuItem(item as! [String: Any])
            self.addItem(menuItem)
        }
    }

    private func buildMenuItem(_ itemDict: [String: Any]) -> NSMenuItem {
        let menuItem: NSMenuItem
        let id: Int = itemDict["id"] as! Int
        let type: String = itemDict["type"] as! String
        let label: String = itemDict["label"] as? String ?? ""
        let toolTip: String = itemDict["toolTip"] as? String ?? ""
        let checked: Bool? = itemDict["checked"] as? Bool
        let disabled: Bool = itemDict["disabled"] as? Bool ?? true

        if (type == "separator") {
            menuItem = NSMenuItem.separator()
        } else {
            menuItem = NSMenuItem()
        }

        menuItem.tag = id
        menuItem.title = label
        if type == "keepOpen" && !disabled {
            menuItem.view = ClickableMenuItemView(label: label) { [weak self] in
                self?.statusItemMenuButtonClicked(menuItem)
            }
        } else if label.contains("\t") {
            let parts = label.components(separatedBy: "\t")
            let needsClick = !disabled && (type == "checkbox" || type == "normal")
            menuItem.view = RightAlignedMenuItemView(
                leftText: parts[0],
                rightText: parts.count > 1 ? parts[1] : "",
                isChecked: checked == true,
                onAction: needsClick ? { [weak self] in
                    self?.statusItemMenuButtonClicked(menuItem)
                } : nil
            )
        }
        menuItem.toolTip = toolTip
        menuItem.isEnabled = !disabled
        menuItem.action = !disabled ? #selector(statusItemMenuButtonClicked) : nil
        menuItem.target = self

        switch (type) {
        case "separator":
            break
        case "submenu":
            if let submenuDict = itemDict["submenu"] as? NSDictionary {
                let submenu = TrayMenu(submenuDict as! [String : Any])
                submenu.onMenuItemClick = { [weak self] (menuItem: NSMenuItem) in
                    guard let strongSelf = self else { return }
                    strongSelf.statusItemMenuButtonClicked(menuItem)
                }
                self.setSubmenu(submenu, for: menuItem)
            }
            break
        case "checkbox":
            if (checked == nil) {
                menuItem.state = .mixed
            } else {
                menuItem.state = checked! ? .on : .off
            }
            break
        default:
            break
        }
        return menuItem
    }

    /// Attempts to update existing NSMenuItems in place with new data.
    /// Returns true on success — the caller should NOT replace the menu.
    /// Returns false if the structure has changed and a full rebuild is needed.
    public func tryUpdate(_ args: [String: Any]) -> Bool {
        guard let newItems = args["items"] as? [NSDictionary] else { return false }
        let existingItems = self.items
        guard existingItems.count == newItems.count else { return false }

        for (index, newItemAny) in newItems.enumerated() {
            let menuItem = existingItems[index]
            let itemDict = newItemAny as! [String: Any]
            let type: String = itemDict["type"] as! String

            if type == "separator" {
                if !menuItem.isSeparatorItem { return false }
                continue
            }
            if menuItem.isSeparatorItem { return false }

            let id: Int = itemDict["id"] as! Int
            let label: String = itemDict["label"] as? String ?? ""
            let toolTip: String = itemDict["toolTip"] as? String ?? ""
            let checked: Bool? = itemDict["checked"] as? Bool
            let disabled: Bool = itemDict["disabled"] as? Bool ?? true

            // Verify view kind compatibility.
            let needsClickable = (type == "keepOpen" && !disabled)
            let needsRightAligned = !needsClickable && label.contains("\t")
            let needsNoView = !needsClickable && !needsRightAligned

            if needsClickable {
                if !(menuItem.view is ClickableMenuItemView) { return false }
            } else if needsRightAligned {
                if !(menuItem.view is RightAlignedMenuItemView) { return false }
            } else if needsNoView {
                if menuItem.view != nil { return false }
            }

            // Submenu structure must match before we commit any mutations.
            if type == "submenu" {
                guard let newSubmenuDict = itemDict["submenu"] as? NSDictionary,
                      let existingSubmenu = menuItem.submenu as? TrayMenu else {
                    return false
                }
                if !existingSubmenu.tryUpdate(newSubmenuDict as! [String: Any]) {
                    return false
                }
            } else if menuItem.submenu != nil {
                return false
            }

            menuItem.tag = id
            menuItem.title = label
            menuItem.toolTip = toolTip
            menuItem.isEnabled = !disabled
            menuItem.action = !disabled ? #selector(statusItemMenuButtonClicked) : nil
            menuItem.target = self

            if needsClickable, let view = menuItem.view as? ClickableMenuItemView {
                view.update(label: label) { [weak self] in
                    self?.statusItemMenuButtonClicked(menuItem)
                }
            } else if needsRightAligned, let view = menuItem.view as? RightAlignedMenuItemView {
                let parts = label.components(separatedBy: "\t")
                let needsClick = !disabled && (type == "checkbox" || type == "normal")
                view.update(
                    leftText: parts[0],
                    rightText: parts.count > 1 ? parts[1] : "",
                    isChecked: checked == true,
                    onAction: needsClick ? { [weak self] in
                        self?.statusItemMenuButtonClicked(menuItem)
                    } : nil
                )
            }

            if type == "checkbox" && menuItem.view == nil {
                if checked == nil {
                    menuItem.state = .mixed
                } else {
                    menuItem.state = checked! ? .on : .off
                }
            }
        }
        return true
    }

    @objc func statusItemMenuButtonClicked(_ sender: Any?) {
        if (sender is NSMenuItem && onMenuItemClick != nil) {
            let menuItem = sender as! NSMenuItem
            self.onMenuItemClick!(menuItem)
        }
    }

    // NSMenuDelegate

    public func menuDidClose(_ menu: NSMenu) {

    }
}
