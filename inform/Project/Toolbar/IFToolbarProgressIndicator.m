//
//  IFToolbarProgressIndicator.m
//  Inform
//
//  Created by Toby Nelson, 2014.
//

#import "IFToolbarProgressIndicator.h"
#import "IFUtility.h"

@implementation IFToolbarProgressIndicator

- (instancetype)init {
    self = [super init];
    if( self ) {
        // Use core animation, so we get to draw everything (including the current progress) in drawRect.
        [self setWantsLayer:YES];
    }
    return self;
}

- (void)drawRect:(NSRect)dirtyRect {
    NSRect rect = [self bounds];
    CGFloat radius = floor(rect.size.height / 2);
    NSBezierPath *bz = [NSBezierPath bezierPathWithRoundedRect: rect xRadius: radius yRadius: radius];
    
    // Draw progress inside
    [bz setClip];
    rect.size.width = floor(rect.size.width * ([self doubleValue] / [self maxValue]));
    [[NSColor colorNamed:@"StatusIndicator"] set];
    NSRectFill(rect);

    // Draw border
    [bz setLineWidth:1.0];
    [[NSColor colorNamed:@"StatusIndicatorBorder"] set];
    [bz stroke];
}

@end
