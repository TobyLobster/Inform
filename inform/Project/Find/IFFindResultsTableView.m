//
//  IFFindResultsTableView.m
//  Inform
//
//  Created by Toby Nelson in 2014.
//

#import "IFFindResultsTableView.h"

@implementation IFFindResultsTableView {
    IBOutlet id<IFFindClickableTableViewDelegate> extendedDelegate;
}

@synthesize extendedDelegate;

- (void)mouseDown:(NSEvent *)theEvent {
    
    NSPoint globalLocation = theEvent.locationInWindow;
    NSPoint localLocation = [self convertPoint:globalLocation fromView:nil];
    NSInteger clickedRow = [self rowAtPoint:localLocation];
    
    [super mouseDown:theEvent];
    
    if (clickedRow != -1) {
        [self.extendedDelegate tableView:self didClickRow:clickedRow];
    }
    [self.window makeKeyAndOrderFront: self];
}

@end
