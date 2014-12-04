//
//  IFProjectController.h
//  Inform
//
//  Created by Andrew Hunter on Wed Aug 27 2003.
//  Copyright (c) 2003 Andrew Hunter. All rights reserved.
//

#import <AppKit/AppKit.h>
#import <ZoomView/ZoomView.h>
#import <ZoomView/ZoomSkeinItem.h>
#import <GlkView/GlkAutomation.h>

#import "IFProjectPolicy.h"
#import "IFProgress.h"

#import "IFIntelFile.h"
#import "IFHeaderController.h"
#import "IFFindResult.h"
#import "IFSourceSharedActions.h"

@class IFToolbarManager;

enum lineStyle {
    IFLineStyleNeutral = 0,
    
	// Temporary highlights
	IFLineStyle_Temporary = 1, // Dummy style

    IFLineStyleWarning = 1,// Temp highlight
    IFLineStyleError,      // Temp highlight
    IFLineStyleFatalError, // Temp highlight
	IFLineStyleHighlight,
	
	IFLineStyle_LastTemporary,

	// 'Permanent highlights'
	IFLineStyle_Permanent = 0xfff, // Dummy style

	// Debugging
    IFLineStyleBreakpoint,
    IFLineStyleExecutionPoint
};

@class IFProjectPane;
@interface IFProjectController : NSWindowController<GlkAutomation, NSToolbarDelegate, NSOpenSavePanelDelegate, NSSplitViewDelegate> {
    IBOutlet NSView* panesView;
    
    // The toolbar manager
    IFToolbarManager* toolbarManager;

    // The collection of panes
    NSMutableArray* projectPanes;
    NSMutableArray* splitViews;
	
	// The current tab view (used for the various tab selection menu items)
	NSTabView* currentTabView;								// The active tab view [ NOT RETAINED ]
	IFProjectPane* currentPane;								// The active project pane [ NOT RETAINED ]
	
	// Highlighting (indexed by file)
	NSMutableDictionary* lineHighlighting;
	BOOL temporaryHighlights;

    // Action after a compile has finished
    SEL compileFinishedAction;
	
	// Compiling
	BOOL noChangesSinceLastCompile;							// Set to YES after a successful compile/run cycle
	BOOL noChangesSinceLastRefresh;
    
    BOOL isCompiling;
	
	// The last file selected
	NSString* lastFilename;
	
	// Debugging
	BOOL waitingAtBreakpoint;
	
	// The last 'active' skein item
	ZoomSkeinItem* lastActiveItem;							// NOT RETAINED
	
	// Policy delegates
	IFProjectPolicy* generalPolicy;
	IFProjectPolicy* docPolicy;                             // Index page can refer to documentation
	IFProjectPolicy* extensionsPolicy;                      // Extensions page can refer to extensions
	
	IFProgress* processingSyntax;
	
	// Glk automation
	id glkInputSource;
	
	// Running the entire skein
	NSMutableArray* skeinNodeStack;
	
	// The headings controller
	IFHeaderController* headerController;
    
    // Switching tabs
    BOOL betweenWindowLoadedAndBecomingMain;
    
    // Actions that can be shared between project and single controllers
    IFSourceSharedActions* sharedActions;
}

- (void) layoutPanes;

- (IFProjectPane*) sourcePane;
- (IFProjectPane*) gamePane;
- (IFProjectPane*) auxPane;
- (IFProjectPane*) skeinPane;
- (IFProjectPane*) transcriptPane: (BOOL) canBeSkein;
- (IFProjectPane*) indexPane;

- (IFProjectPane*) oppositePane: (IFProjectPane*) pane;

// Communication from the containing panes (maybe other uses, too - scripting?)
- (BOOL) selectSourceFile: (NSString*) fileName;
- (void) moveToSourceFilePosition: (int) location;
- (void) moveToSourceFileLine: (int) line;
- (NSString*) selectedSourceFile;

- (void) highlightSourceFileLine: (int) line
						  inFile: (NSString*) file;
- (void) highlightSourceFileLine: (int) line
						  inFile: (NSString*) file
                           style: (enum lineStyle) style;
- (NSArray*) highlightsForFile: (NSString*) file;

- (void) removeHighlightsInFile: (NSString*) file
						ofStyle: (enum lineStyle) style;
- (void) removeHighlightsOfStyle: (enum lineStyle) style;
- (void) removeAllTemporaryHighlights;

- (void) transcriptToPoint: (ZoomSkeinItem*) point
			   switchViews: (BOOL) switchViews;
- (void) transcriptToPoint: (ZoomSkeinItem*) point;

- (NSString*) pathToIndexFile;
- (IFIntelFile*) currentIntelligence;

- (IBAction) addNewFile: (id) sender;

- (BOOL) safeToSwitchTabs;

// Documentation
- (void) openDocUrl: (NSURL*) url;

// Debugging
- (void) updatedBreakpoints: (NSNotification*) not;
- (void) hitBreakpoint: (int) pc;

// Policy delegates
- (IFProjectPolicy*) generalPolicy;
- (IFProjectPolicy*) docPolicy;
- (IFProjectPolicy*) extensionsPolicy;

// Displaying progress
- (void) addProgressIndicator:      (IFProgress*) indicator;
- (void) removeProgressIndicator:   (IFProgress*) indicator;

// Menu options
- (IBAction) shiftLeft:         (id) sender;
- (IBAction) shiftRight:        (id) sender;
- (IBAction) renumberSections:  (id) sender;

- (IBAction) lastCommand:        (id) sender;
- (IBAction) lastCommandInSkein: (id) sender;
- (IBAction) lastChangedCommand: (id) sender;
- (IBAction) nextChangedCommand: (id) sender;
- (IBAction) lastDifference:     (id) sender;
- (IBAction) nextDifference:     (id) sender;
- (IBAction) nextDifferenceBySkein: (id) sender;

- (IBAction) openMaterials:     (id) sender;
- (IBAction) exportIFiction:    (id) sender;

// Tabbing around
- (IBAction) tabSource:         (id) sender;
- (IBAction) tabErrors:         (id) sender;
- (IBAction) tabIndex:          (id) sender;
- (IBAction) tabSkein:          (id) sender;
- (IBAction) tabTranscript:     (id) sender;
- (IBAction) tabGame:           (id) sender;
- (IBAction) tabDocumentation:  (id) sender;
- (IBAction) tabSettings:       (id) sender;

- (IBAction) gotoLeftPane:      (id) sender;
- (IBAction) gotoRightPane:     (id) sender;
- (IBAction) switchPanes:       (id) sender;

// Misc
- (IBAction) docRecipes:          (id) sender;
- (IBAction) docExtensions:       (id) sender;

- (IBAction) showHeadings:        (id) sender;
- (IBAction) showPreviousSection: (id) sender;
- (IBAction) showNextSection:     (id) sender;

- (IBAction) commentOutSelection: (id) sender;
- (IBAction) uncommentSelection:  (id) sender;

- (IBAction) pauseProcess:      (id) sender;
- (IBAction) continueProcess:   (id) sender;
- (IBAction) stepIntoProcess:   (id) sender;
- (IBAction) stepOutProcess:    (id) sender;
- (IBAction) stepOverProcess:   (id) sender;

// Misc delegate actions
- (IBAction) release:           (id) sender;
- (IBAction) releaseForTesting: (id) sender;
- (IBAction) compile:           (id) sender;
- (IBAction) compileAndRun:     (id) sender;
- (IBAction) compileAndDebug:   (id) sender;
- (IBAction) compileAndRefresh: (id) sender;
- (IBAction) replayUsingSkein:  (id) sender;
- (IBAction) stopProcess:       (id) sender;
- (IBAction) showWatchpoints:   (id) sender;
- (IBAction) showBreakpoints:   (id) sender;
- (IBAction) searchDocs:        (id) sender;
- (IBAction) searchProject:     (id) sender;

- (void) changeFirstResponder: (NSResponder*) first;
- (void) searchSelectedItemAtLocation: (int) location
							   phrase: (NSString*) phrase
							   inFile: (NSString*) filename
								 type: (IFFindLocation) type
                            anchorTag: (NSString*) anchorTag;

// Spelling
- (void) setSourceSpellChecking: (BOOL) spellChecking;

// The GLK view
- (IBAction) glkTaskHasStarted: (id) sender;
- (void) setGlkInputSource: (id) glkInputSource;

// Headers
- (IFHeaderController*) headerController;

// Show documentation index page
- (void) docIndex: (id) sender;

- (void) extensionUpdated: (NSString*) javascriptId;

// Can we debug this project?
- (BOOL) canDebug;
- (BOOL) isRunningGame;
- (BOOL) isCompiling;
- (BOOL) isWaitingAtBreakpoint;

@end
