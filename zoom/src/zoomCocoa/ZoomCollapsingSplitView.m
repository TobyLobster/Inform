//
//  ZoomCollapsingSplitView.m
//
//  Created by Collin Pieper on Tue May 13 2003.
//  Copyright (c) 2003 Collin Pieper. All rights reserved.
//

#import "ZoomCollapsingSplitView.h"

@implementation ZoomCollapsingSplitView

// mouseDown:
//
//

- (void)mouseDown:(NSEvent *)event 
{
    if( [event clickCount] == 2 ) 
	{
        id delegate = [self delegate];
        if( delegate && [delegate respondsToSelector:@selector(splitViewDoubleClickedOnDivider:)] )
		{
            [delegate splitViewDoubleClickedOnDivider:self];
		}
	}
	
    [super mouseDown:event];
	
	id delegate = [self delegate];
	if( delegate && [delegate respondsToSelector:@selector(splitViewMouseDownProcessed:)] )
	{
		[delegate splitViewMouseDownProcessed:self];
	}

}

// getSplitPercentage
//
//

- (CGFloat)getSplitPercentage
{
    CGFloat splitTotalSize;
    id subview = [[self subviews] objectAtIndex:0];
    
	if ([self isSubviewCollapsed:subview]) 
	{
        return 0.0;
    }    
    
	NSSize subview_size = [subview frame].size;

    if ([self isVertical])
    {
        splitTotalSize = NSWidth([self frame]) - [self dividerThickness];
        return subview_size.width / splitTotalSize;
    }
    else
    {
        splitTotalSize = NSHeight([self frame]) - [self dividerThickness];
        return subview_size.height / splitTotalSize;
    }
}

// resizeSubviewsToPercentage:
//
//

- (void)resizeSubviewsToPercentage:(CGFloat)splitPercentage
{
    CGFloat splitTotalSize;
    id subview_0 = [[self subviews] objectAtIndex:0];
    
	//
	// resize subview 0
	//
	
	NSRect subview_0_frame = [subview_0 frame];

    if ([self isVertical])
    {
        splitTotalSize = NSWidth([self frame]) - [self dividerThickness];
		subview_0_frame.size.width = splitPercentage * splitTotalSize;
    }
    else
    {
        splitTotalSize = NSHeight([self frame]) - [self dividerThickness];
		subview_0_frame.size.height = splitPercentage * splitTotalSize;
    }

	[subview_0 setFrame:subview_0_frame];

	//
	// resize subview 1
	//
	
    id subview_1 = [[self subviews] objectAtIndex:1];
    
	NSRect subview_1_frame = [subview_1 frame];

    if ([self isVertical])
    {
        splitTotalSize = NSWidth([self frame]) - [self dividerThickness];
		subview_1_frame.origin.x = 0.0;
		subview_1_frame.size.width = (1.0 - splitPercentage) * splitTotalSize;
    }
    else
    {
        splitTotalSize = NSHeight([self frame]) - [self dividerThickness];
		subview_1_frame.origin.y = 0.0;
		subview_1_frame.size.height = (1.0 - splitPercentage) * splitTotalSize;
    }

	[subview_1 setFrame:subview_1_frame];

	//
	// recalc split view
	//
	
	[self adjustSubviews];
			
	[self setNeedsDisplay:YES];
}

@end
