//
//  IFPaneWidths.m
//  Inform
//
//  Moved out of IFProjectController in November 2026.
//

#import "IFPaneWidths.h"

static CGFloat const      minDividerWidth     = 75.0f;

@implementation IFPaneWidths

+ (NSArray<NSNumber*>*) widthsOfPanes: (NSInteger) nviews
                              inWidth: (CGFloat) fullWidth
                         dividerWidth: (CGFloat) dividerWidth
                          proportions: (NSArray*) dividerProportions {
    NSInteger view;
    NSMutableArray<NSNumber*>* widths = [NSMutableArray array];

    // Remaining space for other dividers
    CGFloat remaining        = fullWidth - dividerWidth*(CGFloat)(nviews-1);
    CGFloat totalRemaining   = fullWidth;

    // Work out the widths of the dividers using the preferences
    NSMutableArray<NSNumber*>* realDividerWidths = [NSMutableArray array];

    if (![dividerProportions isKindOfClass: [NSArray class]] || dividerProportions.count <= 0) {
        dividerProportions = @[@1.0f];
    }

    CGFloat totalWidth = 0;
    for (view=0; view<nviews; view++) {
        CGFloat width;

        if (view >= dividerProportions.count) {
            width = [dividerProportions[dividerProportions.count-1] doubleValue];
        } else {
            width = [dividerProportions[view] doubleValue];
        }

        if (width <= 0) width = 1.0;
        [realDividerWidths addObject: @(width)];

        totalWidth += width;
    }

    // Work out the actual widths to use
    CGFloat proportion = remaining / totalWidth;

    for (view=0; view<nviews-1; view++) {
        CGFloat viewWidth = floor(proportion * (realDividerWidths[view]).doubleValue);
        [widths addObject: @(viewWidth)];

        // Update the amount of space remaining
        totalRemaining -= viewWidth + dividerWidth;
    }

    // The final pane has what's left
    [widths addObject: @(totalRemaining)];

    return widths;
}

+ (NSArray<NSNumber*>*) proportionsOfWidths: (NSArray<NSNumber*>*) widths
                              inWindowWidth: (CGFloat) totalWidth {
    NSMutableArray* viewSizes = [NSMutableArray array];

    for (NSNumber* width in widths) {
        [viewSizes addObject: @((CGFloat) (width.doubleValue/totalWidth))];
    }

    return viewSizes;
}

+ (CGFloat) leastDividerPosition: (CGFloat) proposedMinimumPosition {
    if (proposedMinimumPosition < minDividerWidth) {
        proposedMinimumPosition = minDividerWidth;
    }

    return proposedMinimumPosition;
}

+ (CGFloat) greatestDividerPosition: (CGFloat) proposedMaximumPosition
                            inWidth: (CGFloat) width {
    CGFloat limit = MAX(minDividerWidth, width - minDividerWidth);
    if (proposedMaximumPosition > limit) {
        proposedMaximumPosition = limit;
    }

    return proposedMaximumPosition;
}

@end
