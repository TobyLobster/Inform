//
//  GlkFilePromptProtocol.h
//  CocoaGlk
//
//  Created by Andrew Hunter on 28/03/2005.
//  Copyright 2005 Andrew Hunter. All rights reserved.
//

#ifndef __GLKVIEW_GLKFILEPROPMTPROTOCOL_H__
#define __GLKVIEW_GLKFILEPROPMTPROTOCOL_H__

#import <Foundation/Foundation.h>

#import <GlkView/GlkFileRefProtocol.h>

///
/// Protocol used to get the results after we've requested a file prompt
///
@protocol GlkFilePrompt <NSObject>

/// Called when the user chooses a file
- (void) promptedFileRef: (in byref id<GlkFileRef>) fref;
/// Called when the user gives up on us
- (void) promptCancelled;

@end

#endif
