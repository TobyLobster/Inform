//
//  IFSkeinArrowView.m
//  Inform
//
//  Created by Toby Nelson in 2015
//

#import <Cocoa/Cocoa.h>
#import <QuartzCore/QuartzCore.h>
#import "IFSkeinArrowView.h"
#import "IFSkeinConstants.h"

static const CGFloat kSkeinArrowHeadHalfHeight = kSkeinArrowHeadHeight * 0.5f;

@implementation IFSkeinArrowView

@synthesize forceRedraw;

#pragma mark - Initialisation

- (instancetype) initWithFrame:(NSRect) frameRect {
    self = [super initWithFrame: frameRect];

    if (self) {
        [self setWantsLayer: YES];
        self.layerContentsRedrawPolicy = NSViewLayerContentsRedrawOnSetNeedsDisplay;
        forceRedraw = YES;
    }

    return self;
}

-(void) drawArrowWithOffset:(NSPoint) offset color:(NSColor*) color {
    [color set];
    [color setFill];
    NSBezierPath * path = [NSBezierPath bezierPath];
    path.lineWidth = kSkeinArrowLineThickness;

    CGFloat y = floor(self.frame.size.height * 0.5) + 0.5 + offset.y;
    CGFloat h = kSkeinArrowHeadHalfHeight;
    CGFloat w = self.frame.size.width;
    CGFloat m = self.frame.size.width - kSkeinArrowHeadLength + offset.x;

    // Draw arrow head
    path.lineJoinStyle = NSMiterLineJoinStyle;
    path.lineCapStyle = NSButtLineCapStyle;
    [path moveToPoint: NSMakePoint(m, y + h)];
    [path lineToPoint: NSMakePoint(w, y)];
    [path lineToPoint: NSMakePoint(m, y - h)];
    [path lineToPoint: NSMakePoint(m, y + h)];
    [path fill];
    [path stroke];

    // Draw dotted line for stalk
    CGFloat dashArray[] = { 1.0, 3.0 };
    [path setLineDash: dashArray count: 2 phase: 0.0];

    [path moveToPoint: NSMakePoint(0.0, y)];
    [path lineToPoint: NSMakePoint(w, y)];
    [path stroke];
}

-(void) drawRect: (NSRect) dirtyRect {

    // Draw a semi transparent box around the black arrow to stop the black arrow getting
    // visually muddled up with the black links beneath it.
    {
        [[NSColor colorWithDeviceRed: 1.0f
                               green: 1.0f
                                blue: 1.0f
                               alpha: 0.8f] set];

        CGFloat y = floor(self.frame.size.height * 0.5) + 0.5;
        CGFloat h = kSkeinArrowHeadHalfHeight;
        CGFloat m = self.frame.size.width - kSkeinArrowHeadLength - 2.0f;
        NSRectFillUsingOperation(NSMakeRect(0, y - 2.0f, m, 4.0f), NSCompositingOperationSourceOver);
        NSRectFillUsingOperation(NSMakeRect(m,
                                            y - h - kSkeinArrowLineThickness,
                                            kSkeinArrowHeadLength + 2.0f,
                                            2.0*h + 2.0f*kSkeinArrowLineThickness), NSCompositingOperationSourceOver);
    }

    // Draw shadow
    [self drawArrowWithOffset: NSMakePoint(1.0f, -1.0f) color: [NSColor colorWithDeviceRed: 0.0f
                                                                                     green: 0.0f
                                                                                      blue: 0.0f
                                                                                     alpha: 0.15f]];
    // Draw arrow
    [self drawArrowWithOffset: NSMakePoint(0.0f, 0.0f) color: [NSColor colorWithDeviceRed: 0.25f
                                                                                    green: 0.25f
                                                                                     blue: 0.25f
                                                                                    alpha: 1.0f]];

    forceRedraw = NO;
}

@end
