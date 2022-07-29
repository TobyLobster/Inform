//
//  IFRecentFileCell.m
//  Inform
//
//  Created by Toby Nelson 2014
//

#import "IFRecentFileCell.h"

static const int imageSize = 16;
static const int borderWidth = 5;
static const int borderHeight = 0;
static const int recentFilesTabWidth = 130;

@implementation IFRecentFileCell

@synthesize image;

- (id)copyWithZone:(NSZone *)zone
{
    IFRecentFileCell *cell = [super copyWithZone:zone];
    if (cell == nil) {
        return nil;
    }
    
    [cell setImage:[self image]];

    return cell;
}

- (NSAttributedString *)attributedStringValue
{
    NSAttributedString *astr = [[NSAttributedString alloc] initWithString: @""];

    NSString* title = [self stringValue];
    if (title) {
        NSColor *textColour = [self isHighlighted] ? [NSColor selectedTextColor] : [NSColor textColor];
        NSMutableParagraphStyle *paragraph = [[NSMutableParagraphStyle alloc] init];
        NSTextTab* tab = [[NSTextTab alloc] initWithType: NSLeftTabStopType
                                                location: recentFilesTabWidth];
        paragraph.tabStops = @[tab];
        paragraph.lineBreakMode = NSLineBreakByClipping;

        NSDictionary *attrs = @{NSForegroundColorAttributeName: textColour,
                                   NSParagraphStyleAttributeName: paragraph};

        astr = [[NSAttributedString alloc] initWithString:title attributes:attrs];
    }
    
    return astr;
}

- (NSRect)imageRectForBounds:(NSRect)bounds
{
    NSRect imageRect = bounds;
    
    imageRect.size.width = imageSize;
    imageRect.size.height = imageSize;
    
    return imageRect;
}

- (NSRect)titleRectForBounds:(NSRect)bounds
{
    NSRect titleRect = bounds;
    
    titleRect.origin.x += imageSize + borderWidth;
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
                operation:NSCompositingOperationSourceOver
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
