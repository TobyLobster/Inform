//
//  GlkClearMargins.h
//  CocoaGlk
//
//  Created by Andrew Hunter on 20/09/2006.
//  Copyright 2006 Andrew Hunter. All rights reserved.
//

#ifndef __GLKVIEW_GLKCLEARMARGINS_H__
#define __GLKVIEW_GLKCLEARMARGINS_H__

#import <GlkView/GlkViewDefinitions.h>
#if defined(COCOAGLK_IPHONE)
# import <UIKit/UIKit.h>
#else
# import <Cocoa/Cocoa.h>
#endif
#import <GlkView/GlkCustomTextSection.h>

@interface GlkClearMargins : GlkCustomTextSection

@end

#endif
