//
//  IFSourceSections.m
//  Inform
//
//  Moved out of IFSourcePage in November 2026.
//

#import "IFSourceSections.h"
#import "IFSourceLines.h"
#import "IFIntelFile.h"
#import "IFIntelSymbol.h"

@implementation IFSourceSections

+ (IFIntelSymbol*) sectionAfter: (IFIntelSymbol*) section {
	IFIntelSymbol* nextSection	= section.sibling;

	if (!nextSection) {
		IFIntelSymbol* parentSection = section.parent;
		while (parentSection && !nextSection) {
			nextSection = parentSection.sibling;
			parentSection = parentSection.parent;
		}
	}

	return nextSection;
}

+ (IFIntelSymbol*) sectionBefore: (IFIntelSymbol*) section
                          inFile: (IFIntelFile*) intelFile {
	IFIntelSymbol* previousSection = section.previousSibling;

	if (!previousSection) {
		previousSection = section.parent;
		if (previousSection == intelFile.firstSymbol) previousSection = nil;
	}

	return previousSection;
}

+ (IFIntelSymbol*) sectionAbove: (IFIntelSymbol*) section
                         inFile: (IFIntelFile*) intelFile {
	IFIntelSymbol* parentSection	= section.parent;
	if (parentSection && parentSection != intelFile.firstSymbol) {
		return parentSection;
	}
	return nil;
}

+ (IFIntelSymbol*) sectionBelow: (IFIntelSymbol*) currentSection
                        towards: (IFIntelSymbol*) cursorSection {
	// Can't do anything if the cursor is in no section, or the currently selected section is the most specific we can use
	if (cursorSection == nil || currentSection == cursorSection) {
		return nil;
	}

	// Move up the sections until we find one which has the currentSection as a parent
	IFIntelSymbol* lowerSection = cursorSection;
	while (lowerSection && lowerSection.parent != currentSection) {
		lowerSection = lowerSection.parent;
	}

	return lowerSection;
}

+ (IFIntelSymbol*) sectionAtCharacter: (NSUInteger) charNum
                               inFile: (IFIntelFile*) intelFile
                             inString: (NSString*) store {
	return [intelFile nearestSymbolToLine: [IFSourceLines lineForCharacter: charNum
	                                                              inString: store]];
}

+ (NSRange) rangeOfSection: (IFIntelSymbol*) symbol
                    inFile: (IFIntelFile*) intelFile
                  inString: (NSString*) store {
	IFIntelSymbol* followingSymbol	= [self sectionAfter: symbol];

	// Get the range we need to limit to: from the start of the heading's line (the headings count lines from 0, and
	// IFSourceLines from 1)...
	NSRange limitRange;

	NSUInteger symbolLine = [intelFile lineForSymbol: symbol];
	if (symbolLine == NSNotFound) return NSMakeRange(NSNotFound, 0);

	limitRange.location = [IFSourceLines startOfLine: (NSInteger) symbolLine + 1
	                                        inString: store];
	if (limitRange.location == NSNotFound) return NSMakeRange(NSNotFound, 0);

	// ...to the start of the next section's heading's line, or the end of the text
	NSUInteger finalLocation;
	if (followingSymbol) {
		NSUInteger followingLine = [intelFile lineForSymbol: followingSymbol];
		if (followingLine == NSNotFound) return NSMakeRange(NSNotFound, 0);
		finalLocation = [IFSourceLines startOfLine: (NSInteger) followingLine + 1
		                                  inString: store];
	} else {
		finalLocation = store.length;
	}

	if (finalLocation == NSNotFound) return NSMakeRange(NSNotFound, 0);

	// Move the start of the limitation to the first non-whitespace character
	while (limitRange.location < finalLocation) {
		unichar chr = [store characterAtIndex: limitRange.location];
		if (chr != ' ' && chr != '\t' && chr != '\n' && chr != '\r') {
			break;
		}
		limitRange.location++;
	}

	// Leave out the white space before the next section's heading
	if (followingSymbol) {
		while (finalLocation > limitRange.location) {
			unichar chr = [store characterAtIndex: finalLocation - 1];
			if (chr != ' ' && chr != '\t' && chr != '\n' && chr != '\r') {
				break;
			}
			finalLocation--;
		}
	}

	limitRange.length = finalLocation - limitRange.location;
	return limitRange;
}

+ (NSRange) linesOfRange: (NSRange) restriction
                inString: (NSString*) store {
	NSUInteger firstLine = 0;
	NSUInteger finalLine = NSNotFound;

	NSUInteger length = store.length;

	NSUInteger x;
	NSUInteger lineno = 1;
	NSUInteger linepos;

	for (x=0; x<length; x++) {
		unichar chr = [store characterAtIndex: x];

		if (chr == '\n' || chr == '\r') {
			unichar otherchar = chr == '\n'?'\r':'\n';

			lineno++;
			linepos = x + 1;

			if (x < restriction.location) firstLine = lineno;
			else if (x < restriction.location + restriction.length) finalLine = lineno;
			else break;

			// Deal with DOS line endings
			if (linepos < length && [store characterAtIndex: linepos] == otherchar) {
				x++; linepos++;
			}
		}
	}
	if (finalLine == NSNotFound) finalLine = lineno;

	return NSMakeRange(firstLine, finalLine-firstLine);
}

@end
