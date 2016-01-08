//
//  IFToolbarProgressIndicator.m
//  Inform
//
//  Created by Toby Nelson, 2014.
//

#import "IFToolbarProgressIndicator.h"
#import "IFImageCache.h"
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
    float radius = floorf(rect.size.height / 2);
    NSBezierPath *bz = [NSBezierPath bezierPathWithRoundedRect: rect xRadius: radius yRadius: radius];
    
    // Draw progress inside
    [bz setClip];
    rect.size.width = floorf(rect.size.width * ([self doubleValue] / [self maxValue]));
    [[NSColor colorWithDeviceRed:151.0f/255.0f green:151.0f/255.0f blue:151.0f/255.0f alpha:1.0f] set];
    NSRectFill(rect);

    // Draw border
    [bz setLineWidth:1.0];
    [[NSColor colorWithDeviceRed:41.0f/255.0f green:41.0f/255.0f blue:41.0f/255.0f alpha:1.0f] set];
    [bz stroke];
}

@end
