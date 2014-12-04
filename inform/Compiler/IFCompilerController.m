//
//  IFCompilerController.m
//  Inform
//
//  Created by Andrew Hunter on Mon Aug 18 2003.
//  Copyright (c) 2003 Andrew Hunter. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "IFCompilerController.h"

#import "IFAppDelegate.h"

#import "IFCompiler.h"
#import "IFError.h"
#import "IFProjectController.h"

#import "IFJSProject.h"

#import "IFPreferences.h"
#import "IFUtility.h"
#import "NSBundle+IFBundleExtensions.h"

// Possible styles (stored in the styles dictionary)
NSString* IFStyleBase               = @"IFStyleBase";

// Basic compiler messages
NSString* IFStyleCompilerVersion    = @"IFStyleCompilerVersion";
NSString* IFStyleCompilerMessage    = @"IFStyleCompilerMessage";
NSString* IFStyleCompilerWarning    = @"IFStyleCompilerWarning";
NSString* IFStyleCompilerError      = @"IFStyleCompilerError";
NSString* IFStyleCompilerFatalError = @"IFStyleCompilerFatalError";
NSString* IFStyleProgress			= @"IFStyleProgress";

NSString* IFStyleFilename           = @"IFStyleFilename";

// Compiler statistics/dumps/etc
NSString* IFStyleAssembly           = @"IFStyleAssembly";
NSString* IFStyleHexDump            = @"IFStyleHexDump";
NSString* IFStyleStatistics         = @"IFStyleStatistics";

static IFCompilerController* activeController = nil;

@implementation IFCompilerTab

@end

@implementation IFCompilerController

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

    NSMutableParagraphStyle* centered = [[[NSParagraphStyle defaultParagraphStyle] mutableCopy] autorelease];
    [centered setAlignment: NSCenterTextAlignment];
    
    NSDictionary* baseStyle = [NSDictionary dictionaryWithObjectsAndKeys:
        baseFont, NSFontAttributeName,
        [NSColor blackColor], NSForegroundColorAttributeName,
        nil];

    NSDictionary* versionStyle = [NSDictionary dictionaryWithObjectsAndKeys:
        bigFont, NSFontAttributeName,
        centered, NSParagraphStyleAttributeName,
        nil];
    
    NSDictionary* filenameStyle = [NSDictionary dictionaryWithObjectsAndKeys:
        [NSColor blackColor],
        NSForegroundColorAttributeName,
        boldFont, NSFontAttributeName,
        nil];
    
    NSDictionary* messageStyle = [NSDictionary dictionaryWithObjectsAndKeys:
        [NSColor colorWithDeviceRed: 0 green: 0.5 blue: 0 alpha: 1.0],
        NSForegroundColorAttributeName, nil];
    NSDictionary* warningStyle = [NSDictionary dictionaryWithObjectsAndKeys:
        [NSColor colorWithDeviceRed: 0 green: 0 blue: 0.7 alpha: 1.0],
        NSForegroundColorAttributeName,
        boldFont, NSFontAttributeName,
        nil];
    NSDictionary* errorStyle = [NSDictionary dictionaryWithObjectsAndKeys:
        [NSColor colorWithDeviceRed: 0.7 green: 0 blue: 0.0 alpha: 1.0],
        NSForegroundColorAttributeName,
        boldFont, NSFontAttributeName,
        nil];
    NSDictionary* fatalErrorStyle = [NSDictionary dictionaryWithObjectsAndKeys:
        [NSColor colorWithDeviceRed: 1.0 green: 0 blue: 0.0 alpha: 1.0],
        NSForegroundColorAttributeName,
        italicFont, NSFontAttributeName,
        nil];
    NSDictionary* progressStyle = [NSDictionary dictionaryWithObjectsAndKeys:
        [NSColor colorWithDeviceRed: 0.0 green: 0 blue: 0.6 alpha: 1.0],
        NSForegroundColorAttributeName,
        smallFont, NSFontAttributeName,
        nil];
	
    return [NSDictionary dictionaryWithObjectsAndKeys:
        baseStyle, IFStyleBase,
        versionStyle, IFStyleCompilerVersion,
        messageStyle, IFStyleCompilerMessage, warningStyle, IFStyleCompilerWarning,
        errorStyle, IFStyleCompilerError, fatalErrorStyle, IFStyleCompilerFatalError,
        filenameStyle, IFStyleFilename,
		progressStyle, IFStyleProgress,
        nil];
}

// == Initialisation ==
- (void) _registerHandlers {
    if (compiler != nil) {
		[[NSNotificationCenter defaultCenter] addObserver: self
												 selector: @selector(preferencesChanged:)
													 name: IFPreferencesAppFontSizeDidChangeNotification
												   object: [IFPreferences sharedPreferences]];
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
    }
}

- (void) _removeHandlers {
    if (compiler != nil) {
		[[NSNotificationCenter defaultCenter] removeObserver: self
													 name: IFPreferencesAppFontSizeDidChangeNotification
												   object: [IFPreferences sharedPreferences]];
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
    }
}

- (id) init {
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

        tabDictionary = [[NSDictionary alloc] initWithObjectsAndKeys:
                         [NSNumber numberWithInt:(int)IFTabDebugging],   @"debug log.txt",
                         [NSNumber numberWithInt:(int)IFTabInform6],     @"auto.inf",
                         [NSNumber numberWithInt:(int)IFTabReport],      @"problems.html",
                         [NSNumber numberWithInt:(int)IFTabReport],      @"log of problems.txt",
                         [NSNumber numberWithInt:(int)IFTabConsole],     @"compiler",
                         nil];

        [self _registerHandlers];
    }

    return self;
}

- (void) dealloc {    
    [[NSNotificationCenter defaultCenter] removeObserver: self];

    [compiler release];
    [styles release];

    if (errorFiles)		[errorFiles release];
    if (errorMessages)	[errorMessages release];
    if (window)			[window release];
    //if (delegate)      [delegate release];
	
	if (lastProblemURL) [lastProblemURL release];
	if (overrideURL)	[overrideURL release];
	
    if (tabs)           [tabs release];
	if (splitView)		[splitView release];
    if (tabDictionary)  [tabDictionary release];

   [super dealloc];
}

- (void) awakeFromNib {
    awake = YES;
    [[compilerResults textStorage] setDelegate: self];

    messagesSize = [messageScroller frame].size.height;

    NSRect newFrame = [messageScroller frame];
    newFrame.size.height = 0;
    [messageScroller setFrame: newFrame];

    [splitView adjustSubviews];
	
    // Mutter, interface builder won't let you change the enclosing scrollview
    // of an outlineview
    [messageScroller setBorderType: NSNoBorder];

    [resultScroller setHasHorizontalScroller: YES];
    [compilerResults setMaxSize: NSMakeSize(1e8, 1e8)];
    [compilerResults setHorizontallyResizable: YES];
    [compilerResults setVerticallyResizable: YES];
    [[compilerResults textContainer] setWidthTracksTextView: NO];
    [[compilerResults textContainer] setContainerSize: NSMakeSize(1e8, 1e8)];
}

- (void) showWindow: (id) sender {
    if (!awake) {
        [NSBundle oldLoadNibNamed: @"Compiling"
                            owner: self];
    }

    [window orderFront: sender];
}

// == Information ==
- (void) resetCompiler {
    [self _removeHandlers];
    [compiler release];

    compiler = [[IFCompiler alloc] init];
    [self _registerHandlers];

    NSRect newFrame = [messageScroller frame];
    newFrame.size.height = 0;
    [messageScroller setFrame: newFrame];

    [splitView adjustSubviews];
}

- (void) setCompiler: (IFCompiler*) comp {
    [self _removeHandlers];
    [compiler release];

    compiler = [comp retain];
    [self _registerHandlers];

    NSRect newFrame = [messageScroller frame];
    newFrame.size.height = 0;
    [messageScroller setFrame: newFrame];

    [splitView adjustSubviews];
}

- (IFCompiler*) compiler {
    return compiler;
}

// == Starting/stopping the compiler ==
- (BOOL) startCompiling {
    if (window)
        [window setTitle: [NSString stringWithFormat: [IFUtility localizedString: @"Compiling - '%@'..."],
                                                      [[compiler inputFile] lastPathComponent]]];

    if (errorFiles) [errorFiles release];
    if (errorMessages) [errorMessages release];

    errorFiles    = [[NSMutableArray array] retain];
    errorMessages = [[NSMutableArray array] retain];
	
	if (overrideURL != nil) [overrideURL release];
	overrideURL = nil;

    if (delegate &&
        [delegate respondsToSelector: @selector(errorMessagesCleared:)]) {
        [delegate errorMessagesCleared: self];
    }
    
    [[[compilerResults textStorage] mutableString] setString: @""];
    highlightPos = 0;

    [compiler prepareForLaunchWithBlorbStage: NO];

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

- (void) started: (NSNotification*) not {
    if (errorFiles == nil) errorFiles = [[NSMutableArray alloc] init];
    if (errorMessages == nil) errorMessages = [[NSMutableArray alloc] init];
	if (overrideURL != nil) [overrideURL release];
	overrideURL = nil;

    [self clearTabViews];
    [errorMessages removeAllObjects];
    [errorFiles removeAllObjects];
    [compilerMessages reloadData];
	
	[blorbLocation release]; blorbLocation = nil;
    
    [[[compilerResults textStorage] mutableString] setString: @""];
    highlightPos = 0;

    if (delegate &&
        [delegate respondsToSelector: @selector(compileStarted:)]) {
        [delegate compileStarted: self];
    }
}

- (void) finished: (NSNotification*) not {
    int exitCode = [[[not userInfo] objectForKey: @"exitCode"] intValue];
	
	[lastProblemURL release];
	if (overrideURL)
		lastProblemURL = [overrideURL retain];
	else
		lastProblemURL = [[compiler problemsURL] retain];

    [[[compilerResults textStorage] mutableString] appendString: @"\n"];
	[[[compilerResults textStorage] mutableString] appendString: 
		[NSString stringWithFormat: [IFUtility localizedString: @"Compiler finished with code %i"], exitCode]];
	[[[compilerResults textStorage] mutableString] appendString: @"\n"];

    NSString* msg;

    if (exitCode == 0) {
		//NSLog(@"%@", [NSString stringWithFormat: [IFUtility localizedString: @"Compilation succeeded"], exitCode]);

        msg = [IFUtility localizedString: @"Success"];

        if (delegate &&
            [delegate respondsToSelector: @selector(compileCompletedAndSucceeded:)]) {
            [delegate compileCompletedAndSucceeded: self];
        }
    } else {
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

        msg = [IFUtility localizedString: @"Failed"];

        if (delegate &&
            [delegate respondsToSelector: @selector(compileCompletedAndSucceeded:)]) {
            [delegate compileCompletedAndFailed: self];
        }
    }

    if (window)
        [window setTitle: [NSString stringWithFormat: @"%@ - '%@'",
            msg, [[compiler inputFile] lastPathComponent]]];

    [self scrollToEnd];
}

- (void) gotStdout: (NSNotification*) not {
    NSString* data = [[not userInfo] objectForKey: @"string"];
	NSAttributedString* newString = [[[NSAttributedString alloc] initWithString: data
																	 attributes: [styles objectForKey: IFStyleBase]] autorelease];
	
	[[compilerResults textStorage] appendAttributedString: newString];
}

- (void) gotStderr: (NSNotification*) not {
    NSString* data = [[not userInfo] objectForKey: @"string"];
	NSAttributedString* newString = [[[NSAttributedString alloc] initWithString: data
																	 attributes: [styles objectForKey: IFStyleBase]] autorelease];
	
	[[compilerResults textStorage] appendAttributedString: newString];
}

// = Preferences =

- (void) preferencesChanged: (NSNotification*) not {
    // Report
    int tabIndex = [self tabIndexWithTabId: IFTabReport];
    if( tabIndex != NSNotFound ) {
        IFCompilerTab* tab = [tabs objectAtIndex: tabIndex];
        if( [tab->view isKindOfClass:[WebView class]] ) {
            [((WebView*) tab->view) setTextSizeMultiplier: [[IFPreferences sharedPreferences] appFontSizeMultiplier]];
        }
    }

    // Runtime error
    tabIndex = [self tabIndexWithTabId: IFTabRuntime];
    if( tabIndex != NSNotFound ) {
        IFCompilerTab* tab = [tabs objectAtIndex: tabIndex];
        if( [tab->view isKindOfClass:[WebView class]] ) {
            [((WebView*) tab->view) setTextSizeMultiplier: [[IFPreferences sharedPreferences] appFontSizeMultiplier]];
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
				
				[[compiler progress] setMessage: [msg autorelease]];
			}

			return IFStyleProgress;
        case IFLexEndText:
            if( IFLexEndTextString ) {
				NSString* msg;
				
				msg = [[NSString alloc] initWithBytes: IFLexEndTextString
											   length: strlen(IFLexEndTextString)-1
											 encoding: NSUTF8StringEncoding];

				// (Second attempt if UTF-8 makes no sense)
				if (msg == nil) msg = [[NSString alloc] initWithBytes: IFLexEndTextString
															   length: strlen(IFLexEndTextString)-1
															 encoding: NSISOLatin1StringEncoding];

                [compiler setEndTextString: msg];
                [msg autorelease];
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

- (void)textStorageDidProcessEditing: (NSNotification *)aNotification {
    NSTextStorage* storage = [compilerResults textStorage];
    
    // Set the text to the base style
	[storage beginEditing];

    // For each line since highlightPos...
    NSString* str = [storage string];
    int len       = [str length];

    int newlinePos;
    
    do {
        int x;
        
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
            [storage addAttributes: [styles objectForKey: newStyle]
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
										  modes: [NSArray arrayWithObject: NSDefaultRunLoopMode]];
}

// == The error OutlineView ==

- (void) addErrorForFile: (NSString*) file
                  atLine: (int) line
                withType: (IFLex) type
                 message: (NSString*) message {
    // Find the entry for this error message, if it exists. If not,
    // add this as a new file...
    int fileNum = [errorFiles indexOfObject: file];

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
    NSMutableArray* fileMessages = [errorMessages objectAtIndex: fileNum];
    NSArray*        newMessage = [NSArray arrayWithObjects: message, [NSNumber numberWithInt: line], [NSNumber numberWithInt: type], [NSNumber numberWithInt: fileNum], nil];
    [fileMessages addObject: newMessage];

    // Update the outline view
    [compilerMessages reloadData];

    // Pop up the error view if required
    if ([messageScroller frame].size.height == 0) {
        NSRect newFrame = [messageScroller frame];
        newFrame.size.height = messagesSize;
        [messageScroller setFrame: newFrame];

        NSRect splitFrame = [splitView frame];
        NSRect resultFrame = [resultScroller frame];

        resultFrame.size.height = splitFrame.size.height - newFrame.size.height - [splitView dividerThickness];
        [resultScroller setFrame: resultFrame];

        [splitView adjustSubviews];
    }

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

- (int)         outlineView: (NSOutlineView *) outlineView
     numberOfChildrenOfItem: (id) item {
    if (item == nil) {
        return [errorFiles count];
    }
    
    int fileNum = [errorFiles indexOfObjectIdenticalTo: item];

    if (fileNum == NSNotFound) {
        return 0;
    }

    return [[errorMessages objectAtIndex: fileNum] count];
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
        return [errorFiles objectAtIndex: index];
    }

    int fileNum = [errorFiles indexOfObjectIdenticalTo: item];

    if (fileNum == NSNotFound) {
        return nil;
    }

    return [[errorMessages objectAtIndex: fileNum] objectAtIndex: index];
}

- (id)          outlineView: (NSOutlineView *) outlineView
  objectValueForTableColumn: (NSTableColumn *) tableColumn
                     byItem: (id) item {
    if ([item isKindOfClass: [NSString class]]) {
        // Must be a filename
        NSAttributedString* str = [[NSAttributedString alloc] initWithString: [item lastPathComponent]
                                                                  attributes: [styles objectForKey: IFStyleFilename]];

        return [str autorelease];
    }

    // Is an array of the form message, line, type
    NSString* message = [item objectAtIndex: 0];
    int line = [[item objectAtIndex: 1] intValue];
    IFLex type = [[item objectAtIndex: 2] intValue];

    NSDictionary* attr = [styles objectForKey: IFStyleCompilerMessage];

    switch (type) {
        case IFLexCompilerWarning:
            attr = [styles objectForKey: IFStyleCompilerWarning];
            break;
            
        case IFLexCompilerError:
            attr = [styles objectForKey: IFStyleCompilerError];
            break;
            
        case IFLexCompilerFatalError:
            attr = [styles objectForKey: IFStyleCompilerFatalError];
            break;

        default:
            break;
    }

    NSString* msg = [NSString stringWithFormat: @"L%i: %@", line, message];
    NSAttributedString* res = [[NSAttributedString alloc] initWithString: msg
                                                             attributes: attr];
    
    return [res autorelease];
}

- (void) outlineViewSelectionDidChange: (NSNotification *)notification {
    NSObject* obj = [compilerMessages itemAtRow: [compilerMessages selectedRow]];

    if (obj == nil) {
        return; // Nothing selected
    }

    int fileNum = [errorFiles indexOfObjectIdenticalTo: obj];

    if (fileNum != NSNotFound) {
        return; // File item selected
    }
	
    // obj is an array of the form [message, line, type]
    NSArray* msg = (NSArray*) obj;

    // NSString* message = [msg objectAtIndex: 0];
    int       line    = [[msg objectAtIndex: 1] intValue];
    // IFLex type        = [[msg objectAtIndex: 2] intValue];
	fileNum = [[msg objectAtIndex: 3] intValue];

    // Send to the delegate
    if (delegate &&
        [delegate respondsToSelector: @selector(errorMessageHighlighted:atLine:inFile:)]) {
        [delegate errorMessageHighlighted: self
                                   atLine: line
                                   inFile: [errorFiles objectAtIndex: fileNum]];
    }

    return;
}

- (void) windowWillClose: (NSNotification*) not {
    [self autorelease];
}

// Other information

- (int) tabIndexWithTabId: (IFCompilerTabId) tabId {
    for(int index = 0; index < [tabs count]; index++ ) {
        IFCompilerTab* tab = [tabs objectAtIndex:index];
        if( tab->tabId == tabId ) {
            return index;
        }
    }
    return NSNotFound;
}

- (int) tabIdWithTabIndex: (int) tabIndex {
    IFCompilerTab* tab = [tabs objectAtIndex:tabIndex];
    return tab->tabId;
}

-(IFCompilerTabId) tabIdOfItemWithFilename: (NSString *) theFile
{
    NSString* lowerFile = [theFile lowercaseString];
    
    NSNumber* integer = [tabDictionary objectForKey:lowerFile];
    if( integer == nil ) {
        return IFTabInvalid;
    }
    return (IFCompilerTabId)[integer intValue];
}

-(NSString *) filenameOfItemWithTabId: (IFCompilerTabId) tabId
{
    for( NSString* key in tabDictionary)
    {
        if( [[tabDictionary objectForKey:key] intValue] == tabId ) {
            return key;
        }
    }
    return nil;
}

-(bool) tabsContainsTabId: (IFCompilerTabId) tabId {
    return [self tabIndexWithTabId:tabId] != NSNotFound;
}

-(void) replaceViewWithTabId: (IFCompilerTabId) tabId withView: (NSView*) aView {
    int tabIndex = [self tabIndexWithTabId:tabId];
    if( tabIndex != NSNotFound ) {
        IFCompilerTab* tab = [tabs objectAtIndex:tabIndex];
        if( tab ) {
            NSView* newView = [aView retain];
            [tab->view release];
            tab->view = newView;
        }
        IFCompilerTab* tab2 = [tabs objectAtIndex:tabIndex];

        NSAssert(tab2->view == aView, @"Replace didn't work...");
    }
}


- (IFCompilerTabId) makeTabViewItemNamed: (NSString*) tabName
                                withView: (NSView*) newView
                               withTabId: (IFCompilerTabId) tabId {
    IFCompilerTab* newTab = [[IFCompilerTab alloc] init];
    newTab->name = [tabName retain];
    newTab->view = [newView retain];
    newTab->tabId = tabId;
    [newTab autorelease];

	[tabs addObject: newTab];
	
	if (delegate && [delegate respondsToSelector: @selector(viewSetHasUpdated:)]) {
		[delegate viewSetHasUpdated: self];
	}
	
	return newTab->tabId;
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
    [[webView mainFrame] loadRequest: [[[NSURLRequest alloc] initWithURL: url] autorelease]];

	// Add it to the list of tabs
	return [self makeTabViewItemNamed: tabName
							 withView: [webView autorelease]
                            withTabId: tabId];
}

- (IFCompilerTabId) makeTabForFile: (NSString*) file {
	NSString* type = [[file pathExtension] lowercaseString];

	if ([[NSApp delegate] isWebKitAvailable] && ([type isEqualTo: @"html"] ||
												 [type isEqualTo: @"htm"])) {
		// Treat as a webkit URL
		return [self makeTabForURL: [IFProjectPolicy fileURLWithPath: file]
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
        
		// Load the data for the file
		NSString* textData = [[NSString alloc] initWithData: [NSData dataWithContentsOfFile: file]
												   encoding: NSUTF8StringEncoding];
        if( textData == nil ) {
            textData = [[NSString alloc] initWithData: [NSData dataWithContentsOfFile: file]
                                             encoding: NSISOLatin1StringEncoding];
        }
		[[[textView textStorage] mutableString] setString: [textData autorelease]];
        [[textView textStorage] setFont:[NSFont fontWithName:@"Monaco" size:11]];

        // scrollView is the 'parent' of the textView
        [scrollView setDocumentView: [textView autorelease]];
        [scrollView setAutoresizingMask: (NSUInteger) (NSViewWidthSizable|NSViewHeightSizable)];
        [scrollView setHasHorizontalScroller: YES];
        [scrollView setHasVerticalScroller: YES];
		
		// Add the tab
		return [self makeTabViewItemNamed: [IFUtility localizedString: [file lastPathComponent]
                                                              default: [[file lastPathComponent] stringByDeletingPathExtension]
                                                                table: @"CompilerOutput"]
								 withView: [scrollView autorelease]
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
    [[webView mainFrame] loadRequest: [[[NSURLRequest alloc] initWithURL: errorURL] autorelease]];
    [webView autorelease];

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
		
        bool tempFile = [[[key substringToIndex: 4] lowercaseString] isEqualToString: @"temp"];
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
    for(int index = [tabs count] - 1; index >= 0; index--) {
        IFCompilerTab*tab = [tabs objectAtIndex:index];
        if( tab->tabId != IFTabConsole ) {
            [tabs removeObjectAtIndex:index];
            updated = true;
        }
    }
	
	// Notify the delegate that the set of views has updated
    if( updated ) {
        if (delegate && [delegate respondsToSelector: @selector(viewSetHasUpdated:)]) {
            [delegate viewSetHasUpdated: self];
        }
    }

	// Switch to the console view
    if( selectedTabId != IFTabConsole ) {
        [self switchToViewWithTabId: IFTabConsole];
    }
}

// == Delegate ==

- (void) setDelegate: (NSObject*) dg {
	delegate = dg;
}

- (NSObject*) delegate {
    return delegate;
}

// = Web policy delegate methods =

- (void)        webView: (WebView *) sender
   didClearWindowObject: (WebScriptObject *) windowObject
               forFrame: (WebFrame *) frame {
	// Attach the JavaScript object to this webview
	IFJSProject* js = [[IFJSProject alloc] initWithPane: nil];
	
	// Attach it to the script object
	[[sender windowScriptObject] setValue: [js autorelease]
								   forKey: @"Project"];
}

- (void)					webView: (WebView *)sender
	decidePolicyForNavigationAction: (NSDictionary *)actionInformation 
							request: (NSURLRequest *)request 
							  frame: (WebFrame *)frame 
				   decisionListener: (id<WebPolicyDecisionListener>)listener {
	// Blah. Link failure if WebKit isn't available here. Constants aren't weak linked
	
	// Double blah. WebNavigationTypeLinkClicked == null, but the action value == 0. Bleh
	if ([[actionInformation objectForKey: WebActionNavigationTypeKey] intValue] == 0) {
		NSURL* url = [request URL];
		
		if ([[url scheme] isEqualTo: @"source"]) {
			// We deal with these ourselves
			[listener ignore];
			
			// Format is 'source file name#line number'
			NSString* path = [[[request URL] resourceSpecifier] stringByReplacingPercentEscapesUsingEncoding: NSASCIIStringEncoding];
			NSArray* components = [path componentsSeparatedByString: @"#"];
			
			if ([components count] != 2) {
				NSLog(@"Bad source URL: %@", path);
				if ([components count] < 2) return;
				// (try anyway)
			}
			
			NSString* sourceFile = [[components objectAtIndex: 0] stringByReplacingPercentEscapesUsingEncoding: NSUnicodeStringEncoding];
			NSString* sourceLine = [[components objectAtIndex: 1] stringByReplacingPercentEscapesUsingEncoding: NSUnicodeStringEncoding];
			
			// sourceLine can have format 'line10' or '10'. 'line10' is more likely
			int lineNumber = [sourceLine intValue];
			
			if (lineNumber == 0 && [[sourceLine substringToIndex: 4] isEqualToString: @"line"]) {
				lineNumber = [[sourceLine substringFromIndex: 4] intValue];
			}
			
			if (delegate &&
				[delegate respondsToSelector: @selector(errorMessageHighlighted:atLine:inFile:)]) {
				[delegate errorMessageHighlighted: self
										   atLine: lineNumber
										   inFile: sourceFile];
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
			if (delegate && [delegate respondsToSelector: @selector(handleURLRequest:)]) {
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

- (void) setBlorbLocation: (NSString*) location {
	[blorbLocation release];
	blorbLocation = [location copy];
}

- (NSString*) blorbLocation {
	return blorbLocation;
}

- (void) overrideProblemsURL: (NSURL*) problemsURL {
	[overrideURL release];
	overrideURL = [problemsURL copy];
}

- (void) setSplitView: (NSSplitView*) newSplitView {
	// Remember the new split view
	[splitView release];
	splitView = [newSplitView retain];
    superView = [splitView superview];
    
    [splitView setAutoresizingMask: (NSUInteger) (NSViewWidthSizable|NSViewHeightSizable)];

    if( ![self tabsContainsTabId:IFTabConsole]) {
        IFCompilerTab* newTab = [[IFCompilerTab alloc] init];
        newTab->view = [splitView retain];
        newTab->name = [IFUtility localizedString: @"Compiler"
                                          default: @"Compiler"
                                            table: @"CompilerOutput"];
        newTab->tabId = IFTabConsole;
        [tabs addObject:newTab];
        [newTab release];
        
        selectedTabId = IFTabConsole;
	} else {
        [self replaceViewWithTabId: IFTabConsole
                          withView: splitView];
	}
	if (delegate && [delegate respondsToSelector: @selector(viewSetHasUpdated:)]) {
		[delegate viewSetHasUpdated: self];
    }
}

- (NSSplitView*) splitView {
	return splitView;
}

// = Managing the set of views displayed by this object =

- (IFCompilerTabId) selectedTabId {
	return selectedTabId;
}

- (void) switchToViewWithTabId: (IFCompilerTabId) tabId {
	int index = [self tabIndexWithTabId:tabId];

    // Check if available
    if( index == NSNotFound ) return;
    NSAssert([tabs count] > index, @"index too large");

    IFCompilerTab* tab = [tabs objectAtIndex: index];

    NSView* activeView = [[superView subviews] objectAtIndex:0];
    
    // ... or if we can't display anything
	if (activeView == nil) return;
	if (superView == nil) return;
    
	// Swap the view being displayed by this object for the view in auxViews
	NSView* newView = tab->view;

    NSRect rect = [activeView frame];
	[activeView removeFromSuperview];
	[superView addSubview: newView];
    [newView setFrame:rect];
    
    // Give focus to the new window
    if( [[newView class] isSubclassOfClass:[NSSplitView class]] ) {
        [[superView window] makeFirstResponder: [[((NSSplitView*)newView) subviews] objectAtIndex:1]];
    }
    else {
        [[superView window] makeFirstResponder: newView];
    }

	selectedTabId = tab->tabId;
    NSAssert(selectedTabId != IFTabInvalid, @"Invalid tab selected");
	
	// Inform the delegate of the change
	if (delegate && [delegate respondsToSelector: @selector(compiler:switchedToView:)]) {
		[delegate compiler: self
			switchedToView: index];
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
    NSString* file    = [NSString stringWithCString: filC encoding:NSUTF8StringEncoding];
    NSString* message = [NSString stringWithCString: mesC encoding:NSUTF8StringEncoding];
	
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
	[activeController setBlorbLocation: [NSString stringWithUTF8String: whereTo]];
}
