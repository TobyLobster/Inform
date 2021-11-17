//
//  ZoomStoryTableView.m
//  ZoomCocoa
//
//  Created by Collin Pieper on Mon Jun 07 2004.
//  Copyright (c) 2004 Collin Pieper. All rights reserved.
//

#import "ZoomStoryTableView.h"
#import "ZoomiFictionController.h"

#import <Carbon/Carbon.h>

@implementation ZoomStoryTableView

-     (NSDragOperation)draggingSession:(NSDraggingSession *)session
 sourceOperationMaskForDraggingContext:(NSDraggingContext)context
{
	switch (context) {
		case NSDraggingContextOutsideApplication:
			return NSDragOperationCopy;
			break;
			
		default:
		case NSDraggingContextWithinApplication:
			return NSDragOperationNone;
			break;
	}
}

// keyDown:
//
//

- (void)keyDown:(NSEvent *)theEvent
{
    NSString *  key_string;
    unichar		key;

    key_string = [theEvent charactersIgnoringModifiers];
    key = [key_string characterAtIndex:0];

    switch( key )
	{
		// when the delete key is pressed tell the controller to delete the selected rows
		
		case 0x7f:
 		case NSDeleteFunctionKey:
        case NSDeleteCharFunctionKey:
            
			if( [self numberOfSelectedRows] > 0 )
			{
                [(ZoomiFictionController*)[self dataSource] delete:self];
            }
        
			break;
        
		default:
            [super keyDown:theEvent];
    }
}

// mouseDown:
//
//

- (void)mouseDown:(NSEvent*)theEvent
{
    [self cancelEditTimer];

	NSPoint local_point = [self convertPoint:[theEvent locationInWindow] fromView:nil];
	selectedColumn = [self columnAtPoint:local_point];
	selectedRow = [self rowAtPoint:local_point];

    if( ([theEvent clickCount] == 1) &&				// if its a single click and
		([self selectedRow] != -1) &&				// if its in a row and
		([self selectedRow] == selectedRow) )		// if the row is already selected
	{
		willEdit = YES;
		[self startEditTimer];						// start the edit timer
    }

    if ([theEvent clickCount] == 2) 
	{
		willEdit = NO;
		[self sendAction:[self doubleAction] to:[self target]];

    }
	else
	{
		[super mouseDown:theEvent];
	}
}


// startEditTimer
//
//

- (void)startEditTimer
{
	[self performSelector:@selector(editSelectedCell:)
		withObject:NULL
		afterDelay:[NSEvent doubleClickInterval]];
}

// cancelEditTimer
//
//

- (void)cancelEditTimer
{
    [NSObject cancelPreviousPerformRequestsWithTarget:self
                                             selector:@selector(editSelectedCell:)
                                               object:nil];
}

// editSelectedCell:
//
//

- (void)editSelectedCell:(id)sender
{
	if( [self selectedRow] == selectedRow && willEdit )
	{
		[self editColumn:selectedColumn row:selectedRow withEvent:NULL select:YES];
	}
}

@end
