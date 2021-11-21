//
//  IFIsTitleView.m
//  Inform
//
//  Created by Andrew Hunter on Mon May 03 2004.
//  Copyright (c) 2004 Andrew Hunter. All rights reserved.
//

#import "IFIsTitleView.h"
#import "IFInspectorView.h"
#import "IFImageCache.h"

#import <objc/objc-runtime.h>


@implementation IFIsTitleView {
    NSAttributedString* title;						// The title to display

    // Key display
    NSString* keyEquiv;								// (UNUSED) key to open this inspector
    NSString* modifiers;							// (UNUSED) modifiers that apply to the key
}

static NSImage* bgImage = nil;
static NSFont* titleFont = nil;
static CGFloat titleHeight = 0;

static NSDictionary* fontAttributes;

// Bug in weak linking? Can't use NSShadowAttributeName... Hmph
//static NSString* IFNSShadowAttributeName = @"NSShadow";

+ (void) initialize {
	// Background image
	bgImage = [NSImage imageNamed: @"App/Inspector/Inspector-TitleBar"];
	
	// Font to use for titles, etc
	titleFont = [NSFont systemFontOfSize: 11];
	titleHeight = [titleFont ascender] + [titleFont descender];
	titleHeight /= 2;
	titleHeight = ceil(titleHeight);
	
	// Font attributes
    /*
	NSShadow* shadow = nil;
	if (objc_lookUpClass("NSShadow") != nil && 0) {
		shadow = [[NSShadow alloc] init];
		
		[shadow setShadowOffset:NSMakeSize(1, -2)];
		[shadow setShadowBlurRadius:2.5];
		[shadow setShadowColor:[NSColor colorWithDeviceWhite:0.0 alpha:0.75]];
		[shadow autorelease];
	}
    */

	fontAttributes = @{NSFontAttributeName: titleFont,
		NSForegroundColorAttributeName: [NSColor colorWithDeviceWhite: 0.0 alpha: 0.6]/*,
		IFNSShadowAttributeName: shadow*/};

}

+ (CGFloat) titleHeight {
	return ceil([titleFont ascender] + [titleFont descender]) + 8;
}

- (instancetype)initWithFrame:(NSRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
		title = nil;
    }
    return self;
}


// = What to display =

- (void) setTitle: (NSString*) newTitle {
	
	title = [[NSAttributedString alloc] initWithString: [newTitle copy]
											attributes: fontAttributes];
	
	[self setNeedsDisplay: YES];
}

- (void) setKeyEquivalent: (NSString*) equiv {
	keyEquiv = nil;
	if (equiv == nil || [equiv length] <= 0) return;
	
	static const unichar returnChars[] = { 0x21a9 };
	static const unichar escapeChars[] = { 0x238b };
	static const unichar backspaceChars[] = { 0x232b };
	static const unichar tabChars[] = { 0x21e5 };
	
	switch ([keyEquiv characterAtIndex: 0]) {
		case '\r':
		case '\n':
			keyEquiv = [NSString stringWithCharacters: returnChars
												length: 1];
			break;
			
		case '\b':
		case 127:
			keyEquiv = [NSString stringWithCharacters: backspaceChars
												length: 1];
			break;
			
		case 9:
			keyEquiv = [NSString stringWithCharacters: tabChars
												length: 1];
			break;
		
		case '\e':
			keyEquiv = [NSString stringWithCharacters: escapeChars
												length: 1];
			break;
			
		default:
			keyEquiv = [equiv copy];
	}
}

// No idea if Apple keeps constants indicating where these characters are *supposed* to be. Google and Xcode
// documentation are silent on this point. (Couldn't find anything in the headers either)
#define CommandCharacter 0x2318
#define OptionCharacter 0x2325
#define ControlCharacter 0x2303
#define ShiftCharacter 0x21e7

- (void) setKeyEquivalentModifiers: (int) modifiers {
	
}

// = Drawing, etc =

- (void)drawRect:(NSRect)rect {
	NSRect bounds = [self bounds];
	
	// Fill with the background colour
	[[NSColor windowBackgroundColor] set];
	//NSRectFill(rect);
	
	CGFloat x = 0;
	NSRect imgRect;
	imgRect.origin = NSMakePoint(0,0);
	imgRect.size = [bgImage size];
    CGFloat w = imgRect.size.width;
	imgRect.size.height = [IFIsTitleView titleHeight];
	
	while (x < rect.origin.x) x += w;
	while (x < NSMaxX(rect)) {
		[bgImage drawAtPoint: NSMakePoint(x, 0)
					fromRect: imgRect
				   operation: NSCompositingOperationSourceOver
					fraction: 1.0];
		x+=w;
	}
	
	// Draw a line underneath
	[[NSColor controlShadowColor] set];
	NSRectFill(NSMakeRect(rect.origin.x, bounds.origin.y+bounds.size.height-1, rect.size.width, 1));
			
	// Draw the title text
	[title drawAtPoint: NSMakePoint(24, 6-titleHeight)];
}

- (BOOL) isFlipped {
	return YES;
}

- (BOOL) isOpaque {
	return NO;
}

- (NSView*) hitTest: (NSPoint) aPoint {
	// Is transparent to mouse clicks
	return nil;
}

@end
