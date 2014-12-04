//
//  GlkFilePromptProtocol.h
//  CocoaGlk
//
//  Created by Andrew Hunter on 28/03/2005.
//  Copyright 2005 Andrew Hunter. All rights reserved.
//

#if defined(COCOAGLK_IPHONE)
# include <UIKit/UIKit.h>
#else
# import <Cocoa/Cocoa.h>
#endif

#import "GlkFileRefProtocol.h"

//
// Protocol used to get the results after we've requested a file prompt
//

@protocol GlkFilePrompt

- (void) promptedFileRef: (in byref NSObject<GlkFileRef>*) fref;	// Called when the user chooses a file
- (void) promptCancelled;											// Called when the user gives up on us

@end
