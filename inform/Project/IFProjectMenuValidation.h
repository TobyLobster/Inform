//
//  IFProjectMenuValidation.h
//  Inform
//
//  Moved out of IFProjectController in November 2026.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

///
/// What a project window's menu commands depend on, which the window's controller knows
///
@protocol IFProjectMenuState <NSObject>

/// Whether a story is running in the project's game page
@property (atomic, getter=isRunningGame, readonly) BOOL runningGame;
/// Whether the project is an extension project
@property (atomic, getter=isExtensionProject, readonly) BOOL extensionProject;
/// How many test cases the toolbar offers
@property (atomic, readonly) NSUInteger numberOfToolbarTestCases;
/// The test case chosen in the toolbar, nil when Test All is chosen
@property (atomic, readonly, copy, nullable) NSString *toolbarTestCase;
/// Whether Test All is chosen in an extension project's toolbar
@property (atomic, getter=isTestAllCasesSelected, readonly) BOOL testAllCasesSelected;
/// Whether an extension project's test cases are being run
@property (readonly, atomic, getter=isCurrentlyTesting) BOOL currentlyTesting;
/// Whether the project's compiler is running
@property (atomic, getter=isCompilerRunning, readonly) BOOL compilerRunning;
/// Whether the project is in Inform 7, rather than Inform 6
@property (atomic, getter=isUsingNaturalInform, readonly) BOOL usingNaturalInform;
/// Whether the window's first responder is a text view
@property (atomic, getter=isTextViewFirstResponder, readonly) BOOL textViewFirstResponder;
/// The length of the selection in the first responder, when it's a text view
@property (atomic, readonly) NSUInteger firstResponderSelectionLength;
/// Whether the first responder, when it's a text view, shows text with intelligence, such as a story's headings
@property (atomic, readonly) BOOL firstResponderHasIntelligence;
/// Whether there's a current tab view, a pane's, for the menu's commands that switch tabs
@property (atomic, readonly) BOOL hasCurrentTabView;
/// Whether the current pane shows the source page
@property (atomic, getter=isSourcePaneCurrent, readonly) BOOL sourcePaneCurrent;
/// Whether the index page can show the tab given, for the menu's commands that show the index's tabs
- (BOOL) canSelectIndexTab: (int) tab;

@end

///
/// Decides which of a project window's menu commands are enabled
///
@interface IFProjectMenuValidation : NSObject

- (instancetype) init NS_UNAVAILABLE;

/// Whether the menu item with the action and tag given is enabled, in the state given
+ (BOOL) isEnabledAction: (nullable SEL) action
                     tag: (NSInteger) tag
                 inState: (id<IFProjectMenuState>) state;

@end

NS_ASSUME_NONNULL_END
