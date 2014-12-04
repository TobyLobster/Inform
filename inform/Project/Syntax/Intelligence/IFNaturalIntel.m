//
//  IFNaturalIntel.m
//  Inform
//
//  Created by Andrew Hunter on 05/02/2005.
//  Copyright 2005 Andrew Hunter. All rights reserved.
//

#import "IFNaturalIntel.h"
#import "IFSyntaxData.h"
#import "IFPreferences.h"
#import "IFUtility.h"

static NSArray* headingList = nil;

// English number arrays
static NSArray* units;
static NSArray* tens;
static NSArray* majorUnits;
static BOOL indent = YES;

@implementation IFNaturalIntel

// = Hacky way to enable/disable indentation while undoing =
+ (void) disableIndentation {
	indent = NO;
}

+ (void) enableIndentation {
	indent = YES;
}

// = Useful parsing functions = 

+ (int) parseNumber: (NSString*) number {
	// IMPLEMENT ME: parse english numbers (one, two, three, etc)
	
	return [number intValue];
}

+ (int) numberOfHeading: (NSString*) heading {
	NSArray* words = [heading componentsSeparatedByString: @" "];
	
	if ([words count] < 2) return 0;
	
	return [IFNaturalIntel parseNumber: [words objectAtIndex: 1]];
}

// = Startup =

+ (void) initialize {
	if (!headingList) {
		headingList = [[NSArray arrayWithObjects: @"volume", @"book", @"part", @"chapter", @"section", nil] retain];
		
		units = [[NSArray arrayWithObjects: @"zero", @"one", @"two", @"three", @"four", @"five", @"six", @"seven", 
			@"eight", @"nine", @"ten", @"eleven", @"twelve", @"thirteen", @"fourteen", @"fifteen", @"sixteen", 
			@"seventeen", @"eighteen", @"nineteen", nil] retain];
		tens = [[NSArray arrayWithObjects: @"twenty", @"thirty", @"forty", @"fifty", @"sixty", @"seventy", @"eighty",
			@"ninety", @"hundred", nil] retain];
		majorUnits = [[NSArray arrayWithObjects: @"hundred", @"thousand", @"million", @"billion", @"trillion", nil] retain];
	}
}

// = Notifying of the highlighter currently in use =

- (void) setSyntaxData: (IFSyntaxData*) aData {
	highlighter = aData;
}

// = Gathering information (works like rehint) =

- (void) gatherIntelForLine: (NSString*) line
					 styles: (IFSyntaxStyle*) styles
			   initialState: (IFSyntaxState) state
				 lineNumber: (int) lineNumber
				   intoData: (IFIntelFile*) data {
	// Clear out old data for this line
	[data clearSymbolsForLines: NSMakeRange(lineNumber, 1)];
	
	// Heading lines beginning with 'Volume', 'Part', etc  are added to the intelligence
	//if ([line length] < 4) return;				// Nothing to do in this case

	if (styles[0] == IFSyntaxHeading) {
		// Check if this is a heading or not
		// MAYBE FIXME: won't deal well with headings starting with whitespace. Bug or not?
		NSArray* words = [line componentsSeparatedByString: @" "];
		if ([words count] < 1) return;
		
		int headingType = [headingList indexOfObject: [[words objectAtIndex: 0] lowercaseString]] + 1;
		if (headingType == NSNotFound) return;		// Not a heading (hmm, shouldn't happen, I guess)
		
		// Got a heading: add to the intel
		IFIntelSymbol* newSymbol = [[IFIntelSymbol alloc] init];

		[newSymbol setType: IFSectionSymbolType];
		[newSymbol setName: line];
		[newSymbol setRelation: IFSymbolOnLevel];
		[newSymbol setLevelDelta: headingType];
		
		[data addSymbol: newSymbol
				 atLine: lineNumber];

		[newSymbol release];
	} else if (lineNumber == 0) {
		// The title string
		int x = 0;
		int start = 0;
		while (x < [line length] && styles[x] != IFSyntaxGameText) x++;
		start = x;
		while (x < [line length] && styles[x] == IFSyntaxGameText) x++;

		// Add this as a level 0 item
        IFIntelSymbol* newSymbol = [[IFIntelSymbol alloc] init];
        
        NSString* title = [line substringWithRange: NSMakeRange(start, x-start)];
        if( [title length] == 0 ) {
            title = [IFUtility localizedString:@"Story"];
        }

        [newSymbol setType: IFSectionSymbolType];
        [newSymbol setName: title];
        [newSymbol setRelation: IFSymbolOnLevel];
        [newSymbol setLevelDelta: 0];
        
        [data addSymbol: newSymbol
                 atLine: lineNumber];
        
        [newSymbol release];		
	}
}

// = Rewriting =

- (NSString*) rewriteInput: (NSString*) input {
	// No rewriting if indentation is disabled
	if (!indent) return input;
	
	if ([input isEqualToString: @"\n"]) {
		// Auto-tab
		if (![[IFPreferences sharedPreferences] indentAfterNewline]) return nil;
		
		// 'editingLineNumber' will still be the previous line
		int lineNumber = [highlighter editingLineNumber];
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
				int len = [line length];
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
		if (![[IFPreferences sharedPreferences] autoNumberSections]) return nil;

		int lineNumber = [highlighter editingLineNumber];
		IFSyntaxStyle lastStyle = [highlighter styleAtStartOfLine: lineNumber];
		
		if (lastStyle != IFSyntaxGameText && lastStyle != IFSyntaxSubstitution) {
			// If we've got a line 'Volume\n', or (pedantic last line case) 'Volume', then automagically fill
			// in the section number using context info
			NSString* line = [highlighter textForLine: lineNumber];
			NSString* prefix = nil;
			
            // Trim whitespace
            prefix = [line stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
            
			// Line must actually have something on it
			if ([prefix length] < 4) return nil;				// Too short to be of interest
			if ([prefix length] > 8) return nil;				// Too long to be of interest

			// See if this is the start of a heading
			int headingLevel = [headingList indexOfObject: [prefix lowercaseString]];
			if (headingLevel == NSNotFound) return nil;		// Not a heading
			headingLevel++;
			
			// We've got a heading: auto-insert a number
			
			// Find the preceding heading
			IFIntelFile* data = [highlighter intelligenceData];
			IFIntelSymbol* symbol = [data nearestSymbolToLine: lineNumber];
			
			while (symbol && [symbol level] > headingLevel) symbol = [symbol parent];
			
			// Work out the numeric value of the heading
			int lastHeadingNumber = 0;
			
			if (symbol) {
				if ([symbol level] != headingLevel) {
					lastHeadingNumber = 0;			// No preceding items at this level
				} else {
					lastHeadingNumber = [IFNaturalIntel numberOfHeading: [symbol name]];
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
									  withValue: [NSNumber numberWithInt: lineNumber]];
			}
			
			return res;
		}
	}
	
	// No behaviour defined: just fall through
	return nil;
}

- (void) renumberSectionsAfterLine: (NSNumber*) lineObject {
	// Gather some information about what we're about to do
	int lineNumber = [lineObject intValue];
	IFIntelFile* data = [highlighter intelligenceData];
	IFIntelSymbol* firstSymbol = [data nearestSymbolToLine: lineNumber];
	
	if (firstSymbol == nil) return;
	
	int currentSectionNumber = [IFNaturalIntel numberOfHeading: [firstSymbol name]];

	if (currentSectionNumber <= 0) return;
	if ([firstSymbol level] == 0) return;
	
	// Renumber all the siblings
	IFIntelSymbol* symbol = [firstSymbol sibling];
	
	NSMutableArray* todoList = [NSMutableArray array];
	
	while (symbol != nil) {
		currentSectionNumber++;
		
		int symbolSectionNumber = [IFNaturalIntel numberOfHeading: [firstSymbol name]];
		
		if (symbolSectionNumber != currentSectionNumber) {
			// Get the data for the line this symbol is on
			int symbolLineNumber = [data lineForSymbol: symbol];
			NSString* line = [highlighter textForLine: symbolLineNumber];
						
			// Renumber this symbol
			NSMutableArray* words = [[line componentsSeparatedByString: @" "] mutableCopy];
			
			if ([words count] > 1) {
				[words replaceObjectAtIndex: 1
								 withObject: [NSString stringWithFormat: @"%i", currentSectionNumber]];
				NSString* newString = [words componentsJoinedByString: @" "];
			
				// Add to our 'todo' list
				[todoList addObject: [NSArray arrayWithObjects: [NSNumber numberWithInt: symbolLineNumber], newString, nil]];
			}
            [words release];
		}
		
		symbol = [symbol sibling];
	}
	
	// Renumber everything in the todo list
	// (We put things in a todo list to avoid accidently stuffing up the symbol list while we're working on it)

	for(NSArray* todo in todoList) {
		[highlighter replaceLine: [[todo objectAtIndex: 0] intValue]
						withLine: [todo objectAtIndex: 1]];
	}
	
	// We're done
}

@end
