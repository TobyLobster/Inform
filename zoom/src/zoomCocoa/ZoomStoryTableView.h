//
//  ZoomStoryTableView.h
//  ZoomCocoa
//
//  Created by Collin Pieper on Mon Jun 07 2004.
//  Copyright (c) 2004 Collin Pieper. All rights reserved.
//

#import <Cocoa/Cocoa.h>


@interface ZoomStoryTableView : NSTableView {

	int selectedRow;
	int selectedColumn;
	
	BOOL willEdit;
}

- (NSDragOperation)draggingSourceOperationMaskForLocal:(BOOL)isLocal;

- (void)keyDown:(NSEvent *)theEvent;
- (void)mouseDown:(NSEvent*)theEvent;

- (void)startEditTimer;
- (void)cancelEditTimer;
- (void)editSelectedCell:(id)sender;

@end
