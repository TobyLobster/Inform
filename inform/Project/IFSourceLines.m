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

+ (NSRange) rangeOfTextOnLine: (int) line
                     inString: (NSString*) store {
    NSUInteger length = store.length;

    NSUInteger x;
    NSUInteger lineLength;
    NSUInteger linepos = 0;
    int        lineno = 1;

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
        return NSMakeRange(NSNotFound, 0);
    }

    lineLength = 0;
    for (x=0; x<length-linepos; x++) {
        if ([store characterAtIndex: x+linepos] == '\n'
			|| [store characterAtIndex: x+linepos] == '\r') {
            break;
        }
        lineLength++;
    }

    return NSMakeRange(linepos, lineLength);
}

+ (NSRange) rangeOfLine: (NSUInteger) line
               inString: (NSString*) store {
    NSUInteger length = store.length;

    NSUInteger x;
    NSUInteger linepos = 0;
    NSUInteger lineno = 1;

    if (line > lineno) {
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
        return NSMakeRange(NSNotFound, 0);
    }

	// Find the end of this line
	for (x=linepos; x<length; x++) {
        unichar chr = [store characterAtIndex: x];

        if (chr == '\n' || chr == '\r') {
			break;
		}
	}

	return NSMakeRange(linepos, x - linepos + 1);
}

+ (NSUInteger) indexOfLine: (NSUInteger) line
                  inString: (NSString*) store {
    NSUInteger length = store.length;

    NSUInteger x = 0;
    NSUInteger linepos;
    NSUInteger lineno = 1;

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

	return x;
}

+ (int) lineForCharacter: (NSUInteger) charNum
                inString: (NSString*) store {
	int result = 0;

    NSUInteger length = store.length;

    NSUInteger x;
    NSUInteger linepos;
    int lineno;
    lineno = 1;
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

			if (x > charNum) {
				break;
			} else {
				result = lineno;
			}
		}
	}

	return result;
}

@end
