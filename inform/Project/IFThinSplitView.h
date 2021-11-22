//
//  IFThinSplitView.h
//  Inform
//
//  Created by Toby Nelson in 2015
//

#import <AppKit/AppKit.h>

/// Subclass a split view to make a thinner divider
@interface IFThinSplitView : NSSplitView
@property (atomic, readonly) CGFloat dividerThickness;
@end

