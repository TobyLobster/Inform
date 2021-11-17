//
//  ZoomUpperWindow.m
//  ZoomCocoa
//
//  Created by Andrew Hunter on Thu Oct 09 2003.
//  Copyright (c) 2003 Andrew Hunter. All rights reserved.
//

#import "ZoomUpperWindow.h"
#import "ZoomView.h"

static NSString* blankLine(NSInteger length);

@implementation ZoomUpperWindow

- (id) initWithZoomView: (ZoomView*) view {
    self = [super init];
    if (self) {
        theView = view;
        lines = [[NSMutableArray alloc] init];

        backgroundColour = [NSColor blueColor];

        endLine = startLine = 0;
    }
    return self;
}

// Clears the window
- (oneway void) clearWithStyle: (in bycopy ZStyle*) style {
    lines = [[NSMutableArray alloc] init];
    xpos = ypos = 0;

    backgroundColour = style.reversed?[theView foregroundColourForStyle: style]:[theView backgroundColourForStyle: style];
}

// Sets the input focus to this window
- (oneway void) setFocus {
	[theView setFocusedView: self];
}

// Sending data to a window
- (oneway void) writeString: (in bycopy NSString*) string
                  withStyle: (in bycopy ZStyle*) style {
    [style setFixed: YES];

    NSInteger len = [string length];
    for (NSInteger x=0; x<len; x++) {
        if ([string characterAtIndex: x] == '\n') {
            [self writeString: [string substringToIndex: x]
                    withStyle: style];
            ypos++; xpos = 0;
            [self writeString: [string substringFromIndex: x+1]
                    withStyle: style];
            return;
        }
    }

    if (ypos >= [lines count]) {
        for (NSInteger x=[lines count]; x<=ypos; x++) {
            [lines addObject: [[NSMutableAttributedString alloc] init]];
        }
    }

    NSMutableAttributedString* thisLine;
    thisLine = [lines objectAtIndex: ypos];

    NSInteger strlen = [string length];

    // Make sure there is enough space on this line for the text
    if ([thisLine length] <= xpos+strlen) {
        NSFont* fixedFont = [theView fontFromStyle: ZFontStyleFixed];
        NSDictionary* clearStyle = @{NSFontAttributeName: fixedFont};
		NSInteger spacesLen = (xpos+strlen)-[thisLine length];

        NSAttributedString* spaceString = [[NSAttributedString alloc]
            initWithString: blankLine(spacesLen)
                attributes: clearStyle];
        
        [thisLine appendAttributedString: spaceString];
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
static NSString* blankLine(NSInteger length) {
	char* cString = malloc(length);
	
	memset(cString, ' ', length);
	NSData *cStrDat = [NSData dataWithBytesNoCopy:cString length:length freeWhenDone:YES];
	
	NSString* res = [[NSString alloc] initWithData:cStrDat encoding:NSASCIIStringEncoding];
	
	return res;
}

- (oneway void) eraseLineWithStyle: (in bycopy ZStyle*) style {
    if (ypos >= [lines count]) {
        for (NSInteger x=[lines count]; x<=ypos; x++) {
            [lines addObject: [[NSMutableAttributedString alloc] init]];
        }
    }

		int xs, ys;
		NSAttributedString* newString;
		
		[theView dimensionX: &xs Y: &ys];
		
		newString = [theView formatZString: blankLine(xs+1)
								 withStyle: style];
		
        [[lines objectAtIndex: ypos] setAttributedString: newString];
}

// Maintainance
- (int) length {
    return (endLine - startLine);
}

- (NSArray*) lines {
    return [lines copy];
}

@synthesize backgroundColour;

- (void) cutLines {
	int length = [self length];
	if ([lines count] < length) return;
	
    [lines removeObjectsInRange: NSMakeRange(length,
                                             [lines count] - length)];
}

- (void) reformatLines {
	for (NSMutableAttributedString* string in lines) {
		NSRange attributedRange;
		NSDictionary* attr;
		NSInteger len = [string length];
				
		attributedRange.location = 0;
		
		 while (attributedRange.location < len) {
			attr = [string attributesAtIndex: attributedRange.location
							  effectiveRange: &attributedRange];
			
			if (attributedRange.location == NSNotFound) break;
			if (attributedRange.length == 0) break;
			
			// Re-apply the style associated with this block of text
			ZStyle* sty = [attr objectForKey: ZoomStyleAttributeName];
			
			if (sty) {
				NSDictionary* newAttr = [theView attributesForStyle: sty];
				
				[string setAttributes: newAttr
								range: attributedRange];
			}
			
			attributedRange.location += attributedRange.length;
		}
	}
}

#pragma mark - NSCoding
#define LINESCODINGKEY @"lines"
#define BACKGROUNDCOLORCODINGKEY @"backgroundColour"
#define STARTLINECODINGKEY @"startLine"
#define ENDLINECODINGKEY @"endLine"
#define XPOSCODINGKEY @"xpos"
#define YPOSCODINGKEY @"ypos"

- (void) encodeWithCoder: (NSCoder*) encoder {
	if (encoder.allowsKeyedCoding) {
		[encoder encodeInt: startLine forKey: STARTLINECODINGKEY];
		[encoder encodeInt: endLine forKey: ENDLINECODINGKEY];
		[encoder encodeInt: xpos forKey: XPOSCODINGKEY];
		[encoder encodeInt: ypos forKey: YPOSCODINGKEY];
		[encoder encodeObject: lines forKey: LINESCODINGKEY];
		[encoder encodeObject: backgroundColour forKey: BACKGROUNDCOLORCODINGKEY];
	} else {
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
}

- (id)initWithCoder:(NSCoder *)decoder {
	self = [super init];
	
    if (self) {
		if (decoder.allowsKeyedCoding) {
			startLine = [decoder decodeIntForKey: STARTLINECODINGKEY];
			endLine = [decoder decodeIntForKey: ENDLINECODINGKEY];
			xpos = [decoder decodeIntForKey: XPOSCODINGKEY];
			ypos = [decoder decodeIntForKey: YPOSCODINGKEY];
			lines = [decoder decodeObjectOfClasses: [NSSet setWithObjects: [NSMutableAttributedString class], [NSMutableArray class], nil] forKey: LINESCODINGKEY];
			backgroundColour = [decoder decodeObjectOfClass: [NSColor class] forKey: BACKGROUNDCOLORCODINGKEY];
		} else {
			[decoder decodeValueOfObjCType: @encode(int)
										at: &startLine
									  size: sizeof(int)];
			[decoder decodeValueOfObjCType: @encode(int)
										at: &endLine
									  size: sizeof(int)];
			[decoder decodeValueOfObjCType: @encode(int)
										at: &xpos
									  size: sizeof(int)];
			[decoder decodeValueOfObjCType: @encode(int)
										at: &ypos
									  size: sizeof(int)];
			lines = [decoder decodeObject];
			backgroundColour = [decoder decodeObject];
		}
    }
	
    return self;
}

+ (BOOL)supportsSecureCoding
{
	return YES;
}

#pragma mark -

@synthesize zoomView = theView;

#pragma mark - Input styles

@synthesize inputStyle;

@end
