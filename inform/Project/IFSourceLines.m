//
//  IFSourceLines.m
//  Inform
//
//  Moved out of IFSourcePage in November 2026.
//

#import "IFSourceLines.h"

@implementation IFSourceLines

+ (NSUInteger) startOfLine: (NSInteger) line
                  inString: (NSString*) store {
    NSUInteger length = store.length;

    NSUInteger x;
    NSUInteger linepos = 0;
    NSInteger  lineno = 1;

	if (line > lineno)
	{
		for (x=0; x<length; x++) {
			unichar chr = [store characterAtIndex: x];

			if (chr == '\n' || chr == '\r') {
				unichar otherchar = chr == '\n'?'\r':'\n';

				lineno++;
				linepos = x + 1;

				// Deal with DOS line endings
				if (linepos < length && [store characterAtIndex: linepos] == otherchar) {
					x++; linepos++;
				}

				if (lineno == line) {
					break;
				}
			}
		}
	}

    if (lineno != line) {
        return NSNotFound;
    }

    return linepos;
}

/// Where the line starting at an index ends: the index of the character that ends it, or the length of the text
+ (NSUInteger) endOfLineStartingAt: (NSUInteger) linepos
                          inString: (NSString*) store {
    NSUInteger length = store.length;

    NSUInteger x;
	for (x=linepos; x<length; x++) {
        unichar chr = [store characterAtIndex: x];
        
        if (chr == '\n' || chr == '\r') {
			break;
		}
	}

    return x;
}

+ (NSRange) rangeOfTextOnLine: (int) line
                     inString: (NSString*) store {
    NSUInteger linepos = [self startOfLine: line
                                  inString: store];

    if (linepos == NSNotFound) {
        return NSMakeRange(NSNotFound, 0);
    }

    NSUInteger lineEnd = [self endOfLineStartingAt: linepos
                                          inString: store];

    return NSMakeRange(linepos, lineEnd - linepos);
}

+ (NSRange) rangeOfLine: (NSUInteger) line
               inString: (NSString*) store {
    NSUInteger linepos = [self startOfLine: (NSInteger) line
                                  inString: store];

    if (linepos == NSNotFound) {
        return NSMakeRange(NSNotFound, 0);
    }
	
	// Find the end of this line
    NSUInteger lineEnd = [self endOfLineStartingAt: linepos
                                          inString: store];

    // With the character that ends it, if something does
    if (lineEnd < store.length) {
        lineEnd++;
    }
	
	return NSMakeRange(linepos, lineEnd - linepos);
}

+ (NSUInteger) indexOfLine: (NSUInteger) line
                  inString: (NSString*) store {
    NSUInteger linepos = [self startOfLine: (NSInteger) line
                                  inString: store];

	if (linepos == NSNotFound) {
		return NSNotFound;
	}

    // The first line has no line before it
    if (linepos == 0) {
        return 0;
    }

    // The character before the line's start is the last of what ends the line before
	return linepos - 1;
}

+ (int) lineForCharacter: (NSUInteger) charNum
                inString: (NSString*) store {
	int line = 0;
	
    NSUInteger length = store.length;
	
    // Count what ends the lines before the character
    NSUInteger x;
	for (x=0; x<charNum && x<length; x++) {
		unichar chr = [store characterAtIndex: x];
		
		if (chr == '\n' || chr == '\r') {
			unichar otherchar = chr == '\n'?'\r':'\n';
			
			// Deal with DOS line endings
			if (x + 1 < length && [store characterAtIndex: x + 1] == otherchar) {
				x++;
			}
			
			// (The character may be part of what ends its own line)
			if (x < charNum) {
				line++;
			}
		}
	}
	
	return line;
}

@end
