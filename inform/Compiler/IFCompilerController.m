//
//  IFCompilerController.m
//  Inform
//
//  Created by Andrew Hunter on Mon Aug 18 2003.
//  Copyright (c) 2003 Andrew Hunter. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "IFCompilerController.h"

#import "IFCompiler.h"
#import "IFError.h"
#import "IFInTest.h"

#import "IFProject.h"
#import "IFJSProject.h"

#import "IFPreferences.h"
#import "IFUtility.h"
#import "NSBundle+IFBundleExtensions.h"
#import "IFProjectController.h"
#import "IFProgress.h"

// Possible styles (stored in the styles dictionary)
NSString* const IFStyleBase               = @"IFStyleBase";

// Basic compiler messages
NSString* const IFStyleCompilerVersion    = @"IFStyleCompilerVersion";
NSString* const IFStyleCompilerMessage    = @"IFStyleCompilerMessage";
NSString* const IFStyleCompilerWarning    = @"IFStyleCompilerWarning";
NSString* const IFStyleCompilerError      = @"IFStyleCompilerError";
NSString* const IFStyleCompilerFatalError = @"IFStyleCompilerFatalError";
NSString* const IFStyleProgress			= @"IFStyleProgress";

NSString* const IFStyleFilename           = @"IFStyleFilename";

// Compiler statistics/dumps/etc
NSString* const IFStyleAssembly           = @"IFStyleAssembly";
NSString* const IFStyleHexDump            = @"IFStyleHexDump";
NSString* const IFStyleStatistics         = @"IFStyleStatistics";

static IFCompilerController* activeController = nil;

@implementation IFCompilerTab

@end

@interface IFCompilerController ()
@property (atomic, readwrite, copy) NSString *blorbLocation;
@end

@implementation IFCompilerController {
    /// \c YES if we're all initialised (ie, loaded up from a nib)
    BOOL awake;

    /// Output from the compiler ends up here
    IBOutlet NSTextView* compilerResults;
    /// ...and is scrolled around by this thingmebob
    IBOutlet NSScrollView* resultScroller;

    /// Yin/yang?
    IBOutlet NSSplitView*   splitView;
    /// Superview of split view
    IBOutlet NSView*        superView;
    /// This scrolls around our parsed messages
    IBOutlet NSScrollView*  messageScroller;
    /// ...and this actually displays them
    IBOutlet NSOutlineView* compilerMessages;

    /// We're attached to this window
    IBOutlet NSWindow*      window;

    /// When we've got some messages to display, this is how high the pane will be
    CGFloat messagesSize;

    /// This object receives our delegate messages
    __weak id<IFCompilerControllerDelegate> delegate;

    /// Project controller
    IFProjectController*    projectController;

    /// Tabs - array of IFCompilerTab objects
    NSMutableArray*  tabs;
    /// Currently selected tab
    IFCompilerTabId  selectedTabId;
    /// Fixed dictionary of document names and their tabs
    NSDictionary*    tabDictionary;

    // The subtask
    /// This is the actual compiler
    IFCompiler* compiler;
    /// The last problem URL returned by the compiler
    NSURL* lastProblemURL;
    /// The overridden problems URL
    NSURL* overrideURL;

    // Styles
    /// The attributes used to render various strings recognised by the parser
    NSMutableDictionary<NSString*,NSDictionary<NSString*,id>*>* styles;
    /// The position the highlighter has reached (see IFError.[hl])
    NSInteger highlightPos;

    // Error messages
    /// A list of the files that the compiler has reported errors on (this is how we group errors together by file)
    NSMutableArray* errorFiles;
    /// A list of the error messages that the compiler has reported
    NSMutableArray* errorMessages;
    /// Where cblorb has requested that the blorb file be copied
    NSString* blorbLocation;
}

// == Styles ==
+ (NSDictionary*) defaultStyles {
    NSFont* smallFont;
    NSFont* baseFont;
    NSFont* bigFont;

	smallFont = baseFont = bigFont = [NSFont fontWithName: @"Monaco" size: 11.0];
    NSFont* boldFont = [[NSFontManager sharedFontManager] convertFont: bigFont
                                                          toHaveTrait: NSBoldFontMask];
    NSFont* italicFont = [[NSFontManager sharedFontManager] convertFont: boldFont
                                                            toHaveTrait: NSItalicFontMask];

    NSMutableParagraphStyle* centered = [[NSParagraphStyle defaultParagraphStyle] mutableCopy];
    [centered setAlignment: NSTextAlignmentCenter];
    
    NSDictionary* baseStyle = @{NSFontAttributeName: baseFont,
        NSForegroundColorAttributeName: [NSColor textColor]};

    NSDictionary* versionStyle = @{NSFontAttributeName: bigFont,
        NSForegroundColorAttributeName: [NSColor textColor],
        NSParagraphStyleAttributeName: centered};
    
    NSDictionary* filenameStyle = @{NSForegroundColorAttributeName: [NSColor textColor],
        NSFontAttributeName: boldFont};
    
    NSColor *indigoColor;
    if (@available(macOS 10.15, *)) {
        indigoColor = [NSColor systemIndigoColor];
    } else {
        indigoColor = [NSColor colorNamed: @"Compiler/Indigo"];
    }
    NSDictionary* messageStyle = @{NSForegroundColorAttributeName: [NSColor systemGreenColor]};
    NSDictionary* warningStyle = @{NSForegroundColorAttributeName: [NSColor systemBlueColor],
        NSFontAttributeName: boldFont};
    NSDictionary* errorStyle = @{NSForegroundColorAttributeName: [NSColor colorNamed: @"Compiler/DarkRed"],
        NSFontAttributeName: boldFont};
    NSDictionary* fatalErrorStyle = @{NSForegroundColorAttributeName: [NSColor systemRedColor],
        NSFontAttributeName: italicFont};
    NSDictionary* progressStyle = @{NSForegroundColorAttributeName: indigoColor,
        NSFontAttributeName: smallFont};
	
    return @{IFStyleBase: baseStyle,
        IFStyleCompilerVersion: versionStyle,
        IFStyleCompilerMessage: messageStyle, IFStyleCompilerWarning: warningStyle,
        IFStyleCompilerError: errorStyle, IFStyleCompilerFatalError: fatalErrorStyle,
        IFStyleFilename: filenameStyle,
		IFStyleProgress: progressStyle};
}

// == Initialisation ==
- (void) _registerHandlers {
    if (compiler != nil) {
		[[NSNotificationCenter defaultCenter] addObserver: self
												 selector: @selector(preferencesChanged:)
													 name: IFPreferencesAppFontSizeDidChangeNotification
												   object: [IFPreferences sharedPreferences]];

        [[NSNotificationCenter defaultCenter] addObserver: self
                                                 selector: @selector(clearConsole:)
                                                     name: IFCompilerClearConsoleNotification
                                                   object: compiler];
        [[NSNotificationCenter defaultCenter] addObserver: self
                                                 selector: @selector(started:)
                                                     name: IFCompilerStartingNotification
                                                   object: compiler];
        [[NSNotificationCenter defaultCenter] addObserver: self
                                                 selector: @selector(finished:)
                                                     name: IFCompilerFinishedNotification
                                                   object: compiler];
        [[NSNotificationCenter defaultCenter] addObserver: self
                                                 selector: @selector(gotStdout:)
                                                     name: IFCompilerStdoutNotification
                                                   object: compiler];
        [[NSNotificationCenter defaultCenter] addObserver: self
                                                 selector: @selector(gotStderr:)
                                                     name: IFCompilerStderrNotification
                                                   object: compiler];

        // Intest support
        [[NSNotificationCenter defaultCenter] addObserver: self
                                                 selector: @selector(intestStarting:)
                                                     name: IFInTestStartingNotification
                                                   object: nil];
        [[NSNotificationCenter defaultCenter] addObserver: self
                                                 selector: @selector(intestFinished:)
                                                     name: IFInTestFinishedNotification
                                                   object: nil];
        [[NSNotificationCenter defaultCenter] addObserver: self
                                                 selector: @selector(gotIntestStdout:)
                                                     name: IFInTestStdoutNotification
                                                   object: nil];
        [[NSNotificationCenter defaultCenter] addObserver: self
                                                 selector: @selector(gotIntestStderr:)
                                                     name: IFInTestStderrNotification
                                                   object: nil];
    }
}

- (void) _removeHandlers {
    if (compiler != nil) {
		[[NSNotificationCenter defaultCenter] removeObserver: self
													 name: IFPreferencesAppFontSizeDidChangeNotification
												   object: [IFPreferences sharedPreferences]];
        [[NSNotificationCenter defaultCenter] removeObserver: self
                                                        name: IFCompilerClearConsoleNotification
                                                      object: compiler];
        [[NSNotificationCenter defaultCenter] removeObserver: self
                                                        name: IFCompilerStartingNotification
                                                      object: compiler];
        [[NSNotificationCenter defaultCenter] removeObserver: self
                                                        name: IFCompilerFinishedNotification
                                                      object: compiler];
        [[NSNotificationCenter defaultCenter] removeObserver: self
                                                        name: IFCompilerStdoutNotification
                                                      object: compiler];
        [[NSNotificationCenter defaultCenter] removeObserver: self
                                                        name: IFCompilerStderrNotification
                                                      object: compiler];

        // Intest support
        [[NSNotificationCenter defaultCenter] removeObserver: self
                                                        name: IFInTestStartingNotification
                                                      object: nil];
        [[NSNotificationCenter defaultCenter] removeObserver: self
                                                        name: IFInTestFinishedNotification
                                                      object: nil];
        [[NSNotificationCenter defaultCenter] removeObserver: self
                                                        name: IFInTestStdoutNotification
                                                      object: nil];
        [[NSNotificationCenter defaultCenter] removeObserver: self
                                                        name: IFInTestStderrNotification
                                                      object: nil];
    }
}

- (instancetype) init {
    self = [super init];

    if (self) {
        awake = NO;
        compiler = [[IFCompiler alloc] init];
        styles = [[[self class] defaultStyles] mutableCopy];
        highlightPos = 0;

        errorFiles    = nil;
        errorMessages = nil;
        delegate      = nil;

        tabs          = [[NSMutableArray alloc] init];
        selectedTabId = IFTabInvalid;

        tabDictionary = @{@"debug log.txt":         @((int) IFTabDebugging),
                          @"auto.inf":              @((int) IFTabInform6),
                          @"problems.html":         @((int) IFTabReport),
                          @"log of problems.txt":   @((int) IFTabReport),
                          @"compiler":              @((int) IFTabConsole)};

        [self _registerHandlers];
    }

    return self;
}

- (void) dealloc {    
    [[NSNotificationCenter defaultCenter] removeObserver: self];
}

- (void) awakeFromNib {
    awake = YES;
    [[compilerResults textStorage] setDelegate: self];

    messagesSize = 0; // [messageScroller frame].size.height;

    [splitView setDelegate: self];
    [self adjustSplitView];

    [messageScroller setBorderType: NSNoBorder];

    [resultScroller setHasHorizontalScroller: YES];
    [compilerResults setMaxSize: NSMakeSize(1e8, 1e8)];
    [compilerResults setHorizontallyResizable: YES];
    [compilerResults setVerticallyResizable: YES];
    [[compilerResults textContainer] setWidthTracksTextView: NO];
    [[compilerResults textContainer] setContainerSize: NSMakeSize(1e8, 1e8)];
    [compilerResults setBackgroundColor: NSColor.textBackgroundColor];
}

- (void) showWindow: (id) sender {
    if (!awake) {
        [NSBundle oldLoadNibNamed: @"Compiling"
                            owner: self];
    }

    [window orderFront: sender];
}

// == Information ==
- (void) setProjectController: (IFProjectController*) pc {
    projectController = pc;
}

- (void) resetCompiler {
    [self _removeHandlers];

    compiler = [[IFCompiler alloc] init];
    [self _registerHandlers];

    [self adjustSplitView];
}

- (void) setCompiler: (IFCompiler*) comp {
    [self _removeHandlers];

    compiler = comp;
    [self _registerHandlers];

    [self adjustSplitView];
}

- (IFCompiler*) compiler {
    return compiler;
}

// == Starting/stopping the compiler ==
- (BOOL) startCompiling {
    if (window)
        [window setTitle: [NSString stringWithFormat: [IFUtility localizedString: @"Compiling - '%@'..."],
                                                      [[compiler inputFile] lastPathComponent]]];


    errorFiles    = [NSMutableArray array];
    errorMessages = [NSMutableArray array];
	
	overrideURL = nil;

    if (delegate &&
        [delegate respondsToSelector: @selector(errorMessagesCleared:)]) {
        [delegate errorMessagesCleared: self];
    }

    [[[compilerResults textStorage] mutableString] setString: @""];
    highlightPos = 0;

    if (![compiler prepareForLaunchWithBlorbStage: NO testCase: nil])
    {
        return NO;
    }
	[compiler launch];

    return YES;
}

- (BOOL) abortCompiling {
    if (window)
        [window setTitle: [NSString stringWithFormat: @"Aborted - '%@'",
            [[compiler inputFile] lastPathComponent]]];

    return YES;
}

// == Compiler messages ==
- (void) scrollToEnd {
	[compilerResults scrollRangeToVisible: NSMakeRange([[compilerResults textStorage] length], 0)];
}

- (void) clearConsole: (NSNotification*) not {
    if (errorFiles == nil) errorFiles = [[NSMutableArray alloc] init];
    if (errorMessages == nil) errorMessages = [[NSMutableArray alloc] init];

    [errorMessages removeAllObjects];
    [errorFiles removeAllObjects];
    [compilerMessages reloadData];

    [self clearTabViews];

    [[[compilerResults textStorage] mutableString] setString: @""];
    highlightPos = 0;
}

- (void) started: (NSNotification*) not {
	overrideURL = nil;
    blorbLocation = nil;
}

- (void) finished: (NSNotification*) not {
    int exitCode = [[not userInfo][@"exitCode"] intValue];
	
	if (overrideURL)
		lastProblemURL = overrideURL;
	else
		lastProblemURL = [compiler problemsURL];

    // Add to results
    [[[compilerResults textStorage] mutableString] appendString: @"\n"];
	[[[compilerResults textStorage] mutableString] appendString: 
		[NSString stringWithFormat: [IFUtility localizedString: @"Compiler finished with code %i"], exitCode]];
	[[[compilerResults textStorage] mutableString] appendString: @"\n"];
    [self adjustSplitView];

    // Log error
    if (exitCode != 0) {
		switch (exitCode) {
			case SIGILL:
			case SIGABRT:
			case SIGBUS:
			case SIGSEGV:
				NSLog(@"%@", [NSString stringWithFormat: [IFUtility localizedString: @"Compiler crashed with code %i"], exitCode]);
				break;
				
			default:
				NSLog(@"%@", [NSString stringWithFormat: [IFUtility localizedString: @"Compilation failed with code %i"], exitCode]);
				break;
		}

        if (delegate &&
            [delegate respondsToSelector: @selector(compileCompletedAndFailed:)]) {
            [delegate compileCompletedAndFailed: self];
        }
    }

    [self scrollToEnd];
}

- (void) gotStdout: (NSNotification*) not {
    NSString* data = [not userInfo][@"string"];
	NSAttributedString* newString = [[NSAttributedString alloc] initWithString: data
																	 attributes: styles[IFStyleBase]];
	
	[[compilerResults textStorage] appendAttributedString: newString];
}

- (void) gotStderr: (NSNotification*) not {
    NSString* data = [not userInfo][@"string"];
	NSAttributedString* newString = [[NSAttributedString alloc] initWithString: data
																	 attributes: styles[IFStyleBase]];
	
	[[compilerResults textStorage] appendAttributedString: newString];
}

#pragma mark - intest support

- (void) intestStarting: (NSNotification*) not {
    NSString* command = [not userInfo][@"command"];
    NSArray*  args    = [not userInfo][@"args"];

    NSMutableString* message = [[NSMutableString alloc] init];
    [message appendString: [IFUtility localizedString: @"Launching: "]];
    [message appendString: command];
    [message appendString: @" "];
    for (NSString* arg in args) {
        [message appendString: arg];
        [message appendString: @" "];
    }
    [message appendString: @"\n"];

    // Add to results
    NSAttributedString* newString = [[NSAttributedString alloc] initWithString: message
                                                                    attributes: styles[IFStyleBase]];
    [[compilerResults textStorage] appendAttributedString: newString];
}

- (void) intestFinished: (NSNotification*) not {
    int exitCode = [[not userInfo][@"exitCode"] intValue];

    // Add to results
    [[[compilerResults textStorage] mutableString] appendString:
     [NSString stringWithFormat: [IFUtility localizedString: @"Intest finished with code %i"], exitCode]];
    [[[compilerResults textStorage] mutableString] appendString: @"\n"];

    // Log error
    if (exitCode != 0) {
        switch (exitCode) {
            case SIGILL:
            case SIGABRT:
            case SIGBUS:
            case SIGSEGV:
                NSLog(@"%@", [NSString stringWithFormat: [IFUtility localizedString: @"Intest crashed with code %i"], exitCode]);
                break;

            default:
                NSLog(@"%@", [NSString stringWithFormat: [IFUtility localizedString: @"Intest failed with code %i"], exitCode]);
                break;
        }
    }

    [self scrollToEnd];
}

- (void) gotIntestStdout: (NSNotification*) not {
    NSString* data = [not userInfo][@"string"];
    NSAttributedString* newString = [[NSAttributedString alloc] initWithString: data
                                                                    attributes: styles[IFStyleBase]];

    [[compilerResults textStorage] appendAttributedString: newString];
}

- (void) gotIntestStderr: (NSNotification*) not {
    NSString* data = [not userInfo][@"string"];
    NSAttributedString* newString = [[NSAttributedString alloc] initWithString: data
                                                                    attributes: styles[IFStyleCompilerError]];
    
    [[compilerResults textStorage] appendAttributedString: newString];
}


#pragma mark - Preferences

- (void) preferencesChanged: (NSNotification*) not {
    // Report
    NSUInteger tabIndex = [self tabIndexWithTabId: IFTabReport];
    if( tabIndex != NSNotFound ) {
        IFCompilerTab* tab = tabs[tabIndex];
        if( [tab.view isKindOfClass:[WebView class]] ) {
            [((WebView*) tab.view) setTextSizeMultiplier: [[IFPreferences sharedPreferences] appFontSizeMultiplier]];
        }
    }

    // Runtime error
    tabIndex = [self tabIndexWithTabId: IFTabRuntime];
    if( tabIndex != NSNotFound ) {
        IFCompilerTab* tab = tabs[tabIndex];
        if( [tab.view isKindOfClass:[WebView class]] ) {
            [((WebView*) tab.view) setTextSizeMultiplier: [[IFPreferences sharedPreferences] appFontSizeMultiplier]];
        }
    }
}

// == Dealing with highlighting of the compiler output ==

- (NSString*) styleForLine: (NSString*) line {
    activeController = self;
    IFLex res = IFErrorScanString([line cStringUsingEncoding:NSUTF8StringEncoding]);
    
    switch (res) {
        case IFLexBase:
            return IFStyleBase;

        case IFLexCompilerVersion:
            return IFStyleCompilerVersion;
            
        case IFLexCompilerMessage:
            return IFStyleCompilerMessage;
            
        case IFLexCompilerWarning:
            return IFStyleCompilerWarning;
            
        case IFLexCompilerError:
            return IFStyleCompilerError;
            
        case IFLexCompilerFatalError:
            return IFStyleCompilerFatalError;

        case IFLexAssembly:
            return IFStyleAssembly;
            
        case IFLexHexDump:
            return IFStyleHexDump;
            
        case IFLexStatistics:
            return IFStyleStatistics;
			
		case IFLexProgress:
			[[compiler progress] setPercentage: IFLexLastProgress];
			
			if (IFLexLastProgressString) {
				NSString* msg;
				
				msg = [[NSString alloc] initWithBytes: IFLexLastProgressString
											   length: strlen(IFLexLastProgressString)-2
											 encoding: NSUTF8StringEncoding];
				
				// (Second attempt if UTF-8 makes no sense)
				if (msg == nil) msg = [[NSString alloc] initWithBytes: IFLexLastProgressString
															   length: strlen(IFLexLastProgressString)-2
															 encoding: NSISOLatin1StringEncoding];
				
				[[compiler progress] setMessage: msg];
			}

			return IFStyleProgress;
        case IFLexEndText:
            if( IFLexEndTextString ) {
				NSString* msg;
				
				msg = [[NSString alloc] initWithBytes: IFLexEndTextString
											   length: strlen(IFLexEndTextString)-1
											 encoding: NSUTF8StringEncoding];

				// (Second attempt if UTF-8 makes no sense)
				if (msg == nil)
                {
                    msg = [[NSString alloc] initWithBytes: IFLexEndTextString
												   length: strlen(IFLexEndTextString)-1
												 encoding: NSISOLatin1StringEncoding];
                }

                [compiler setEndTextString: msg];
            }
            return IFStyleCompilerMessage;
    }

    return nil;
    
    // Version strings have the form 'Foo Inform x.xx (Date)'
    
    
    // MPW style errors and warnings have the form:
    // File "file.h"; line 10	#
    //if ([[line substringWithRange: NSMakeRange(0, 4)] isEqualTo: @"File"]) {
        // May be an MPW string
    //    return nil;
    //}

    //return nil;
}

- (void)textStorage:(NSTextStorage *)storage didProcessEditing:(NSTextStorageEditActions)editedMask range:(NSRange)editedRange changeInLength:(NSInteger)delta {
    // Set the text to the base style
	[storage beginEditing];

    // For each line since highlightPos...
    NSString* str = [storage string];
    NSInteger len = [str length];

    NSInteger newlinePos;
    
    do {
        NSInteger x;
        
        newlinePos = -1;

        for (x=highlightPos; x<len; x++) {
            if ([str characterAtIndex: x] == '\n') {
                newlinePos = x;
                break;
            }
        }

        if (newlinePos == -1) {
            break;
        }

        // ... set the style appropriately
        NSRange lineRange = NSMakeRange(highlightPos, (newlinePos-highlightPos)+1);
        NSString* newStyle = [self styleForLine: [str substringWithRange: lineRange]];

        if (newStyle != nil) {
            [storage addAttributes: styles[newStyle]
                             range: lineRange];
        }

        highlightPos = newlinePos + 1;
    } while (newlinePos != -1);
    
    // Finish up
	[storage endEditing];
	
	[[NSRunLoop currentRunLoop] performSelector: @selector(scrollToEnd)
										 target: self
									   argument: nil
										  order: 128
										  modes: @[NSDefaultRunLoopMode]];
}

// == The error OutlineView ==

- (void) addErrorForFile: (NSString*) file
                  atLine: (int) line
                withType: (IFLex) type
                 message: (NSString*) message {
    // Find the entry for this error message, if it exists. If not,
    // add this as a new file...
    NSUInteger fileNum = [errorFiles indexOfObject: file];

    if (fileNum == NSNotFound) {
        fileNum = [errorFiles count];

        [errorFiles addObject: file];
        [errorMessages addObject: [NSMutableArray array]];

        [compilerMessages reloadData];
        [compilerMessages reloadItem: file
                      reloadChildren: YES];

        [compilerMessages expandItem: file];
    }

    // Add an entry for this error message
    NSMutableArray* fileMessages = errorMessages[fileNum];
    NSArray*        newMessage = @[message, @(line), @((int) type), @(fileNum)];
    [fileMessages addObject: newMessage];

    // Update the outline view
    [compilerMessages reloadData];

    [self adjustSplitView];

    // Notify the delegate
    if (delegate != nil &&
        [delegate respondsToSelector: @selector(compilerAddError:forFile:atLine:withType:message:)]) {
        [delegate compilerAddError: self
                           forFile: file
                            atLine: line
                          withType: type
                           message: message];
    }
}

- (NSInteger)   outlineView: (NSOutlineView *) outlineView
     numberOfChildrenOfItem: (id) item {
    if (item == nil) {
        return [errorFiles count];
    }
    
    NSUInteger fileNum = [errorFiles indexOfObjectIdenticalTo: item];

    if (fileNum == NSNotFound) {
        return 0;
    }

    return [errorMessages[fileNum] count];
}

- (BOOL)outlineView: (NSOutlineView *) outlineView
   isItemExpandable: (id) item {
    if (item == nil) return YES;
    return [errorFiles indexOfObjectIdenticalTo: item] != NSNotFound;
}

- (id)outlineView:(NSOutlineView *)outlineView
            child:(int)index
           ofItem:(id)item {
    if (item == nil) {
        return errorFiles[index];
    }

    NSUInteger fileNum = [errorFiles indexOfObjectIdenticalTo: item];

    if (fileNum == NSNotFound) {
        return nil;
    }

    return errorMessages[fileNum][index];
}

- (id)          outlineView: (NSOutlineView *) outlineView
  objectValueForTableColumn: (NSTableColumn *) tableColumn
                     byItem: (id) item {
    if ([item isKindOfClass: [NSString class]]) {
        // Must be a filename
        NSAttributedString* str = [[NSAttributedString alloc] initWithString: [item lastPathComponent]
                                                                  attributes: styles[IFStyleFilename]];

        return str;
    }

    // Is an array of the form message, line, type
    NSString* message = item[0];
    int line = [item[1] intValue];
    IFLex type = [item[2] intValue];

    NSDictionary* attr = styles[IFStyleCompilerMessage];

    switch (type) {
        case IFLexCompilerWarning:
            attr = styles[IFStyleCompilerWarning];
            break;
            
        case IFLexCompilerError:
            attr = styles[IFStyleCompilerError];
            break;
            
        case IFLexCompilerFatalError:
            attr = styles[IFStyleCompilerFatalError];
            break;

        default:
            break;
    }

    NSString* msg = [NSString stringWithFormat: @"L%i: %@", line, message];
    NSAttributedString* res = [[NSAttributedString alloc] initWithString: msg
                                                             attributes: attr];
    
    return res;
}

- (void) outlineViewSelectionDidChange: (NSNotification *)notification {
    NSObject* obj = [compilerMessages itemAtRow: [compilerMessages selectedRow]];

    if (obj == nil) {
        return; // Nothing selected
    }

    NSUInteger fileNum = [errorFiles indexOfObjectIdenticalTo: obj];

    if (fileNum != NSNotFound) {
        return; // File item selected
    }
	
    // obj is an array of the form [message, line, type]
    NSArray* msg = (NSArray*) obj;

    // NSString* message = [msg objectAtIndex: 0];
    int       line    = [msg[1] intValue];
    // IFLex type        = [[msg objectAtIndex: 2] intValue];
	fileNum = [msg[3] intValue];

    // Send to the delegate
    if (delegate &&
        [delegate respondsToSelector: @selector(errorMessageHighlighted:atLine:inFile:)]) {
        [delegate errorMessageHighlighted: self
                                   atLine: line
                                   inFile: errorFiles[fileNum]];
    }

    return;
}

- (void) windowWillClose: (NSNotification*) not {
    //[self autorelease];
}

// Other information

- (NSUInteger) tabIndexWithTabId: (IFCompilerTabId) tabId {
    for(int index = 0; index < [tabs count]; index++ ) {
        IFCompilerTab* tab = tabs[index];
        if( tab.tabId == tabId ) {
            return index;
        }
    }
    return NSNotFound;
}

- (int) tabIdWithTabIndex: (int) tabIndex {
    IFCompilerTab* tab = tabs[tabIndex];
    return tab.tabId;
}

-(IFCompilerTabId) tabIdOfItemWithFilename: (NSString *) theFile
{
    NSString* lowerFile = [theFile lowercaseString];
    
    NSNumber* integer = tabDictionary[lowerFile];
    if( integer == nil ) {
        return IFTabInvalid;
    }
    return (IFCompilerTabId)[integer intValue];
}

-(NSString *) filenameOfItemWithTabId: (IFCompilerTabId) tabId
{
    for( NSString* key in tabDictionary)
    {
        if( [tabDictionary[key] intValue] == tabId ) {
            return key;
        }
    }
    return nil;
}

-(bool) tabsContainsTabId: (IFCompilerTabId) tabId {
    return [self tabIndexWithTabId:tabId] != NSNotFound;
}

-(void) replaceViewWithTabId: (IFCompilerTabId) tabId withView: (NSView*) aView {
    NSUInteger tabIndex = [self tabIndexWithTabId:tabId];
    if( tabIndex != NSNotFound ) {
        IFCompilerTab* tab = tabs[tabIndex];
        if( tab ) {
            tab.view = aView;
        }
        IFCompilerTab* tab2 = tabs[tabIndex];

        NSAssert(tab2.view == aView, @"Replace didn't work...");
    }
}


- (IFCompilerTabId) makeTabViewItemNamed: (NSString*) tabName
                                withView: (NSView*) newView
                               withTabId: (IFCompilerTabId) tabId {
    IFCompilerTab* newTab = [[IFCompilerTab alloc] init];
    newTab.name = tabName;
    newTab.view = newView;
    newTab.tabId = tabId;

	[tabs addObject: newTab];
	
	if ([delegate respondsToSelector: @selector(viewSetHasUpdated:)]) {
		[delegate viewSetHasUpdated: self];
	}
	
	return newTab.tabId;
}

- (IFCompilerTabId) makeTabForURL: (NSURL*) url
                            named: (NSString*) tabName
                        withTabId: (IFCompilerTabId) tabId {
	// Create a new web view
	WebView* webView = [[WebView alloc] initWithFrame: [superView frame]];
	[webView setAutoresizingMask: (NSUInteger) (NSViewWidthSizable|NSViewHeightSizable)];
	
	[webView setHostWindow: [splitView window]];
	[webView setPolicyDelegate: self];
    [webView setTextSizeMultiplier: [[IFPreferences sharedPreferences] appFontSizeMultiplier]];
	[webView setFrameLoadDelegate: self];
    [[webView mainFrame] loadRequest: [[NSURLRequest alloc] initWithURL: url]];

	// Add it to the list of tabs
	return [self makeTabViewItemNamed: tabName
							 withView: webView
                            withTabId: tabId];
}

- (IFCompilerTabId) makeTabForFile: (NSString*) file {
	NSString* type = [[file pathExtension] lowercaseString];

	if ( [type isEqualTo: @"html"] ||
         [type isEqualTo: @"htm"] ) {
		// Treat as a webkit URL
		return [self makeTabForURL: [NSURL fileURLWithPath: file]
							 named: [IFUtility localizedString: [file lastPathComponent]
                                                       default: [[file lastPathComponent] stringByDeletingPathExtension]
                                                         table: @"CompilerOutput"]
                         withTabId: [self tabIdOfItemWithFilename:[file lastPathComponent]]];
	} else {
		// Create the new text view
		NSTextView* textView = [[NSTextView alloc] initWithFrame: [superView frame]];
        NSScrollView* scrollView = [[NSScrollView alloc] initWithFrame: [superView frame]];
		
        [[textView textContainer] setWidthTracksTextView: NO];
        [[textView textContainer] setContainerSize: NSMakeSize(1e8, 1e8)];
        [textView setMinSize:NSMakeSize(0.0, 0.0)];
        [textView setMaxSize:NSMakeSize(1e8, 1e8)];
        [textView setVerticallyResizable:YES];
        [textView setHorizontallyResizable:YES];
        [textView setAutoresizingMask: (NSUInteger) (NSViewWidthSizable|NSViewHeightSizable)];
        [textView setEditable: NO];
        [textView setUsesFindPanel: YES];

        NSMutableArray * tabStops = [[NSMutableArray alloc] init];
        for(int i = 0; i < 50; i++)
        {
            NSTextTab * tab = [[NSTextTab alloc] initWithType: NSLeftTabStopType location: (20 * i)];
            [tabStops addObject: tab];
        }
        NSMutableParagraphStyle * nameParagraphStyle = [[NSParagraphStyle defaultParagraphStyle] mutableCopy];

        [nameParagraphStyle setHeadIndent: 20.0];
        [nameParagraphStyle setTabStops: tabStops];

		// Load the data for the file
		NSString* textData = [[NSString alloc] initWithData: [NSData dataWithContentsOfFile: file]
												   encoding: NSUTF8StringEncoding];
        if( textData == nil ) {
            textData = [[NSString alloc] initWithData: [NSData dataWithContentsOfFile: file]
                                             encoding: NSISOLatin1StringEncoding];
        }

        NSMutableAttributedString * attrString = [[NSMutableAttributedString alloc] initWithString: textData
                                                                                        attributes: @{ NSParagraphStyleAttributeName : nameParagraphStyle }];
        [[textView textStorage] setFont:[NSFont fontWithName:@"Monaco" size:11]];
        [[textView textStorage] setAttributedString: attrString];

        // scrollView is the 'parent' of the textView
        [scrollView setDocumentView: textView];
        [scrollView setAutoresizingMask: (NSUInteger) (NSViewWidthSizable|NSViewHeightSizable)];
        [scrollView setHasHorizontalScroller: YES];
        [scrollView setHasVerticalScroller: YES];
		
		// Add the tab
		return [self makeTabViewItemNamed: [IFUtility localizedString: [file lastPathComponent]
                                                              default: [[file lastPathComponent] stringByDeletingPathExtension]
                                                                table: @"CompilerOutput"]
								 withView: scrollView
                                withTabId: [self tabIdOfItemWithFilename:[file lastPathComponent]]];
	}
}

- (void) showRuntimeError: (NSURL*) errorURL {
	// Create a web view
	WebView* webView = [[WebView alloc] initWithFrame: [superView frame]];
	
	[webView setAutoresizingMask: (NSUInteger) (NSViewWidthSizable|NSViewHeightSizable)];
	[webView setHostWindow: [splitView window]];
	[webView setPolicyDelegate: self];
    [webView setTextSizeMultiplier: [[IFPreferences sharedPreferences] appFontSizeMultiplier]];
	[webView setFrameLoadDelegate: self];
    [[webView mainFrame] loadRequest: [[NSURLRequest alloc] initWithURL: errorURL]];

	if ([self tabsContainsTabId:IFTabRuntime]) {
		// Replace the existing runtime error view
        [self replaceViewWithTabId: IFTabRuntime withView: webView];
	} else {
		// Add a new runtime error view
		[self makeTabViewItemNamed: [IFUtility localizedString: @"Runtime errors"]
                          withView: webView
                         withTabId: IFTabRuntime];
	}
	
	// Switch to the runtime view
	[self switchToViewWithTabId: IFTabRuntime];
}

- (void) showContentsOfFilesIn: (NSFileWrapper*) files
					  fromPath: (NSString*) path {
    if (![files isDirectory]) {
        return; // Nothing to do
    }
	
	// The set of files we should avoid showing
	NSMutableSet* excludedFiles = [NSMutableSet set];
	
	if (![[IFPreferences sharedPreferences] showDebuggingLogs]) {
		[excludedFiles addObject: @"debug log.txt"];
		[excludedFiles addObject: @"auto.inf"];
	}

	// If there is a compiler-supplied problems file, add this to the tab view
	if (lastProblemURL != nil) {
		[self makeTabForURL: lastProblemURL
                      named: [IFUtility localizedString: @"Problems.html"
                                                default: @"Problems"
                                                  table: @"CompilerOutput"]
                  withTabId: IFTabReport];
	}
	
	NSString* excludedFilename = nil;
	if (lastProblemURL) {
		excludedFilename = [[[[lastProblemURL path] lastPathComponent] stringByDeletingPathExtension] lowercaseString];
	}

	// Enumerate across the list of files in the filewrapper
    for( NSString* key in [files fileWrappers] ) {
        NSString* type = [[key pathExtension] lowercaseString];
		
		// Skip this file if it's in the excluded list
		if ([excludedFiles containsObject: [key lowercaseString]]) continue;

		// HTML, text and inf files go in a tab view showing various different status messages
		// With NI, the problems file is most important: we substitute this if the compiler wants
		NSString* filename = [[key stringByDeletingPathExtension] lowercaseString];

        bool tempFile = ([key length] >= 4) && ([[[key substringToIndex: 4] lowercaseString] isEqualToString: @"temp"]);
        bool goodFileType = [type isEqualTo: @"inf"] ||
                            [type isEqualTo: @"txt"] ||
                            [type isEqualTo: @"html"] ||
                            [type isEqualTo: @"htm"];
        bool excludedFile = (lastProblemURL != nil) && ([filename isEqualToString: @"problems"] || [filename isEqualToString: excludedFilename]);

        if (!tempFile && !excludedFile && goodFileType) {
			[self makeTabForFile: [path stringByAppendingPathComponent: key]];
        }
    }

	[self switchToViewWithTabId: IFTabReport];
}

- (void) clearTabViews {
    bool updated = false;

	// Clear all views except the console view
    for(int index = (int) [tabs count] - 1; index >= 0; index--) {
        IFCompilerTab*tab = tabs[index];
        if( tab.tabId != IFTabConsole ) {
            [tabs removeObjectAtIndex:index];
            updated = true;
        }
    }
	
	// Notify the delegate that the set of views has updated
    if( updated ) {
        if ([delegate respondsToSelector: @selector(viewSetHasUpdated:)]) {
            [delegate viewSetHasUpdated: self];
        }
    }

	// Switch to the console view
    if( selectedTabId != IFTabConsole ) {
        [self switchToViewWithTabId: IFTabConsole];
    }
}

// == Delegate ==

@synthesize delegate;

#pragma mark - Web policy delegate methods

- (void)        webView: (WebView *) sender
   didClearWindowObject: (WebScriptObject *) windowObject
               forFrame: (WebFrame *) frame {
	// Attach the JavaScript object to this webview
	IFJSProject* js = [[IFJSProject alloc] initWithPane: nil];
	
	// Attach it to the script object
	[[sender windowScriptObject] setValue: js
								   forKey: @"Project"];
}

- (void)					webView: (WebView *)sender
	decidePolicyForNavigationAction: (NSDictionary *)actionInformation 
							request: (NSURLRequest *)request 
							  frame: (WebFrame *)frame 
				   decisionListener: (id<WebPolicyDecisionListener>)listener {
	// Blah. Link failure if WebKit isn't available here. Constants aren't weak linked
	
	// Double blah. WebNavigationTypeLinkClicked == null, but the action value == 0. Bleh
	if ([actionInformation[WebActionNavigationTypeKey] intValue] == 0) {
		NSURL* url = [request URL];
		
		if ([[url scheme] isEqualTo: @"source"]) {
			// We deal with these ourselves
			[listener ignore];

			// Format is 'source file name#line number'
            NSArray* results = [IFUtility decodeSourceSchemeURL: [request URL]];
            results = [[projectController document] redirectLinksToExtensionSourceCode: results];
            if( results == nil ) {
                return;
            }
            NSString* sourceFile = results[0];
            int lineNumber = [results[1] intValue];

			if (delegate &&
				[delegate respondsToSelector: @selector(errorMessageHighlighted:atLine:inFile:)]) {
				[delegate errorMessageHighlighted: self
										   atLine: lineNumber
										   inFile: sourceFile];
			}
			
			// Finished
			return;
		}
        else if ([[url scheme] isEqualTo: @"skein"]) {
            // We deal with these ourselves
            [listener ignore];

            // e.g. 'skein:1003?case=B'
            NSArray* results = [IFUtility decodeSkeinSchemeURL: [request URL]];
            if( results == nil ) {
                return;
            }
            NSString* testCase = results[0];
            NSNumberFormatter* formatter = [[NSNumberFormatter alloc] init];
            unsigned long skeinNodeId = [[formatter numberFromString:results[1]] unsignedLongValue];

            // Move to the appropriate place in the file
            if (![projectController showTestCase: testCase skeinNode: skeinNodeId]) {
                NSLog(@"Can't select test case '%@'", testCase);
                return;
            }

            // Finished
            return;
        }


		// General URL policy
		WebDataSource* activeSource = [frame dataSource];
		
		if (activeSource == nil) {
			activeSource = [frame provisionalDataSource];
			if (activeSource != nil) {
				NSLog(@"Using the provisional data source - frame not finished loading?");
			}
		}
		
		if (activeSource == nil) {
			NSLog(@"Unable to establish a datasource for this frame: will probably redirect anyway");
		}
		
		NSURL* absolute1 = [[[request URL] absoluteURL] standardizedURL];
		NSURL* absolute2 = [[[[activeSource request] URL] absoluteURL] standardizedURL];
        
        bool samePage   = [IFUtility url:absolute1 equals:absolute2];

		// We only redirect if the page is different to the current one
		if (!samePage) {
			if ([delegate respondsToSelector: @selector(handleURLRequest:)]) {
				if ([delegate handleURLRequest: request]) {
					[listener ignore];
					return;
				}
			}
		}
	}
	
	// default action
	[listener use];
}

@synthesize blorbLocation;

- (void) overrideProblemsURL: (NSURL*) problemsURL {
	overrideURL = [problemsURL copy];
}

-(void) adjustSplitView {
    NSRect newFrame = [messageScroller frame];
    newFrame.size.height = 0;
    [messageScroller setFrame:newFrame];

    NSRect resultFrame = [resultScroller frame];

    resultFrame.size.height = splitView.frame.size.height - newFrame.size.height - [splitView dividerThickness];
    [resultScroller setFrame: resultFrame];

//    [splitView adjustSubviews];
}

@synthesize splitView;
- (void) setSplitView: (NSSplitView*) newSplitView {
	// Remember the new split view
	splitView = newSplitView;
    superView = [splitView superview];
    
    [splitView setAutoresizingMask: (NSUInteger) (NSViewWidthSizable|NSViewHeightSizable)];

    if( ![self tabsContainsTabId:IFTabConsole]) {
        IFCompilerTab* newTab = [[IFCompilerTab alloc] init];
        newTab.view = splitView;
        newTab.name = [IFUtility localizedString: @"Compiler"
                                          default: @"Compiler"
                                            table: @"CompilerOutput"];
        newTab.tabId = IFTabConsole;
        [tabs addObject:newTab];
        
        selectedTabId = IFTabConsole;
	} else {
        [self adjustSplitView];
        [self replaceViewWithTabId: IFTabConsole
                          withView: splitView];
	}

    if ([delegate respondsToSelector: @selector(viewSetHasUpdated:)]) {
		[delegate viewSetHasUpdated: self];
    }
}

#pragma mark - Managing the set of views displayed by this object

@synthesize selectedTabId;

- (void) switchToViewWithTabId: (IFCompilerTabId) tabId {
	NSUInteger index = [self tabIndexWithTabId:tabId];

    // Check if available
    if( index == NSNotFound ) return;
    NSAssert([tabs count] > index, @"index too large");

    IFCompilerTab* tab = tabs[index];

    NSView* activeView = [superView subviews][0];
    
    // ... or if we can't display anything
	if (activeView == nil) return;
	if (superView == nil) return;
    
	// Swap the view being displayed by this object for the view in auxViews
	NSView* newView = tab.view;

    NSRect rect = [activeView frame];
	[activeView removeFromSuperview];
	[superView addSubview: newView];
    [newView setFrame:rect];
    
    // Give focus to the new window
    if( [[newView class] isSubclassOfClass:[NSSplitView class]] ) {
        [[superView window] makeFirstResponder: [((NSSplitView*)newView) subviews][1]];
    }
    else {
        [[superView window] makeFirstResponder: newView];
    }

	selectedTabId = tab.tabId;
    //NSAssert(selectedTabId != IFTabInvalid, @"Invalid tab selected");
	
	// Inform the delegate of the change
	if ([delegate respondsToSelector: @selector(compiler:switchedToView:)]) {
		[delegate compiler: self
			switchedToView: (int) index];
	}
}

- (void) switchToSplitView {
	[self switchToViewWithTabId: IFTabConsole];
}

- (void) switchToRuntimeErrorView {
	[self switchToViewWithTabId: IFTabRuntime];
}

- (NSArray*) viewTabs {
	return tabs;
}

@end

// == The lexical helper function to actually add error messages ==

static NSString* memSetting = @"The memory setting ";
static NSString* exceeds = @"The story file exceeds ";
static NSString* readable = @"This program has overflowed the maximum readable-memory size of the Z-machine format.";

void IFErrorAddError(const char* filC,
					 int line,
                     IFLex type,
                     const char* mesC) {
    NSString* file    = @(filC);
    NSString* message = @(mesC);
	
	// Look for known error messages
	if (type == IFLexCompilerFatalError 
		&& [message length] > [memSetting length]
		&& [[message substringToIndex: [memSetting length]] isEqualToString: memSetting]) {
		[activeController overrideProblemsURL: [NSURL URLWithString: @"inform:/ErrorI6MemorySetting.html"]];
	}
	
	if (type == IFLexCompilerFatalError
		&& [message length] > [exceeds length]
		&& [[message substringToIndex: [exceeds length]] isEqualToString: exceeds]) {
		[activeController overrideProblemsURL: [NSURL URLWithString: @"inform:/ErrorI6TooBig.html"]];
	}
	
	if ((type == IFLexCompilerFatalError || type == IFLexCompilerError)
		&& [message length] > [readable length]
		&& [[message substringToIndex: [readable length]] isEqualToString: readable]) {
		[activeController overrideProblemsURL: [NSURL URLWithString: @"inform:/ErrorI6Readable.html"]];
	}
	
    // Pass the rest to the controller
    [activeController addErrorForFile: file
                               atLine: line
                             withType: type
                              message: message];
}

void IFErrorCopyBlorbTo(const char* whereTo) {
	[activeController setBlorbLocation: @(whereTo)];
}
