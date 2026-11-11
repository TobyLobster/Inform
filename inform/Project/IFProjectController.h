//
//  IFProjectController.h
//  Inform
//
//  Created by Andrew Hunter on Wed Aug 27 2003.
//  Copyright (c) 2003 Andrew Hunter. All rights reserved.
//

#import <AppKit/AppKit.h>
#import <GlkView/GlkAutomation.h>
#import <WebKit/WebKit.h>
#import "IFSkeinView.h"
#import "IFProjectTypes.h"
#import "IFFindResult.h"
#import "IFSourceSharedActions.h"
#import "IFRuntimeErrorParser.h"
#import "IFProjectMenuValidation.h"

NS_ASSUME_NONNULL_BEGIN

@class ZoomView;
@class IFSkeinItem;
@class IFProgress;
@class IFIntelFile;
@class IFHeaderController;
@class IFProjectPane;

@interface IFProjectController : NSWindowController<GlkAutomation,
                                                    NSToolbarDelegate,
                                                    NSOpenSavePanelDelegate,
                                                    NSSplitViewDelegate,
                                                    IFSkeinViewDelegate,
                                                    IFRuntimeErrorParserDelegate,
                                                    NSMenuItemValidation,
                                                    NSToolbarItemValidation,
                                                    IFProjectMenuState>

- (void) layoutPanes;

/// The panes to show the source, the running game, documentation and the index in (all nil once the
/// window has closed, and the running game's also nil when no game is running)
@property (atomic, readonly, strong, nullable) IFProjectPane *sourcePane;
@property (atomic, readonly, strong, nullable) IFProjectPane *runningGamePane;
@property (atomic, readonly, strong, nullable) IFProjectPane *auxPane;
@property (atomic, readonly, strong, nullable) IFProjectPane *indexPane;


- (nullable IFProjectPane*) oppositePane: (IFProjectPane*) pane;

// Communication from the containing panes
- (BOOL) showTestCase: (NSString*) testCase skeinNode:(unsigned long) skeinNodeId;
- (BOOL) selectSourceFile: (NSString*) fileName;
- (void) moveToSourceFileLine: (NSInteger) line;

- (void) highlightSourceFileLine: (NSInteger) line
                          inFile: (NSString*) file
                           style: (IFLineStyle) style;
- (nullable NSArray<NSArray<NSNumber*>*>*) highlightsForFile: (nullable NSString*) file;

- (void) removeHighlightsInFile: (NSString*) file
                        ofStyle: (IFLineStyle) style;
- (void) removeHighlightsOfStyle: (IFLineStyle) style;
- (void) removeAllTemporaryHighlights;

@property (readonly, atomic, getter=isCurrentlyTesting) BOOL currentlyTesting;

@property (atomic, readonly, strong, nullable) IFIntelFile *currentIntelligence;

@property (atomic, readonly) BOOL safeToSwitchTabs;
@property (atomic, nullable) NSOpenPanel* openExtensionPanel;
@property (atomic, nullable) NSOpenPanel* openLegacyExtensionPanel;

- (void) zoomViewIsWaitingForInput;

// Displaying progress
- (void) addProgressIndicator:      (IFProgress*) indicator;
- (void) removeProgressIndicator:   (IFProgress*) indicator;

// Menu options
- (IBAction) shiftLeft:         (nullable id) sender;
- (IBAction) shiftRight:        (nullable id) sender;
- (IBAction) renumberSections:  (nullable id) sender;

- (IBAction) openMaterials:     (nullable id) sender;
- (IBAction) exportIFiction:    (nullable id) sender;

// Tabbing around
- (IBAction) tabSource:         (nullable id) sender;
- (IBAction) tabErrors:         (nullable id) sender;
- (IBAction) tabIndex:          (nullable id) sender;
- (IBAction) tabSkein:          (nullable id) sender;
- (IBAction) tabGame:           (nullable id) sender;
- (IBAction) tabDocumentation:  (nullable id) sender;
- (IBAction) tabSettings:       (nullable id) sender;
- (IBAction) tabExtensions:     (nullable id) sender;
- (IBAction) showIndexTab:      (nullable id) sender;

- (IBAction) gotoLeftPane:      (nullable id) sender;
- (IBAction) gotoRightPane:     (nullable id) sender;
- (IBAction) switchPanes:       (nullable id) sender;

- (IBAction) docRecipes:          (nullable id) sender;
- (IBAction) docExtensions:       (nullable id) sender;
- (IBAction) showHeadings:        (nullable id) sender;
- (IBAction) showPreviousSection: (nullable id) sender;
- (IBAction) showNextSection:     (nullable id) sender;
- (IBAction) showCurrentSectionOnly: (nullable id) sender;
- (IBAction) showEntireSource:    (nullable id) sender;
- (IBAction) showFewerHeadings:   (nullable id) sender;
- (IBAction) showMoreHeadings:    (nullable id) sender;
- (IBAction) commentOutSelection: (nullable id) sender;
- (IBAction) uncommentSelection:  (nullable id) sender;
- (IBAction) release:           (nullable id) sender;
- (IBAction) releaseForTesting: (nullable id) sender;
- (IBAction) compile:           (nullable id) sender;
- (IBAction) compileAndRun:     (nullable id) sender;
- (IBAction) compileAndDebug:   (nullable id) sender;
- (IBAction) compileAndRefresh: (nullable id) sender;
- (IBAction) replayUsingSkein:  (nullable id) sender;
- (IBAction) replayEntireSkein: (nullable id) sender;
- (IBAction) stopProcess:       (nullable id) sender;
- (IBAction) searchDocs:        (nullable id) sender;
- (IBAction) searchProject:     (nullable id) sender;
- (IBAction) testSelector:      (nullable id) sender;
- (IBAction) installLegacyExtension:  (nullable id) sender;
- (IBAction) exportExtension:   (nullable id) sender;
- (IBAction) testMe:            (nullable id) sender;

- (void) changeFirstResponder: (nullable NSResponder*) first;
- (void) searchShowSelectedItemAtLocation: (NSInteger) location
                                   phrase: (NSString*) phrase
                                   inFile: (NSString*) filename
                                     type: (IFFindLocation) type
                                anchorTag: (nullable NSString*) anchorTag;

// Spelling
- (void) setSourceSpellChecking: (BOOL) spellChecking;

// The GLK view
- (IBAction) glkTaskHasStarted: (nullable id) sender;
@property (atomic, strong, nullable) id<ZoomViewInputSource> glkInputSource;

// Headers
@property (atomic, readonly, strong) IFHeaderController *headerController;

// Show documentation index page
- (void) docIndex: (nullable id) sender;

- (void) extensionUpdated: (nullable NSString*) javascriptId;

@property (atomic, getter=isRunningGame, readonly) BOOL runningGame;
@property (atomic, getter=isCompiling, readonly) BOOL compiling;
/// Whether Play All has threads of the skein left to play
@property (atomic, getter=isPlayingAll, readonly) BOOL playingAll;

- (void) inputSourceHasFinished: (nullable id) source;
- (void) showPublicLibrary;

- (IBAction) addExtensionFromFile: (nullable id) sender;
- (IBAction) addExtensionFromLegacyInstalledFolder: (nullable id) sender;

-(void) confirmInbuildAction;
-(void) installExtension: (NSString*) extension;
-(void) uninstallExtension: (NSString*) extension;
-(void) moderniseExtension: (NSString*) extension;
-(void) testExtension: (NSString*) extension
              command: (NSString*) command
             testcase: (NSString*) testcase;
-(void) installExtensionURL: (NSURL*) extension;

@end

NS_ASSUME_NONNULL_END
