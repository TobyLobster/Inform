//
//  IFRecentFileCell.m
//  Inform
//
//  Created by Toby Nelson 2014
//

#import "IFRecentFileCell.h"

@implementation IFRecentFileCell

static const int imageSize = 16;
static const int borderWidth = 5;
static const int borderHeight = 0;
static const int recentFilesTabWidth = 130;

@synthesize image;

-(void) dealloc {
    [super dealloc];
}

- (id)copyWithZone:(NSZone *)zone
{
    IFRecentFileCell *cell = [super copyWithZone:zone];
    if (cell == nil) {
        return nil;
    }
    
    // Clear the image and subtitle as they won't be retained
    cell->image = nil;
    [cell setImage:[self image]];
    
    return cell;
}

- (NSAttributedString *)attributedStringValue
{
    NSAttributedString *astr = nil;

    NSString* title = [self stringValue];
    if (title) {
        NSColor *textColour = [self isHighlighted] ? [NSColor whiteColor] : [NSColor blackColor];
        NSMutableParagraphStyle *paragraph = [[NSMutableParagraphStyle alloc] init];
        NSTextTab* tab = [[NSTextTab alloc] initWithType: NSLeftTabStopType
                                                location: recentFilesTabWidth];
        paragraph.tabStops = [NSArray arrayWithObject: tab];
        paragraph.lineBreakMode = NSLineBreakByClipping;
        [tab release];

        NSDictionary *attrs = [NSDictionary dictionaryWithObjectsAndKeys:
                                   textColour, NSForegroundColorAttributeName,
                                   paragraph, NSParagraphStyleAttributeName,
                                   nil];
        [paragraph autorelease];

        astr = [[[NSAttributedString alloc] initWithString:title attributes:attrs] autorelease];
    }
    
    return astr;
}

- (NSRect)imageRectForBounds:(NSRect)bounds
{
    NSRect imageRect = bounds;
    
    imageRect.origin.x += borderWidth;
    imageRect.origin.y += borderHeight;
    imageRect.size.width = imageSize;
    imageRect.size.height = imageSize;
    
    return imageRect;
}

- (NSRect)titleRectForBounds:(NSRect)bounds
{
    NSRect titleRect = bounds;
    
    titleRect.origin.x += imageSize + (borderWidth * 2);
    titleRect.origin.y += borderHeight;
    
    NSAttributedString *title = [self attributedStringValue];
    if (title) {
        titleRect.size = [title size];
    } else {
        titleRect.size = NSZeroSize;
    }
    
    CGFloat maxX = NSMaxX(bounds);
    CGFloat maxWidth = maxX - NSMinX(titleRect);
    if (maxWidth < 0) {
        maxWidth = 0;
    }
    
    titleRect.size.width = MIN(NSWidth(titleRect), maxWidth);
    
    return titleRect;
}

- (void)drawInteriorWithFrame:(NSRect)cellFrame inView:(NSView *)controlView
{
    NSRect imageRect = [self imageRectForBounds:cellFrame];
    if (image) {
        [image drawInRect:imageRect
                 fromRect:NSZeroRect
                operation:NSCompositeSourceOver
                 fraction:1.0
           respectFlipped:YES
                    hints:nil];
    } else {
        NSBezierPath *path = [NSBezierPath bezierPathWithRect:imageRect];
        [[NSColor grayColor] set];
        [path fill];
    }
    
    NSRect titleRect = [self titleRectForBounds:cellFrame];
    NSAttributedString *aTitle = [self attributedStringValue];
    if ([aTitle length] > 0) {
        [aTitle drawInRect:titleRect];
    }
}

@end
