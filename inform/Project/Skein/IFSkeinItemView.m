//
//  IFSkeinItemView.m
//  Inform
//
//  Created by Toby Nelson in 2015
//

#import <Cocoa/Cocoa.h>
#import "IFSkeinItemView.h"
#import "IFSkeinLayoutItem.h"
#import "IFSkeinLayout.h"
#import "IFSkein.h"
#import "IFSkeinItem.h"
#import "IFSkeinView.h"
#import "IFSkeinConstants.h"
#import "IFUtility.h"
#import "IFPreferences.h"
#import "IFDiffer.h"

#define SELECTION_OPTION_1    1

/// Visible size of the menu image
static const CGFloat kMenuVisibleWidth        = 21.0;
/// Visible size of the menu image
static const CGFloat kMenuVisibleHeight       = 21.0;
/// Offset from end of command to draw menu image
static const CGFloat kDrawMenuOffsetX         = -3.0;

static const CGFloat kMenuMouseOverOffsetX    = 6.0;
static const CGFloat kMenuMouseOverOffsetY    = 4.0;

// Images
/// Active item
static NSImage* active;
/// Selected item
static NSImage* selected;
/// Unselected item
static NSImage* unselected;
/// Output differs from blessed transcript
static NSImage* differsBadge;
/// Winning item
static NSImage* starBadge;
/// No blessed transcript to test against
static NSImage* untestedBadge;
/// Active item
static NSImage* activeMenu;
/// Selected item
static NSImage* selectedMenu;
/// Unselected item
static NSImage* unselectedMenu;
/// highlight when mouse over
static NSImage* overMenu;

static NSDictionary* itemTextActiveAttributes           = nil;
static NSDictionary* itemTextSelectedAttributes         = nil;
static NSDictionary* itemTextUnselectedAttributes       = nil;

static NSDictionary* itemTestMeTextActiveAttributes     = nil;
static NSDictionary* itemTestMeTextSelectedAttributes   = nil;
static NSDictionary* itemTestMeTextUnselectedAttributes = nil;

static NSDictionary* itemTextRootActiveAttributes       = nil;
static NSDictionary* itemTextRootSelectedAttributes     = nil;
static NSDictionary* itemTextRootUnselectedAttributes   = nil;

#if defined(DEBUG_EXPORT_HELP_IMAGES)

@interface NSImage (SSWPNGAdditions)
- (BOOL)writePNGToURL:(NSURL*)URL outputSizeInPixels:(NSSize)outputSizePx error:(NSError*__autoreleasing*)error;
@end

@implementation NSImage (SSWPNGAdditions)
- (BOOL)writePNGToURL:(NSURL*)URL outputSizeInPixels:(NSSize)outputSizePx error:(NSError*__autoreleasing*)error
{
    BOOL result = YES;
    NSImage* scalingImage = [NSImage imageWithSize:[self size] flipped:NO drawingHandler:^BOOL(NSRect dstRect) {
        [self drawAtPoint:NSMakePoint(0.0, 0.0) fromRect:dstRect operation:NSCompositingOperationSourceOver fraction:1.0];
        return YES;
    }];
    NSRect proposedRect = NSMakeRect(0.0, 0.0, outputSizePx.width, outputSizePx.height);
    CGColorSpaceRef colorSpace = CGColorSpaceCreateWithName(kCGColorSpaceGenericRGB);
    CGContextRef cgContext = CGBitmapContextCreate(NULL, proposedRect.size.width, proposedRect.size.height, 8, 4*proposedRect.size.width, colorSpace, kCGBitmapByteOrderDefault|kCGImageAlphaPremultipliedLast);
    CGColorSpaceRelease(colorSpace);
    NSGraphicsContext* context = [NSGraphicsContext graphicsContextWithGraphicsPort:cgContext flipped:NO];
    CGContextRelease(cgContext);
    CGImageRef cgImage = [scalingImage CGImageForProposedRect:&proposedRect context:context hints:nil];
    CGImageDestinationRef destination = CGImageDestinationCreateWithURL((__bridge CFURLRef)(URL), kUTTypePNG, 1, NULL);
    CGImageDestinationAddImage(destination, cgImage, nil);
    if(!CGImageDestinationFinalize(destination))
    {
        if( error ) {
            NSDictionary* details = @{NSLocalizedDescriptionKey:@"Error writing PNG image"};
            [details setValue:@"ran out of money" forKey:NSLocalizedDescriptionKey];
            *error = [NSError errorWithDomain:@"SSWPNGAdditionsErrorDomain" code:10 userInfo:details];
        }
        result = NO;
    }
    CFRelease(destination);
    return result;
}
@end

#endif // defined(DEBUG_EXPORT_HELP_IMAGES)


@implementation IFSkeinItemView {
    NSTrackingArea * menuTrackingArea;
    NSTrackingArea * lozengeTrackingArea;
    BOOL             insideMenuArea;
    BOOL             insideLozengeArea;

    // Dragging
    BOOL             dragCanMove;
}

@synthesize layoutItem;
@synthesize drawnStateHash;

// Class initialisation
+ (void) initialize {
    active          = [NSImage imageNamed: @"App/Skein/Skein-active"];
    selected        = [NSImage imageNamed: @"App/Skein/Skein-selected"];
    unselected      = [NSImage imageNamed: @"App/Skein/Skein-unselected"];
    differsBadge    = [NSImage imageNamed: @"App/Skein/SkeinDiffersBadge"];
    starBadge       = [NSImage imageNamed: @"App/Skein/SkeinStarBadge"];
    activeMenu      = [NSImage imageNamed: @"App/Skein/Skein-active-menu"];
    selectedMenu    = [NSImage imageNamed: @"App/Skein/Skein-selected-menu"];
    unselectedMenu  = [NSImage imageNamed: @"App/Skein/Skein-unselected-menu"];
    overMenu        = [NSImage imageNamed: @"App/Skein/Skein-over-menu"];

//    NSColor* selectedColor = [NSColor colorWithCalibratedRed:  43.0/255.0
//                                                       green: 123.0/255.0
//                                                        blue: 156.0/255.0
//                                                       alpha:   1.0];
//    NSColor* activeColor = [NSColor colorWithCalibratedRed: 120.0/255.0
//                                                     green:  74.0/255.0
//                                                      blue: 145.0/255.0
//                                                     alpha:   1.0];
//    NSColor* unselectedColor = [NSColor colorWithCalibratedRed: 93.0/255.0
//                                                         green: 93.0/255.0
//                                                          blue: 93.0/255.0
//                                                         alpha:  1.0];
    NSColor* testMeTextColor = [NSColor colorWithCalibratedRed: 0.8
                                                         green: 0.8
                                                          blue: 0.8
                                                         alpha: 1.0];
    CGFloat size = [IFSkeinView fontSize];
    NSFont* standardFont = [NSFont systemFontOfSize: size];
    NSFont* testMeFont   = [NSFont systemFontOfSize: size];
    NSFont* rootFont     = [NSFont boldSystemFontOfSize: size];

    // Standard attributes
    if (!itemTextSelectedAttributes) {
        itemTextSelectedAttributes = @{ NSFontAttributeName:            standardFont,
//                                        NSBackgroundColorAttributeName: selectedColor,
                                        NSForegroundColorAttributeName: [NSColor whiteColor] };
    }

    if (!itemTextActiveAttributes) {
        itemTextActiveAttributes = @{ NSFontAttributeName:            standardFont,
//                                      NSBackgroundColorAttributeName: activeColor,
                                      NSForegroundColorAttributeName: [NSColor whiteColor] };
    }

    if (!itemTextUnselectedAttributes) {
        itemTextUnselectedAttributes = @{ NSFontAttributeName:            standardFont,
//                                          NSBackgroundColorAttributeName: unselectedColor,
                                          NSForegroundColorAttributeName: [NSColor whiteColor] };
    }

    // "Test me" attributes
    if (!itemTestMeTextSelectedAttributes) {
        itemTestMeTextSelectedAttributes = @{ NSFontAttributeName:        testMeFont,
                                              NSObliquenessAttributeName:     @(0.2),
//                                              NSBackgroundColorAttributeName: selectedColor,
                                              NSForegroundColorAttributeName: testMeTextColor };
    }

    if (!itemTestMeTextActiveAttributes) {
        itemTestMeTextActiveAttributes = @{ NSFontAttributeName:            testMeFont,
                                            NSObliquenessAttributeName:     @(0.2),
//                                            NSBackgroundColorAttributeName: activeColor,
                                            NSForegroundColorAttributeName: testMeTextColor };
    }

    if (!itemTestMeTextUnselectedAttributes) {
        itemTestMeTextUnselectedAttributes = @{ NSFontAttributeName:            testMeFont,
                                                NSObliquenessAttributeName:     @(0.2),
//                                                NSBackgroundColorAttributeName: unselectedColor,
                                                NSForegroundColorAttributeName: testMeTextColor };
    }
    
    
    // Root attributes
    if (!itemTextRootSelectedAttributes) {
        itemTextRootSelectedAttributes = @{ NSFontAttributeName:            rootFont,
//                                            NSBackgroundColorAttributeName: selectedColor,
                                            NSForegroundColorAttributeName: [NSColor whiteColor] };
    }

    if (!itemTextRootActiveAttributes) {
        itemTextRootActiveAttributes = @{ NSFontAttributeName:              rootFont,
//                                          NSBackgroundColorAttributeName:   activeColor,
                                          NSForegroundColorAttributeName:   [NSColor whiteColor] };
    }

    if (!itemTextRootUnselectedAttributes) {
        itemTextRootUnselectedAttributes = @{ NSFontAttributeName:              rootFont,
//                                              NSBackgroundColorAttributeName:   unselectedColor,
                                              NSForegroundColorAttributeName:   [NSColor whiteColor] };
    }
}

#pragma mark - Initialisation

- (instancetype) initWithFrame:(NSRect) frameRect {
    self = [super initWithFrame: frameRect];

    if (self) {
        layoutItem = nil;
        [self setWantsLayer: YES];
        [self setLayerContentsRedrawPolicy: NSViewLayerContentsRedrawOnSetNeedsDisplay];
        drawnStateHash = 0;
        insideMenuArea = NO;
        insideLozengeArea = NO;
        [self registerForDraggedTypes: @[IFSkeinItemPboardType]];
    }

    return self;
}

+(void) adjustAttributesToFontSize {
    CGFloat size = [IFSkeinView fontSize];

    itemTextRootUnselectedAttributes    = [IFUtility adjustAttributesFontSize: itemTextRootUnselectedAttributes   size: size];
    itemTextRootSelectedAttributes      = [IFUtility adjustAttributesFontSize: itemTextRootSelectedAttributes     size: size];
    itemTextRootActiveAttributes        = [IFUtility adjustAttributesFontSize: itemTextRootActiveAttributes       size: size];
    itemTextUnselectedAttributes        = [IFUtility adjustAttributesFontSize: itemTextUnselectedAttributes       size: size];
    itemTextSelectedAttributes          = [IFUtility adjustAttributesFontSize: itemTextSelectedAttributes         size: size];
    itemTextActiveAttributes            = [IFUtility adjustAttributesFontSize: itemTextActiveAttributes           size: size];
    itemTestMeTextUnselectedAttributes  = [IFUtility adjustAttributesFontSize: itemTestMeTextUnselectedAttributes size: size];
    itemTestMeTextSelectedAttributes    = [IFUtility adjustAttributesFontSize: itemTestMeTextSelectedAttributes   size: size];
    itemTestMeTextActiveAttributes      = [IFUtility adjustAttributesFontSize: itemTestMeTextActiveAttributes     size: size];
}


+(NSDictionary*) attributesForLayoutItem: (IFSkeinLayoutItem*) layoutItem
                                    size: (CGFloat) fontSize {
    int index = 0;

    // Unselected, selected, active
    if (layoutItem.recentlyPlayed) {
        index = 2;
    } else if (layoutItem.onSelectedLine) {
        index = 1;
    }

    // Root, Standard, Test Me
    if (layoutItem.item.isTestSubItem) {
        index += 6;
    }
    else if( layoutItem.item.parent != nil) {
        index += 3;
    }

    return @[itemTextRootUnselectedAttributes,  itemTextRootSelectedAttributes, itemTextRootActiveAttributes,
             itemTextUnselectedAttributes,      itemTextSelectedAttributes,     itemTextActiveAttributes,
             itemTestMeTextUnselectedAttributes,itemTestMeTextSelectedAttributes, itemTestMeTextActiveAttributes
             ][index];
}

+(NSImage*) backgroundForLayoutItem:(IFSkeinLayoutItem*) layoutItem {
    if (layoutItem.recentlyPlayed) {
        return active;
    }
    if (layoutItem.onSelectedLine) {
        return selected;
    }
    return unselected;
}

+(NSImage*) backgroundMenuForLayoutItem:(IFSkeinLayoutItem*) layoutItem {

    if (layoutItem.recentlyPlayed) {
        return activeMenu;
    }
    if (layoutItem.onSelectedLine) {
        return selectedMenu;
    }
    return unselectedMenu;
}

+ (NSSize) commandSize:(IFSkeinLayoutItem *) layoutItem {
    if( layoutItem.item.commandSizeDidChange ) {
        NSDictionary* attributes = (layoutItem.item.parent == nil) ? itemTextRootActiveAttributes : itemTextActiveAttributes;
        layoutItem.item.cachedCommandSize = [layoutItem.item.command sizeWithAttributes: attributes];
        layoutItem.item.commandSizeDidChange = NO;
    }
    return layoutItem.item.cachedCommandSize;
}

+ (void) drawLozengeImage: (NSImage*) img
                  atPoint: (NSPoint) pos
                withWidth: (CGFloat) width {
    pos.x = floor(pos.x);
    pos.y = floor(pos.y);
    width = floor(width);

    if (width <= 0.0) width = 1.0;

    // Using image slicing makes this so much easier.
    NSRect drawRect = (NSRect){pos, NSMakeSize(width, kSkeinItemImageHeight)};
    // TODO: Test this!
    drawRect.size.width += kSkeinItemImageCommandLeftBorder + kSkeinItemImageCommandRightBorder;
    [img drawInRect: drawRect
           fromRect: NSZeroRect
          operation: NSCompositingOperationSourceOver
           fraction: 1.0
     respectFlipped: YES
              hints: nil];
}

-(void) drawRect: (NSRect) dirtyRect {
    [[NSColor colorWithCalibratedRed:0.0f green:0.0f blue:0.0f alpha:1.0f] set];

    // Draw the background
    NSImage* background = [[self class] backgroundForLayoutItem: layoutItem];
    NSSize commandSize  = [[self class] commandSize: layoutItem];
    CGFloat commandX = kSkeinItemImageCommandLeftBorder;

    CGFloat imageHeight = background.size.height;
    CGFloat commandY = floor((imageHeight - commandSize.height) / 2.0f + 1.0f);

    // Draw the lozenge
    [[self class] drawLozengeImage: background
                           atPoint: NSMakePoint(0, 0)
                         withWidth: commandSize.width];

    // Draw star if we are the winning item
    if ([[self.skeinView skein] isTheWinningItem: layoutItem.item]) {
        float height = starBadge.size.height/2;
        float width = starBadge.size.width/2;
        [starBadge drawInRect: NSMakeRect(0.0, 0.0 /*floor(self.frame.size.height) - height - 9*/,
                                          width, height)
                     fromRect: NSZeroRect
                    operation: NSCompositingOperationSourceOver
                     fraction: 1.0];
    }

    // Draw the menu if necessary
    if( insideLozengeArea || insideMenuArea ) {
        if( [self.skeinView hasMenu: layoutItem.item] ) {
            NSImage* backgroundMenu = [[self class] backgroundMenuForLayoutItem: layoutItem];
            NSPoint drawPoint = NSMakePoint(floor(commandX + commandSize.width + kDrawMenuOffsetX),
                                            floor(self.frame.size.height) - backgroundMenu.size.height);
            [backgroundMenu drawAtPoint: drawPoint
                               fromRect: NSZeroRect
                              operation: NSCompositingOperationSourceOver
                               fraction: 1.0];
            if( insideMenuArea ) {
                [overMenu   drawAtPoint: drawPoint
                               fromRect: NSZeroRect
                              operation: NSCompositingOperationSourceOver
                               fraction: 1.0];
            }
        }
    }

    // Draw the text
    NSDictionary* sizedTextAttributes = [[self class] attributesForLayoutItem: layoutItem
                                                                         size: [IFSkeinView fontSize]];


    [layoutItem.item.command drawAtPoint: NSMakePoint(floor(commandX), floor(commandY))
                          withAttributes: sizedTextAttributes];

    // Draw the badge if necessary
    if (layoutItem.item.hasBadge) {
        [differsBadge drawAtPoint: NSMakePoint(0.0,
                                               floor(self.frame.size.height) - differsBadge.size.height)
                         fromRect: NSZeroRect
                        operation: NSCompositingOperationSourceOver
                         fraction: 1.0];
    }
    drawnStateHash = [layoutItem drawStateHash];

    /*
    [[NSColor colorWithCalibratedRed:1.0f green:0.0f blue:0.0f alpha:0.5f] set];
    NSRect menuAreaRect = NSMakeRect(commandX + commandSize.width + kDrawMenuOffsetX,
                                     self.frame.size.height - kMenuVisibleHeight,
                                     kMenuVisibleWidth, kMenuVisibleHeight);
    NSRectFillUsingOperation(menuAreaRect, NSCompositingOperationSourceOver);

    [[NSColor colorWithCalibratedRed:0.0f green:1.0f blue:0.0f alpha:0.5f] set];
    NSRect localLozengeRect = [layoutItem localSpaceLozengeRect];
    NSRectFillUsingOperation(localLozengeRect, NSCompositingOperationSourceOver);
    */
}

+(void) drawHelpItem: (NSString*) title
    isRecentlyPlayed: (BOOL) recentlyPlayed
      isSelectedLine: (BOOL) selectedLine
            isBadged: (BOOL) badge
              isRoot: (BOOL) root
          isTestItem: (BOOL) testItem
            showMenu: (BOOL) showMenu
          insideMenu: (BOOL) insideMenu
               width: (int) width
              height: (int) height {
    [[NSColor colorWithCalibratedRed:0.0f green:0.0f blue:0.0f alpha:1.0f] set];

    NSImage* background;
    NSImage* backgroundMenu;
    int textAttributesIndex = 0;

    // Played / Selected / Unselected
    if( recentlyPlayed ) {
        background = active;
        backgroundMenu = activeMenu;
        textAttributesIndex = 2;
    }
    else if( selectedLine ) {
        background = selected;
        backgroundMenu = selectedMenu;
        textAttributesIndex = 1;
    }
    else {
        background = unselected;
        backgroundMenu = unselectedMenu;
    }

    // Root / Standard / Test Me
    if (testItem) {
        textAttributesIndex += 6;
    }
    else if( !root ) {
        textAttributesIndex += 3;
    }

    // Draw the background
    NSDictionary* attributes = root ? itemTextRootActiveAttributes : itemTextActiveAttributes;
    NSSize commandSize       = [title sizeWithAttributes: attributes];
    CGFloat commandX         = kSkeinItemImageCommandLeftBorder;

    CGFloat imageHeight = background.size.height;
    CGFloat commandY = floor((imageHeight - commandSize.height) / 2.0 + 1.0);

    // Draw the lozenge
    [[self class] drawLozengeImage: background
                           atPoint: NSMakePoint(0, 0)
                         withWidth: commandSize.width];

    // Draw the menu if necessary
    if( showMenu ) {
        NSPoint drawPoint = NSMakePoint(floor(commandX + commandSize.width + kDrawMenuOffsetX),
                                        floor(height) - backgroundMenu.size.height);
        [backgroundMenu drawAtPoint: drawPoint
                           fromRect: NSZeroRect
                          operation: NSCompositingOperationSourceOver
                           fraction: 1.0];
        if( insideMenu ) {
            [overMenu   drawAtPoint: drawPoint
                           fromRect: NSZeroRect
                          operation: NSCompositingOperationSourceOver
                           fraction: 1.0];
        }
    }

    // Draw the text
    NSDictionary* sizedTextAttributes =  @[itemTextRootUnselectedAttributes,  itemTextRootSelectedAttributes, itemTextRootActiveAttributes,
                                 itemTextUnselectedAttributes,      itemTextSelectedAttributes,     itemTextActiveAttributes,
                                 itemTestMeTextUnselectedAttributes,itemTestMeTextSelectedAttributes, itemTestMeTextActiveAttributes
                                ][textAttributesIndex];

    [title drawAtPoint: NSMakePoint(floor(commandX), floor(commandY))
        withAttributes: sizedTextAttributes];

    // Draw the badge if necessary
    if (badge) {
        [differsBadge drawAtPoint: NSMakePoint(0.0, floor(height) - differsBadge.size.height)
                         fromRect: NSZeroRect
                        operation: NSCompositingOperationSourceOver
                         fraction: 1.0];
    }
}


-(IFSkeinView*) skeinView {
    if( [self.superview isKindOfClass: [IFSkeinView class]] ) {
        return (IFSkeinView *) self.superview;
    }
    return nil;
}

-(IFSkein*) skein {
    return [self skeinView].skein;
}

- (NSMenu *)menuForEvent:(NSEvent *)event {
    // Context menu is handled by the parent view
    return [self.superview menuForEvent: event];
}

- (NSImage*) imageForDragging {
    NSRect imgRect;

    imgRect.origin = NSMakePoint(0,0);
    imgRect.size = self.frame.size;

    NSImage* img = [[NSImage alloc] initWithSize: imgRect.size];

    // Turn off insideLozengeArea, remembering what it was before
    BOOL oldInsideLozengeArea = insideLozengeArea;
    insideLozengeArea = NO;

    // Draw image
    [img lockFocus];
    [[NSColor clearColor] set];
    NSRectFill(imgRect);
    [self drawRect: imgRect];
    [img unlockFocus];

    // Restore insideLozengeArea back to what it was
    insideLozengeArea = oldInsideLozengeArea;

    return img;
}

#if defined(DEBUG_EXPORT_HELP_IMAGES)
+ (void)  exportHelpTo:(NSString*) pngFile
                  text:(NSString*) text
      isRecentlyPlayed:(BOOL) isRecentlyPlayed
        isSelectedLine:(BOOL) isSelectedLine
              isBadged:(BOOL) isBadged
                isRoot:(BOOL) isRoot
            isTestItem:(BOOL) isTestItem
              showMenu:(BOOL) showMenu
            insideMenu:(BOOL) insideMenu
                 width:(int) width
                height:(int) height {

    NSRect imgRect;

    imgRect.origin = NSMakePoint(0,0);
    imgRect.size = NSMakeSize(width, height);

    NSImage* img = [[NSImage alloc] initWithSize: imgRect.size];

    // Draw image
    [img lockFocus];
    [[NSColor clearColor] set];
    NSRectFill(imgRect);
    [IFSkeinItemView drawHelpItem: text
                 isRecentlyPlayed: isRecentlyPlayed
                   isSelectedLine: isSelectedLine
                         isBadged: isBadged
                           isRoot: isRoot
                       isTestItem: isTestItem
                         showMenu: showMenu
                       insideMenu: insideMenu
                            width: width
                           height: height];
    [img unlockFocus];

    NSError* error;
    [img writePNGToURL: [NSURL URLWithString:pngFile] outputSizeInPixels: imgRect.size error: &error];
}

+ (void) exportHelpImages {
    [self exportHelpTo:@"file:///Users/tobynelson/HelpStoryTitle.png"     text:@"Story Title" isRecentlyPlayed:NO  isSelectedLine:NO  isBadged:NO  isRoot:YES isTestItem:NO showMenu:NO  insideMenu: NO width:100 height:30];
    [self exportHelpTo:@"file:///Users/tobynelson/HelpBadgedBlueKnot.png" text:@"Command"     isRecentlyPlayed:NO  isSelectedLine:YES isBadged:YES isRoot:NO  isTestItem:NO showMenu:NO  insideMenu: NO width:100 height:30];
    [self exportHelpTo:@"file:///Users/tobynelson/HelpBlueKnot.png"       text:@"Command"     isRecentlyPlayed:NO  isSelectedLine:YES isBadged:NO  isRoot:NO  isTestItem:NO showMenu:NO  insideMenu: NO width:100 height:30];
    [self exportHelpTo:@"file:///Users/tobynelson/HelpGreyKnot.png"       text:@"Command"     isRecentlyPlayed:NO  isSelectedLine:NO  isBadged:NO  isRoot:NO  isTestItem:NO showMenu:NO  insideMenu: NO width:100 height:30];
    [self exportHelpTo:@"file:///Users/tobynelson/HelpGreyKnotMenu.png"   text:@"Command"     isRecentlyPlayed:NO  isSelectedLine:NO  isBadged:NO  isRoot:NO  isTestItem:NO showMenu:YES insideMenu: NO width:100 height:30];
    [self exportHelpTo:@"file:///Users/tobynelson/HelpPurpleKnot.png"     text:@"Command"     isRecentlyPlayed:YES isSelectedLine:YES isBadged:NO  isRoot:NO  isTestItem:NO showMenu:NO  insideMenu: NO width:100 height:30];
}
#endif // defined(DEBUG_EXPORT_HELP_IMAGES)

-(BOOL) canClickItem {
    if( !layoutItem.item.isTestSubItem ) return YES;
    if( !layoutItem.onSelectedLine ) return YES;

    return NO;
}

-(void) updateCurrentCursor {
    if( insideMenuArea && [self.skeinView hasMenu: layoutItem.item] ) {
        [[NSCursor pointingHandCursor] set];
    } else if( insideLozengeArea && [self canClickItem] ) {
        [[NSCursor pointingHandCursor] set];
    }
    else {
        [[NSCursor openHandCursor] set];
    }
}

-(void) mouseEnteredMenuArea {
    insideMenuArea = YES;
    [self updateCurrentCursor];
    [self setNeedsDisplay: YES];
}

-(void) mouseExitedMenuArea {
    insideMenuArea = NO;
    [self updateCurrentCursor];
    [self setNeedsDisplay: YES];
}

-(void) mouseEnteredLozengeArea {
    insideLozengeArea = YES;
    [self updateCurrentCursor];
    [self setNeedsDisplay: YES];
}

-(void) mouseExitedLozengeArea {
    insideLozengeArea = NO;
    [self updateCurrentCursor];
    [self setNeedsDisplay: YES];
}

-(NSTrackingArea*) addTrackingAreaWithRect: (NSRect) areaRect
                                  mousePos: (NSPoint) currentMousePos
                            insideSelector: (SEL) insideSelector {
    NSRect visibleRect = [self visibleRect];
    areaRect = NSIntersectionRect(areaRect, visibleRect);

    if( !NSIsEmptyRect( areaRect )) {
        // Do we start inside the rectangle?
        NSTrackingAreaOptions options = 0;
        if (NSPointInRect(currentMousePos, areaRect)) {
            [IFUtility performSelector: insideSelector object: self];

            options = NSTrackingAssumeInside;
        }

        NSTrackingArea* trackingArea = [[NSTrackingArea alloc] initWithRect: areaRect
                                                                    options: NSTrackingMouseEnteredAndExited |
                                                                             /*NSTrackingCursorUpdate |*/
                                                                             NSTrackingActiveInKeyWindow | options
                                                                      owner: self
                                                                   userInfo: nil];
        [self addTrackingArea: trackingArea];
        return trackingArea;
    }
    return nil;
}

-(void) updateTrackingAreas {
    // Remove any existing tracking areas (because they are no longer valid)
    if( menuTrackingArea ) {
        [self removeTrackingArea: menuTrackingArea];
        menuTrackingArea = nil;
    }
    if( lozengeTrackingArea ) {
        [self removeTrackingArea: lozengeTrackingArea];
        lozengeTrackingArea = nil;
    }

    // Exit the areas (because they are no longer valid)
    if( insideMenuArea ) {
        [self mouseExitedMenuArea];
    }
    if( insideLozengeArea ) {
        [self mouseExitedLozengeArea];
    }

    // Get current mouse position
    NSPoint currentMousePos = [[self window] mouseLocationOutsideOfEventStream];
    currentMousePos = [self convertPoint: currentMousePos
                                fromView: nil];

    // Add tracking areas
    {
        // Add the menu tracking area
        CGFloat commandX = kSkeinItemImageCommandLeftBorder;
        NSSize commandSize  = [[self class] commandSize: layoutItem];
        NSRect menuAreaRect = NSMakeRect(commandX + commandSize.width + kDrawMenuOffsetX,
                                         self.frame.size.height - kMenuVisibleHeight,
                                         kMenuVisibleWidth, kMenuVisibleHeight);

        // Adjust from the visible area to get the mouse over area
        menuAreaRect = NSMakeRect(menuAreaRect.origin.x + kMenuMouseOverOffsetX,
                                  menuAreaRect.origin.y + kMenuMouseOverOffsetY,
                                  menuAreaRect.size.width  - kMenuMouseOverOffsetX,
                                  menuAreaRect.size.height - kMenuMouseOverOffsetY);

        menuTrackingArea = [self addTrackingAreaWithRect: menuAreaRect
                                                mousePos: currentMousePos
                                          insideSelector: @selector(mouseEnteredMenuArea)];

        // Add the lozenge area
        NSRect localLozengeRect = [layoutItem localSpaceLozengeRect];

        // Combine the two rectangles into one unified rectangle
        NSRect unifiedRect = NSUnionRect(localLozengeRect, menuAreaRect);

        lozengeTrackingArea = [self addTrackingAreaWithRect: unifiedRect
                                                   mousePos: currentMousePos
                                             insideSelector: @selector(mouseEnteredLozengeArea)];
    }

    [super updateTrackingAreas];
}

- (void) mouseEntered: (NSEvent*) event {
    if( event.trackingArea == menuTrackingArea ) {
        [self mouseEnteredMenuArea];
    }
    else if( event.trackingArea == lozengeTrackingArea ) {
        [self mouseEnteredLozengeArea];
    }
}

- (void) mouseExited: (NSEvent*) event {
    if( event.trackingArea == menuTrackingArea ) {
        [self mouseExitedMenuArea];
    }
    else if( event.trackingArea == lozengeTrackingArea ) {
        [self mouseExitedLozengeArea];
    }
}

- (void) mouseUp: (NSEvent*) event {
    if( ( insideMenuArea ) && [self.skeinView hasMenu: layoutItem.item] ) {
        NSMenu* menu = [self.skeinView menuForItem: layoutItem.item];
        [NSMenu popUpContextMenu: menu withEvent: event forView: self.skeinView];
        return;
    } else if ( insideLozengeArea ) {
        if( !layoutItem.onSelectedLine ) {
            // Select an item not currently on the selected line
            [self.skeinView selectItem: layoutItem.item withAnimation:YES];
        } else
#ifdef SELECTION_OPTION_1
            [self.skeinView selectItem: nil withAnimation:YES];
#else
        if (layoutItem.parent == nil ) {
            // Clear selection if clicking the (selected) root item
            [self.skeinView selectItem: nil withAnimation:YES];
        } else if ([event clickCount] == 1) {
            // Play to point if clicking on a selected item that's not the root
            [self.skeinView playToPoint: layoutItem.item];
        }
#endif
        return;
    }
    [super mouseUp: event];
}

-(BOOL) canDragItem {
    if( layoutItem.item.parent == nil ) {
        return NO;
    }
    if( layoutItem.item.isTestSubItem ) {
        return NO;
    }

    return YES;
}

- (void) mouseDragged: (NSEvent*) event {
    if( ![self canDragItem] ) {
        [super mouseDragged: event];
        return;
    }

    // Drag this item. Default action is a move action, but a copy op is possible if command is held down.

    // Create an image of this item
    if( self.skeinView ) {
        NSImage* itemImage = [self imageForDragging];

        self.skein.draggingItem = layoutItem.item;
        dragCanMove = ![layoutItem.item hasDescendant: self.skein.activeItem];

        NSDraggingItem *dragItem = [[NSDraggingItem alloc] initWithPasteboardWriter: layoutItem.item];
//        [dragItem setImageComponentsProvider:^NSArray<NSDraggingImageComponent *> * _Nonnull{
//            NSDraggingImageComponent *dragImage = [[NSDraggingImageComponent alloc] initWithKey: NSDraggingImageComponentIconKey];
//            dragImage.contents = itemImage;
//
//            return @[dragImage];
//        }];
        [dragItem setDraggingFrame:(NSRect){NSZeroPoint, itemImage.size} contents:itemImage];

        [self beginDraggingSessionWithItems: @[dragItem] event:event source:self];
    }
}

#pragma mark - NSDraggingSource protocol

- (NSDragOperation)draggingSession:(NSDraggingSession *)session sourceOperationMaskForDraggingContext:(NSDraggingContext)context {
    if (context == NSDraggingContextWithinApplication) {
        if (dragCanMove) {
            return NSDragOperationCopy | NSDragOperationMove;
        } else {
            return NSDragOperationCopy;
        }
    } else {
        return NSDragOperationNone;
    }
}

- (void)draggingSession: (NSDraggingSession *) session
           endedAtPoint: (NSPoint) screenPoint
              operation: (NSDragOperation) operation {
    if ((operation & NSDragOperationMove) && self.skein.draggingItem != nil && dragCanMove) {

        // Keep selected item valid...
        if( [self.skein.draggingItem hasDescendant: self.skeinView.selectedItem] ) {
            self.skeinView.selectedItem = self.skein.draggingItem.parent;
        }

        // Finish the move operation by removing the source items
        [self.skein.draggingItem removeFromParent];
        self.skein.draggingSourceNeedsUpdating = YES;
    }

    if( self.skein.draggingSourceNeedsUpdating ) {
        [self.skein postSkeinChangedWithAnimate: YES
                              keepActiveVisible: NO];
        self.skein.draggingSourceNeedsUpdating = NO;
    }
    self.skein.draggingItem = nil;
}

#pragma mark - NSDraggingDestination protocol

- (BOOL) isDragToSameSkein:(id <NSDraggingInfo>)sender {
    bool draggingIntoSameSkein = NO;
    id source = [sender draggingSource];
    if( [source isKindOfClass: [IFSkeinItemView class]] ) {
        IFSkeinView * sourceSkeinView       = (IFSkeinView *) [source superview];
        IFSkeinView * destinationSkeinView  = self.skeinView;
        draggingIntoSameSkein = (sourceSkeinView.skein == destinationSkeinView.skein);
    }
    return draggingIntoSameSkein;
}

-(BOOL) canDropOntoItem:(IFSkeinItem*) destinationItem
                 sender:(id <NSDraggingInfo>) sender {
    if (destinationItem == nil ) {
        return NO;
    }

    // If dropping onto to the source skein, check we are not dropping in a bad place
    if( [self isDragToSameSkein: sender] ) {
        if ( destinationItem == self.skein.draggingItem.parent ) {
            return NO;
        }

        if( [self.skein.draggingItem hasDescendant: destinationItem] ) {
            return NO;
        }
    }

    if( destinationItem.children.count > 0 ) {
        IFSkeinItem* firstChild = destinationItem.children[0];
        if( firstChild.isTestSubItem ) {
            return NO;
        }
    }
    return YES;
}

- (NSDragOperation) updateDragCursor: (id <NSDraggingInfo>) sender {
    NSPoint dragPoint = [self.skeinView convertPoint: [sender draggingLocation]
                                            fromView: nil];

    IFSkeinItem* destinationItem = [self.skeinView itemAtPoint: dragPoint];

    if ( ![self canDropOntoItem: destinationItem
                         sender: sender] ) {
        [[NSCursor operationNotAllowedCursor] set];

        return NSDragOperationNone;
    }

    BOOL isMoveOperation = [sender draggingSourceOperationMask] & NSDragOperationMove;
    BOOL isDraggingToChild = [self.skein.draggingItem hasDescendant: destinationItem];
    if ( isMoveOperation && !isDraggingToChild) {
        [[NSCursor pointingHandCursor] set];

        return NSDragOperationMove;
    }

    [[NSCursor dragCopyCursor] set];
    return NSDragOperationCopy;
}

- (NSDragOperation)draggingEntered:(id <NSDraggingInfo>)sender {
    return [self updateDragCursor: sender];
}

- (NSDragOperation)draggingUpdated:(id <NSDraggingInfo>)sender {
    return [self updateDragCursor: sender];
}

- (void)draggingExited:(id <NSDraggingInfo>)sender {
}

- (BOOL)prepareForDragOperation:(id <NSDraggingInfo>)sender {
    return YES;
}

- (BOOL)performDragOperation:(id <NSDraggingInfo>)sender {
    NSPoint dragPoint = [self.skeinView convertPoint: [sender draggingLocation]
                                            fromView: nil];
    IFSkeinItem* destinationItem = [self.skeinView itemAtPoint: dragPoint];

    if (destinationItem == nil) return NO;

    // Decode the IFSkeinItemPboardType data for this operation
    NSPasteboard* pboard = [sender draggingPasteboard];
    NSData*       data = [pboard dataForType: IFSkeinItemPboardType];
    if (data == nil) return NO;

    IFSkeinItem* newItem = [NSKeyedUnarchiver unarchivedObjectOfClass: [IFSkeinItem class]
                                                             fromData: data
                                                                error: NULL];
    if (newItem == nil) return NO;

    // Add this as a child of the old item
    [destinationItem addChild: newItem];

    // If source and destination of the drag are in different skeins, update the destination skein
    // otherwise we leave the update for the source drag protocol to update the skein, since it may
    // first delete some source items to complete a move operation.
    if( [self isDragToSameSkein: sender] ) {
        self.skein.draggingSourceNeedsUpdating = YES;
    }
    else {
        [self.skein postSkeinChangedWithAnimate: YES
                              keepActiveVisible: NO];
    }

    return YES;
}

- (void)concludeDragOperation:(id <NSDraggingInfo>)sender {
    // Nothing to do
}

@end
