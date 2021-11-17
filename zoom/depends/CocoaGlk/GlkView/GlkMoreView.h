//
//  GlkMoreView.h
//  CocoaGlk
//
//  Created by Andrew Hunter on 09/10/2006.
//  Copyright 2006 Andrew Hunter. All rights reserved.
//

#ifndef __GLKVIEW_GLKMOREVIEW_H__
#define __GLKVIEW_GLKMOREVIEW_H__

#import <GlkView/GlkViewDefinitions.h>
#if defined(COCOAGLK_IPHONE)
# import <UIKit/UIKit.h>
#else
# import <Cocoa/Cocoa.h>
#endif


@interface GlkMoreView : GlkSuperView {
	GlkSuperImage* moreImage;
}

@end

#endif
