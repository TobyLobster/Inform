//
//  IFSettingsControllerTests.swift
//  InformTests
//

import XCTest

/// A setting that records what it's asked to do, with a view of its own
private class RecordingSetting: IFSetting {
    private let name: String
    private let enabled: Bool
    private(set) var compilersAsked: [String] = []
    private(set) var sets = 0
    private(set) var updates = 0
    /// Called as the setting sets the compiler settings from its view
    var whileSetting: (() -> Void)?

    init(_ name: String, enabled: Bool = true) {
        self.name = name
        self.enabled = enabled
        super.init(nibName: nil)
        settingView = NSView(frame: NSRect(x: 0, y: 0, width: 200, height: 30))
    }

    override var title: String {
        return name
    }

    override func enable(forCompiler compiler: String) -> Bool {
        compilersAsked.append(compiler)
        return enabled
    }

    override func setSettings() {
        sets += 1
        whileSetting?()
    }

    override func updateFromCompilerSettings() {
        updates += 1
    }
}

/// A recording setting of another class, as each class of setting has its own part of the compiler settings
private final class OtherSetting: RecordingSetting {
}

@MainActor
final class IFSettingsControllerTests: XCTestCase {

    /// The standard settings, as the app adds them when it starts
    private let standardSettings = ["IFOutputSettings", "IFI7OutputSettings", "IFRandomSettings", "IFCompilerOptions",
                                    "IFMiscSettings", "IFCompilerVersionSettings", "IFBasicInformSettings",
                                    "IFAdvancedSettings"]

    private func name(_ setting: IFSetting) -> String {
        return String(describing: type(of: setting))
    }

    /// A settings view, as the Settings page's nib has
    private func settingsView() throws -> NSView {
        let viewClass = try XCTUnwrap(NSClassFromString("Inform.IFSettingsView") as? NSView.Type)
        return viewClass.init(frame: NSRect(x: 0, y: 0, width: 300, height: 100))
    }

    /// Gives a controller a settings view, as the Settings page's nib does
    private func give(_ view: NSView, to controller: IFSettingsController) {
        controller.setValue(view, forKey: "settingsView")
    }

    /// The number of times a notification is posted by an object during a block
    private func notifications(named name: NSNotification.Name, from object: AnyObject,
                               during block: () -> Void) -> Int {
        var count = 0
        let observer = NotificationCenter.default.addObserver(forName: name, object: object, queue: nil) { _ in
            count += 1
        }
        block()
        NotificationCenter.default.removeObserver(observer)
        return count
    }

    // MARK: - The standard settings

    func testTheStandardSettings() throws {
        let first = try XCTUnwrap(IFSettingsController.makeStandardSettings() as? [IFSetting])
        XCTAssertEqual(first.map { name($0) }, standardSettings)
        for setting in first {
            XCTAssertNil(setting.compilerSettings)
        }

        // Each call makes new ones
        let second = try XCTUnwrap(IFSettingsController.makeStandardSettings() as? [IFSetting])
        XCTAssertEqual(second.count, first.count)
        for (a, b) in zip(first, second) {
            XCTAssertFalse(a === b, name(a))
        }
    }

    /// A controller made with `init`, as the Settings page's nib makes it, has standard settings of its own, and
    /// shows those for Inform 7
    func testAControllerForTheStandardSettings() throws {
        let controller = IFSettingsController()
        let compilerSettings = IFCompilerSettings()
        let classes = try XCTUnwrap(IFSettingsController.makeStandardSettings() as? [IFSetting]).map { type(of: $0) }
        let theirOwn = classes.map { compilerSettings.setting(for: $0) }

        controller.compilerSettings = compilerSettings
        let view = try settingsView()
        give(view, to: controller)

        var shown: [NSView] = []
        for (settingClass, ownSetting) in zip(classes, theirOwn) {
            let setting = try XCTUnwrap(compilerSettings.setting(for: settingClass))
            XCTAssertFalse(setting === ownSetting, name(setting))
            XCTAssertIdentical(setting.compilerSettings, compilerSettings)
            if setting.enable(forCompiler: IFCompilerNaturalInform) {
                shown.append(try XCTUnwrap(setting.settingView))
            }
        }
        XCTAssertEqual(shown.count, 5)
        XCTAssertEqual(view.subviews, shown)
    }

    // MARK: - A controller

    func testANewController() {
        let controller = IFSettingsController(settings: [RecordingSetting("A")])
        XCTAssertNil(controller.compilerSettings)
        XCTAssertNil(controller.value(forKey: "settingsView"))
    }

    /// The compiler settings are given the controller's settings, which read what the compiler settings read from
    /// the project
    func testGivingItCompilerSettings() throws {
        let a = RecordingSetting("A")
        let b = OtherSetting("B")
        let controller = IFSettingsController(settings: [a, b])
        let compilerSettings = IFCompilerSettings()
        let plist: [String: Any] = [NSStringFromClass(RecordingSetting.self): ["Key": 1]]
        XCTAssertTrue(compilerSettings.restore(fromPlist: try PropertyListSerialization.data(fromPropertyList: plist,
                                                                                         format: .xml,
                                                                                         options: 0)))

        controller.compilerSettings = compilerSettings
        XCTAssertIdentical(controller.compilerSettings, compilerSettings)
        XCTAssertIdentical(a.compilerSettings, compilerSettings)
        XCTAssertIdentical(b.compilerSettings, compilerSettings)
        XCTAssertIdentical(compilerSettings.setting(for: RecordingSetting.self), a)
        XCTAssertIdentical(compilerSettings.setting(for: OtherSetting.self), b)
        XCTAssertEqual(compilerSettings.dictionary(for: RecordingSetting.self)["Key"] as? Int, 1)
        XCTAssertEqual(a.updates, 1)
        XCTAssertEqual(b.updates, 0)

        // The same compiler settings again change nothing
        controller.compilerSettings = compilerSettings
        XCTAssertEqual(a.updates, 1)

        // Others
        let others = IFCompilerSettings()
        controller.compilerSettings = others
        XCTAssertIdentical(a.compilerSettings, others)
        XCTAssertIdentical(others.setting(for: OtherSetting.self), b)
    }

    /// The view shows the settings for the compiler. The Settings page's nib gives the controller its view before
    /// the page gives it compiler settings, and until then the settings are asked about no compiler
    func testTheView() throws {
        let a = RecordingSetting("A")
        let b = OtherSetting("B", enabled: false)
        let controller = IFSettingsController(settings: [a, b])
        let view = try settingsView()

        give(view, to: controller)
        XCTAssertIdentical(controller.value(forKey: "settingsView") as AnyObject?, view)
        XCTAssertEqual(view.subviews, [a.settingView])
        XCTAssertEqual(a.compilersAsked, [""])
        XCTAssertEqual(b.compilersAsked, [""])

        controller.compilerSettings = IFCompilerSettings()
        XCTAssertEqual(view.subviews, [a.settingView])
        XCTAssertEqual(a.compilersAsked, ["", IFCompilerNaturalInform])
        XCTAssertEqual(b.compilersAsked, ["", IFCompilerNaturalInform])
    }

    // MARK: - Changes

    /// A controller for three settings, the last not shown, with a view and then compiler settings, as the Settings
    /// page gives them
    private func controllerWithSettings() throws -> (IFSettingsController, IFCompilerSettings, RecordingSetting,
                                                     RecordingSetting, RecordingSetting) {
        let a = RecordingSetting("A")
        let b = OtherSetting("B")
        let hidden = RecordingSetting("Hidden", enabled: false)
        let controller = IFSettingsController(settings: [a, b, hidden])
        give(try settingsView(), to: controller)
        let compilerSettings = IFCompilerSettings()
        controller.compilerSettings = compilerSettings
        return (controller, compilerSettings, a, b, hidden)
    }

    /// A setting changed in its view sets the compiler settings, and then every setting shows them
    func testASettingThatChanges() throws {
        let (controller, compilerSettings, a, b, hidden) = try controllerWithSettings()
        let updates = [a.updates, b.updates, hidden.updates]

        let posted = notifications(named: .IFSetting, from: compilerSettings) {
            a.settingsHaveChanged(nil)
        }
        XCTAssertEqual(a.sets, 1)
        XCTAssertEqual(b.sets, 0)
        XCTAssertEqual(hidden.sets, 0)
        // Once when the setting has set them, and once for the change to them
        XCTAssertEqual([a.updates, b.updates, hidden.updates], updates.map { $0 + 2 })
        XCTAssertEqual(posted, 1)

        // A setting that isn't shown isn't heard
        hidden.settingsHaveChanged(nil)
        XCTAssertEqual(hidden.sets, 0)
        _ = controller
    }

    /// While a setting sets the compiler settings, their changes aren't shown, which would undo what it hasn't set yet
    func testSettingsArentShownWhileOneIsSet() throws {
        let (controller, compilerSettings, a, b, _) = try controllerWithSettings()
        var updatesWhileSetting: Int?
        a.whileSetting = { [unowned a, unowned b] in
            let before = a.updates + b.updates
            compilerSettings.settingsHaveChanged()
            updatesWhileSetting = a.updates + b.updates - before
        }

        a.settingsHaveChanged(nil)
        XCTAssertEqual(updatesWhileSetting, 0)
        _ = controller
    }

    /// No setting, or anything that isn't a setting, means all of them changed, shown or not
    func testAllTheSettingsChange() throws {
        let (controller, compilerSettings, a, b, hidden) = try controllerWithSettings()

        let posted = notifications(named: .IFSetting, from: compilerSettings) {
            controller.settingsHaveChanged(nil)
        }
        XCTAssertEqual([a.sets, b.sets, hidden.sets], [1, 1, 1])
        XCTAssertEqual(posted, 3)

        controller.settingsHaveChanged(self)
        XCTAssertEqual([a.sets, b.sets, hidden.sets], [2, 2, 2])
    }

    /// The settings show changes to the controller's compiler settings, once each, and no others
    func testTheCompilerSettingsChanging() throws {
        let (controller, compilerSettings, a, b, hidden) = try controllerWithSettings()
        var updates = [a.updates, b.updates, hidden.updates]

        compilerSettings.settingsHaveChanged()
        XCTAssertEqual([a.updates, b.updates, hidden.updates], updates.map { $0 + 1 })

        updates = [a.updates, b.updates, hidden.updates]
        IFCompilerSettings().settingsHaveChanged()
        XCTAssertEqual([a.updates, b.updates, hidden.updates], updates)

        // Other compiler settings
        let others = IFCompilerSettings()
        controller.compilerSettings = others
        updates = [a.updates, b.updates, hidden.updates]
        compilerSettings.settingsHaveChanged()
        XCTAssertEqual([a.updates, b.updates, hidden.updates], updates)
        others.settingsHaveChanged()
        XCTAssertEqual([a.updates, b.updates, hidden.updates], updates.map { $0 + 1 })
    }

    /// A standard setting changed in its view, as its user would, changes the compiler settings. The Settings page
    /// has every setting show the compiler settings when it gives them to the controller, as the controller only has
    /// those in the project's plist do that.
    func testChangingAStandardSetting() throws {
        let controller = IFSettingsController()
        let compilerSettings = IFCompilerSettings()
        give(try settingsView(), to: controller)
        controller.compilerSettings = compilerSettings
        controller.updateAllSettings()
        let basicClass: AnyClass = try XCTUnwrap(NSClassFromString("Inform.IFBasicInformSettings"))
        let basic = try XCTUnwrap(compilerSettings.setting(for: basicClass))
        let button = try XCTUnwrap(basic.value(forKey: "basicInform") as? NSButton)
        XCTAssertEqual(button.state, compilerSettings.basicInform ? .on : .off)

        let wanted = !compilerSettings.basicInform
        button.state = wanted ? .on : .off
        NSApp.sendAction(try XCTUnwrap(button.action), to: button.target, from: button)
        XCTAssertEqual(compilerSettings.basicInform, wanted)
        XCTAssertEqual(button.state, wanted ? .on : .off)
    }
}
