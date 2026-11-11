//
//  IFToolbarStatusView.swift
//  Inform
//
//  Created by Toby Nelson, 2014.
//

import AppKit

private let idealTopBorder: CGFloat                = 6.0
private let minTopBorder: CGFloat                  = 2.0
private let minBottomBorder: CGFloat               = 4.0
private let leftBorder: CGFloat                    = 20.0
private let rightCancelBorder: CGFloat             = 10.0
private let rightProgressBorder: CGFloat           = 20.0
private let cancelWidth: CGFloat                   = 16.0
private let idealGapBetweenTitleAndStory: CGFloat  = 5.0
private let cancelHeight: CGFloat                  = 16.0
private let gapWidthBetweenStoryAndCancel: CGFloat = 5.0
private let gapBetweenWelcomeImageAndText: CGFloat = 10.0

@objc @implementation extension IFToolbarStatusView {
    private final var progressIndicator: IFToolbarProgressIndicator!
    private final var isInProgress = false
    private final var isStoryActive = false
    private final var cancellable = false

    private final var titleText: NSTextField!
    private final var storyText: NSTextField!
    private final var cancelButton: NSButton!
    private final var informImage: NSImage?

    // 'Welcome' objects
    private final var welcomeTitle: NSTextField!
    private final var welcomeBuild: NSTextField!
    private final var welcomeImageView: NSImageView!

    weak var delegate: IFToolbarManager?

    // MARK: - Initialisation

    public override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)

        delegate = nil

        let buildString  = String(format: IFUtility.localizedString("Build %@"), IFUtility.coreBuildVersion ?? "(null)")
        let informString = IFUtility.localizedString("Inform")
        informImage = NSImage(named: "Blob-Logo")

        let dict: [NSAttributedString.Key: Any] = [.font: NSTextField().font!]
        let informSize = informString.size(withAttributes: dict)
        let informBuildSize = buildString.size(withAttributes: dict)

        // Create Welcome title text field
        welcomeTitle = NSTextField(frame: NSRect(x: 0.0, y: 0.0, width: informSize.width, height: informSize.height))
        welcomeTitle.stringValue = ""
        welcomeTitle.isBezeled = false
        welcomeTitle.drawsBackground = false
        welcomeTitle.isEditable = false
        welcomeTitle.isSelectable = false
        welcomeTitle.alignment = .right
        welcomeTitle.textColor = NSColor(named: "StatusWelcomeText")
        welcomeTitle.autoresizingMask = [.width, .minYMargin]
        welcomeTitle.stringValue = informString
        addSubview(welcomeTitle)

        // Create Welcome build text field
        welcomeBuild = NSTextField(frame: NSRect(x: 0.0, y: 0.0, width: informBuildSize.width, height: informBuildSize.height))
        welcomeBuild.stringValue = ""
        welcomeBuild.isBezeled = false
        welcomeBuild.drawsBackground = false
        welcomeBuild.isEditable = false
        welcomeBuild.isSelectable = false
        welcomeBuild.alignment = .left
        welcomeBuild.textColor = NSColor(named: "StatusWelcomeText")
        welcomeBuild.autoresizingMask = [.width, .minYMargin]
        welcomeBuild.stringValue = buildString
        addSubview(welcomeBuild)

        welcomeImageView = NSImageView()
        welcomeImageView.image = informImage
        welcomeImageView.imageAlignment = .alignCenter
        welcomeImageView.imageFrameStyle = .none
        welcomeImageView.imageScaling = .scaleNone
        addSubview(welcomeImageView)

        // Create text field
        titleText = NSTextField()
        titleText.stringValue = ""
        titleText.isBezeled = false
        titleText.drawsBackground = false
        titleText.isEditable = false
        titleText.isSelectable = false
        titleText.alignment = .center
        titleText.textColor = NSColor(named: "StatusWelcomeText")
        titleText.autoresizingMask = [.width, .minYMargin]
        addSubview(titleText)

        // Create story text field
        storyText = NSTextField()
        storyText.stringValue = ""
        storyText.isBezeled = false
        storyText.drawsBackground = false
        storyText.isEditable = false
        storyText.isSelectable = false
        storyText.alignment = .center
        storyText.textColor = NSColor(named: "StatusWelcomeText")
        storyText.autoresizingMask = [.width, .minYMargin]
        addSubview(storyText)

        // Create progress bar
        progressIndicator = IFToolbarProgressIndicator()
        progressIndicator.autoresizingMask = [.width, .maxYMargin]
        progressIndicator.isHidden = true
        addSubview(progressIndicator)

        // Create cancel button
        cancelButton = NSButton()
        cancelButton.setButtonType(.momentaryChange)
        cancelButton.image = NSImage(named: "App/Toolbar/cancelOut")
        cancelButton.alternateImage = NSImage(named: "App/Toolbar/cancelIn")
        cancelButton.isBordered = false
        cancelButton.action = #selector(cancelAction)
        cancelButton.target = self
        cancelButton.isHidden = true
        addSubview(cancelButton)

        wantsLayer = true
        adjustSubviews()

        isInProgress = false
        isStoryActive = false

        // NSViewFrameDidChangeNotification
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(adjustSubviews),
                                               name: NSView.frameDidChangeNotification,
                                               object: self)
    }

    /// Swift requires this, as `init(frame:)` is overridden. The Objective-C didn't override `initWithCoder:`, so
    /// this doesn't make the view's parts either: the status view is only made with `init(frame:)`.
    public required init?(coder: NSCoder) {
        super.init(coder: coder)
    }

    private final func updateStoryTextAndCancelBox() {
        let attrs: [NSAttributedString.Key: Any] = [.font: titleText.font!]

        // Cancel button rect
        var cancelRect = NSRect.zero

        cancelRect.size.width = cancelWidth
        cancelRect.size.height = cancelHeight

        var titleRect = titleText.frame
        var storyRect = storyText.frame
        var progressRect = progressIndicator.frame

        progressRect.size.width = frame.size.width - leftBorder - rightProgressBorder
        progressRect.size.height = 10.0

        if !isInProgress && isStoryActive && !storyText.stringValue.isEmpty {
            // Line up with story text
            storyRect.size.width = frame.size.width - (gapWidthBetweenStoryAndCancel + cancelWidth)

            let storySize = storyText.stringValue.size(withAttributes: attrs)

            cancelRect.origin.x = frame.size.width / 2 + (storySize.width / 2) - (gapWidthBetweenStoryAndCancel + cancelWidth) / 2 + gapWidthBetweenStoryAndCancel
            cancelRect.origin.y = storyRect.origin.y + storySize.height / 2 - (cancelHeight / 2)
        } else {
            // Line up with where progress bar is
            cancelRect.origin.x = frame.size.width - cancelRect.size.width - rightCancelBorder
            cancelRect.origin.y = progressRect.origin.y + progressRect.size.height / 2 - cancelHeight / 2

            if cancelButton.isHidden {
                progressRect.size.width = frame.size.width - leftBorder - rightProgressBorder
            } else {
                progressRect.size.width = frame.size.width - leftBorder - cancelRect.size.width - 2.0 * rightCancelBorder
            }

            storyRect.size.width = frame.size.width
        }

        // While the progress bar is shown, the story text is hidden, so a message goes above the bar, the two
        // together in the middle of the view, if they fit
        let progressAndTitleBottom = floor((frame.size.height - progressRect.size.height - titleRect.size.height) / 2)
        if isInProgress && !titleText.stringValue.isEmpty && progressAndTitleBottom >= minTopBorder {
            titleText.isHidden = false

            progressRect.origin.y = progressAndTitleBottom
            titleRect.origin.y    = progressAndTitleBottom + progressRect.size.height
            cancelRect.origin.y   = frame.size.height / 2 - cancelRect.size.height / 2
        } else {
            // Make sure title doesn't overlap story text
            if titleRect.origin.y < (storyRect.origin.y + storyRect.size.height) {
                titleRect.origin.y = storyRect.origin.y + storyRect.size.height
            }

            // Make sure title is within reasonable height bounds, otherwise hide it
            if (titleRect.origin.y + titleRect.size.height) > (frame.size.height - minTopBorder) {
                titleText.isHidden = true

                // Centre everything vertically if title doesn't fit
                progressRect.origin.y = frame.size.height / 2 - progressRect.size.height / 2
                storyRect.origin.y    = frame.size.height / 2 - storyRect.size.height / 2
                cancelRect.origin.y   = frame.size.height / 2 - cancelRect.size.height / 2
            } else {
                titleText.isHidden = false
            }
        }

        titleRect.origin.x = floor(titleRect.origin.x)
        titleRect.origin.y = floor(titleRect.origin.y)
        storyRect.origin.x = floor(storyRect.origin.x)
        storyRect.origin.y = floor(storyRect.origin.y)
        progressRect.origin.x = floor(progressRect.origin.x)
        progressRect.origin.y = floor(progressRect.origin.y)
        cancelRect.origin.x = floor(cancelRect.origin.x)
        cancelRect.origin.y = floor(cancelRect.origin.y)

        titleText.frame = titleRect
        cancelButton.frame = cancelRect
        storyText.frame = storyRect
        progressIndicator.frame = progressRect
    }

    @objc private final func adjustSubviews() {
        let attrs: [NSAttributedString.Key: Any] = [.font: NSTextField().font!]

        let titleHeight    = "Fg".size(withAttributes: attrs).height
        let progressWidth  = frame.size.width - leftBorder - rightProgressBorder
        let progressHeight: CGFloat = 8.0

        // Work out ideal titleText frame
        var titleRect = NSRect.zero
        titleRect.size.width  = frame.size.width
        titleRect.size.height = titleHeight
        titleRect.origin.x    = 0.0
        titleRect.origin.y    = frame.size.height - titleHeight - idealTopBorder

        // Work out ideal progress bar frame
        var progressRect = NSRect.zero
        progressRect.size.width  = progressWidth
        progressRect.size.height = progressHeight
        progressRect.origin.x    = leftBorder
        progressRect.origin.y    = (titleRect.origin.y / 2.0) - (progressRect.size.height / 2.0)

        // Make sure progress bar isn't pushed too low
        if progressRect.origin.y < minBottomBorder {
            progressRect.origin.y = minBottomBorder
            titleRect.origin.y    = frame.size.height - titleHeight - minTopBorder
        }

        // Make sure title doesn't overlap progress
        if titleRect.origin.y < (progressRect.origin.y + progressRect.size.height) {
            titleRect.origin.y = progressRect.origin.y + progressRect.size.height
        }

        // Story text rect
        var storyRect = NSRect.zero
        storyRect.size.width  = frame.size.width
        storyRect.size.height = titleHeight
        storyRect.origin.x    = 0.0
        storyRect.origin.y    = titleRect.origin.y - storyRect.size.height - idealGapBetweenTitleAndStory
        if storyRect.origin.y < minBottomBorder {
            storyRect.origin.y = minBottomBorder
        }

        // Make sure title doesn't overlap story text
        if titleRect.origin.y < (storyRect.origin.y + storyRect.size.height) {
            titleRect.origin.y = storyRect.origin.y + storyRect.size.height
        }

        titleText.frame = titleRect
        storyText.frame = storyRect
        progressIndicator.frame = progressRect

        // Update welcome items
        let imageSize = informImage?.size ?? .zero
        var frameLeft  = floor((frame.size.width / 2)  - (imageSize.width / 2))
        let frameTop   = floor((frame.size.height / 2) - (imageSize.height / 2))
        var frameRight = frameLeft + imageSize.width
        welcomeImageView.frame = NSRect(x: frameLeft, y: frameTop, width: imageSize.width, height: imageSize.height)
        frameLeft  -= gapBetweenWelcomeImageAndText
        frameRight += gapBetweenWelcomeImageAndText
        welcomeTitle.frame = NSRect(x: 0.0,
                                    y: floor((frame.size.height / 2) - (welcomeTitle.frame.size.height / 2)),
                                    width: frameLeft,
                                    height: welcomeTitle.frame.size.height)
        welcomeBuild.frame = NSRect(x: frameRight,
                                    y: floor((frame.size.height / 2) - (welcomeBuild.frame.size.height / 2)),
                                    width: frame.size.width - frameRight,
                                    height: welcomeBuild.frame.size.height)

        // Set story text and cancel button positions. Hide title if needed
        updateStoryTextAndCancelBox()
    }

    public override func draw(_ dirtyRect: NSRect) {
        let kDropShadow = NSShadow()
        kDropShadow.shadowColor = NSColor(named: "StatusShadow")
        kDropShadow.shadowOffset = NSSize(width: 0, height: -1.0)
        kDropShadow.shadowBlurRadius = 1.0

        let kBorderColor = NSColor(named: "StatusBorder")
        var kBackgroundGradient: NSGradient? = nil
        if let start = NSColor(named: "BackgroundGradientStart"), let end = NSColor(named: "BackgroundGradientEnd") {
            kBackgroundGradient = NSGradient(colorsAndLocations: (start, 0.0), (end, 1.0))
        }
        var bounds = self.bounds
        bounds.size.height -= 1.0
        bounds.origin.y += 1.0
        bounds.origin.x -= 0.5

        let path = NSBezierPath(roundedRect: bounds,
                                xRadius: 5.0,
                                yRadius: 5.0)
        // Draw drop shadow
        do {
            NSGraphicsContext.saveGraphicsState()
            kDropShadow.set()
            path.fill()
            NSGraphicsContext.restoreGraphicsState()
        }

        // Draw gradient
        do {
            kBackgroundGradient?.draw(in: path,
                                      angle: -90.0)
        }

        // Draw stroke
        do {
            kBorderColor?.setStroke()
            path.lineWidth = 2.0
            path.setClip()
            path.stroke()
        }
    }

    func showMessage(_ aTitle: String) {
        titleText.stringValue = aTitle
        updateVisibility()
    }

    private static func currentTime() -> String {
        let timeFormat = DateFormatter()
        timeFormat.dateFormat = "HH:mm"

        let now = Date()

        let theTime = timeFormat.string(from: now)
        return theTime
    }

    private final func updateVisibility() {
        if isInProgress {
            storyText.isHidden = true
            progressIndicator.isHidden = false
            cancelButton.isHidden = !cancellable
        } else if isStoryActive {
            storyText.isHidden = false
            progressIndicator.isHidden = true
            cancelButton.isHidden = !cancellable
        } else {
            storyText.isHidden = false
            progressIndicator.isHidden = true
            cancelButton.isHidden = true
        }
        updateStoryTextAndCancelBox()

        // Show welcome?
        var welcomeIsHidden = true
        if storyText.isHidden || storyText.stringValue.isEmpty {
            if titleText.isHidden || titleText.stringValue.isEmpty {
                if progressIndicator.isHidden {
                    welcomeIsHidden = false
                }
            }
        }

        welcomeTitle.isHidden = welcomeIsHidden
        welcomeBuild.isHidden = welcomeIsHidden
        welcomeImageView.isHidden = welcomeIsHidden
    }

    /// The version of the compiler the project uses (with no project, an empty string, as nil reached the version
    /// check, and an empty string is taken as the current version)
    private final func getCompilerVersion() -> String {
        let toolbar = delegate
        let projectController = toolbar?.projectController
        let project = projectController?.document as? IFProject
        return project?.compiler.settings?.compilerVersion ?? ""
    }

    func startStory() {
        isStoryActive = true
        cancellable = true

        let version = getCompilerVersion()

        if IFUtility.isLatestMajorMinorCompilerVersion(version) {
            storyText.stringValue = String(format: IFUtility.localizedString("Story started at %@."),
                                           IFToolbarStatusView.currentTime())
        } else {
            storyText.stringValue = String(format: IFUtility.localizedString("Using historic version %@. Started at %@."),
                                           version, IFToolbarStatusView.currentTime())
        }

        updateVisibility()
    }

    func stopStory() {
        isStoryActive = false

        let version = getCompilerVersion()

        if IFUtility.isLatestMajorMinorCompilerVersion(version) {
            storyText.stringValue = IFUtility.localizedString("Story stopped.")
        } else {
            storyText.stringValue = String(format: IFUtility.localizedString("Using historic version %@. Story stopped."),
                                           version)
        }

        updateVisibility()
    }

    func canCancel(_ aCanCancel: Bool) {
        cancellable = aCanCancel
    }

    func startProgress() {
        // A message from before the progress bar was shown isn't this progress's
        if !isInProgress {
            titleText.stringValue = ""
        }
        isInProgress = true

        progressIndicator.startAnimation(self)
        progressIndicator.usesThreadedAnimation = true
        updateVisibility()
    }

    func setProgressMaxValue(_ maxValue: CGFloat) {
        progressIndicator.maxValue = maxValue
    }

    func updateProgress(_ progressValue: CGFloat) {
        progressIndicator.doubleValue = progressValue
    }

    func setProgressIndeterminate(_ indeterminate: Bool) {
        progressIndicator.isIndeterminate = indeterminate
    }

    func stopProgress() {
        // Disable progress bars
        progressIndicator.doubleValue = 0.0
        progressIndicator.isIndeterminate = true
        progressIndicator.usesThreadedAnimation = false
        progressIndicator.stopAnimation(self)

        isInProgress = false
        updateVisibility()
    }

    @objc private final func cancelAction() {
        cancelButton.isHidden = true
        delegate?.cancelProgress()
    }

    func updateToolbar() {
        adjustSubviews()
    }
}
