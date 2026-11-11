//
//  IFSkeinPlayAll.h
//  Inform
//
//  Moved out of IFProjectController in November 2026.
//

#import <Foundation/Foundation.h>

@class IFSkeinItem;

NS_ASSUME_NONNULL_BEGIN

///
/// The skein's Play All: the knots it plays to, one after another. Each is the end of a thread, or, where a thread ends
/// in the commands that a "test me" knot ran, that knot, which runs them again. The threads go in order, a knot's first
/// child's first.
///
NS_SWIFT_UI_ACTOR
@interface IFSkeinPlayAll : NSObject

- (instancetype) init NS_UNAVAILABLE;
/// The knots to play to in the skein with this root
- (instancetype) initWithRootItem: (IFSkeinItem*) rootItem NS_DESIGNATED_INITIALIZER;

/// The next knot to play to, or nil once they've all been played to
@property (atomic, readonly, nullable) IFSkeinItem* nextItem;
/// Takes away the next knot, as it's being played to
- (void) removeNextItem;

@end

NS_ASSUME_NONNULL_END
