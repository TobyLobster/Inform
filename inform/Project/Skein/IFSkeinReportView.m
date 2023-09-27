//
//  IFSkeinReportView.m
//  Inform
//
//  Created by Toby Nelson in 2015
//

#import "IFSkeinReportView.h"
#import "IFSkeinReportItemView.h"
#import "IFSkein.h"
#import "IFSkeinItem.h"
#import "IFSkeinConstants.h"
#import "IFSkeinLayout.h"
#import "IFSkeinLayoutItem.h"
#import "IFSkeinBlessButton.h"
#import "IFPreferences.h"
#import "IFUtility.h"
#import "IFDiffer.h"
#import "NSString+IFStringExtensions.h"


@implementation IFSkeinReportView {
    NSMutableArray*     itemViews;
    unsigned long       treeHash;
    NSTrackingArea*     viewTrackingArea;
}

@synthesize reportDetails;
@synthesize rootTree;
@synthesize delegate;
@synthesize forceResizeDueToFontSizeChange;

static NSDictionary* commandAttr = nil;
static NSDictionary* normalAttr = nil;
static NSDictionary* insertAttr = nil;
static NSDictionary* deleteAttr = nil;

+(void) initialize {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
    commandAttr   = @{ NSFontAttributeName: [NSFont boldSystemFontOfSize: kSkeinDefaultReportFontSize] };
    normalAttr    = @{ NSFontAttributeName: [NSFont systemFontOfSize: kSkeinDefaultReportFontSize] };
    insertAttr    = @{ NSFontAttributeName: [NSFont systemFontOfSize: kSkeinDefaultReportFontSize],
                       NSBackgroundColorAttributeName: [NSColor colorWithCalibratedRed:0.0f green:0.75f blue:0.0f alpha:0.45f] };
    deleteAttr    = @{ NSFontAttributeName: [NSFont systemFontOfSize: kSkeinDefaultReportFontSize],
                       NSBackgroundColorAttributeName: [NSColor colorWithCalibratedRed:1.0f green:0.0f blue:0.1f alpha:0.45f],
                       NSStrikethroughStyleAttributeName: @(NSUnderlineStyleSingle),
                       NSStrikethroughColorAttributeName: [NSColor colorWithCalibratedRed:0.0f green:0.0f blue:0.0f alpha:1.0f] };

    [IFSkeinReportView adjustAttributesToFontSize];
    });
}

+(void) adjustAttributesToFontSize {
    CGFloat fontSize = kSkeinDefaultReportFontSize * [IFPreferences sharedPreferences].appFontSizeMultiplier;
    commandAttr = [IFUtility adjustAttributesFontSize: commandAttr size: fontSize];
    normalAttr  = [IFUtility adjustAttributesFontSize: normalAttr  size: fontSize];
    insertAttr  = [IFUtility adjustAttributesFontSize: insertAttr  size: fontSize];
    deleteAttr  = [IFUtility adjustAttributesFontSize: deleteAttr  size: fontSize];
}

-(instancetype) init {
    self = [super init];
	
    if (self) {
		rootTree      = nil;
        reportDetails = [[NSMutableArray alloc] init];
        itemViews     = [[NSMutableArray alloc] init];
        treeHash      = 0;
        forceResizeDueToFontSizeChange = YES;

        [self setWantsLayer: YES];
    }

    return self;
}

-(NSAttributedString*) reportForItem:(IFSkeinItem*) item {
    IFDiffer* diffResult = item.differences;

    NSMutableAttributedString* output = nil;
    if( (diffResult.differences).count == 0 ) {
        output = [[NSMutableAttributedString alloc] initWithString: diffResult.ideal attributes: normalAttr];
    }
    else {
        output = [[NSMutableAttributedString alloc] initWithString: @"" attributes: normalAttr];
        for( IFDiffEdit* edit in diffResult.differences ) {
            switch( edit->formOfEdit ) {
                case DELETE_EDIT:
                {
                    NSString* substring = [diffResult.ideal substringWithRange: edit->fragment];
                    [output appendAttributedString: [[NSAttributedString alloc] initWithString: substring
                                                                                    attributes: deleteAttr] ];
                }
                break;
                case PRESERVE_EDIT:
                {
                    NSString* substring = [diffResult.ideal substringWithRange: edit->fragment];
                    [output appendAttributedString: [[NSAttributedString alloc] initWithString: substring
                                                                                    attributes: normalAttr] ];
                }
                break;
                case PRESERVE_ACTUAL_EDIT:
                {
                    NSString* substring = [diffResult.actual substringWithRange: edit->fragment];
                    [output appendAttributedString: [[NSAttributedString alloc] initWithString: substring
                                                                                    attributes: normalAttr] ];
                }
                break;
                case INSERT_EDIT:
                {
                    NSString* substring = [diffResult.actual substringWithRange: edit->fragment];
                    [output appendAttributedString: [[NSAttributedString alloc] initWithString: substring
                                                                                    attributes: insertAttr] ];
                }
                break;
            }
        }
    }

    NSMutableAttributedString* result = [[NSMutableAttributedString alloc] init];

    if( item.parent != nil ) {
        NSString* prompt = [IFSkeinItem promptForString: item.parent.actual];
        if( ![prompt isEqualToString: @">"] ) {
            NSMutableAttributedString* promptAttr = [[NSMutableAttributedString alloc] initWithString: [NSString stringWithFormat: @"%@", prompt]
                                                                                           attributes: normalAttr];
            [result appendAttributedString: promptAttr];
        }
        NSMutableAttributedString* command  = [[NSMutableAttributedString alloc] initWithString: [NSString stringWithFormat: @"%@\n", item.command]
                                                                                     attributes: commandAttr];
        [result appendAttributedString: command];
    }

    [result appendAttributedString: output];

    return result;
}

-(unsigned long) treeHashFromLeaf:(IFSkeinItem*) item {
    unsigned long result = 0;
    unsigned long count = 0;
    while( item ) {
        result ^= item.reportStateHash + (count << 7);
        item = item.parent;
        count++;
    }
    result ^= count;
    return result;
}

-(void) updateReportDetails {
    // Find leaf node of the selected line
    IFSkeinLayoutItem* leafItem = rootTree.leafSelectedLineItem;

    unsigned long newTreeHash = [self treeHashFromLeaf: leafItem.item];

    if( (forceResizeDueToFontSizeChange) || ((treeHash == 0) || (newTreeHash != treeHash)) ) {
        // Remove all details
        [reportDetails removeAllObjects];

        // Create and position new subviews
        IFSkeinLayoutItem* layoutItem = leafItem;
        CGFloat totalHeight = 0.0f;
        int itemViewsIndex = 0;
        int maxLevel = layoutItem.level;

        // Create any subviews required
        while( itemViews.count <= maxLevel ) {
            IFSkeinReportItemView* reportItemView = [[IFSkeinReportItemView alloc] init];
            [itemViews addObject: reportItemView];
        }

        // Remove subviews that are not needed
        for( int i = maxLevel; i < itemViews.count; i++ ) {
            [itemViews[i] removeFromSuperview];
        }

        while(layoutItem && layoutItem.onSelectedLine) {
            NSAttributedString* report = [self reportForItem: layoutItem.item];

            IFSkeinReportItemView* reportItemView = itemViews[maxLevel-itemViewsIndex];
            reportItemView.uniqueId = layoutItem.item.uniqueId;

            if (reportItemView.superview == nil ) {
                [self addSubview: reportItemView];
            }
            reportItemView.blessButton.target = self;
            reportItemView.blessButton.action = @selector(blessButtonPressed:);
            reportItemView.blessButton.tag = (NSInteger) layoutItem.item.uniqueId;
            reportItemView.blessButton.blessState = layoutItem.item.hasDifferences;

            // Set the top border height for the item
            if( itemViewsIndex == maxLevel ) {
                reportItemView.topBorderHeight = kSkeinReportInsideTopBorder;
            } else {
                reportItemView.topBorderHeight = kDottedSeparatorGapBelowLine;
            }

            // Set the text
            [reportItemView setAttributedString: report
                                    forceChange: forceResizeDueToFontSizeChange];

            // Resize based on size of text. Includes borders and ensures a minimum height for each item.
            CGFloat viewHeight = reportItemView.textHeight;

            // Work out height between items
            CGFloat fullStrideHeight = reportItemView.topBorderHeight + viewHeight;
            if( itemViewsIndex == 0 ) {
                fullStrideHeight += kSkeinReportInsideBottomBorder;
            } else {
                fullStrideHeight += kDottedSeparatorGapAboveLine + kDottedSeparatorLineThickness;
            }

            // Height between items has a minimum value
            fullStrideHeight = MAX(kSkeinMinLevelHeight, fullStrideHeight);

            // Resize the view height based on our calculated stride height
            viewHeight       = fullStrideHeight - kDottedSeparatorLineThickness;
            reportItemView.frame = NSMakeRect(0, totalHeight, reportItemView.frame.size.width, viewHeight);

            // Move to next item
            totalHeight += fullStrideHeight;

            // Adjust height of the last item
            if( itemViewsIndex == maxLevel ) {
                fullStrideHeight -= kSkeinReportInsideTopBorder;
                fullStrideHeight += kDottedSeparatorGapBelowLine;
            }

            // Record the heights
            [reportDetails insertObject:@(fullStrideHeight) atIndex: 0];

            // Move on to next entry
            layoutItem = layoutItem.parent;
            itemViewsIndex++;
        }
        // Don't need a separator after the last item, so take off it's height
        totalHeight = MAX(0.0f, totalHeight);

        // remove any extra views at the end
        while (itemViews.count > itemViewsIndex ) {
            [itemViews.lastObject removeFromSuperview];
            [itemViews removeLastObject];
        }

        [self setFrameSize: NSMakeSize( kSkeinReportWidth, totalHeight )];
        [self setNeedsDisplay: YES];

        treeHash =  newTreeHash;
        forceResizeDueToFontSizeChange = NO;
    }
}

#pragma mark - Drawing

- (void)drawRect: (NSRect) dirtyRect {
    [[NSColor colorWithCalibratedRed: 243.0f / 255.0f
                               green: 216.0f / 255.0f
                                blue: 101.0f / 255.0f
                               alpha: 1.0f] set];
    NSRectFill(dirtyRect);

    [[NSColor colorWithCalibratedRed: 0.0f
                               green: 0.0f
                                blue: 0.0f
                               alpha: 0.25f] set];
    NSBezierPath * path = [NSBezierPath bezierPath];
    path.lineWidth = kDottedSeparatorLineThickness;
    CGFloat dashArray[] = { 8.0f, 6.0f };
    [path setLineDash: dashArray count: 2 phase: 0.0f];

    CGFloat totalHeight = 0;
    for( int index = (int) reportDetails.count - 1; index > 0; index-- ) {
        CGFloat height = [reportDetails[index] doubleValue];
        totalHeight += height;

        CGFloat y = floor(totalHeight) - (kDottedSeparatorLineThickness * 0.5f);
        [path moveToPoint: NSMakePoint(0.0f, y)];
        [path lineToPoint: NSMakePoint(self.frame.size.width, y)];
    }
    [path stroke];
}

-(NSRect) rectForItem:(IFSkeinLayoutItem*) layoutItem {
    for( IFSkeinReportItemView* itemView in itemViews ) {
        if( itemView.uniqueId == layoutItem.item.uniqueId ) {
            return NSMakeRect(itemView.frame.origin.x,
                              self.frame.size.height - itemView.frame.origin.y - itemView.frame.size.height,
                              itemView.frame.size.width,
                              itemView.frame.size.height);
        }
    }
    return NSZeroRect;
}

- (void) cursorUpdate: (NSEvent*) event {
    [[NSCursor arrowCursor] set];
}

-(void) mouseDown:(NSEvent *)theEvent {
    // Do nothing. Stops the parent view from capturing the mouse events
}

-(void) mouseUp:(NSEvent *)theEvent {
    // Do nothing. Stops the parent view from capturing the mouse events
}

-(void) mouseDragged:(NSEvent *)theEvent {
    // Do nothing. Stops the parent view from capturing the mouse events
}


-(void) updateTrackingAreas {

    // Track the current view rect, so we can change it's mouse cursor
    if( viewTrackingArea ) {
        [self removeTrackingArea:viewTrackingArea];
        viewTrackingArea = nil;
    }

    NSPoint currentMousePos = self.window.mouseLocationOutsideOfEventStream;
    currentMousePos = [self convertPoint: currentMousePos fromView: nil];
    NSRect visibleRect = self.visibleRect;

    if( !NSIsEmptyRect( visibleRect )) {
        // Do we start inside the rectangle?
        NSTrackingAreaOptions options = 0;
        if (NSPointInRect(currentMousePos, visibleRect)) {
            options = NSTrackingAssumeInside;
        }

        viewTrackingArea = [[NSTrackingArea alloc] initWithRect: visibleRect
                                                        options: NSTrackingCursorUpdate |
                                                                 NSTrackingActiveInKeyWindow | options
                                                          owner: self
                                                       userInfo: nil];
        [self addTrackingArea: viewTrackingArea];
    }

    [super updateTrackingAreas];
}

-(void) blessButtonPressed:(NSObject*) sender {
    if( [sender isKindOfClass: [IFSkeinBlessButton class]] ) {
        IFSkeinBlessButton * button = (IFSkeinBlessButton*) sender;
        [button toggleBlessState];
        unsigned long uniqueId = (unsigned long) button.tag;

        IFSkeinLayoutItem* layoutItem = rootTree.leafSelectedLineItem;
        while( layoutItem ) {
            if( layoutItem.item.uniqueId == uniqueId ) {
                if( [delegate respondsToSelector: @selector(setItemBlessed:bless:)] ) {
                    [delegate setItemBlessed: layoutItem.item bless: !button.blessState];
                }
                break;
            }
            layoutItem = layoutItem.parent;
        }
    }
}

@end
