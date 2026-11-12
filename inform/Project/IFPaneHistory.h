//
//  IFPaneHistory.h
//  Inform
//
//  Moved out of IFProjectPane in November 2026.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@class IFHistoryEvent;

///
/// A project pane's history, for its Back and Forward buttons: the events that show again what the pane and its pages
/// showed, in order, and which of them is the current one. What's recorded in one pass of the run loop goes in one
/// event, and while an event is replayed, nothing is recorded.
///
NS_SWIFT_UI_ACTOR
@interface IFPaneHistory : NSObject

- (instancetype) init NS_UNAVAILABLE;
/// A history with no events, which calls the handler given when an event is added, and when it goes backwards or
/// forwards
- (instancetype) initWithChangeHandler: (void (^)(void)) changed NS_DESIGNATED_INITIALIZER;

/// The event to record what's done in this pass of the run loop in: the one added in it already, if there is one, or
/// else a new one with the object given as its target, added after the current event, in place of any after it; nil
/// while an event is replayed
- (nullable IFHistoryEvent*) eventForObject: (id) object;

/// Whether there's an event before the current one
@property (atomic, readonly) BOOL canGoBackwards;
/// Whether there's an event after the current one
@property (atomic, readonly) BOOL canGoForwards;

/// Replays the event before the current one, which becomes the current one, if there is one
- (void) goBackwards;
/// Replays the event after the current one, which becomes the current one, if there is one
- (void) goForwards;

/// Forgets the events, which may hold on to the pane, as the pane closes
- (void) clear;

@end

NS_ASSUME_NONNULL_END
