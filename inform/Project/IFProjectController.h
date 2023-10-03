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
                                                    IFRuntimeErrorParserDelegate>

- (void) layoutPanes;

@property (atomic, readonly, strong) IFProjectPane *sourcePane;
@property (atomic, readonly, strong) IFProjectPane *runningGamePane;
@property (atomic, readonly, strong) IFProjectPane *auxPane;
@property (atomic, readonly, strong) IFProjectPane *indexPane;


- (IFProjectPane*) oppositePane: (IFProjectPane*) pane;

// Communication from the containing panes
- (BOOL) showTestCase: (NSString*) testCase skeinNode:(unsigned long) skeinNodeId;
- (BOOL) selectSourceFile: (NSString*) fileName;
- (void) moveToSourceFilePosition: (NSInteger) location;
- (void) moveToSourceFileLine: (NSInteger) line;
@property (atomic, readonly, copy) NSString *selectedSourceFile;

- (void) highlightSourceFileLine: (NSInteger) line
                          inFile: (NSString*) file;
- (void) highlightSourceFileLine: (NSInteger) line
                          inFile: (NSString*) file
                           style: (IFLineStyle) style;
- (NSArray*) highlightsForFile: (NSString*) file;

- (void) removeHighlightsInFile: (NSString*) file
                        ofStyle: (IFLineStyle) style;
- (void) removeHighlightsOfStyle: (IFLineStyle) style;
- (void) removeAllTemporaryHighlights;

-(BOOL) isCurrentlyTesting;
@property (readonly, atomic, getter=isCurrentlyTesting) BOOL currentlyTesting;

@property (atomic, readonly, strong) IFIntelFile *currentIntelligence;

@property (atomic, readonly) BOOL safeToSwitchTabs;
@property (atomic) NSOpenPanel* openExtensionPanel;
@property (atomic) NSOpenPanel* openLegacyExtensionPanel;

- (void) zoomViewIsWaitingForInput;

// Documentation
- (void) openDocUrl: (NSURL*) url;

// Displaying progress
- (void) addProgressIndicator:      (IFProgress*) indicator;
- (void) removeProgressIndicator:   (IFProgress*) indicator;

// Menu options
- (IBAction) shiftLeft:         (id) sender;
- (IBAction) shiftRight:        (id) sender;
- (IBAction) renumberSections:  (id) sender;

- (IBAction) openMaterials:     (id) sender;
- (IBAction) exportIFiction:    (id) sender;

// Tabbing around
- (IBAction) tabSource:         (id) sender;
- (IBAction) tabErrors:         (id) sender;
- (IBAction) tabIndex:          (id) sender;
- (IBAction) tabSkein:          (id) sender;
- (IBAction) tabGame:           (id) sender;
- (IBAction) tabDocumentation:  (id) sender;
- (IBAction) tabSettings:       (id) sender;

- (IBAction) gotoLeftPane:      (id) sender;
- (IBAction) gotoRightPane:     (id) sender;
- (IBAction) switchPanes:       (id) sender;

- (IBAction) docRecipes:          (id) sender;
- (IBAction) docExtensions:       (id) sender;
- (IBAction) showHeadings:        (id) sender;
- (IBAction) showPreviousSection: (id) sender;
- (IBAction) showNextSection:     (id) sender;
- (IBAction) commentOutSelection: (id) sender;
- (IBAction) uncommentSelection:  (id) sender;
- (IBAction) release:           (id) sender;
- (IBAction) releaseForTesting: (id) sender;
- (IBAction) compile:           (id) sender;
- (IBAction) compileAndRun:     (id) sender;
- (IBAction) compileAndDebug:   (id) sender;
- (IBAction) compileAndRefresh: (id) sender;
- (IBAction) replayUsingSkein:  (id) sender;
- (IBAction) stopProcess:       (id) sender;
- (IBAction) searchDocs:        (id) sender;
- (IBAction) searchProject:     (id) sender;
- (IBAction) testSelector:      (id) sender;
- (IBAction) installLegacyExtension:  (id) sender;
- (IBAction) exportExtension:   (id) sender;
- (IBAction) testMe:            (id) sender;

- (void) changeFirstResponder: (NSResponder*) first;
- (void) searchShowSelectedItemAtLocation: (NSInteger) location
                                   phrase: (NSString*) phrase
                                   inFile: (NSString*) filename
                                     type: (IFFindLocation) type
                                anchorTag: (NSString*) anchorTag;

// Spelling
- (void) setSourceSpellChecking: (BOOL) spellChecking;

// The GLK view
- (IBAction) glkTaskHasStarted: (id) sender;
@property (atomic, strong) id<ZoomViewInputSource> glkInputSource;

// Headers
@property (atomic, readonly, strong) IFHeaderController *headerController;

// Show documentation index page
- (void) docIndex: (id) sender;

- (void) extensionUpdated: (NSString*) javascriptId;

@property (atomic, getter=isRunningGame, readonly) BOOL runningGame;
@property (atomic, getter=isCompiling, readonly) BOOL compiling;

- (void) inputSourceHasFinished: (id) source;
- (void) showPublicLibrary;

- (IBAction) addExtensionFromFile: (id) sender;
- (IBAction) addExtensionFromLegacyInstalledFolder: (id) sender;

-(void) confirmInbuildAction;
-(void) installExtension: (NSString*) extension;
-(void) uninstallExtension: (NSString*) extension;
-(void) moderniseExtension: (NSString*) extension;
-(void) testExtension: (NSString*) extension
              command: (NSString*) command
             testcase: (NSString*) testcase;

@end
