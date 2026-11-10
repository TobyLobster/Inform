//
//  IFPaneChoice.h
//  Inform
//
//  Moved out of IFProjectController in November 2026.
//

#import <Foundation/Foundation.h>
#import "IFProjectPaneType.h"

NS_ASSUME_NONNULL_BEGIN

///
/// Which of a project window's panes to show something in, from what each pane is showing: the source; the
/// documentation and the like, beside the source; and the index. And which pane is opposite another.
///
/// The panes are given as what each is showing, IFProjectPaneType numbers, in order, and a pane is chosen by its
/// index among them
///
@interface IFPaneChoice : NSObject

- (instancetype) init NS_UNAVAILABLE;

/// The pane to show the source in: the first showing it; failing that, the pane after the last one showing errors, if
/// there's a pane after it; failing that, the first
+ (NSInteger) sourcePaneForViews: (NSArray<NSNumber*>*) views;
/// The pane to show the documentation and the like in: the first showing the documentation; failing that, the last
/// showing anything but the source or the game; failing that, the pane after the first one showing the source, or
/// with none showing it, the second, if there's such a pane; failing that, the first
+ (NSInteger) auxPaneForViews: (NSArray<NSNumber*>*) views;
/// The pane to show the index in: the first showing it; failing that, the pane to show the documentation in
+ (NSInteger) indexPaneForViews: (NSArray<NSNumber*>*) views;

/// The pane opposite the one given, of the number of panes given: the one before it, or for the first, the last
+ (NSInteger) paneOppositePane: (NSInteger) index
                         count: (NSInteger) count;

@end

NS_ASSUME_NONNULL_END
