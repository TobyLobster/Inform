//
//  IFIntelFile.h
//  Inform
//
//  Created by Andrew Hunter on 05/02/2005.
//  Copyright 2005 Andrew Hunter. All rights reserved.
//

#import <Cocoa/Cocoa.h>

#import "IFIntelSymbol.h"

extern NSString* IFIntelFileHasChangedNotification;

//
// 'Intelligence' data for a file.
// Basically, maintains a linked list of symbols gathered from a file.
//
// Contains the details stored about a file, and the means to access them
//
@interface IFIntelFile : NSObject {
	// Data
	NSMutableArray* symbols;	// List of symbols added to the file
	int* symbolLines;			// We access this a lot: C-style array is faster. The line number each symbol in the symbols array occurs on (ie, one entry per symbol)
	
	// Notifications
	BOOL notificationPending;	// YES if we're preparing to send a notification that this object has changed
}

// Adding and removing symbols
- (void) insertLineBeforeLine: (int) line;					// Updates the symbol list as if someone has inserted a new line before the given line
- (void) removeLines: (NSRange) lines;						// Removes lines and symbols in the given range (ie, update the symbol locations as if the user had deleted the given range of lines)
- (void) clearSymbolsForLines: (NSRange) lines;				// Removes symbols for the given range of lines

- (void) addSymbol: (IFIntelSymbol*) symbol					// Adds a new symbol at the given line number
			atLine: (int) line;

// Finding symbols
- (IFIntelSymbol*) firstSymbol;								// First symbol stored in this object
- (IFIntelSymbol*) nearestSymbolToLine: (int) line;			// Nearest symbol to a given line number (first symbol on the line if there are any symbols for that line, or the first symbol on the line before if not)
- (IFIntelSymbol*) firstSymbolOnLine: (int) line;			// nil if there are no symbols for the given line, or the first symbol for that line otherwise
- (IFIntelSymbol*) lastSymbolOnLine: (int) line;			// nil if there are no symbols for the given line, or the last symbol for that line otherwise
- (int) lineForSymbol: (IFIntelSymbol*) symbolToFind;		// Given a symbol, works out which line number it occurs on

// Sending notifications
- (void) intelFileHasChanged;								// Requests that a notification be sent that this object has changed

@end
