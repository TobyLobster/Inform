//
//  GlkWindowController.h
//  CocoaGlk
//
//  Created by Andrew Hunter on 18/03/2005.
//  Copyright 2005 Andrew Hunter. All rights reserved.
//

#import <Cocoa/Cocoa.h>

#import <GlkView/GlkView.h>

@interface GlkWindowController : NSWindowController<GlkViewDelegate> {
	/// The view in which the actual action takes place
	IBOutlet GlkView* glkView;
	/// The statusbar text
	IBOutlet NSTextField* status;
}

// The GlkView
- (GlkView*) glkView;

@end
