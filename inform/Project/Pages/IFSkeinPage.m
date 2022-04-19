//
//  IFSkeinPage.m
//  Inform
//
//  Created by Andrew Hunter on 25/03/2007.
//  Copyright 2007 Andrew Hunter. All rights reserved.
//

#import "IFSkeinPage.h"
#import "IFSkeinLayout.h"
#import "IFSkein.h"
#import "IFCompilerSettings.h"
#import "IFProject.h"
#import "IFPreferences.h"
#import "IFUtility.h"
#import "IFPageBarCell.h"
#import "IFProjectController.h"
#import "IFProjectPolicy.h"

static const CGFloat webViewHeight = 250.0f;

@implementation IFSkeinPage {
    // The skein view
    IBOutlet NSSplitView*   splitView;
    /// The skein view
    IBOutlet IFSkeinView*   skeinView;
    
    IBOutlet WebView*       webView;

    NSUInteger cachedHash;

    NSString* testingTemplate;
    BOOL      settingDividerProgrammatically;


    // The page bar buttons
    /// The 'Play All Blessed' button
    IFPageBarCell*          playAllCell;
    /// The 'Save Transcript' button
    IFPageBarCell*          saveTranscript;
    /// The 'Show Help/Hide Help' button
    IFPageBarCell*          toggleHelp;
}

#pragma mark - Initialisation

- (instancetype) initWithProjectController: (IFProjectController*) controller {
	self = [super initWithNibName: @"Skein"
				projectController: controller];

	if (self) {
		IFProject* doc = [self.parent document];

        settingDividerProgrammatically = NO;

        // Split view
        [splitView setDelegate: self];

		// Skein view
		[skeinView setSkein: [doc currentSkein]];
		[skeinView setDelegate: self.parent];

        // Web view
        [webView setPolicyDelegate: [self.parent generalPolicy]];
        [webView setTextSizeMultiplier: [[IFPreferences sharedPreferences] appFontSizeMultiplier]];
        [webView setUIDelegate: self.parent];
        [webView setFrameLoadDelegate: self];

        // Load template and html fragments
        [self loadHTMLTemplate];

        cachedHash = 0;
        [self updateHelpHTML];

        [[NSNotificationCenter defaultCenter] addObserver: self
                                                 selector: @selector(didResizeSplitView:)
                                                     name: NSSplitViewDidResizeSubviewsNotification
                                                   object: nil];
        [[NSNotificationCenter defaultCenter] addObserver: self
                                                 selector: @selector(fontSizePreferenceChanged:)
                                                     name: IFPreferencesAppFontSizeDidChangeNotification
                                                   object: [IFPreferences sharedPreferences]];
		[[NSNotificationCenter defaultCenter] addObserver: self
												 selector: @selector(skeinSelectionDidChange:)
													 name: IFSkeinSelectionChangedNotification
												   object: nil];
        [[NSNotificationCenter defaultCenter] addObserver: self
                                                 selector: @selector(skeinDidChange:)
                                                     name: IFSkeinChangedNotification
                                                   object: nil];
        [[NSNotificationCenter defaultCenter] addObserver: self
                                                 selector: @selector(skeinWasReplaced:)
                                                     name: IFSkeinReplacedNotification
                                                   object: nil];


		// Create the cells for the page bar
		playAllCell = [[IFPageBarCell alloc] initTextCell: [IFUtility localizedString: @"Play All Blessed"]];
		[playAllCell setTarget: self];
		[playAllCell setAction: @selector(replayEntireSkein:)];

        saveTranscript = [[IFPageBarCell alloc] initTextCell: [IFUtility localizedString: @"Save Transcript"]];
        [saveTranscript setTarget: self];
        [saveTranscript setAction: @selector(saveTranscript:)];
        [saveTranscript setEnabled: NO];

        toggleHelp = [[IFPageBarCell alloc] initTextCell: @""];
        [toggleHelp setTarget: self];
        [toggleHelp setAction: @selector(toggleHelp:)];
        [toggleHelp setEnabled: YES];

        if( [[doc settings] testingTabHelpShown] ) {
            [self setTestingTabHelpShownTitleControl: YES];
            [self setTestingTabSplitControlShowingHelp: YES];
        }
        else {
            [self setTestingTabHelpShownTitleControl: NO];
            [self setTestingTabSplitControlShowingHelp: NO];
        }
    }

	return self;
}

- (void) dealloc {
	[[NSNotificationCenter defaultCenter] removeObserver: self];
}

- (void) updateHelpHTML {
    NSString* html = testingTemplate;
    NSUInteger hash = [html hash];
    if( cachedHash != hash )
    {
        [self loadHTMLString: html];
        cachedHash = hash;
    }
    NSMutableArray* jsCommands = [[NSMutableArray alloc] init];

    IFProject* doc = [self.parent document];
    int count = [[doc settings] testingTabShownCount];
    BOOL showWelcome = (count < 10);
    BOOL isGreyOrBlueVisible  = [skeinView isAnyItemGrey] || [skeinView isAnyItemBlue];
    BOOL isTickOrCrossVisible = [skeinView isTickVisible] || [skeinView isCrossVisible];

    [jsCommands addObject: showWelcome                              ? @"showBlock('welcome')"   : @"hideBlock('welcome')"];
    [jsCommands addObject: (skeinView.layoutTree.rootItem != nil)   ? @"showBlock('title')"     : @"hideBlock('title')"];
    [jsCommands addObject: [skeinView isAnyItemPurple]              ? @"showBlock('purple')"    : @"hideBlock('purple')"];
    [jsCommands addObject: isGreyOrBlueVisible                      ? @"showBlock('grey')"      : @"hideBlock('grey')"];
    [jsCommands addObject: isGreyOrBlueVisible                      ? @"showBlock('blue')"      : @"hideBlock('blue')"];
    [jsCommands addObject: [skeinView isReportVisible]              ? @"showBlock('report')"    : @"hideBlock('report')"];
    [jsCommands addObject: isTickOrCrossVisible                     ? @"showBlock('tick')"      : @"hideBlock('tick')"];
    [jsCommands addObject: [skeinView isCrossVisible]               ? @"showBlock('cross')"     : @"hideBlock('cross')"];
    [jsCommands addObject: [skeinView isBadgedItemVisible]          ? @"showBlock('badge')"     : @"hideBlock('badge')"];
    [jsCommands addObject: ([skeinView itemsVisible] >= 2)          ? @"showBlock('threads')"   : @"hideBlock('threads')"];
    [jsCommands addObject: ([skeinView itemsVisible] == 1)          ? @"showBlock('knots')"     : @"hideBlock('knots')"];
    [jsCommands addObject: (([skeinView itemsVisible] >= 2) && ([skeinView itemsVisible] <= 10))
                                                                    ? @"showBlock('moreknots')" : @"hideBlock('moreknots')"];
    [jsCommands addObject: ([skeinView itemsVisible] >= 5)          ? @"showBlock('menu')"      : @"hideBlock('menu')"];
    [jsCommands addObject: !showWelcome                             ? @"showBlock('welcomead')"   : @"hideBlock('welcomead')"];

    for (NSString* command in jsCommands ) {
        [webView stringByEvaluatingJavaScriptFromString: command];
    }
}

-(void) didSwitchToPage {
    // Remember how many times we have gone to this page, so we can show appropriate help
    IFProject* doc = [self.parent document];
    int count = [[doc settings] testingTabShownCount];
    count++;
    [[doc settings] setTestingTabShownCount: count];
    [[doc settings] settingsHaveChanged];

    // Make sure the skein is shown properly
    if(skeinView &&
       skeinView.skein) {
        [skeinView.skein postSkeinChangedWithAnimate: NO
                                   keepActiveVisible: NO];
    }

    [self updateHelpHTML];
}

#pragma mark WebViewLoadDelegate

- (void)webView:(WebView *)sender didFinishLoadForFrame:(WebFrame *)frame {
    if (frame == [sender mainFrame]) {
        // After a short pause while the DOM lays itself out properly, make sure the Javascript shows and hides the correct items
        [self performSelector: @selector(updateHelpHTML)
                   withObject: nil
                   afterDelay: 0.0];
    }
}

#pragma mark - Preferences

- (void) fontSizePreferenceChanged: (NSNotification*) not {
    [self.skeinView fontSizePreferenceChanged: not];
}


#pragma mark - Details about this view

- (NSString*) title {
	return [IFUtility localizedString: @"Skein Page Title"];
}

#pragma mark - The skein view

- (IFSkeinView*) skeinView {
	return skeinView;
}

- (void) skeinSelectionDidChange: (NSNotification*) not {
    BOOL enableSaveTranscript = skeinView.selectedItem != nil;
    [saveTranscript setEnabled: enableSaveTranscript];
    [self performSelector: @selector(updateHelpHTML)
               withObject: nil
               afterDelay: 0.0];
}

- (void) skeinDidChange: (NSNotification*) not {
    [self performSelector: @selector(updateHelpHTML)
               withObject: nil
               afterDelay: 0.0];
}

- (void) skeinWasReplaced: (NSNotification*) not {
    IFProject* doc = [self.parent document];
    [skeinView setSkein: [doc currentSkein]];
    [self performSelector: @selector(updateHelpHTML)
               withObject: nil
               afterDelay: 0.0];
}

- (IBAction) replayEntireSkein: (id) sender {
	[[NSApp targetForAction: @selector(replayEntireSkein:)] replayEntireSkein: sender];
}

- (IBAction) saveTranscript: (id) sender {
    [skeinView saveTranscript: sender];
}

#pragma mark - The page bar

- (NSArray*) toolbarCells {
	return @[playAllCell, saveTranscript, toggleHelp];
}

- (void) selectActiveSkeinItem {
    if( skeinView &&
       skeinView.skein &&
       skeinView.skein.activeItem) {
        [skeinView selectItem: skeinView.skein.activeItem];
    }
}

-(BOOL) selectSkeinItemWithNodeId:(unsigned long) skeinItemNodeId {
    if( skeinView ) {
        return [skeinView selectItemWithNodeId: skeinItemNodeId];
    }
    return NO;
}

- (void) setTestingTabHelpShownTitleControl:(BOOL) helpIsShown {
    if( helpIsShown ) {
        [toggleHelp setTitle: [IFUtility localizedString: @"Hide Help"]];
    }
    else {
        [toggleHelp setTitle: [IFUtility localizedString: @"Show Help"]];
    }
    [[toggleHelp controlView] setNeedsDisplay: YES];
}

- (void) setTestingTabHelpShownSetting:(BOOL) helpIsShown {
    IFProject* doc = [self.parent document];

    [[doc settings] setTestingTabHelpShown: helpIsShown];
    [[doc settings] settingsHaveChanged];
}

- (void) didResizeSplitView: (NSNotification*) not {
    if( !settingDividerProgrammatically ) {
        if( [splitView isSubviewCollapsed: webView] ) {
            [self setTestingTabHelpShownTitleControl: NO];
            [self setTestingTabHelpShownSetting: NO];
        }
        else {
            [self setTestingTabHelpShownTitleControl: YES];
            [self setTestingTabHelpShownSetting: YES];
        }
    }
}

- (BOOL) isTestingTabSplitControlShowingHelp {
    return ![splitView isSubviewCollapsed: webView];
}

- (void) setTestingTabSplitControlShowingHelp:(BOOL) showHelp {
    [self setTestingTabHelpShownTitleControl: showHelp];

    settingDividerProgrammatically = YES;
    if( showHelp ) {
        [splitView setPosition: webViewHeight ofDividerAtIndex:0];
    }
    else {
        [splitView setPosition: [splitView bounds].size.height ofDividerAtIndex:0];
    }
    settingDividerProgrammatically = NO;
}

-(void) toggleHelp: (id) sender {
    if( sender == [toggleHelp controlView] ) {
        if( [self isTestingTabSplitControlShowingHelp] ) {
            [self setTestingTabHelpShownTitleControl: NO];
            [self setTestingTabSplitControlShowingHelp: NO];
            [self setTestingTabHelpShownSetting: NO];
        }
        else {
            [self setTestingTabHelpShownTitleControl: YES];
            [self setTestingTabSplitControlShowingHelp: YES];
            [self setTestingTabHelpShownSetting: YES];
        }
    }
}

-(void) loadHTMLString:(NSString*) htmlString
{
    [[webView mainFrame] loadHTMLString: htmlString baseURL: [NSURL URLWithString: @"inform:/"]];
}

-(void) loadHTMLTemplate {
    NSError* error = nil;
    testingTemplate     = [NSString stringWithContentsOfURL: [NSURL URLWithString: @"inform:/TestingTemplate.html"]       encoding: NSUTF8StringEncoding error: &error];
    assert(testingTemplate);
}

#pragma mark - Split view delegate

- (BOOL)    splitView: (NSSplitView *) split
   canCollapseSubview: (NSView *) subview {
    if( [split.subviews[1] isEqual:subview] ) {
        return YES;
    }
    return NO;
}

- (CGFloat)     splitView: (NSSplitView *) split
   constrainSplitPosition: (CGFloat) proposedPosition
              ofSubviewAt: (NSInteger) dividerIndex
{
    CGFloat limit = MAX(webViewHeight, [split bounds].size.height - webViewHeight);
    return limit;
}

- (void)splitView:(NSSplitView *)split resizeSubviewsWithOldSize:(NSSize)oldSize
{
    // If either view is collapsed, do the standard behaviour
    if( [split isSubviewCollapsed: split.subviews[0]] ) {
        [split adjustSubviews];
        return;
    }
    if( [split isSubviewCollapsed: split.subviews[1]] ) {
        [split adjustSubviews];
        return;
    }

    // Both views are visible
    NSRect newFrame = [split frame];
    CGFloat dividerThickness = [split dividerThickness];

    NSRect rect0 = [[[split subviews] objectAtIndex:0] frame];
    NSRect rect1 = [[[split subviews] objectAtIndex:1] frame];
    CGFloat minSize0 = -1;
    CGFloat height0 = 0;

    rect0.origin = NSMakePoint(0, 0);
    rect0.size.width = newFrame.size.width;
    rect1.size.width = newFrame.size.width;
    rect1.size.height = webViewHeight;

    // Adjust view at index 0 to keep view 1 at it's current height
    height0 = newFrame.size.height - rect1.size.height - dividerThickness;
    if (height0 < minSize0) {
        rect0.size.height = minSize0;
        rect1.size.height = newFrame.size.height - rect0.size.height - dividerThickness;
    } else {
        rect0.size.height = height0;
    }

    rect1.origin = NSMakePoint(0, rect0.size.height + dividerThickness);

    [[[split subviews] objectAtIndex:0] setFrame:rect0];
    [[[split subviews] objectAtIndex:1] setFrame:rect1];
}


@end
