//
//  ZoomCollapsingSplitView.h
//
//  Created by Collin Pieper on Tue May 13 2003.
//  Copyright (c) 2003 Collin Pieper. All rights reserved.
//


#import <AppKit/AppKit.h>

@interface NSSplitView (ZoomCollapsingSplitViewDelegateMethods) 

- (void)splitViewDoubleClickedOnDivider:(NSSplitView *)splitView;
- (void)splitViewMouseDownProcessed:(NSSplitView *)splitView;

@end

@interface ZoomCollapsingSplitView : NSSplitView 

- (CGFloat)getSplitPercentage;
- (void)resizeSubviewsToPercentage:(CGFloat)splitPercentage;

@end
