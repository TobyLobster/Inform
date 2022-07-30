//
//  IFGamePage.m
//  Inform
//
//  Created by Andrew Hunter on 25/03/2007.
//  Copyright 2007 Andrew Hunter. All rights reserved.
//

#import "IFGamePage.h"
#import "IFErrorsPage.h"
#import "IFSkein.h"
#import "IFSkeinItem.h"
#import "IFPreferences.h"
#import "IFGlkResources.h"
#import "IFRuntimeErrorParser.h"
#import "IFUtility.h"
#import "IFProgress.h"
#import "IFProjectController.h"
#import "IFProjectTypes.h"
#import "IFProject.h"
#import <ZoomView/ZoomView.h>
#import <GlkSound/GlkSound.h>
#import "Inform-Swift.h"

@interface IFGamePage () <GlkViewDelegate, ZoomViewOutputReceiver, ZoomViewDelegate>

@end

@interface IFSemiTransparentView : NSView

@end

@implementation IFSemiTransparentView

- (void)drawRect:(NSRect)dirtyRect {
    // When the game is not running, show this view (semi transparent white) over the top.
    [[NSColor colorWithDeviceRed: 1.0 green: 1.0 blue: 1.0 alpha: 0.5] setFill];
    NSRectFill(dirtyRect);
    [super drawRect:dirtyRect];
}
@end

@implementation IFGamePage {
    /// The Glk (glulxe) view
    GlkView*		 gView;
    /// The Z-Machine view
    ZoomView*        zView;
    /// The filename of the game to start
    NSString*        gameToRun;
    /// \c YES to switch view to show the game page
    BOOL             switchToPage;
    
    GlkSoundHandler *soundHandler;

    /// The progress indicator (how much we've compiled, how the game is running, etc)
    IFProgress*      gameRunningProgress;
    NSView*          semiTransparentView;

    /// \c YES if we are allowed to set breakpoints
    BOOL             setBreakpoint;
    /// List of commands to automatically run once game has started
    NSArray<NSString*>* testCommands;
}

#pragma mark - Initialisation

- (instancetype) initWithProjectController: (IFProjectController*) controller {
	self = [super initWithNibName: @"Game"
				projectController: controller];
	
	if (self) {
        zView           = nil;
        gView           = nil;
        gameToRun       = nil;
        _isRunningGame  = NO;
        testCommands    = nil;
        switchToPage    = NO;

		// Register for breakpoints updates
		[[NSNotificationCenter defaultCenter] addObserver: self
												 selector: @selector(preferencesChanged:)
													 name: IFPreferencesAppFontSizeDidChangeNotification
												   object: [IFPreferences sharedPreferences]];
	}
	
	return self;
}

- (void) dealloc {
	[[NSNotificationCenter defaultCenter] removeObserver: self];

	if (gameRunningProgress) {
        [gameRunningProgress stopProgress];
		[self.parent removeProgressIndicator: gameRunningProgress];
		gameRunningProgress = nil;
	}
		
    if (zView) {
        [zView removeFromSuperview];
		[zView setDelegate: nil];
		[zView killTask];
	}
	if (gView) {
        [gView removeFromSuperview];
		[gView setDelegate: nil];
		[gView terminateClient];
		gView = nil;
	}
    _isRunningGame = NO;

}

#pragma mark - Details about this view

- (NSString*) title {
	return [IFUtility localizedString: @"Game Page Title"
                              default: @"Game"];
}

#pragma mark - Page validation

- (BOOL) shouldShowPage {
	return zView != nil || gView != nil;
}

#pragma mark - The game view

- (void) preferencesChanged: (NSNotification*) not {
	[zView setScaleFactor: 1.0/[[IFPreferences sharedPreferences] appFontSizeMultiplier]];
	[gView setScaleFactor: [[IFPreferences sharedPreferences] appFontSizeMultiplier]];
}

- (void) activateDebug {
	setBreakpoint = YES;
}

- (void) startRunningGame: (NSString*) fileName {
	[[[self.parent document] currentSkein] interpreterRestart];
	
    if (zView) {
		[zView killTask];
        [zView removeFromSuperview];
        zView = nil;
    }
	
	if (gView) {
		[gView terminateClient];
		[gView removeFromSuperview];
		gView = nil;
	}
    if( semiTransparentView == nil ) {
        semiTransparentView = [[IFSemiTransparentView alloc] initWithFrame:[self.view frame]];
        semiTransparentView.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;
        
        // "Wants layer" is set so that the subviews (semiTransparentView and zView/gView) are ordered in Z correctly when sibling views overlap
        self.view.wantsLayer = YES;
        [self.view addSubview:semiTransparentView];
    }
    
    gameToRun = [fileName copy];
	
	if (!gameRunningProgress) {
		gameRunningProgress = [[IFProgress alloc] initWithPriority: IFProgressPriorityRunGame
                                                  showsProgressBar: NO
                                                         canCancel: YES];
        [gameRunningProgress setCancelAction: @selector(stopProcess:)
                                   forObject: self.parent];
		[self.parent addProgressIndicator: gameRunningProgress];
        [gameRunningProgress startProgress];
	}

	//[gameRunningProgress setMessage: [IFUtility localizedString: @"Loading story file"]];

	if ([[gameToRun pathExtension] isEqualToString: @"ulx"]) {
		IFRuntimeErrorParser* runtimeErrors = [[IFRuntimeErrorParser alloc] init];
		[runtimeErrors setDelegate: self.parent];

		// Screws up the first responder, will cause the GlkView object to force a new first responder after it starts
		[[self.parent window] makeFirstResponder: [self.parent window]];
		
		// Work out the default client to use
		NSString*		clientName = [[IFPreferences sharedPreferences] glulxInterpreter];
        clientName = [clientName stringByAppendingString:@"-client"];
		//NSLog(@"Using glulx interpreter '%@'", clientName);
		
		// Start running as a glulxe task
        soundHandler = [[GlkSoundHandler alloc] init];
		gView = [[GlkView alloc] init];
        gView.soundHandler = soundHandler;
		[gView setDelegate: self];
		[gView addOutputReceiver: self.parent];
		[gView addOutputReceiver: runtimeErrors];
		
		[gView setImageSource: [[IFGlkResources alloc] initWithProject: [self.parent document]]];
		
		[gView setAutoresizingMask: (NSViewWidthSizable|NSViewHeightSizable)];
		[gView setFrame: [self.view bounds]];
		[self.view addSubview: gView];
		
		[gView setScaleFactor: [[IFPreferences sharedPreferences] appFontSizeMultiplier]];
		
        [gView setInputFileURL: [NSURL fileURLWithPath: fileName]];
        
        NSString * interpreterPath = [NSBundle.mainBundle pathForAuxiliaryExecutable: clientName];
        //NSLog(@"Launching interpreter %@", interpreterPath);

		[gView launchClientApplication: interpreterPath
						 withArguments: nil];
	} else {
		// Start running as a Zoom task
		IFRuntimeErrorParser* runtimeErrors = [[IFRuntimeErrorParser alloc] init];
		
		[runtimeErrors setDelegate: self.parent];
		
		zView = [[ZoomView alloc] init];
		[zView setDelegate: self];
		[[[self.parent document] currentSkein] interpreterRestart];
		[zView addOutputReceiver: [[self.parent document] currentSkein]];
		[zView addOutputReceiver: runtimeErrors];
		[zView runNewServer: nil];
		
		[zView setColours: @[[NSColor colorWithDeviceRed: 0 green: 0 blue: 0 alpha: 1],
                             [NSColor colorWithDeviceRed: 1 green: 0 blue: 0 alpha: 1],
                             [NSColor colorWithDeviceRed: 0 green: 1 blue: 0 alpha: 1],
                             [NSColor colorWithDeviceRed: 1 green: 1 blue: 0 alpha: 1],
                             [NSColor colorWithDeviceRed: 0 green: 0 blue: 1 alpha: 1],
                             [NSColor colorWithDeviceRed: 1 green: 0 blue: 1 alpha: 1],
                             [NSColor colorWithDeviceRed: 0 green: 1 blue: 1 alpha: 1],
                             [NSColor colorWithDeviceRed: 1 green: 1 blue: 1 alpha: 1],
                            
                             [NSColor colorWithDeviceRed: .73 green: .73 blue: .73 alpha: 1],
                             [NSColor colorWithDeviceRed: .53 green: .53 blue: .53 alpha: 1],
                             [NSColor colorWithDeviceRed: .26 green: .26 blue: .26 alpha: 1]]];

		[zView setScaleFactor: 1.0/[[IFPreferences sharedPreferences] appFontSizeMultiplier]];
		
		[zView setFrame: [self.view bounds]];
		[zView setAutoresizingMask: NSViewWidthSizable|NSViewHeightSizable];
		[self.view addSubview: zView];
	}
    [semiTransparentView setHidden: YES];
    _isRunningGame = YES;
}

- (void) setPointToRunTo: (IFSkeinItem*) item {

    NSMutableArray* commands = [[NSMutableArray alloc] init];

    while( (item != nil) && (item.parent != nil) ) {
        [commands addObject: item.command];
        item = item.parent;
    }
    [self setTestCommands: [commands copy]];
}

- (void) setTestMe: (BOOL) testMe {
    if( testMe ) {
        [self setTestCommands: @[@"test me"]];
    }
    else {
        [self setTestCommands: nil];
    }
}

- (void) setTestCommands: (NSArray*) myTestCommands {
    testCommands = [myTestCommands copy];
}

- (BOOL) hasTestCommands {
    return ( testCommands.count > 0 );
}

- (void) setSwitchToPage: (BOOL) willSwitchToPage {
    switchToPage = willSwitchToPage;
}

- (void) stopRunningGame {
    if (zView) {
		[zView killTask];
    }
	
	if (gView) {
		[gView terminateClient];
	}
    
    _isRunningGame = NO;

    [[[self.parent document] currentSkein] interpreterStop];

    // Make sure the semi transparent white window is shown on top of other views
    [semiTransparentView removeFromSuperview];
    [self.view addSubview: semiTransparentView
               positioned: NSWindowAbove
               relativeTo: nil];
    [semiTransparentView setHidden: NO];
    [semiTransparentView setNeedsDisplay: YES];
    [gameRunningProgress stopStory];
}

- (void) pauseRunningGame {
	if (zView) {
		[zView debugTask];
	}
}

@synthesize zoomView = zView;
@synthesize glkView = gView;

// (GlkView delegate functions)
- (void) taskHasStarted {
    if ( switchToPage ) {
        [self switchToPage];
    }
	
	[self.parent glkTaskHasStarted: self];
	
    [gameRunningProgress stopProgress];
	[gameRunningProgress startStory];
	
	if (testCommands != nil) {
        TestCommands* inputSource = [[TestCommands alloc] initWithCommands: testCommands];
        testCommands = nil;
        [self.parent setGlkInputSource: inputSource];
        [gView addInputReceiver: self.parent];
    }
}

// (ZoomView delegate functions)

- (BOOL) disableLogo {
    return YES;
}

- (void) inputSourceHasFinished: (id<ZoomViewInputSource>) sender {
	[self.parent inputSourceHasFinished: nil];
}

- (void) zMachineStarted: (id) sender {	
    [[zView zMachine] loadStoryFile: 
        [NSData dataWithContentsOfFile: gameToRun]];
	
	[[zView zMachine] loadDebugSymbolsFromFile: [[[[[self.parent document] fileURL] path] stringByAppendingPathComponent: @"Build"] stringByAppendingPathComponent: @"gameinfo.dbg"]
							withSourcePath: [[[[self.parent document] fileURL] path] stringByAppendingPathComponent: @"Source"]];
	
	// Set the initial breakpoint if 'Debug' was selected
	if (setBreakpoint) {
		if (![[zView zMachine] setBreakpointAtName: @"Initialise"]) {
			[[zView zMachine] setBreakpointAtName: @"main"];
		}
	}
	
	setBreakpoint = NO;
	
	// Run to the appropriate point in the current skein
	if( testCommands ) {
        TestCommands* inputSource = [[TestCommands alloc] initWithCommands: testCommands];
        testCommands = nil;
        [zView setInputSource: inputSource];
    }
    if( switchToPage ) {
        [self switchToPage];
    }

    [[self.parent window] makeFirstResponder: [zView textView]];
	
    [gameRunningProgress stopProgress];
	[gameRunningProgress startStory];
}

- (NSString*) pathForNamedFile: (NSString*) name {
	// Append .glkdata if the name has no extension
	name = [name lastPathComponent];
	name = [[name stringByDeletingPathExtension] stringByAppendingPathExtension: @"glkdata"];

	// Work out the location of the materials directory
	NSURL* projectURL	= [[self.parent document] fileURL];
	NSURL* materialsURL	= [[self.parent document] materialsDirectoryURL];

	// Default location is materials/Files
	NSURL* filesDirURL = [materialsURL URLByAppendingPathComponent: @"Files"];

	// Use this directory if it exists
	BOOL isDir;
	BOOL exists = [[NSFileManager defaultManager] fileExistsAtPath: filesDirURL.path
													   isDirectory: &isDir];
	
	if (exists && isDir) {
		// Use the files directory
		return [filesDirURL URLByAppendingPathComponent: name].path;
	} else {
		// Use the directory the project is in
		return [[projectURL URLByDeletingLastPathComponent] URLByAppendingPathComponent: name].path;
	}
}

#pragma mark - Debugging

- (void) zoomWaitingForInput {
    [self.parent zoomViewIsWaitingForInput];
}

-(void) didSwitchToPage {
    if( gView ) {
        [gView showMoreWindow];
    }
}

-(void) didSwitchAwayFromPage {
    if( gView ) {
        [gView hideMoreWindow];
    }
}

@end
