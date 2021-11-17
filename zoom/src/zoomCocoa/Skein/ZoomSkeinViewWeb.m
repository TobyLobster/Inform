//
//  ZoomSkeinViewWeb.m
//  ZoomCocoa
//
//  Created by Andrew Hunter on Sat Jul 03 2004.
//  Copyright (c) 2004 Andrew Hunter. All rights reserved.
//

#import "ZoomSkeinView.h"
#import "ZoomSkeinWeb.h"

@implementation ZoomSkeinView(ZoomSkeinViewWeb)

- (void)setDataSource:(WebDataSource *)dataSource {
	ZoomSkein* newSkein = (id)[dataSource representation];
	
	if ([newSkein isKindOfClass: [ZoomSkein class]]) {
		[self setSkein: newSkein];
	} else {
		NSLog(@"ZoomSkeinView(Web): tried to load data source that does not have a valid skein representation");
	}
}

- (void)dataSourceUpdated:(__unused WebDataSource *)dataSource {
	NSLog(@"ZoomSkeinView: data source update");
}

- (void)layout {
	NSLog(@"ZoomSkeinView: layout in web");

	// FIXME: need to have a separate header file for our private methods
	// FIXME II: may need a 'defer layouts' flag to stop layoutSkein being automagically called
	[self layoutSkein];
}

- (void)setNeedsLayout:(BOOL)flag {
	NSLog(@"ZoomSkeinView: setNeedsLayout: %i", flag);
	
	if (flag) {
		skeinNeedsLayout = YES;
	}
	[super setNeedsLayout:flag];
}

- (void)viewDidMoveToHostWindow {
	NSLog(@"ZoomSkeinView: viewDidMoveToHostWindow");
}

- (void)viewWillMoveToHostWindow:(__unused NSWindow *)hostWindow {
	NSLog(@"ZoomSkeinView: viewWillMoveToHostWindow");
}

@end
