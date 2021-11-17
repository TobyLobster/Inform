//
//  GlkViewDefinitions.h
//  CocoaGlk
//
//  Created by C.W. Betts on 12/11/18.
//

#ifndef GlkViewDefinitions_h
#define GlkViewDefinitions_h

#include <TargetConditionals.h>
#if TARGET_OS_IPHONE
#define COCOAGLK_IPHONE 1
#endif

#import <Foundation/Foundation.h>
#include <CoreGraphics/CoreGraphics.h>

#ifdef COCOAGLK_IPHONE
#import <UIKit/UIKit.h>
typedef CGRect GlkRect;
typedef CGPoint GlkPoint;
typedef CGSize GlkCocoaSize;
#define GlkColor UIColor
#define GlkFont UIFont
#define GlkSuperImage UIImage
#define GlkSuperView UIView
#define GlkMakePoint CGPointMake
#define GlkRectFill UIRectFill
#define GlkInsetRect CGRectInset
#define GlkMakeRect CGRectMake
#define GlkMakeSize CGSizeMake
#else
#import <AppKit/AppKit.h>
typedef NSRect GlkRect;
typedef NSPoint GlkPoint;
typedef NSSize GlkCocoaSize;
#define GlkColor NSColor
#define GlkFont NSFont
#define GlkSuperImage NSImage
#define GlkSuperView NSView
#define GlkMakePoint NSMakePoint
#define GlkRectFill NSRectFill
#define GlkInsetRect NSInsetRect
#define GlkMakeRect NSMakeRect
#define GlkMakeSize NSMakeSize
#endif

#endif /* GlkViewDefinitions_h */
