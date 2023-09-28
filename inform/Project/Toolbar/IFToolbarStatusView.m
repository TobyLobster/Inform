//
//  IFToolbarStatusView.m
//  Inform
//
//  Created by Toby Nelson, 2014.
//

#import "IFToolbarStatusView.h"
#import "IFToolbarManager.h"
#import "IFUtility.h"
#import "IFProjectController.h"
#import "IFCompilerSettings.h"
#import "IFCompiler.h"
#import "IFProject.h"
#import "Inform-Swift.h"

static CGFloat idealTopBorder                = 6.0f;
static CGFloat minTopBorder                  = 2.0f;
static CGFloat minBottomBorder               = 4.0f;
static CGFloat leftBorder                    = 20.0f;
static CGFloat rightCancelBorder             = 10.0f;
static CGFloat rightProgressBorder           = 20.0f;
static CGFloat cancelWidth                   = 16.0f;
static CGFloat idealGapBetweenTitleAndStory  = 5.0f;
static CGFloat cancelHeight                  = 16.0f;
static CGFloat gapWidthBetweenStoryAndCancel = 5.0f;
static CGFloat gapBetweenWelcomeImageAndText = 10.0f;

@implementation IFToolbarStatusView {
    NSString*                   title;
    CGFloat                     progress;
    CGFloat                     total;
    IFToolbarProgressIndicator* progressIndicator;
    BOOL                        isInProgress;
    BOOL                        isStoryActive;
    BOOL                        canCancel;
    IFProjectController *       controller;

    NSTextField*                titleText;
    NSTextField*                storyText;
    NSButton*                   cancelButton;
    NSImage*                    informImage;

    // 'Welcome' objects
    NSTextField*                welcomeTitle;
    NSTextField*                welcomeBuild;
    NSImageView*                welcomeImageView;

    __weak IFToolbarManager*    delegate;
}

#pragma mark - Initialisation

- (instancetype) initWithFrame: (NSRect)frameRect {
	self = [super initWithFrame: frameRect];
	
	if (self) {
        delegate = nil;
        _isExtensionProject = NO;

        NSString* buildString  = [NSString stringWithFormat: [IFUtility localizedString: @"Build %@"], [IFUtility localizedString: @"Build Version"]];
        NSString* informString = [IFUtility localizedString: @"Inform"];
        informImage = [NSImage imageNamed: @"Blob-Logo"];

        NSDictionary* dict = @{NSFontAttributeName: [[NSTextField alloc] init].font};
        NSSize informSize = [informString sizeWithAttributes: dict];
        NSSize informBuildSize = [buildString sizeWithAttributes: dict];

        // Create Welcome title text field
        welcomeTitle = [[NSTextField alloc] initWithFrame: NSMakeRect(0.0f, 0.0f, informSize.width, informSize.height)];
        welcomeTitle.stringValue = @"";
        [welcomeTitle setBezeled: NO];
        [welcomeTitle setDrawsBackground: NO];
        [welcomeTitle setEditable: NO];
        [welcomeTitle setSelectable: NO];
        welcomeTitle.alignment = NSTextAlignmentRight;
        welcomeTitle.textColor = [NSColor colorNamed:@"StatusWelcomeText"];
        welcomeTitle.autoresizingMask = (NSUInteger) (NSViewWidthSizable | NSViewMinYMargin);
        welcomeTitle.stringValue = informString;
        [self addSubview: welcomeTitle];

        // Create Welcome build text field
        welcomeBuild = [[NSTextField alloc] initWithFrame: NSMakeRect(0.0f, 0.0f, informBuildSize.width, informBuildSize.height)];
        welcomeBuild.stringValue = @"";
        [welcomeBuild setBezeled: NO];
        [welcomeBuild setDrawsBackground: NO];
        [welcomeBuild setEditable: NO];
        [welcomeBuild setSelectable: NO];
        welcomeBuild.alignment = NSTextAlignmentLeft;
        welcomeBuild.textColor = [NSColor colorNamed:@"StatusWelcomeText"];
        welcomeBuild.autoresizingMask = (NSUInteger) (NSViewWidthSizable | NSViewMinYMargin);
        welcomeBuild.stringValue = buildString;
        [self addSubview: welcomeBuild];

        welcomeImageView = [[NSImageView alloc] init];
        welcomeImageView.image = informImage;
        welcomeImageView.imageAlignment = NSImageAlignCenter;
        welcomeImageView.imageFrameStyle = NSImageFrameNone;
        welcomeImageView.imageScaling = NSImageScaleNone;
        [self addSubview: welcomeImageView];

        // Create text field
        titleText = [[NSTextField alloc] init];
        titleText.stringValue = @"";
        [titleText setBezeled: NO];
        [titleText setDrawsBackground: NO];
        [titleText setEditable: NO];
        [titleText setSelectable: NO];
        titleText.alignment = NSTextAlignmentCenter;
        titleText.textColor = [NSColor colorNamed:@"StatusWelcomeText"];
        titleText.autoresizingMask = (NSUInteger) (NSViewWidthSizable | NSViewMinYMargin);
        [self addSubview: titleText];

        // Create story text field
        storyText = [[NSTextField alloc] init];
        storyText.stringValue = @"";
        [storyText setBezeled: NO];
        [storyText setDrawsBackground: NO];
        [storyText setEditable: NO];
        [storyText setSelectable: NO];
        storyText.alignment = NSTextAlignmentCenter;
        storyText.textColor = [NSColor colorNamed:@"StatusWelcomeText"];
        storyText.autoresizingMask = (NSUInteger) (NSViewWidthSizable | NSViewMinYMargin);
        [self addSubview: storyText];
        
        // Create progress bar
        progressIndicator = [[IFToolbarProgressIndicator alloc] init];
        progressIndicator.autoresizingMask = (NSUInteger) (NSViewWidthSizable | NSViewMaxYMargin);
        [progressIndicator setHidden: YES];
        [self addSubview: progressIndicator];

        // Create cancel button
        cancelButton = [[NSButton alloc] init];
        [cancelButton setButtonType: NSButtonTypeMomentaryChange];
        cancelButton.image = [NSImage imageNamed: @"App/Toolbar/cancelOut"];
        cancelButton.alternateImage = [NSImage imageNamed: @"App/Toolbar/cancelIn"];
        [cancelButton setBordered: NO];
        cancelButton.action = @selector(cancelAction);
        cancelButton.target = self;
        [cancelButton setHidden: YES];
        [self addSubview: cancelButton];

        [self setWantsLayer:YES];
        [self adjustSubviews];

        isInProgress = NO;
        isStoryActive = NO;

        // NSViewFrameDidChangeNotification
		[[NSNotificationCenter defaultCenter] addObserver: self
												 selector: @selector(adjustSubviews)
													 name: NSViewFrameDidChangeNotification
												   object: self];
	}

	return self;
}

-(void) updateStoryTextAndCancelBox {
    NSDictionary* attrs = @{NSFontAttributeName: titleText.font};

    // Cancel button rect
    NSRect cancelRect;

    cancelRect.size.width = cancelWidth;
    cancelRect.size.height = cancelHeight;
    
    NSRect titleRect = titleText.frame;
    NSRect storyRect = storyText.frame;
    NSRect progressRect = progressIndicator.frame;

    progressRect.size.width = self.frame.size.width - leftBorder - rightProgressBorder;
    progressRect.size.height = 10.0f;

    if( !isInProgress && isStoryActive && (storyText.stringValue.length> 0) ) {
        // Line up with story text
        storyRect.size.width = self.frame.size.width - (gapWidthBetweenStoryAndCancel + cancelWidth);

        NSSize storySize = [storyText.stringValue sizeWithAttributes: attrs];

        cancelRect.origin.x = self.frame.size.width/2 + (storySize.width/2) - (gapWidthBetweenStoryAndCancel + cancelWidth)/2 + gapWidthBetweenStoryAndCancel;
        cancelRect.origin.y = storyRect.origin.y + storySize.height/2 - (cancelHeight / 2);
    } else {
        // Line up with where progress bar is
        cancelRect.origin.x = self.frame.size.width - cancelRect.size.width - rightCancelBorder;
        cancelRect.origin.y = progressRect.origin.y + progressRect.size.height/2 - cancelHeight/2;

        if( cancelButton.hidden ) {
            progressRect.size.width = self.frame.size.width - leftBorder - rightProgressBorder;
        } else {
            progressRect.size.width = self.frame.size.width - leftBorder - cancelRect.size.width - 2.0f * rightCancelBorder;
        }

        storyRect.size.width = self.frame.size.width;
    }

    // Make sure title doesn't overlap story text
    if (titleRect.origin.y < (storyRect.origin.y + storyRect.size.height)) {
        titleRect.origin.y = storyRect.origin.y + storyRect.size.height;
    }
    
    // Make sure title is within reasonable height bounds, otherwise hide it
    if ( (titleRect.origin.y + titleRect.size.height) > (self.frame.size.height - minTopBorder) ) {
        [titleText setHidden: YES];

        // Centre everything vertically if title doesn't fit
        progressRect.origin.y = self.frame.size.height/2 - progressRect.size.height/2;
        storyRect.origin.y    = self.frame.size.height/2 - storyRect.size.height/2;
        cancelRect.origin.y   = self.frame.size.height/2 - cancelRect.size.height/2;
    } else {
        [titleText setHidden: NO];
    }
    
    titleRect.origin.x = floor(titleRect.origin.x);
    titleRect.origin.y = floor(titleRect.origin.y);
    storyRect.origin.x = floor(storyRect.origin.x);
    storyRect.origin.y = floor(storyRect.origin.y);
    progressRect.origin.x = floor(progressRect.origin.x);
    progressRect.origin.y = floor(progressRect.origin.y);
    cancelRect.origin.x = floor(cancelRect.origin.x);
    cancelRect.origin.y = floor(cancelRect.origin.y);

    titleText.frame = titleRect;
    cancelButton.frame = cancelRect;
    storyText.frame = storyRect;
    progressIndicator.frame = progressRect;
}

-(void) adjustSubviews {
    NSDictionary* attrs = @{NSFontAttributeName: [[NSTextField alloc] init].font};

    CGFloat titleHeight                 = [@"Fg" sizeWithAttributes: attrs].height;
    CGFloat progressWidth               = self.frame.size.width - leftBorder - rightProgressBorder;
    CGFloat progressHeight              = 8.0f;

    if( canCancel ) {
        progressWidth -= (2.0f * leftBorder) - cancelWidth;
    }
    
    // Work out ideal titleText frame
    NSRect titleRect;
    titleRect.size.width  = self.frame.size.width;
    titleRect.size.height = titleHeight;
    titleRect.origin.x    = 0.0f;
    titleRect.origin.y    = self.frame.size.height - titleHeight - idealTopBorder;

    // Work out ideal progress bar frame
    NSRect progressRect;
    progressRect.size.width  = progressWidth;
    progressRect.size.height = progressHeight;
    progressRect.origin.x    = leftBorder;
    progressRect.origin.y    = (titleRect.origin.y / 2.0f) - (progressRect.size.height / 2.0f);

    // Make sure progress bar isn't pushed too low
    if (progressRect.origin.y < minBottomBorder ) {
        progressRect.origin.y = minBottomBorder;
        titleRect.origin.y    = self.frame.size.height - titleHeight - minTopBorder;
    }

    // Make sure title doesn't overlap progress
    if (titleRect.origin.y < (progressRect.origin.y + progressRect.size.height)) {
        titleRect.origin.y = progressRect.origin.y + progressRect.size.height;
    }

    // Story text rect
    NSRect storyRect;
    storyRect.size.width  = self.frame.size.width;
    storyRect.size.height = titleHeight;
    storyRect.origin.x    = 0.0f;
    storyRect.origin.y    = titleRect.origin.y - storyRect.size.height - idealGapBetweenTitleAndStory;
    if( storyRect.origin.y < minBottomBorder ) {
        storyRect.origin.y = minBottomBorder;
    }

    // Make sure title doesn't overlap story text
    if (titleRect.origin.y < (storyRect.origin.y + storyRect.size.height)) {
        titleRect.origin.y = storyRect.origin.y + storyRect.size.height;
    }

    titleText.frame = titleRect;
    storyText.frame = storyRect;
    progressIndicator.frame = progressRect;

    // Update welcome items
    CGFloat frameLeft  = floor((self.frame.size.width / 2)  - (informImage.size.width / 2));
    CGFloat frameTop   = floor((self.frame.size.height / 2) - (informImage.size.height / 2));
    CGFloat frameRight = frameLeft + informImage.size.width;
    welcomeImageView.frame = NSMakeRect(frameLeft, frameTop, informImage.size.width, informImage.size.height);
    frameLeft  -= gapBetweenWelcomeImageAndText;
    frameRight += gapBetweenWelcomeImageAndText;
    welcomeTitle.frame = NSMakeRect(0.0f,
                                       floor((self.frame.size.height / 2) - (welcomeTitle.frame.size.height/2)),
                                       frameLeft,
                                       welcomeTitle.frame.size.height);
    welcomeBuild.frame = NSMakeRect(frameRight,
                                       floor((self.frame.size.height / 2) - (welcomeBuild.frame.size.height/2)),
                                       self.frame.size.width - frameRight,
                                       welcomeBuild.frame.size.height);

    // Set story text and cancel button positions. Hide title if needed
    [self updateStoryTextAndCancelBox];
}


- (void)drawRect: (NSRect) dirtyRect {
    NSShadow *kDropShadow = [[NSShadow alloc] init];
    kDropShadow.shadowColor = [NSColor colorNamed:@"StatusShadow"];
    kDropShadow.shadowOffset = NSMakeSize(0, -1.0);
    kDropShadow.shadowBlurRadius = 1.0f;

    NSColor *kBorderColor = [NSColor colorNamed:@"StatusBorder"];
    NSGradient *kBackgroundGradient = [[NSGradient alloc] initWithColorsAndLocations:
                           [NSColor colorNamed:@"BackgroundGradientStart"], 0.0,
                           [NSColor colorNamed:@"BackgroundGradientEnd"], 1.0, nil];
    NSGradient * kExtensionBackgroundGradient = [[NSGradient alloc] initWithColorsAndLocations:
                                    [NSColor colorNamed:@"BackgroundGradientStart"], 0.0,
                                    [NSColor colorNamed:@"BackgroundGradientEnd"], 1.0, nil];
    NSRect bounds = self.bounds;
    bounds.size.height -= 1.0;
    bounds.origin.y += 1.0;
    bounds.origin.x -= 0.5f;

    NSBezierPath *path = [NSBezierPath bezierPathWithRoundedRect: bounds
                                                         xRadius: 5.0
                                                         yRadius: 5.0];
    // Draw drop shadow
    {
        [NSGraphicsContext saveGraphicsState];
        [kDropShadow set];
        [path fill];
        [NSGraphicsContext restoreGraphicsState];
    }

    // Draw gradient
    NSGradient* gradient;
    if( _isExtensionProject ) {
        gradient = kExtensionBackgroundGradient;
    }
    else {
        gradient = kBackgroundGradient;
    }
    {
        [gradient drawInBezierPath: path
                             angle: -90.0];
    }

    // Draw stroke
    {
        [kBorderColor setStroke];
        path.lineWidth = 2.0f;
        [path setClip];
        [path stroke];
    }
}

-(void) showMessage: (NSString*) aTitle {
    titleText.stringValue = aTitle;
}

+ (NSString*) currentTime {
    NSDateFormatter *timeFormat = [[NSDateFormatter alloc] init];
    timeFormat.dateFormat = @"HH:mm";
    
    NSDate *now = [[NSDate alloc] init];
    
    NSString *theTime = [timeFormat stringFromDate: now];
    return theTime;
}

-(void) updateVisibility {
    if( isInProgress ) {
        [storyText          setHidden: YES];
        [progressIndicator  setHidden: NO];
        cancelButton.hidden = !canCancel;
    } else if ( isStoryActive ) {
        [storyText          setHidden: NO];
        [progressIndicator  setHidden: YES];
        cancelButton.hidden = !canCancel;
    } else {
        [storyText          setHidden: NO];
        [progressIndicator  setHidden: YES];
        [cancelButton       setHidden: YES];
    }
    [self updateStoryTextAndCancelBox];
    
    // Show welcome?
    BOOL welcomeIsHidden = YES;
    if( storyText.isHidden || ((storyText.stringValue).length == 0) ) {
        if( titleText.isHidden || ((titleText.stringValue).length == 0) ) {
            if( progressIndicator.isHidden ) {
                welcomeIsHidden = NO;
            }
        }
    }

    welcomeTitle.hidden = welcomeIsHidden;
    welcomeBuild.hidden = welcomeIsHidden;
    welcomeImageView.hidden = welcomeIsHidden;
}

-(NSString*) getCompilerVersion
{
    IFToolbarManager * toolbar = delegate;
    IFProjectController* projectController = toolbar.projectController;
    IFProject * project = projectController.document;
    return project.compiler.settings.compilerVersion;
}

-(void) startStory {
    isStoryActive = YES;
    canCancel = YES;

    NSString* version = [self getCompilerVersion];

    if ([IFUtility isLatestMajorMinorCompilerVersion: version])
    {
        storyText.stringValue = [NSString stringWithFormat: [IFUtility localizedString: @"Story started at %@."], [[self class] currentTime]];
    }
    else
    {
        storyText.stringValue = [NSString stringWithFormat: [IFUtility localizedString: @"Using historic version %@. Started at %@."], version, [[self class] currentTime]];
    }
    
    [self updateVisibility];
}

-(void) stopStory {
    isStoryActive = NO;

    NSString* version = [self getCompilerVersion];

    if ([IFUtility isLatestMajorMinorCompilerVersion: version])
    {
        storyText.stringValue = [IFUtility localizedString:@"Story stopped."];
    }
    else
    {
        storyText.stringValue = [NSString stringWithFormat: [IFUtility localizedString: @"Using historic version %@. Story stopped."], version];
    }

    [self updateVisibility];
}

-(void) canCancel: (BOOL) aCanCancel {
    canCancel = aCanCancel;
}

-(void) startProgress {
    isInProgress = YES;

    [progressIndicator  startAnimation: self];
    [progressIndicator  setUsesThreadedAnimation: YES];
    [self updateVisibility];
}

-(void) setProgressMaxValue: (CGFloat) maxValue {
    progressIndicator.maxValue = maxValue;
}

-(void) updateProgress: (CGFloat) progressValue {
    progressIndicator.doubleValue = progressValue;
}

-(void) setProgressIndeterminate: (BOOL) indeterminate {
    progressIndicator.indeterminate = indeterminate;
}

-(void) stopProgress {
    // Disable progress bars
    progressIndicator.doubleValue = 0.0f;
    [progressIndicator setIndeterminate: YES];
    [progressIndicator setUsesThreadedAnimation: NO];
    [progressIndicator stopAnimation: self];

    isInProgress = NO;
    [self updateVisibility];
}

@synthesize delegate;

-(void) cancelAction {
    [cancelButton setHidden: YES];
    [delegate cancelProgress];
}

-(void) updateToolbar {
    [self adjustSubviews];
}

@end
