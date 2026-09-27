import Cocoa

class AnimationsSheet: SheetWindow {
    private static let title = NSLocalizedString("Animations", comment: "")
    private static let labelDelay = NSLocalizedString("Apparition delay of Switcher", comment: "")
    private static let labelFadeOut = NSLocalizedString("Fade out animation of Switcher", comment: "")
    private static let labelFadeIn = NSLocalizedString("Fade in animation of Preview", comment: "")
    private static let labelPieMenuAnimation = NSLocalizedString("Pie menu expansion animation", comment: "")
    private static let labelPieMenuSpeed = NSLocalizedString("Pie menu animation speed", comment: "")

    /// Pre-build search index for the open-button. See `SettingsSearchIndex.sheetSearchableStrings`.
    static let searchableStrings: [String] = [
        title, labelDelay, labelFadeOut, labelFadeIn,
        labelPieMenuAnimation, labelPieMenuSpeed
    ]

    override func makeContentView() -> NSView {
        let table = TableGroupView(title: Self.title, width: SheetWindow.width)
        let slider = LabelAndControl.makeLabelWithSlider("", "windowDisplayDelay", 0, 900, 19, true, "ms", width: 180)
        let rule = slider[1]
        let indicator = slider[2] as! NSTextField
        indicator.alignment = .right
        indicator.fit(56, indicator.fittingSize.height)
        table.addRow(leftText: Self.labelDelay, rightViews: [rule, indicator])
        table.addRow(leftText: Self.labelFadeOut, rightViews: LabelAndControl.makeSwitch("fadeOutAnimation"))
        table.addRow(leftText: Self.labelFadeIn, rightViews: LabelAndControl.makeSwitch("previewFadeInAnimation"))

        let pieSlider = LabelAndControl.makeLabelWithSlider("", "pieMenuAnimationSpeed", 0, 100, 11, false, "", width: 180)
        let pieRule = pieSlider[1]
        let pieIndicator = pieSlider[2] as! NSTextField
        pieIndicator.alignment = .right
        pieIndicator.fit(56, pieIndicator.fittingSize.height)

        (pieRule as? NSControl)?.isEnabled = Preferences.pieMenuAnimationEnabled

        let pieMenuSwitch = LabelAndControl.makeSwitch("pieMenuAnimationEnabled", extraAction: { sender in
            let isEnabled = (sender as? NSButton)?.state == .on
            (pieRule as? NSControl)?.isEnabled = isEnabled
        })

        table.addRow(leftText: Self.labelPieMenuAnimation, rightViews: [pieMenuSwitch])
        table.addRow(leftText: Self.labelPieMenuSpeed, rightViews: [pieRule, pieIndicator])

        return table
    }
}

