//
//  IFPaneWidths.h
//  Inform
//
//  Moved out of IFProjectController in November 2026.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

///
/// The widths of a project window's panes, side by side with a divider between each two: how wide each is laid out
/// from the proportions the preferences keep, the proportions kept after they're resized, and how far a divider can
/// be dragged
///
@interface IFPaneWidths : NSObject

- (instancetype) init NS_UNAVAILABLE;

/// The widths of the number of panes given, at least 1, filling the width given with the dividers. Each pane but the
/// last gets its proportion of what the dividers leave, rounded down, and the last gets the rest. A pane after the
/// proportions given takes the last one, a proportion that isn't more than 0 counts as 1, and with no proportions,
/// or something other than an array of them, the panes are the same width
+ (NSArray<NSNumber*>*) widthsOfPanes: (NSInteger) count
                              inWidth: (CGFloat) width
                         dividerWidth: (CGFloat) dividerWidth
                          proportions: (nullable NSArray*) proportions;

/// The proportions to keep for panes of the widths given, each its width over the window's
+ (NSArray<NSNumber*>*) proportionsOfWidths: (NSArray<NSNumber*>*) widths
                              inWindowWidth: (CGFloat) windowWidth;

/// Where a divider can be dragged to, for the one proposed, leaving the pane before it at least the narrowest a pane
/// can be
+ (CGFloat) leastDividerPosition: (CGFloat) proposedPosition;
/// Where a divider can be dragged to in a split view of the width given, for the one proposed, leaving the pane after
/// it at least the narrowest a pane can be, unless the split view is too narrow for both
+ (CGFloat) greatestDividerPosition: (CGFloat) proposedPosition
                            inWidth: (CGFloat) width;

@end

NS_ASSUME_NONNULL_END
