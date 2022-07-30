//
//  IFInspectorWindow.m
//  Inform
//
//  Created by Andrew Hunter on Thu Apr 29 2004.
//  Copyright (c) 2004 Andrew Hunter. All rights reserved.
//

#import "IFInspectorWindow.h"
#import "IFInspectorView.h"
#import "IFIsFlippedView.h"
#import "IFProjectController.h"
#import "IFProject.h"
#import "IFUtility.h"
#import "IFInspector.h"
#import "IFPreferences.h"
#import "IFCompilerSettings.h"

static NSString* IFInspectorDefaults = @"IFInspectorDefaults";
static NSString* IFInspectorShown = @"IFInspectorShown";

@implementation IFInspectorWindow {
    /// The dictionary of inspectors (maps inspector keys to inspectors)
    NSMutableDictionary* inspectorDict;

    /// The list of inspectors
    NSMutableArray* inspectors;
    /// The list of inspector views
    NSMutableArray<IFInspectorView*>* inspectorViews;

    /// \c YES if we're in the middle of updating
    BOOL updating;

    // The main window
    /// Flag that indicates if we've processed a new main window event yet
    BOOL newMainWindow;
    /// The 'main window' that we're inspecting
    NSWindow* activeMainWindow;

    // Whether or not the main window should pop up when inspectors suddenly show up
    /// \c YES if the inspector window is currently offscreen (because, for example, none of the inspectors are returning yes to [available])
    BOOL hidden;
    /// \c YES if the inspector window should be shown again (ie, the window was closed because there was nothing to show, not because the user dismissed it)
    BOOL shouldBeShown;

    // List of most/least recently shown inspectors
    /// Array of inspectors in the order that the user asked for them
    NSMutableArray* shownInspectors;
}

+ (IFInspectorWindow*) sharedInspectorWindow {
	static IFInspectorWindow* sharedWindow = nil;
	
	if (sharedWindow == nil) {
		sharedWindow = [[[self class] alloc] init];
		
		NSNumber* shown = [[NSUserDefaults standardUserDefaults] objectForKey: IFInspectorShown];
		
		if ([shown isKindOfClass: [NSNumber class]] && [shown boolValue] == YES) {
			[sharedWindow showWindow: nil];
		} else {
			[[sharedWindow window] orderOut: nil];
		}
	}
	
	return sharedWindow;
}

+ (void) initialize {
	// Register our defaults (which inspectors are open/closed)
	[[NSUserDefaults standardUserDefaults] registerDefaults: 
		@{IFInspectorDefaults: @{}, 
			IFInspectorShown: @NO}];
}

- (instancetype) init {
	// Create ourselves a window
	NSScreen* mainScreen = [NSScreen mainScreen];
    CGFloat width = 240;
    CGFloat height = 10;
	
	NSPanel* ourWindow = [[NSPanel alloc] initWithContentRect: NSMakeRect(NSMaxX([mainScreen frame])-width-50, NSMaxY([mainScreen frame])-height-50, 
																				 width, height)
													styleMask: NSWindowStyleMaskTitled|NSWindowStyleMaskClosable|NSWindowStyleMaskUtilityWindow
													  backing: NSBackingStoreBuffered
														defer: YES];
	
	[ourWindow setFloatingPanel: YES];
	[ourWindow setTitle: [IFUtility localizedString: @"Inspectors"]];
	[ourWindow setMinSize: NSMakeSize(0,0)];
	[ourWindow setMaxSize: NSMakeSize(4000, 4000)];
	
	[ourWindow setBecomesKeyOnlyIfNeeded: YES];
	
	// Initialise ourselves properly
	return [self initWithWindow: ourWindow];
}

- (instancetype)initWithWindow:(NSWindow *)window {
	self = [super initWithWindow: window];
	
	if (self) {
		inspectors = [[NSMutableArray alloc] init];
		inspectorViews = [[NSMutableArray alloc] init];
		updating = NO;
		
		hidden = ![[[NSUserDefaults standardUserDefaults] objectForKey: IFInspectorShown] boolValue];
		
		[window setDelegate: self];
		
		inspectorDict = [[NSMutableDictionary alloc] init];
		
		// The sole purpose of IFIsFlippedView is to return YES to isFlipped...
		[[self window] setContentView: [[IFIsFlippedView alloc] init]];
		
		// - Easy, but broken (doesn't handle the changing size of the window correctly)
		//[self setWindowFrameAutosaveName: @"InspectorWindowFrame"];
		
		[[NSNotificationCenter defaultCenter] addObserver: self
												 selector: @selector(newMainWindow:)
													 name: NSWindowDidBecomeMainNotification
												   object: nil];
		[[NSNotificationCenter defaultCenter] addObserver: self
												 selector: @selector(byeMainWindow:)
													 name: NSWindowDidResignMainNotification
												   object: nil];
		newMainWindow = NO;
		activeMainWindow = nil;
		
		shownInspectors = [[NSMutableArray alloc] init];
	}
	
	return self;
}

- (void) dealloc {
	[[NSNotificationCenter defaultCenter] removeObserver: self];
}

#pragma mark - Dealing with inspector views

- (void) addInspector: (IFInspector*) newInspector {
	// Add the inspector
	[newInspector setInspectorWindow: self];
	[inspectors addObject: newInspector];

	// Create an inspector view for it
	NSRect ourFrame = [[[self window] contentView] frame];
	IFInspectorView* insView = [[IFInspectorView alloc] initWithFrame: NSMakeRect(0,0,ourFrame.size.width,20)];
	
	[insView setView: [newInspector inspectorView]];
	[insView setTitle: [newInspector title]];
	
	[insView setPostsFrameChangedNotifications: YES];
	[[NSNotificationCenter defaultCenter] addObserver: self
											 selector: @selector(updateInspectors:)
												 name: NSViewFrameDidChangeNotification
											   object: insView];
	
	[[[self window] contentView] addSubview: insView];
	[inspectorViews addObject: insView];
	
	// Add the inspector key map thingie
	if (inspectorDict[[newInspector key]] != nil) {
		NSLog(@"BUG: inspector added twice");
	} else {
		inspectorDict[[newInspector key]] = @((int)[inspectors count]-1);
	}
	
	// Set the expanded flag according to the preferences
	NSDictionary* inspectorDefaults = [[NSUserDefaults standardUserDefaults] objectForKey: IFInspectorDefaults];
	if (inspectorDefaults && [inspectorDefaults isKindOfClass: [NSDictionary class]]) {
		[newInspector setExpanded: [inspectorDefaults[[newInspector key]] boolValue]];
	}

	// Update the list of inspectors
	[self updateInspectors];
}

- (void) shrinkInspectorsToFit {
	// Work out the maximum height of the inspector window
	NSRect screenRect = [[[self window] screen] frame];
	NSRect currentFrame = [[self window] frame];
    CGFloat difference = currentFrame.size.height - [[[self window] contentView] frame].size.height;

    CGFloat maxHeight = screenRect.size.height - (NSMaxY(screenRect) - NSMaxY(currentFrame));
	maxHeight -= difference;
		
	// Return if there's only one open inspector
	if ([shownInspectors count] <= 1) return;
	
	// Work out the current height of the inspector window
	NSEnumerator* realInspectorEnum = [inspectors objectEnumerator];
	IFInspector* inspector;
    CGFloat currentHeight = 0;
	
	for( IFInspectorView* insView in inspectorViews ) {
		inspector = [realInspectorEnum nextObject];
		
		if ([inspector available]) {
			currentHeight += [insView frame].size.height;
		}
	}
		
	// Close least recently used inspectors until there's only one shown, or everything fits on the screen	
	if (currentHeight > maxHeight) {
		// (Will recurse if this changes the state any)
		[shownInspectors[0] setExpanded: NO];
	}
}

- (void) setInspectorState: (BOOL) shown
					forKey: (NSString*) key {
	NSNumber* insNum = inspectorDict[key];
		
	if (insNum == nil) {
		NSLog(@"BUG: attempt to show/hide unknown inspector '%@'", key);
		return;
	}
	
	[inspectorViews[[insNum intValue]] setExpanded: shown];
}

- (void) inspectorViewDidChange: (IFInspectorView*) view
						toState: (BOOL) expanded {
	if (expanded && [shownInspectors indexOfObjectIdenticalTo: view] != NSNotFound) return;
	
	[shownInspectors removeObjectIdenticalTo: view];
	if (expanded) {
		[shownInspectors addObject: view];
	}

	[self shrinkInspectorsToFit];
}

- (BOOL) inspectorStateForKey: (NSString*) key {
	NSNumber* insNum = inspectorDict[key];
	
	if (insNum == nil) {
		NSLog(@"BUG: attempt to show/hide unknown inspector '%@'", key);
		return NO;
	}
	
	return [inspectorViews[[insNum intValue]] isExpanded];
}

- (void) showInspector: (IFInspector*) inspector {
	[self showInspectorWithKey: [inspector key]];
}

- (void) showInspectorWithKey: (NSString*) key {
	[self setInspectorState: YES
					 forKey: key];
}

- (void) hideInspector: (IFInspector*) inspector {
	[self hideInspectorWithKey: [inspector key]];
}

- (void) hideInspectorWithKey: (NSString*) key {
	[self setInspectorState: NO
					 forKey: key];
}

#pragma mark - Dealing with updates

- (void) updateInspectors: (NSNotification*) not {
	[self updateInspectors];
}

- (void) updateInspectors {
	if (updating) return;
	
	[[NSRunLoop currentRunLoop] performSelector: @selector(finishUpdate)
										 target: self
									   argument: nil
										  order: 128
										  modes: @[NSDefaultRunLoopMode]];
	updating = YES;
}

- (bool) isInform7ProjectActive {
    // Are we on an Inform 7 project?
	NSWindowController* control = [activeMainWindow windowController];
	if (control != nil && [control isKindOfClass: [IFProjectController class]]) {
        return true;
    }
    return false;
}

- (void) finishUpdate {
	// Display + order all the inspector and relevant controls
	updating = NO; // Do this first: if there's an exception, then we won't be hurt as much
	
	NSRect contentFrame = [[[self window] contentView] frame];
	
	NSEnumerator* realInspectorEnum = [inspectors objectEnumerator];
	IFInspector* inspector;

   	bool inform7Project = [self isInform7ProjectActive];
	
	NSMutableDictionary* inspectorState = [[NSMutableDictionary alloc] init];
	
	// Position all the inspectors
    CGFloat ypos = contentFrame.origin.y;
	for( IFInspectorView* insView in inspectorViews ) {
		inspector = [realInspectorEnum nextObject];
		
		inspectorState[[inspector key]] = @([inspector isExpanded]);
		
        // Inspectors are only shown for Inform 6 projects.
		if ([inspector available] && !inform7Project) {
			NSRect insFrame = [insView frame];
		
			insFrame.origin = NSMakePoint(contentFrame.origin.x, ypos);
			insFrame.size.width = contentFrame.size.width;
		
			[insView setFrame: insFrame];
			
			if ([insView superview] != [[self window] contentView]) {
				[[[self window] contentView] addSubview: insView];
			}
			
			ypos += insFrame.size.height;
		} else {
			if ([insView superview] == [[self window] contentView]) {
				[insView removeFromSuperview];
			}
		}
	}
	
	[[NSUserDefaults standardUserDefaults] setObject: inspectorState
											  forKey: IFInspectorDefaults];
	
	// ypos defines the size of the window
	
	// We only show the window if there's some inspectors to display
	shouldBeShown = YES;
	
	if (ypos == contentFrame.origin.y) {
		shouldBeShown = NO;
		[[self window] orderOut: self];
	} else if (!hidden) {
		if (![[self window] isVisible]) {
			[[self window] orderFront: self];
		}
	}
	
	// Need to do things this way as Jaguar has no proper calculation routines
	NSRect currentFrame = [[self window] frame];
	
    CGFloat difference = currentFrame.size.height - contentFrame.size.height;
	
	NSRect newFrame = currentFrame;
	newFrame.size.height = ypos + difference;
	newFrame.origin.y -= newFrame.size.height-currentFrame.size.height;
	
	[[self window] setFrame: newFrame
					display: YES];
}

#pragma mark - Dealing with window changes

@synthesize activeWindow = activeMainWindow;

- (void) newMainWindow: (NSNotification*) notification {
	// Notify the inspectors of the change
	NSWindow* newMain = [notification object];
	
	if (activeMainWindow != newMain) {
		activeMainWindow = newMain;
	
		if (!newMainWindow) {
			newMainWindow = YES;
			[[NSRunLoop currentRunLoop] performSelector: @selector(updateMainWindow:)
												 target: self
											   argument: nil
												  order: 129
												  modes: @[NSDefaultRunLoopMode, NSModalPanelRunLoopMode]];
		}
	}
}

- (void) byeMainWindow: (NSNotification*) notification {
	// Notify the inspectors of the change
	NSWindow* notTheMainWindowAnyMore = [notification object];
	
	if (activeMainWindow == notTheMainWindowAnyMore) {
		activeMainWindow = nil;

		if (!newMainWindow) {
			newMainWindow = YES;
			[[NSRunLoop currentRunLoop] performSelector: @selector(updateMainWindow:)
												 target: self
											   argument: nil
												  order: 129
												  modes: @[NSDefaultRunLoopMode, NSModalPanelRunLoopMode]];
		}
	}
}

- (void) updateMainWindow: (id) arg {
	// The main window has changed: notify the inspectors
	newMainWindow = NO;
	[inspectors makeObjectsPerformSelector: @selector(inspectWindow:)
								withObject: activeMainWindow];
	[self updateInspectors];
}

// Whether or not we're hidden
- (BOOL)windowShouldClose:(id)aNotification {
	hidden = YES;
	
	[[NSUserDefaults standardUserDefaults] setObject: @NO
											  forKey: IFInspectorShown];
	
	return YES;
}

- (void) showWindow: (id) sender {
	hidden = NO;
	
	[[NSUserDefaults standardUserDefaults] setObject: @YES
											  forKey: IFInspectorShown];
	
	if (shouldBeShown) {
		[super showWindow: sender];
	}
}

@synthesize hidden;

@end
