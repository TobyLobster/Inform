//
//  IFScanner.m
//  Inform
//
//  Created by Toby Nelson in 2014
//

#import "IFScanner.h"
#import "Regex.h"
#include <wctype.h>

@implementation IFScanner

+(NSRange) findNextMatch: (NSString*) phrase
                 storage: (NSString*) storage
                position: (NSUInteger) searchPosition
                 options: (IFFindType) searchType
        regexFoundGroups: (NSArray<NSString*>*__strong*) foundGroupsOut {

    NSStringCompareOptions options;
    RKLRegexOptions regexOptions;
    NSRange range = NSMakeRange(NSNotFound, 0);
    bool found = false;
    if( foundGroupsOut != nil ) {
        *foundGroupsOut = nil;
    }

    int storageLength = (int) storage.length;
    
    if( searchType & IFFindCaseInsensitive ) {
        options = NSLiteralSearch | NSCaseInsensitiveSearch;
        regexOptions = RKLCaseless;
    }
    else {
        options = NSLiteralSearch;
        regexOptions = RKLNoOptions;
    }
    
    // Remove case insensitive flag, to be left with just the search type proper
    searchType = (IFFindType) (searchType & ~IFFindCaseInsensitive);

    while (!found) {
        if( searchPosition >= storageLength ) {
            // Reached the end of the text - no more matches
            range = NSMakeRange(NSNotFound, 0);
            break;
        }

        if( searchType == IFFindRegexp ) {
            //
            // Search for a regex match
            //
            range = [storage rangeOfRegex: phrase
                                  options: regexOptions
                                  inRange: NSMakeRange(searchPosition, storageLength - searchPosition)
                                  capture: 0L
                                    error: NULL];
            //
            // Make array of any found groups, if required
            //
            if( foundGroupsOut != nil ) {
                NSError* error;
                NSArray* array = [storage captureComponentsMatchedByRegex: phrase
                                                                  options: regexOptions
                                                                    range: NSMakeRange(searchPosition, storageLength - searchPosition)
                                                                    error: &error];
                if( array.count > 0 ) {
                    *foundGroupsOut = array;
                }
            }
        } else {
            //
            // Standard, non-regex search
            //
            range = [storage rangeOfString: phrase
                                   options: options
                                     range: NSMakeRange(searchPosition, storageLength - searchPosition)];
        }
        
        if( range.location == NSNotFound ) {
            // Not found
            break;
        }

        //
        // We ignore any zero length results
        //
        if( range.length > 0 ) {
            //
            // Check for start / end of word conditions, if required
            //
            bool startOfWord = false;
            bool endOfWord = false;

            switch( searchType ) {
                case IFFindBeginsWith:
                case IFFindCompleteWord:
                {
                    // Check if we are at the start of a word...
                    if (range.location != 0) {
                        unichar chr = [storage characterAtIndex: range.location-1];
                        
                        if (!iswalnum(chr)) {
                            // Is preceded by non-alphabetic character, so is a word
                            startOfWord = true;
                        }
                    } else {
                        // At start: is the start of a word
                        startOfWord = true;
                    }

                    // Have we found a start of word match?
                    if( searchType == IFFindBeginsWith ) {
                        if( startOfWord ) {
                            found = true;
                            break;
                        }
                    }

                    if( (searchType == IFFindCompleteWord) && startOfWord ) {
                        // For a complete word match, we must check if we are also at the end of a word...
                        if((range.location + range.length) < storageLength) {
                            unichar chr = [storage characterAtIndex: range.location + range.length];
                            
                            if (!iswalnum(chr)) {
                                // Is followed by non-alphabetic character, so is a word
                                endOfWord = true;
                            }
                        }
                        else {
                            endOfWord = true;
                        }
                        
                        // Have we found a whole word match?
                        if( endOfWord ) {
                            found = true;
                            break;
                        }
                    }
                    break;
                }

                case IFFindContains:
                case IFFindRegexp:
                default:
                {
                    // No extra checks required here, we have found a match
                    found = true;
                    break;
                }
            }
        }
        searchPosition = range.location + 1;
        NSAssert(searchPosition <= storageLength, @"Parsed too far in storage for search?");
    }

    NSAssert(range.location == NSNotFound || range.length > 0, @"Found match of length zero");
    return range;
}

+(NSRange) findPreviousMatch: (NSString*) phrase
                     storage: (NSString*) storage
                    position: (NSUInteger) searchPosition
                     options: (IFFindType) searchType
            regexFoundGroups: (NSArray<NSString*>*__strong*) foundGroupsOut {
    NSRange lastResult = NSMakeRange(NSNotFound, 0);
    NSRange result;
    NSUInteger currentPosition = 0;
    if( foundGroupsOut != nil ) {
        *foundGroupsOut = nil;
    }

    // Brute force: search from the start until we reach our search position, then use the last match found
    do {
        result = [self findNextMatch: phrase
                             storage: storage
                            position: currentPosition
                             options: searchType
                    regexFoundGroups: foundGroupsOut];

        if( (result.location == NSNotFound) || (result.location > searchPosition) ) {
            break;
        }
        lastResult = result;
        NSAssert(result.location == NSNotFound || result.length > 0, @"Found match of length zero");
        currentPosition = result.location + 1;
    }
    while( true );

    NSAssert(lastResult.location == NSNotFound || lastResult.length > 0, @"Found match of length zero");
    return lastResult;
}

@end
