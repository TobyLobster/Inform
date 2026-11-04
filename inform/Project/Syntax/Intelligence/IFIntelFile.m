//
//  IFIntelFile.m
//  Inform
//
//  Created by Andrew Hunter on 05/02/2005.
//  Copyright 2005 Andrew Hunter. All rights reserved.
//

#import "IFIntelFile.h"
#import "IFIntelSymbol.h"

#define IntelDebug 0

// FIXME: symbols are supposed to be deliniated by type, so we should really be using one of these objects
// per symbol type;
NSString* const IFIntelFileHasChangedNotification = @"IFIntelFileHasChangedNotification";

@implementation IFIntelFile {
    // Data
    /// List of symbols added to the file
    NSMutableArray<IFIntelSymbol*>* symbols;
    /// We access this a lot: C-style array is faster. The line number each symbol in the symbols array occurs on (ie, one entry per symbol)
    int* symbolLines;

    // Notifications
    /// YES if we're preparing to send a notification that this object has changed
    BOOL notificationPending;
}

- (instancetype) init {
	self = [super init];
	
	if (self) {
		symbols = [[NSMutableArray alloc] init];
		symbolLines = NULL;
	}
	
	return self;
}

- (int) indexOfSymbolOnLine: (NSUInteger) lineNumber {
	// BINARY SEARCH POWER! Is there anything this wacky algorithm cannot do?
	
	// Either the last item of the previous line, or the first item of this line
	int nSymbols = (int) symbols.count;
	
	if (nSymbols == 0) return -1;
	
	int top, middle, bottom;
	
	bottom = 0;
	top = nSymbols - 1;
	middle = 0;
	while (top >= bottom) {
		middle = (top + bottom)>>1;
		
		if (symbolLines[middle] < lineNumber) {
			bottom = middle + 1;
		} else if (symbolLines[middle] > lineNumber) {
			top = middle - 1;
		} else if (symbolLines[middle] == lineNumber) {
			return middle;
		}
	}
	
	return middle;
}

- (int) indexOfStartOfLine: (NSUInteger) lineNumber {
	// Returns the symbol location of the symbol before the start of the line
	int symbol = [self indexOfSymbolOnLine: lineNumber];
	
	while (symbol >= 0 && symbolLines[symbol] >= lineNumber) symbol--;
	
	return symbol;
}

- (int) indexOfEndOfLine: (int) lineNumber {
	// Returns the symbol location of the symbol after the start of the line
	int symbol = [self indexOfSymbolOnLine: lineNumber];
	int nSymbols = (int) symbols.count;
	
	while (symbol >= 0 && symbolLines[symbol] >= lineNumber) symbol--;
	if (symbol < 0) symbol = 0;
	while (symbol < nSymbols && symbolLines[symbol] <= lineNumber) symbol++;
	
	return symbol;
}

#pragma mark - Adding and removing symbols

- (void) insertLineBeforeLine: (int) line {
	// Renumber lines as appropriate
	int firstSymbol = [self indexOfStartOfLine: line] + 1;
	int nSymbols = (int) symbols.count;
	int symbol;
	
#if IntelDebug
	NSLog(@"Intel: adding line before line %i (starting at symbol %i)", line, firstSymbol);
#endif
	
	for (symbol=firstSymbol; symbol<nSymbols; symbol++) {
		symbolLines[symbol]++;
	}
	
	[self intelFileHasChanged];
}

- (void) removeLines: (NSRange) lines {
	// Clear out the symbols for these lines
	[self clearSymbolsForLines: lines];
	
	// Change the location of the remaining lines
	int firstSymbol = [self indexOfStartOfLine: lines.location] + 1;
	int nSymbols = (int) symbols.count;
	int symbol;
	
#if IntelDebug
	NSLog(@"Intel: removing %i lines after line %i (starting at symbol %i)", lines.length, lines.location, firstSymbol);
#endif
	
	for (symbol=firstSymbol; symbol<nSymbols; symbol++) {
		symbolLines[symbol] -= lines.length;
	}
	
	[self intelFileHasChanged];
}

- (void) clearSymbolsForLines: (NSRange) lines {
	// These are EXCLUSIVE (remember?)
	int firstSymbol = [self indexOfStartOfLine: lines.location];
	int lastSymbol = [self indexOfStartOfLine: lines.location + lines.length] + 1;
	int nSymbols = (int) symbols.count;
	
	if (firstSymbol >= lastSymbol) {
		// Should never happen (aka the Programmer's Lament)
		NSLog(@"BUG: clearSymbols for line symbol %i > %i", firstSymbol, lastSymbol);
		NSLog(@"[IFIntelFile clearSymbolsForLines] failed");
		return;
	}
	
	// firstSymbol+1 == lastSymbol iff there are no symbols to remove
	if (firstSymbol+1 == lastSymbol)
		return;
	
#if IntelDebug
	NSLog(@"Clearing symbols for lines (%i-%i). Symbol range (%i-%i)", lines.location, lines.location+lines.length, firstSymbol, lastSymbol);
#endif
	
	// Remove symbols between firstSymbol and lastSymbol
	int x;
	
	// First remove from the list
	IFIntelSymbol* first = nil;
	if (firstSymbol >= 0) first = symbols[firstSymbol];
	
	for (x=firstSymbol+1; x<lastSymbol; x++) {
		IFIntelSymbol* thisSymbol = symbols[x];

#if IntelDebug
		NSLog(@"\tClearing symbol '%@' (line %i)", thisSymbol, symbolLines[x]);
#endif
		
		thisSymbol.nextSymbol = nil;
		thisSymbol.lastSymbol = nil;
	}
	
	IFIntelSymbol* last = nil;
	if (lastSymbol < symbols.count) last = symbols[lastSymbol];
	
	if (first) first.nextSymbol = last;
	if (last) last.lastSymbol = first;
	
	// Remove from the arrays
	[symbols removeObjectsInRange: NSMakeRange(firstSymbol+1, lastSymbol-(firstSymbol+1))];
	memmove(symbolLines + (firstSymbol+1), symbolLines + lastSymbol, sizeof(*symbolLines)*(nSymbols-(lastSymbol)));
	
	[self intelFileHasChanged];
}

- (void) addSymbol: (IFIntelSymbol*) newSymbol
			atLine: (int) line {
	int symbol = [self indexOfEndOfLine: line];
	int nSymbols = (int) symbols.count;
	
#if IntelDebug
	NSLog(@"Inserting symbol %@ at line %i (symbol location %i)", newSymbol, line, symbol);
#endif
	
	// Need to insert at symbol...
	symbolLines = realloc(symbolLines, sizeof(*symbolLines)*(nSymbols+1));
	memmove(symbolLines + symbol + 1, symbolLines + symbol, sizeof(*symbolLines)*(nSymbols - symbol));
	
	symbolLines[symbol] = line;
	[symbols insertObject: newSymbol
				  atIndex: symbol];
	
	// Adjust the symbol list
	if (symbol > 0)
		newSymbol.lastSymbol = symbols[symbol-1];
	else
		newSymbol.lastSymbol = nil;
	
	if (symbol < nSymbols)
		newSymbol.nextSymbol = symbols[symbol+1];
	else
		newSymbol.nextSymbol = nil;
	
	if (newSymbol.lastSymbol)
		newSymbol.lastSymbol.nextSymbol = newSymbol;
	if (newSymbol.nextSymbol)
		newSymbol.nextSymbol.lastSymbol = newSymbol;
	
	[self intelFileHasChanged];
}

#pragma mark - Debug

- (NSString*) description {
	NSMutableString* res = [NSMutableString string];
	
	[res appendFormat: @"<IFIntelFile %i symbols:", (int) symbols.count];
	
	int symbol;
	for (symbol=0; symbol<symbols.count; symbol++) {
		[res appendFormat: @"\n\tLine %i - %@", symbolLines[symbol], symbols[symbol]];
	}
	
	[res appendFormat: @">"];
	
	return res;
}

#pragma mark - Finding symbols

- (IFIntelSymbol*) nearestSymbolToLine: (int) line {
	int nSymbols = (int) symbols.count;
	int symbol = [self indexOfStartOfLine: line];
	
	// Special case: for the very first symbol in the file, there is no 'preceding symbol', so we would otherwise abort here
	if (nSymbols > 0 && symbol == -1 && symbolLines[0] == line) return symbols[0];
	
	if (symbol < 0) return nil;
	if (symbol >= nSymbols) return nil;
	if (symbol+1 == nSymbols) return symbols[symbol];
	if (symbolLines[symbol+1] == line) return symbols[symbol+1];
	
	return symbols[symbol];
}

- (IFIntelSymbol*) firstSymbolOnLine: (int) line {
	int nSymbols = (int) symbols.count;
	int symbol = [self indexOfStartOfLine: line];
	
	if (symbol < 0) return nil;
	if (symbol+1 >= nSymbols) return nil;
	if (symbolLines[symbol+1] != line) return nil;
	
	return symbols[symbol+1];
}

- (IFIntelSymbol*) lastSymbolOnLine: (int) line {
	int symbol = [self indexOfEndOfLine: line];
	
	if (symbol <= 0) return nil;
	if (symbolLines[symbol-1] != line) return nil;
	
	return symbols[symbol-1];
}

- (NSUInteger) lineForSymbol: (IFIntelSymbol*) symbolToFind {
	int symbol;
	int nSymbols = (int) symbols.count;
	
	for (symbol=0; symbol<nSymbols; symbol++) {
		if (symbols[symbol] == symbolToFind)
			return symbolLines[symbol];
	}
	
	return NSNotFound;
}

- (IFIntelSymbol*) firstSymbol {
    return symbols.firstObject;
}

- (void) intelFileHasChanged {
	if (!notificationPending) {
		notificationPending = YES;
		[self performSelector: @selector(finishNotifyingChange)
				   withObject: self
				   afterDelay: 2.0];
	}
}

- (void) finishNotifyingChange {
	[[NSNotificationCenter defaultCenter] postNotificationName: IFIntelFileHasChangedNotification
														object: self];
	notificationPending = NO;
}

@end
