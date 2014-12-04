//
//  ZoomView.h
//  ZoomCocoa
//
//  Created by Andrew Hunter on Wed Sep 10 2003.
//  Copyright (c) 2003 Andrew Hunter. All rights reserved.
//

#import <AppKit/AppKit.h>
#import "ZoomProtocol.h"
#import "ZoomMoreView.h"
#import "ZoomTextView.h"
#import "ZoomScrollView.h"
#import "ZoomPreferences.h"
#import "ZoomCursor.h"
#import "ZoomInputLine.h"
#import "ZoomBlorbFile.h"
#import "ZoomTextToSpeech.h"

#define ZBoldStyle 1
#define ZUnderlineStyle 2
#define ZFixedStyle 4
#define ZSymbolicStyle 8

extern NSString* ZoomStyleAttributeName;

@class ZoomScrollView;
@class ZoomTextView;
@class ZoomPixmapWindow;
@interface ZoomView : NSView<NSTextViewDelegate, NSTextStorageDelegate, NSOpenSavePanelDelegate, ZDisplay, NSCoding> {
    NSObject<ZMachine>* zMachine;

    // Subviews
	BOOL editingTextView;
	BOOL willScrollToEnd;
	BOOL willDisplayMore;
    ZoomTextView* textView;
    NSTextContainer* upperWindowBuffer; // Things hidden under the upper window
    ZoomScrollView* textScroller;

    int inputPos;
    BOOL receiving;
    BOOL receivingCharacters;

    double morePoint;
    double moreReferencePoint;
    BOOL moreOn;

    ZoomMoreView* moreView;

    NSArray* fonts; // 16 entries
	NSArray* originalFonts;			// As for fonts, used to cache the 'original' font definitions when scaling is in effect
    NSArray* colours; // 11 entries

    NSMutableArray* upperWindows;
    NSMutableArray* lowerWindows; // Not that more than one makes any sort of sense
    int lastUpperWindowSize;
    int lastTileSize;
    BOOL upperWindowNeedsRedrawing;

    BOOL exclusiveMode;

    // The task, if we're running it
    NSTask* zoomTask;
    NSPipe* zoomTaskStdout;
    NSMutableString* zoomTaskData;

    // The delegate
    NSObject* delegate;
    
    // Details about the file we're currently saving
    long creatorCode; // 'YZZY' for Zoom
    long typeCode;
	
	// Preferences
	ZoomPreferences* viewPrefs;
	
	float scaleFactor;
	
	// Command history
	NSMutableArray* commandHistory;
	int				historyPos;
	
	// Terminating characters
	NSSet* terminatingChars;
	
	// View with input focus
	NSObject<ZWindow>* focusedView;
	
	// Pixmap view
	ZoomCursor*       pixmapCursor;
	ZoomPixmapWindow* pixmapWindow;
	
	// Manual input
	ZoomInputLine*    inputLine;
	NSPoint			  inputLinePos;
	
	// Autosave
	NSData* lastAutosave;
	int		upperWindowsToRestore;
	BOOL	restoring;
	
	// Output receivers
	NSMutableArray* outputReceivers;
	ZoomTextToSpeech* textToSpeechReceiver;
	
	// Input source
	NSObject* inputSource;
	
	// Resources
	ZoomBlorbFile* resources;
}

// The delegate
- (void) setDelegate: (id) delegate;
- (id)   delegate;

- (void) killTask;

// debugTask forces a breakpoint at the next instruction. Note that the task must have
// debugging symbols loaded, or this will kill the task. Also note that the effect may
// be different than expected if the task is waiting for input.
- (void) debugTask;

- (void) setScaleFactor: (float) scaling;

// Specifying what to run
- (void) runNewServer: (NSString*) serverName;
- (NSObject<ZMachine>*) zMachine;
- (void) setZMachine: (NSObject<ZMachine>*) machine;

// Scrolling, more prompt
- (void) scrollToEnd;
- (void) resetMorePrompt;
- (void) updateMorePrompt;

- (void) setShowsMorePrompt: (BOOL) shown;
- (void) displayMoreIfNecessary;
- (void) page;

- (void) retileUpperWindowIfRequired;

// Formatting a string
- (NSDictionary*) attributesForStyle: (ZStyle*) style;
- (NSAttributedString*) formatZString: (NSString*) zString
                            withStyle: (ZStyle*) style;

- (ZoomTextView*) textView;
- (void) writeAttributedString: (NSAttributedString*) string;
- (void) clearLowerWindowWithStyle: (ZStyle*) style;

// Setting the focused view
- (void) setFocusedView: (NSObject<ZWindow>*) view;
- (NSObject<ZWindow>*) focusedView;

// Dealing with the history
- (NSString*) lastHistoryItem;
- (NSString*) nextHistoryItem;

// Fonts, colours, etc
- (NSFont*) fontWithStyle: (int) style;
- (NSColor*) foregroundColourForStyle: (ZStyle*) style;
- (NSColor*) backgroundColourForStyle: (ZStyle*) style;

- (void) setFonts:   (NSArray*) fonts;
- (void) setColours: (NSArray*) colours;

// File saving
- (long) creatorCode;
- (void) setCreatorCode: (long) code;

// The upper window
- (int)  upperWindowSize;
- (void) setUpperBuffer: (double) bufHeight;
- (double) upperBufferHeight;
- (void) rearrangeUpperWindows;
- (NSArray*) upperWindows;
- (void) padToLowerWindow;

- (void) upperWindowNeedsRedrawing;

// Event handling
- (BOOL) handleKeyDown: (NSEvent*) theEvent;
- (void) clickAtPointInWindow: (NSPoint) windowPos
					withCount: (int) count;

// Setting/updating preferences
- (void) setPreferences: (ZoomPreferences*) prefs;
- (void) preferencesHaveChanged: (NSNotification*)not;

- (void) reformatWindow;

// Autosaving
- (BOOL) createAutosaveDataWithCoder: (NSCoder*) encoder;
- (void) restoreAutosaveFromCoder: (NSCoder*) decoder;

- (BOOL) isRunning;

- (void) restoreSaveState: (NSData*) state;

// 'Manual' input
- (void) setInputLinePos: (NSPoint) pos;
- (void) setInputLine: (ZoomInputLine*) input;
- (ZoomInputLine*) inputLine;

// Output receivers
- (void) addOutputReceiver: (id) receiver;
- (void) removeOutputReceiver: (id) receiver;

- (void) orInputCommand: (NSString*) command;
- (void) orInputCharacter: (NSString*) character;
- (void) orOutputText:   (NSString*) outputText;
- (void) orWaitingForInput;
- (void) orInterpreterRestart;

- (ZoomTextToSpeech*) textToSpeech;

// Input sources (nil = default, window input source)
- (void) setInputSource: (id) source;
- (void) removeInputSource: (id) source;

// Resources
- (void)		   setResources: (ZoomBlorbFile*) resources;
- (ZoomBlorbFile*) resources;

// Terminating characters
- (void) setTerminatingCharacters: (NSSet*) chars;
- (NSSet*) terminatingCharacters;

@end

// ZoomView delegate methods
@interface NSObject(ZoomViewDelegate)

- (void) zMachineStarted: (id) sender;
- (void) zMachineFinished: (id) sender;

- (NSString*) defaultSaveDirectory;
- (BOOL)      useSavePackage;
- (void)      prepareSavePackage: (ZPackageFile*) file;
- (void)	  loadedSkeinData: (NSData*) skeinData;

- (void) hitBreakpoint: (int) pc;

- (void) zoomViewIsNotResizable;

- (void) zoomWaitingForInput;

- (void) beep;

- (void) inputSourceHasFinished: (id) inputSource;

@end

// ZoomView input/output receivers
@interface NSObject(ZoomViewOutputReceiver)

// Direct output
- (void) inputCommand:   (NSString*) command;
- (void) inputCharacter: (NSString*) character;
- (void) outputText:     (NSString*) outputText;

// Status notifications
- (void) zoomWaitingForInput;
- (void) zoomInterpreterRestart;

@end

@interface NSObject(ZoomViewInputSource)

// Retrieve the next command
- (NSString*) nextCommand;

// Return YES if you want to turn off more prompts
- (BOOL) disableMorePrompt;

@end
