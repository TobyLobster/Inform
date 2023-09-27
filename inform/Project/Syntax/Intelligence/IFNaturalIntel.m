//
//  IFNaturalIntel.m
//  Inform
//
//  Created by Andrew Hunter on 05/02/2005.
//  Copyright 2005 Andrew Hunter. All rights reserved.
//

#import "IFNaturalIntel.h"
#import "IFSyntaxStyles.h"
#import "IFSyntaxData.h"
#import "IFPreferences.h"
#import "IFUtility.h"
#import "IFIntelSymbol.h"

static NSArray* headingList = nil;
static NSArray* autoNumberHeading = nil;

// English number arrays
static NSArray* units;
static NSArray* tens;
static NSArray* majorUnits;
static BOOL indent = YES;

@implementation IFNaturalIntel {
    IFSyntaxData* highlighter;				// The highlighter that wants us to gather intelligence
}

#pragma mark - Hacky way to enable/disable indentation while undoing
+ (void) disableIndentation {
	indent = NO;
}

+ (void) enableIndentation {
	indent = YES;
}

#pragma mark - Useful parsing functions 

+ (int) parseNumber: (NSString*) number {
	// IMPLEMENT ME: parse english numbers (one, two, three, etc)
	
	return number.intValue;
}

+ (int) numberOfHeading: (NSString*) heading {
	NSArray* words = [heading componentsSeparatedByString: @" "];
	
	if (words.count < 2) return 0;
	
	return [IFNaturalIntel parseNumber: words[1]];
}

#pragma mark - Startup

+ (void) initialize {
	if (!headingList) {
		headingList = @[@"---- documentation ----", @"volume", @"book", @"part", @"chapter", @"section", @"example"];
        autoNumberHeading = @[@NO, @YES, @YES, @YES, @YES, @YES, @NO];
		
		units = @[@"zero", @"one", @"two", @"three", @"four", @"five", @"six", @"seven", 
			@"eight", @"nine", @"ten", @"eleven", @"twelve", @"thirteen", @"fourteen", @"fifteen", @"sixteen", 
			@"seventeen", @"eighteen", @"nineteen"];
		tens = @[@"twenty", @"thirty", @"forty", @"fifty", @"sixty", @"seventy", @"eighty",
			@"ninety", @"hundred"];
		majorUnits = @[@"hundred", @"thousand", @"million", @"billion", @"trillion"];
	}
}

#pragma mark - Notifying of the highlighter currently in use

- (void) setSyntaxData: (IFSyntaxData*) aData {
	highlighter = aData;
}

#pragma mark - Gathering information (works like rehint)

-(BOOL) isHeading:(NSString*) line {
    line = line.lowercaseString;
    for(NSString* heading in headingList) {
        if( [line isEqualToString: heading] ) {
            return YES;
        }
    }

    return NO;
}

-(NSUInteger) indexOfHeading:(NSString*) line {
    NSUInteger index = 0;

    line = line.lowercaseString;
    for(NSString* heading in headingList) {
        if( [line startsWith: heading] ) {
            return index;
        }
        index++;
    }

    return NSNotFound;
}

-(BOOL) autonumberHeading:(NSString*) line {
    NSUInteger index = 0;

    line = line.lowercaseString;
    for(NSString* heading in headingList) {
        if( [line startsWith: heading] ) {
            return [autoNumberHeading[index] boolValue];
        }
        index++;
    }

    return NO;
}

- (void) gatherIntelForLine: (NSString*) line
					 styles: (IFSyntaxStyles*) styles
			   initialState: (IFSyntaxState) state
				 lineNumber: (int) lineNumber
				   intoData: (IFIntelFile*) data {
	// Clear out old data for this line
	[data clearSymbolsForLines: NSMakeRange(lineNumber, 1)];
	
	// Heading lines beginning with 'Volume', 'Part', etc  are added to the intelligence
    if ([styles read:0] == IFSyntaxHeading) {
		// Check if this is a heading or not
        // Trim whitespace
        NSString* prefix = [line stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
        NSUInteger headingType = [self indexOfHeading: prefix];
        if (headingType == NSNotFound) {
            return;
        }

		// Got a heading: add to the intel
		IFIntelSymbol* newSymbol = [[IFIntelSymbol alloc] init];

		newSymbol.type = IFSectionSymbolType;
		newSymbol.name = line;
		newSymbol.relation = IFSymbolOnLevel;
		newSymbol.levelDelta = (int) headingType;
		
		[data addSymbol: newSymbol
				 atLine: lineNumber];

	} else if (lineNumber == 0) {
		// The title string
		int x = 0;
		int start = 0;
		while (x < line.length && [styles read:x] != IFSyntaxGameText)
            x++;
		start = x;
		while (x < line.length && [styles read:x] == IFSyntaxGameText)
            x++;

		// Add this as a level 0 item
        IFIntelSymbol* newSymbol = [[IFIntelSymbol alloc] init];
        
        NSString* title = [line substringWithRange: NSMakeRange(start, x-start)];
        if( title.length == 0 ) {
            title = [IFUtility localizedString:@"Story"];
        }

        newSymbol.type = IFSectionSymbolType;
        newSymbol.name = title;
        newSymbol.relation = IFSymbolOnLevel;
        newSymbol.levelDelta = 0;
        
        [data addSymbol: newSymbol
                 atLine: lineNumber];
        
	}
}

#pragma mark - Rewriting

- (NSString*) rewriteInput: (NSString*) input {
	// No rewriting if indentation is disabled
	if (!indent) return input;
	
	if ([input isEqualToString: @"\n"]) {
		// Auto-tab
		if (![IFPreferences sharedPreferences].indentAfterNewline) return nil;
		
		// 'editingLineNumber' will still be the previous line
		int lineNumber = highlighter.editingLineNumber;
		int tabs = [highlighter numberOfTabStopsForLine: lineNumber];
		
		// If we're not currently in a string...
		IFSyntaxStyle lastStyle = [highlighter styleAtEndOfLine: lineNumber];
		if (lastStyle != IFSyntaxGameText && lastStyle != IFSyntaxSubstitution) {
			unichar lastChar = [highlighter characterAtEndOfLine: lineNumber];

			if (lastChar == ':') {
				// Increase tab depth if last character of last line was ':'
				tabs++;
			} else if (lastChar == '\t' || lastChar == ' ') {
				// If line was entirely whitespace then reduce tabs back to 0
				NSString* line = [highlighter textForLine: lineNumber];
				int len = (int) line.length;
				int x;
				BOOL whitespace = YES;
				
				for (x=0; x<len-1; x++) {
					// Loop to len-1 as last character will always be '\n'
					// Exception is the very last line in the file. But we're OK there, as we know the last
					// character is whitespace anyway
					unichar chr = [line characterAtIndex: x];
					
					if (chr != '\t' && chr != ' ') {
						whitespace = NO;
						break;
					}
				}
				
				if (whitespace) {
					// Line was entirely whitespace: no tabs now
					tabs = 0;
				}
			}
		}
		
		if (tabs > 0) {
			// Auto-indent the next line
			NSMutableString* res = [NSMutableString stringWithString: @"\n"];
			
			int x;
			for (x=0; x<tabs; x++) {
				[res appendString: @"\t"];
			}
			
			return res;
		} else {
			// Leave as-is
			return nil;
		}
	} else if ([input isEqualToString: @" "]) {
		if (![IFPreferences sharedPreferences].autoNumberSections) return nil;

		int lineNumber = highlighter.editingLineNumber;
		IFSyntaxStyle lastStyle = [highlighter styleAtStartOfLine: lineNumber];

		if (lastStyle != IFSyntaxGameText && lastStyle != IFSyntaxSubstitution) {
			// If we've got a line 'Volume\n', or (pedantic last line case) 'Volume', then automagically fill
			// in the section number using context info
			NSString* line = [highlighter textForLine: lineNumber];
			NSString* prefix = nil;
			
            // Trim whitespace
            prefix = [line stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
            
			// See if this is the start of a heading
            if( ![self isHeading:prefix] ) {
                return nil;
            }

            // Get heading level
			NSUInteger headingLevel = [self indexOfHeading:prefix];
			if (headingLevel == NSNotFound) return nil;         // Not a heading
            if( ![self autonumberHeading:prefix] )
                return nil;  // Don't try to auto number "---- DOCUMENTATION ----" heading, etc

			// We've got a heading: auto-insert a number

			// Find the preceding heading
			IFIntelFile* data = highlighter.intelligenceData;
			IFIntelSymbol* symbol = [data nearestSymbolToLine: lineNumber];
			
			while (symbol && symbol.level > headingLevel) symbol = symbol.parent;
			
			// Work out the numeric value of the heading
			int lastHeadingNumber = 0;
			
			if (symbol) {
				if (symbol.level != headingLevel) {
					lastHeadingNumber = 0;			// No preceding items at this level
				} else {
					lastHeadingNumber = [IFNaturalIntel numberOfHeading: symbol.name];
					if (lastHeadingNumber == 0) {
						lastHeadingNumber = -1;		// There was a preceding heading, but we don't know the number
					}
				}
			}
			
			// Work out the result
			NSMutableString* res = nil;
			
			if (lastHeadingNumber >= 0) {
				// Insert a suitable new heading number
				res = [NSMutableString stringWithFormat: @" %i - ", lastHeadingNumber+1];
				
				[highlighter callbackForEditing: @selector(renumberSectionsAfterLine:)
									  withValue: @(lineNumber)];
			}
			
			return res;
		}
	}
	
	// No behaviour defined: just fall through
	return nil;
}

- (void) renumberSectionsAfterLine: (NSNumber*) lineObject {
	// Gather some information about what we're about to do
	int lineNumber = lineObject.intValue;
	IFIntelFile* data = highlighter.intelligenceData;
	IFIntelSymbol* firstSymbol = [data nearestSymbolToLine: lineNumber];
	
	if (firstSymbol == nil) return;
	
	int currentSectionNumber = [IFNaturalIntel numberOfHeading: firstSymbol.name];

	if (currentSectionNumber <= 0) return;
	if (firstSymbol.level == 0) return;
	
	// Renumber all the siblings
	IFIntelSymbol* symbol = firstSymbol.sibling;
	
	NSMutableArray* todoList = [NSMutableArray array];
	
	while (symbol != nil) {
		currentSectionNumber++;
		
		int symbolSectionNumber = [IFNaturalIntel numberOfHeading: firstSymbol.name];
		
		if (symbolSectionNumber != currentSectionNumber) {
			// Get the data for the line this symbol is on
			NSUInteger symbolLineNumber = [data lineForSymbol: symbol];
			NSString* line = [highlighter textForLine: (int) symbolLineNumber];

			// Renumber this symbol
			NSMutableArray* words = [[line componentsSeparatedByString: @" "] mutableCopy];
			
			if (words.count > 1) {
				words[1] = [NSString stringWithFormat: @"%i", currentSectionNumber];
				NSString* newString = [words componentsJoinedByString: @" "];
			
				// Add to our 'todo' list
				[todoList addObject: @[@(symbolLineNumber), newString]];
			}
		}
		
		symbol = symbol.sibling;
	}
	
	// Renumber everything in the todo list
	// (We put things in a todo list to avoid accidently stuffing up the symbol list while we're working on it)

	for(NSArray* todo in todoList) {
		[highlighter replaceLine: [todo[0] intValue]
						withLine: todo[1]];
	}
	
	// We're done
}

@end
