//
//  IFSkeinLinkView.m
//  Inform
//
//  Created by Toby Nelson in 2015
//

#import <Cocoa/Cocoa.h>
#import <QuartzCore/QuartzCore.h>
#import "IFSkeinLinkView.h"

@implementation IFSkeinLinkView {
}

#pragma mark - Initialisation

- (instancetype) initWithFrame:(NSRect) frameRect {
    self = [super initWithFrame: frameRect];

    if (self) {
        [self setWantsLayer: YES];
        [self setLayerContentsRedrawPolicy: NSViewLayerContentsRedrawOnSetNeedsDisplay];
    }

    return self;
}

-(void) drawRect: (NSRect) dirtyRect {
    NSRect blackRect = [self bounds];

    // Leave a one pixel border blank, because this helps antialiasing
    blackRect = NSInsetRect(blackRect, 0.0f, 1.0f);

    // Only draw the part that needs redrawing
    blackRect = NSIntersectionRect(blackRect, dirtyRect);

    // Draw rectangle
    [[NSColor colorWithDeviceRed:0.25f
                           green:0.25f
                            blue:0.25f
                           alpha:1.0f] set];
    NSRectFill(blackRect);
}

@end
