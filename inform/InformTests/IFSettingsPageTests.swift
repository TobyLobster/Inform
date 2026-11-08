//
//  IFSettingsPageTests.swift
//  InformTests
//

import XCTest

/// Stands in for a project's controller, with a project of its own and no window
private final class ProjectControllerStandIn: IFProjectController {
    /// The project, which a window controller doesn't keep
    var project: IFProject?

    override var document: AnyObject? {
        get {
            return project
        }
        set {
        }
    }

    /// No window, so that a project's isn't loaded, as its toolbar manager asks for it whenever any window resizes
    override var window: NSWindow? {
        get {
            return nil
        }
        set {
        }
    }
}

/// A setting that counts the times it shows the compiler settings
private final class CountingSetting: IFSetting {
    private(set) var updates = 0

    override init() {
        super.init(nibName: nil)
        settingView = NSView(frame: NSRect(x: 0, y: 0, width: 200, height: 30))
    }

    override var title: String {
        return "Counting"
    }

    override func enable(forCompiler compiler: String) -> Bool {
        return true
    }

    override func updateFromCompilerSettings() {
        updates += 1
    }
}

final class IFSettingsPageTests: XCTestCase {

    /// A controller for a project. It isn't told of changes to any compiler settings, as it would make its window a
    /// toolbar for them, which saves its configuration in the user's preferences.
    private func projectController(for project: IFProject) -> ProjectControllerStandIn {
        let controller = ProjectControllerStandIn()
        NotificationCenter.default.removeObserver(controller)
        controller.project = project
        return controller
    }

    private func settingsController(of page: IFSettingsPage) throws -> IFSettingsController {
        return try XCTUnwrap(page.value(forKey: "settingsController") as? IFSettingsController)
    }

    /// The Basic Inform setting's checkbox, which is ticked in its nib, and isn't for a new project
    private func basicInformButton(of settings: IFCompilerSettings) throws -> NSButton {
        let basicClass: AnyClass = try XCTUnwrap(NSClassFromString("Inform.IFBasicInformSettings"))
        let basic = try XCTUnwrap(settings.setting(for: basicClass))
        return try XCTUnwrap(basic.value(forKey: "basicInform") as? NSButton)
    }

    // MARK: - The page

    func testTheTitle() {
        let controller = projectController(for: IFProject())
        XCTAssertEqual(IFSettingsPage(projectController: controller).title, "Settings")
    }

    /// The project's controller selects the Settings tab by the page's class name
    func testTheIdentifier() {
        let controller = projectController(for: IFProject())
        XCTAssertEqual(IFSettingsPage(projectController: controller).identifier, "IFSettingsPage")
    }

    /// A new page shows its project's settings in its view, each showing what the project has
    func testANewPage() throws {
        let project = IFProject()
        let controller = projectController(for: project)
        let page = IFSettingsPage(projectController: controller)
        XCTAssertIdentical(page.parent, controller)

        let settingsController = try settingsController(of: page)
        XCTAssertIdentical(settingsController.compilerSettings, project.settings)
        let settingsView = try XCTUnwrap(settingsController.value(forKey: "settingsView") as? NSView)
        XCTAssertTrue(settingsView.isDescendant(of: page.view))
        XCTAssertEqual(settingsView.subviews.count, 5)
        XCTAssertEqual(try basicInformButton(of: project.settings).state, .off)
        withExtendedLifetime(controller) {}
    }

    // MARK: - Settings

    /// Updating the settings shows the settings the project has now
    func testUpdatingTheSettings() throws {
        let controller = projectController(for: IFProject())
        let page = IFSettingsPage(projectController: controller)
        let other = IFProject()
        other.settings.basicInform = true

        controller.project = other
        page.updateSettings()
        XCTAssertIdentical(try settingsController(of: page).compilerSettings, other.settings)
        XCTAssertEqual(try basicInformButton(of: other.settings).state, .on)
        withExtendedLifetime(controller) {}
    }

    /// Changes to the project's settings are shown
    func testChangesToTheSettings() throws {
        let project = IFProject()
        let controller = projectController(for: project)
        let page = IFSettingsPage(projectController: controller)
        let button = try basicInformButton(of: project.settings)

        project.settings.basicInform = true
        XCTAssertEqual(button.state, .on)
        project.settings.basicInform = false
        XCTAssertEqual(button.state, .off)
        withExtendedLifetime((controller, page)) {}
    }

    /// Each change to the project's settings is shown once, and changes to others aren't shown: counted with a
    /// setting of a settings controller of our own
    func testTheChangesShown() throws {
        let project = IFProject()
        let controller = projectController(for: project)
        let page = IFSettingsPage(projectController: controller)
        let counting = CountingSetting()
        let settingsController = IFSettingsController(settings: [counting])
        page.setValue(settingsController, forKey: "settingsController")
        page.updateSettings()
        XCTAssertIdentical(settingsController.compilerSettings, project.settings)

        var updates = counting.updates
        project.settings.settingsHaveChanged()
        XCTAssertGreaterThanOrEqual(counting.updates, updates + 1)

        updates = counting.updates
        IFProject().settings.settingsHaveChanged()
        XCTAssertEqual(counting.updates, updates)
        withExtendedLifetime(controller) {}
    }

    /// Once its project's controller has finished with it, the page leaves its settings as they are
    func testAFinishedPage() throws {
        let project = IFProject()
        let controller = projectController(for: project)
        let page = IFSettingsPage(projectController: controller)

        page.finished()
        XCTAssertNil(page.parent)
        controller.project = IFProject()
        page.updateSettings()
        XCTAssertIdentical(try settingsController(of: page).compilerSettings, project.settings)
    }
}
