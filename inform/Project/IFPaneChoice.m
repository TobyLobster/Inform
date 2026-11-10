//
//  IFPaneChoice.m
//  Inform
//
//  Moved out of IFProjectController in November 2026.
//

#import "IFPaneChoice.h"

@implementation IFPaneChoice

+ (NSInteger) sourcePaneForViews: (NSArray<NSNumber*>*) views {
    // Returns the current pane containing the source code (or an appropriate pane that source code can be displayed in)
    int paneToUse = 0;
    int x;

    for (x=0; x<views.count; x++) {
        IFProjectPaneType thisView = [views[x] intValue];

        if (thisView == IFSourcePane) {
            // Always use the first source pane found
            paneToUse = x;
            break;
        }

        if (thisView == IFErrorPane) {
            // Avoid a pane showing error messages
            paneToUse = x+1;
        }
    }

    if (paneToUse >= views.count) {
        // All error views?
        paneToUse = 0;
    }

    return paneToUse;
}

+ (NSInteger) auxPaneForViews: (NSArray<NSNumber*>*) views {
    // Returns the auxiliary pane: the one to use for displaying documentation, etc
    int paneToUse = -1;
    int x;

    for (x=0; x<views.count; x++) {
        IFProjectPaneType thisView = [views[x] intValue];

        if (thisView == IFDocumentationPane) {
            // Doc pane has priority
            paneToUse = x;
            break;
        }
    }

    // If no documentation pane available, choose something else.
    if (paneToUse == -1) {
        paneToUse = 1;
        for (x=(int)views.count-1; x>=0; x--) {
            IFProjectPaneType thisView = [views[x] intValue];

            if (thisView != IFSourcePane &&
                thisView != IFGamePane) {
                // Anything but the source or game...
                paneToUse = x;
                break;
            }

            if (thisView == IFSourcePane) {
                // Avoid a pane showing the source code
                paneToUse = x+1;
            }
        }
    }

    if (paneToUse >= views.count) {
        // All source views?
        paneToUse = 0;
    }

    return paneToUse;
}

+ (NSInteger) indexPaneForViews: (NSArray<NSNumber*>*) views {
    // Returns the current pane containing the index
    int x;

    for (x=0; x<views.count; x++) {
        IFProjectPaneType thisView = [views[x] intValue];

        if (thisView == IFIndexPane) {
            // This is the index pane
            return x;
        }
    }

    // No index pane showing: use the aux pane
    return [self auxPaneForViews: views];
}

+ (NSInteger) paneOppositePane: (NSInteger) index
                         count: (NSInteger) count {
    // Get it's 'opposite'
    NSInteger opposite = index-1;
    if (opposite < 0) opposite = count-1;

    return opposite;
}

@end
