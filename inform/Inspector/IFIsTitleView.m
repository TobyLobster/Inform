//
//  IFIsTitleView.m
//  Inform
//
//  Created by Andrew Hunter on Mon May 03 2004.
//  Copyright (c) 2004 Andrew Hunter. All rights reserved.
//

#import "IFIsTitleView.h"
#import "IFInspectorView.h"

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

+ (void) initialize {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
	// Background image
	bgImage = [NSImage imageNamed: @"App/Inspector/Inspector-TitleBar"];
	
	// Font to use for titles, etc
	titleFont = [NSFont systemFontOfSize: 11];
	titleHeight = [titleFont ascender] + [titleFont descender];
	titleHeight /= 2;
	titleHeight = ceil(titleHeight);
	
	// Font attributes
    
	NSShadow* shadow = [[NSShadow alloc] init];
		
		[shadow setShadowOffset:NSMakeSize(1, -2)];
		[shadow setShadowBlurRadius:2.5];
		[shadow setShadowColor:[NSColor colorWithDeviceWhite:0.0 alpha:0.75]];

	fontAttributes = @{NSFontAttributeName: titleFont,
		NSForegroundColorAttributeName: [NSColor colorWithDeviceWhite: 0.0 alpha: 0.6],
                       NSShadowAttributeName: shadow};
    });
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
	
	switch ([keyEquiv characterAtIndex: 0]) {
		case '\r':
		case '\n':
			keyEquiv = @"\u21a9";
			break;
			
		case '\b':
		case 127:
			keyEquiv = @"\u232b";
			break;
			
		case 9:
			keyEquiv = @"\u21e5";
			break;
		
		case '\e':
			keyEquiv = @"\u238b";
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
	
	NSRect imgRect;
	imgRect.origin = NSMakePoint(0,0);
	imgRect.size = [bgImage size];
	imgRect.size.height = [IFIsTitleView titleHeight];
    NSRect drawRect;
    drawRect.origin = NSZeroPoint;
    drawRect.size.width = rect.size.width;
    drawRect.size.height = imgRect.size.height;
	
    // TODO: Test me!
    [bgImage drawInRect: drawRect
               fromRect: imgRect
              operation: NSCompositingOperationSourceOver
               fraction: 1.0];
	
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
