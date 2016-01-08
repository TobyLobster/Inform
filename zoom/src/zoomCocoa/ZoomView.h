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
@interface ZoomView : NSView<NSTextViewDelegate, NSTextStorageDelegate, NSOpenSavePanelDelegate, ZDisplay, NSCoding>

// The delegate
@property (atomic, assign) id delegate;

- (void) killTask;

// debugTask forces a breakpoint at the next instruction. Note that the task must have
// debugging symbols loaded, or this will kill the task. Also note that the effect may
// be different than expected if the task is waiting for input.
- (void) debugTask;

- (void) setScaleFactor: (float) scaling;

// Specifying what to run
- (void) runNewServer: (NSString*) serverName;
@property (atomic, strong) NSObject<ZMachine> *zMachine;

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

@property (atomic, readonly, strong) ZoomTextView *textView;
- (void) writeAttributedString: (NSAttributedString*) string;
- (void) clearLowerWindowWithStyle: (ZStyle*) style;

// Setting the focused view
@property (atomic, strong) NSObject<ZWindow> *focusedView;

// Dealing with the history
@property (atomic, readonly, copy) NSString *lastHistoryItem;
@property (atomic, readonly, copy) NSString *nextHistoryItem;

// Fonts, colours, etc
- (NSFont*) fontWithStyle: (int) style;
- (NSColor*) foregroundColourForStyle: (ZStyle*) style;
- (NSColor*) backgroundColourForStyle: (ZStyle*) style;

- (void) setFonts:   (NSArray*) fonts;
- (void) setColours: (NSArray*) colours;

// File saving
- (long) creatorCode;
- (void) setCreatorCode: (uint32_t) code;

// The upper window
@property (atomic, readonly) int upperWindowSize;
- (void) setUpperBuffer: (double) bufHeight;
@property (atomic, readonly) double upperBufferHeight;
- (void) rearrangeUpperWindows;
@property (atomic, readonly, copy) NSArray *upperWindows;
- (void) padToLowerWindow;

- (void) upperWindowNeedsRedrawing;

// Event handling
- (BOOL) handleKeyDown: (NSEvent*) theEvent;
- (void) clickAtPointInWindow: (NSPoint) windowPos
					withCount: (NSInteger) count;

// Setting/updating preferences
- (void) setPreferences: (ZoomPreferences*) prefs;
- (void) preferencesHaveChanged: (NSNotification*)not;

- (void) reformatWindow;

// Autosaving
- (BOOL) createAutosaveDataWithCoder: (NSCoder*) encoder;
- (void) restoreAutosaveFromCoder: (NSCoder*) decoder;

@property (atomic, getter=isRunning, readonly) BOOL running;

- (void) restoreSaveState: (NSData*) state;

// 'Manual' input
- (void) setInputLinePos: (NSPoint) pos;
@property (atomic, strong) ZoomInputLine *inputLine;

// Output receivers
- (void) addOutputReceiver: (id) receiver;
- (void) removeOutputReceiver: (id) receiver;

- (void) orInputCommand: (NSString*) command;
- (void) orInputCharacter: (NSString*) character;
- (void) orOutputText:   (NSString*) outputText;
- (void) orWaitingForInput;
- (void) orInterpreterRestart;

@property (atomic, readonly, strong) ZoomTextToSpeech *textToSpeech;

// Input sources (nil = default, window input source)
- (void) setInputSource: (id) source;
- (void) removeInputSource: (id) source;

// Resources
@property (atomic, strong) ZoomBlorbFile *resources;

// Terminating characters
-(NSSet *) terminatingCharacters;
-(oneway void) setTerminatingCharacters:(in bycopy NSSet*) terminatingChars;

@end

// ZoomView delegate methods
@interface NSObject(ZoomViewDelegate)

- (void) zMachineStarted: (id) sender;
- (void) zMachineFinished: (id) sender;

- (NSString*) defaultSaveDirectory;
@property (atomic, readonly) BOOL useSavePackage;
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
@property (atomic, readonly, copy) NSString *nextCommand;

// Return YES if you want to turn off more prompts
@property (atomic, readonly) BOOL disableMorePrompt;

@end
