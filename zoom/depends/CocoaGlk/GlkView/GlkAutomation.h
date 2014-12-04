//
//  GlkAutomation.h
//  CocoaGlk
//
//  Created by Andrew Hunter on 29/06/2006.
//  Copyright 2005 Andrew Hunter. All rights reserved.
//

//
// Automation interface
//
// This can be implemented by classes that are interested in sending or receiving commands to a GlkView. As the GlkView
// itself implements this interface, it can also be used to synchronise multiple GlkViews so that they run the same
// commands.
//
// Window numbers specify the position of the window, as counted by a depth first search, starting at the top with
// window #0, and moving to the left first.
//

#import <GlkView/GlkView.h>

@protocol GlkAutomation

// Notifications about events that have occured in the view (when using this automation object for output)

- (void) receivedCharacters: (NSString*) characters					// Text has arrived at the specified text buffer window (from the game)
					 window: (int) windowNumber
				   fromView: (GlkView*) view;
- (void) userTyped: (NSString*) userInput							// The user has typed the specified string into the specified window (which is any window that is waiting for input)
			window: (int) windowNumber
		 lineInput: (BOOL) isLineInput
		  fromView: (GlkView*) view;
- (void) userClickedAtXPos: (int) xpos								// The user has clicked at a specified position in the given window
					  ypos: (int) ypos
					window: (int) windowNumber
				  fromView: (GlkView*) view;
- (void) viewWaiting: (GlkView*) view;								// Called on output views to indicate that glk_select() has been called

// Using this automation object for input

- (void) viewIsWaitingForInput: (GlkView*) view;					// The game has reached a glk_select() loop

@end
