//
//  IFSkeinPlayAll.m
//  Inform
//
//  Moved out of IFProjectController in November 2026.
//

#import "IFSkeinPlayAll.h"
#import "IFSkeinItem.h"

@implementation IFSkeinPlayAll {
    /// Stack of skein items, the next last
    NSMutableArray<IFSkeinItem*>* skeinNodeStack;
}

- (instancetype) initWithRootItem: (IFSkeinItem*) rootItem {
    self = [super init];

    if (self) {
        skeinNodeStack = [[NSMutableArray alloc] init];

        [self fillNode: rootItem];
    }

    return self;
}

- (void) fillNode: (IFSkeinItem*) item {
    if( item.children.count > 0 ) {
        for( IFSkeinItem* child in [item.children reverseObjectEnumerator] ) {
            [self fillNode: child];
        }
        return;
    }

    // Add to the stack
    while( item.isTestSubItem ) {
        item = item.parent;
    }
    [skeinNodeStack addObject: item];
}

- (IFSkeinItem*) nextItem {
    return skeinNodeStack.lastObject;
}

- (void) removeNextItem {
    [skeinNodeStack removeLastObject];
}

@end
