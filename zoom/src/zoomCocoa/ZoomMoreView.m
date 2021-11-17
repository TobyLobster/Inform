//
//  ZoomMoreView.m
//  ZoomCocoa
//
//  Created by Andrew Hunter on Thu Oct 09 2003.
//  Copyright (c) 2003 Andrew Hunter. All rights reserved.
//

#import "ZoomMoreView.h"


@implementation ZoomMoreView

- (id)initWithFrame:(NSRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        // Initialization code here.
    }
    return self;
}

- (void) setSize {
    NSString* more = @"[More…]";
    NSDictionary* moreAttributes = @{
        NSFontAttributeName: [NSFont systemFontOfSize: 12],
        NSBackgroundColorAttributeName: [NSColor controlAccentColor],
        NSForegroundColorAttributeName: [NSColor labelColor]};
    NSSize moreSize = [more sizeWithAttributes: moreAttributes];
    NSRect frame = [self frame];
    moreSize.width += 2;
    moreSize.width = ceil(moreSize.width);
    moreSize.height += 2;
    frame.size = moreSize;
    
    [self setFrame: frame];
}

- (void)drawRect:(__unused NSRect)rect {
    NSString* more = NSLocalizedString(@"[More...]", @"[More…]");
    NSDictionary* moreAttributes =@{
        NSFontAttributeName: [NSFont systemFontOfSize: 12],
        NSBackgroundColorAttributeName: [NSColor controlAccentColor],
        NSForegroundColorAttributeName: [NSColor labelColor]};

    NSSize moreSize = [more sizeWithAttributes: moreAttributes];
    NSRect frame = [self bounds];

    NSPoint drawPoint = NSMakePoint(NSMaxX(frame) - moreSize.width - 1,
                                    NSMinY(frame) + 1);

    // Draw the text (and the background!)
    [more drawAtPoint: drawPoint
       withAttributes: moreAttributes];

    // Draw the border
    [NSBezierPath setDefaultLineWidth: 0.5];
    
    [[NSColor selectedTextBackgroundColor] set];

    [NSBezierPath strokeLineFromPoint: NSMakePoint(NSMinX(frame)+.5, NSMinY(frame)+.5)
                              toPoint: NSMakePoint(NSMinX(frame)+.5, NSMaxY(frame)-.5)];
    [NSBezierPath strokeLineFromPoint: NSMakePoint(NSMinX(frame)+.5, NSMaxY(frame)-.5)
                              toPoint: NSMakePoint(NSMaxX(frame)-.5, NSMaxY(frame)-.5)];;
    
    [[NSColor selectedContentBackgroundColor] set];

    [NSBezierPath strokeLineFromPoint: NSMakePoint(NSMinX(frame)+.5, NSMinY(frame)+.5)
                              toPoint: NSMakePoint(NSMaxX(frame)-.5, NSMinY(frame)+.5)];
    [NSBezierPath strokeLineFromPoint: NSMakePoint(NSMaxX(frame)-.5, NSMinY(frame)+.5)
                              toPoint: NSMakePoint(NSMaxX(frame)-.5, NSMaxY(frame)-.5)];;
}

@end
