//
//  IFIntelFile.h
//  Inform
//
//  Created by Andrew Hunter on 05/02/2005.
//  Copyright 2005 Andrew Hunter. All rights reserved.
//

#import <Cocoa/Cocoa.h>

NS_ASSUME_NONNULL_BEGIN

@class IFIntelSymbol;

static NSNotificationName const IFIntelFileHasChangedNotification = @"IFIntelFileHasChangedNotification";

///
/// 'Intelligence' data for a file.
/// Basically, maintains a linked list of symbols gathered from a file.
///
/// Contains the details stored about a file, and the means to access them
///
@interface IFIntelFile : NSObject

// Adding and removing symbols
/// Updates the symbol list as if someone has inserted a new line before the given line
- (void) insertLineBeforeLine: (int) line;
/// Removes lines and symbols in the given range (ie, update the symbol locations as if the user had deleted the given range of lines)
- (void) removeLines: (NSRange) lines;
/// Removes symbols for the given range of lines
- (void) clearSymbolsForLines: (NSRange) lines;

/// Adds a new symbol at the given line number
- (void) addSymbol: (IFIntelSymbol*) symbol
			atLine: (int) line;

// Finding symbols
/// First symbol stored in this object
@property (nonatomic, readonly, strong, nullable) IFIntelSymbol *firstSymbol;
/// Nearest symbol to a given line number (first symbol on the line if there are any symbols for that line, or the first symbol on the line before if not)
- (nullable IFIntelSymbol*) nearestSymbolToLine: (int) line;
/// Given a symbol, works out which line number it occurs on
- (NSUInteger) lineForSymbol: (nullable IFIntelSymbol*) symbolToFind;

// Sending notifications
/// Requests that a notification be sent that this object has changed
- (void) intelFileHasChanged;

@end

NS_ASSUME_NONNULL_END
