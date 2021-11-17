//
//  GlkAutomation.h
//  CocoaGlk
//
//  Created by Andrew Hunter on 29/06/2006.
//  Copyright 2005 Andrew Hunter. All rights reserved.
//

#ifndef __GLKVIEW_GLKAUTOMATION_H__
#define __GLKVIEW_GLKAUTOMATION_H__

#import <Foundation/Foundation.h>
#import <GlkView/GlkView.h>

/// Automation interface
///
/// This can be implemented by classes that are interested in sending or receiving commands to a GlkView. As the GlkView
/// itself implements this interface, it can also be used to synchronise multiple GlkViews so that they run the same
/// commands.
///
/// Window numbers specify the position of the window, as counted by a depth first search, starting at the top with
/// window #0, and moving to the left first.
@protocol GlkAutomation <NSObject>

// Notifications about events that have occured in the view (when using this automation object for output)

/// Text has arrived at the specified text buffer window (from the game)
- (void) receivedCharacters: (NSString*) characters
					 window: (int) windowNumber
				   fromView: (GlkView*) view;
/// The user has typed the specified string into the specified window (which is any window that is waiting for input)
- (void) userTyped: (NSString*) userInput
			window: (int) windowNumber
		 lineInput: (BOOL) isLineInput
		  fromView: (GlkView*) view;
/// The user has clicked at a specified position in the given window
- (void) userClickedAtXPos: (int) xpos
					  ypos: (int) ypos
					window: (int) windowNumber
				  fromView: (GlkView*) view;
/// Called on output views to indicate that glk_select() has been called
- (void) viewWaiting: (GlkView*) view;

// Using this automation object for input

/// The game has reached a \c glk_select() loop
- (void) viewIsWaitingForInput: (GlkView*) view;

@end

#endif
