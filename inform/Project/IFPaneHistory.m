//
//  IFPaneHistory.m
//  Inform
//
//  Moved out of IFProjectPane in November 2026.
//

#import "IFPaneHistory.h"
#import "IFHistoryEvent.h"

@implementation IFPaneHistory {
    /// The history actions for this object
    NSMutableArray<IFHistoryEvent*>* history;
    /// The last history event created
    IFHistoryEvent* lastEvent;
    /// The position that we are in the history
    NSInteger       historyPos;
    /// If true, then new history items are not created
    BOOL            replaying;

    /// Called when the history has changed
    void (^changed)(void);
}

- (instancetype) initWithChangeHandler: (void (^)(void)) changeHandler {
    self = [super init];

    if (self) {
		history = [[NSMutableArray alloc] init];
		historyPos = -1;
        changed = [changeHandler copy];
    }

    return self;
}

- (BOOL) canGoBackwards {
	return historyPos > 0;
}

- (BOOL) canGoForwards {
	return historyPos < history.count-1;
}

- (void) clearLastEvent {
	lastEvent = nil;
}

- (void) addHistoryEvent: (IFHistoryEvent*) newEvent {
    NSLog(@"HISTORY: Pane History (%@): (addHistoryEvent) %@", self, newEvent);
	if (newEvent == nil) return;

	// If we've gone backwards in the history, then remove the 'forward' history items
	if (historyPos != history.count-1) {
		[history removeObjectsInRange: NSMakeRange(historyPos+1, history.count-(historyPos+1))];
	}

	// Add the new history item
	[history addObject: newEvent];
	historyPos++;

	// Record it as the last event
	if (lastEvent == nil) {
		[[NSRunLoop currentRunLoop] performSelector: @selector(clearLastEvent)
											 target: self
										   argument: nil
											  order: 99
											  modes: @[NSDefaultRunLoopMode]];
	}

	lastEvent = newEvent;

	changed();
}

- (IFHistoryEvent*) eventForObject: (id) object {
	if (replaying) return nil;

	IFHistoryEvent* event;
	if (lastEvent) {
		event = lastEvent;
	} else {
		// Construct a new event based on this obejct
		IFHistoryEvent* newEvent = [[IFHistoryEvent alloc] initWithObject: object];
		[self addHistoryEvent: newEvent];

		event = newEvent;
	}

	return event;
}

- (void) goBackwards {
	if (historyPos <= 0) return;


	replaying = YES;
	[history[historyPos-1] replay];
	historyPos--;
	replaying = NO;

	changed();
}

- (void) goForwards {
	if (historyPos >= history.count-1) return;


	replaying = YES;
	[history[historyPos+1] replay];
	historyPos++;
	replaying = NO;

	changed();
}

- (void) clear {
	history     = nil;
	lastEvent   = nil;
	historyPos  = 0;
}

@end
