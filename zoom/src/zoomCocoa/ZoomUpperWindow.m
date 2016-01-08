//
//  ZoomUpperWindow.m
//  ZoomCocoa
//
//  Created by Andrew Hunter on Thu Oct 09 2003.
//  Copyright (c) 2003 Andrew Hunter. All rights reserved.
//

#import "ZoomUpperWindow.h"


@implementation ZoomUpperWindow {
    ZoomView* theView;

    int startLine, endLine;

    NSMutableArray* lines;
    int xpos, ypos;

    NSColor* backgroundColour;
    ZStyle* inputStyle;
}

- (instancetype) initWithZoomView: (ZoomView*) view {
    self = [super init];
    if (self) {
        theView = view;
        lines = [[NSMutableArray alloc] init];
        backgroundColour = [[NSColor blueColor] retain];
        endLine = startLine = 0;
    }
    return self;
}

- (void) dealloc {
    //[theView release];
    [lines release];
	[inputStyle release];
    [backgroundColour release];
    [super dealloc];
}

// Clears the window
- (oneway void) clearWithStyle: (in bycopy ZStyle*) style {
    [lines release];
    lines = [[NSMutableArray alloc] init];
    xpos = ypos = 0;

    [backgroundColour release];
    backgroundColour = [[style reversed]?[theView foregroundColourForStyle: style]:[theView backgroundColourForStyle: style]
		retain];
}

// Sets the input focus to this window
- (oneway void) setFocus {
	[theView setFocusedView: self];
}

// Sending data to a window
- (oneway void) writeString: (in bycopy NSString*) string
                  withStyle: (in bycopy ZStyle*) style
                  isCommand: (in bycopy BOOL) isCommand {
    [style setFixed: YES];

    int x;
    int len = (int) [string length];
    for (x=0; x<len; x++) {
        if ([string characterAtIndex: x] == '\n') {
            [self writeString: [string substringToIndex: x]
                    withStyle: style
                    isCommand: isCommand];
            ypos++; xpos = 0;
            [self writeString: [string substringFromIndex: x+1]
                    withStyle: style
                    isCommand: isCommand];
            return;
        }
    }

    if (ypos >= [lines count]) {
        int x;
        for (x=(int) [lines count]; x<=ypos; x++) {
            [lines addObject: [[[NSMutableAttributedString alloc] init] autorelease]];
        }
    }

    NSMutableAttributedString* thisLine;
    thisLine = lines[ypos];

    int strlen = (int) [string length];

    // Make sure there is enough space on this line for the text
    if ([thisLine length] <= xpos+strlen) {
        NSFont* fixedFont = [theView fontWithStyle: ZFixedStyle];
        NSDictionary* clearStyle = @{NSFontAttributeName: fixedFont};

        NSAttributedString* spaceString = [[NSAttributedString alloc]
                                    initWithString: blankLine((xpos+strlen)-(int) [thisLine length])
                                        attributes: clearStyle];
        
        [thisLine appendAttributedString: spaceString];

        [spaceString release];
    }

    // Replace the appropriate section of the line
    NSAttributedString* thisString = [theView formatZString: string
                                                  withStyle: style];
    [thisLine replaceCharactersInRange: NSMakeRange(xpos, strlen)
                  withAttributedString: thisString];
    xpos += strlen;

    [theView upperWindowNeedsRedrawing];
}

// Size (-1 to indicate an unsplit window)
- (oneway void) startAtLine: (int) line {
    startLine = line;
}

- (oneway void) endAtLine:   (int) line {
    endLine = line;

    [theView rearrangeUpperWindows];
}

// Cursor positioning
- (oneway void) setCursorPositionX: (in int) xp
                                 Y: (in int) yp {
    xpos = xp; ypos = yp-startLine;
	
	if (xpos < 0) xpos = 0;
	if (ypos < 0) ypos = 0;
}

- (NSPoint) cursorPosition {
    return NSMakePoint(xpos, ypos+startLine);
}


// Line erasure
static NSString* blankLine(int length) {
	return [@"" stringByPaddingToLength: length
                             withString: @" "
                        startingAtIndex: 0];
}

- (oneway void) eraseLineWithStyle: (in bycopy ZStyle*) style {
    if (ypos >= [lines count]) {
        int x;
        for (x=(int) [lines count]; x<=ypos; x++) {
            [lines addObject: [[[NSMutableAttributedString alloc] init] autorelease]];
        }
    }

		int xs, ys;
		NSAttributedString* newString;
		
		[theView dimensionX: &xs Y: &ys];
		
		newString = [theView formatZString: blankLine(xs+1)
								 withStyle: style];
		
        [lines[ypos] setAttributedString: newString];
}

// Maintainance
- (int) length {
    return (endLine - startLine);
}

- (NSArray*) lines {
    return lines;
}

- (NSColor*) backgroundColour {
    return backgroundColour;
}

- (void) cutLines {
	int length = [self length];
	if ([lines count] < length) return;
	
    [lines removeObjectsInRange: NSMakeRange(length,
                                             [lines count] - length)];
}

- (void) reformatLines {
	NSEnumerator* lineEnum = [lines objectEnumerator];
	NSMutableAttributedString* string;
	
	while (string = [lineEnum nextObject]) {
		NSRange attributedRange;
		NSDictionary* attr;
		int len = (int) [string length];
				
		attributedRange.location = 0;
		
		 while (attributedRange.location < len) {
			attr = [string attributesAtIndex: attributedRange.location
							  effectiveRange: &attributedRange];
			
			if (attributedRange.location == NSNotFound) break;
			if (attributedRange.length == 0) break;
			
			// Re-apply the style associated with this block of text
			ZStyle* sty = attr[ZoomStyleAttributeName];
			
			if (sty) {
				NSDictionary* newAttr = [theView attributesForStyle: sty];
				
				[string setAttributes: newAttr
								range: attributedRange];
			}
			
			attributedRange.location += attributedRange.length;
		}
	}
}

// = NSCoding =
- (void) encodeWithCoder: (NSCoder*) encoder {
	[encoder encodeValueOfObjCType: @encode(int)
								at: &startLine];
	[encoder encodeValueOfObjCType: @encode(int)
								at: &endLine];
	[encoder encodeValueOfObjCType: @encode(int)
								at: &xpos];
	[encoder encodeValueOfObjCType: @encode(int)
								at: &ypos];
	[encoder encodeObject: lines];
	[encoder encodeObject: backgroundColour];
}

- (instancetype)initWithCoder:(NSCoder *)decoder {
    self = [self initWithZoomView: nil];
	
    if (self) {
		[decoder decodeValueOfObjCType: @encode(int)
									at: &startLine];
		[decoder decodeValueOfObjCType: @encode(int)
									at: &endLine];
		[decoder decodeValueOfObjCType: @encode(int)
									at: &xpos];
		[decoder decodeValueOfObjCType: @encode(int)
									at: &ypos];
        [lines release];
        [backgroundColour release];
		lines = [[decoder decodeObject] retain];
		backgroundColour = [[decoder decodeObject] retain];
    }
	
    return self;
}

- (void) setZoomView: (ZoomView*) view {
	theView = view;
}

// = Input styles =

- (oneway void) setInputStyle: (in bycopy ZStyle*) newInputStyle {
	if (inputStyle) [inputStyle release];
	inputStyle = [newInputStyle copy];
}

- (bycopy ZStyle*) inputStyle {
	return inputStyle;
}

@end
