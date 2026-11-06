//
//  IFScanner.m
//  Inform
//
//  Created by Toby Nelson in 2014
//

#import "IFScanner.h"

@implementation IFScanner

/// Compiles a regular expression (nil if the pattern isn't one). Recent ones are kept, since Find All
/// and Find in Files search once for each match.
+(nullable NSRegularExpression*) regularExpression: (NSString*) pattern
                                          options: (NSRegularExpressionOptions) options {
    static NSCache<NSString*, NSRegularExpression*>* cache;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        cache = [[NSCache alloc] init];
        cache.countLimit = 16;
    });

    NSString* key = [NSString stringWithFormat: @"%lu:%@", (unsigned long) options, pattern];
    NSRegularExpression* regex = [cache objectForKey: key];
    if( regex == nil ) {
        regex = [NSRegularExpression regularExpressionWithPattern: pattern
                                                          options: options
                                                            error: NULL];
        if( regex != nil ) {
            [cache setObject: regex forKey: key];
        }
    }
    return regex;
}

+(NSRange) findNextMatch: (NSString*) phrase
                 storage: (NSString*) storage
                position: (NSUInteger) searchPosition
                 options: (IFFindType) searchType
        regexFoundGroups: (NSArray<NSString*>*__strong*) foundGroupsOut {

    NSStringCompareOptions options;
    NSRegularExpressionOptions regexOptions;
    NSRange range = NSMakeRange(NSNotFound, 0);
    bool found = false;
    if( foundGroupsOut != nil ) {
        *foundGroupsOut = nil;
    }

    int storageLength = (int) storage.length;
    
    if( searchType & IFFindCaseInsensitive ) {
        options = NSLiteralSearch | NSCaseInsensitiveSearch;
        regexOptions = NSRegularExpressionCaseInsensitive;
    }
    else {
        options = NSLiteralSearch;
        regexOptions = 0;
    }
    
    // Remove case insensitive flag, to be left with just the search type proper
    searchType = (IFFindType) (searchType & ~IFFindCaseInsensitive);

    // A pattern that isn't a regular expression gives nil, which finds nothing. ^ and $ match at the
    // start and end of each line, as the Find window's help says.
    NSRegularExpression* regex = nil;
    if( searchType == IFFindRegexp ) {
        regex = [self regularExpression: phrase options: regexOptions | NSRegularExpressionAnchorsMatchLines];
    }

    while (!found) {
        if( searchPosition >= storageLength ) {
            // Reached the end of the text - no more matches
            range = NSMakeRange(NSNotFound, 0);
            break;
        }

        if( searchType == IFFindRegexp ) {
            //
            // Search for a regex match. ^ doesn't match where the search starts unless a line starts there,
            // and \b sees the text before it.
            //
            NSTextCheckingResult* match = [regex firstMatchInString: storage
                                                            options: NSMatchingWithoutAnchoringBounds | NSMatchingWithTransparentBounds
                                                              range: NSMakeRange(searchPosition, storageLength - searchPosition)];
            range = (match != nil) ? match.range : NSMakeRange(NSNotFound, 0);
            //
            // Make array of any found groups, if required: the whole match, then each group
            // (an empty string if it took no part)
            //
            if( (foundGroupsOut != nil) && (match != nil) ) {
                NSMutableArray* array = [NSMutableArray arrayWithCapacity: match.numberOfRanges];
                for( NSUInteger group = 0; group < match.numberOfRanges; group++ ) {
                    NSRange groupRange = [match rangeAtIndex: group];
                    [array addObject: (groupRange.location == NSNotFound) ? @"" : [storage substringWithRange: groupRange]];
                }
                *foundGroupsOut = array;
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
                        
                        if (![[NSCharacterSet alphanumericCharacterSet] characterIsMember: chr]) {
                            // Is preceded by a character that is not a letter, accent or digit, so is a word
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
                            
                            if (![[NSCharacterSet alphanumericCharacterSet] characterIsMember: chr]) {
                                // Is followed by a character that is not a letter, accent or digit, so is a word
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

    // Not the groups of a match of no characters passed over on the way
    if( (foundGroupsOut != nil) && (range.location == NSNotFound) ) {
        *foundGroupsOut = nil;
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
    NSArray<NSString*>* lastGroups = nil;
    NSRange result;
    NSUInteger currentPosition = 0;

    // Brute force: search from the start until we reach our search position, then use the last match found
    do {
        NSArray<NSString*>* groups = nil;
        result = [self findNextMatch: phrase
                             storage: storage
                            position: currentPosition
                             options: searchType
                    regexFoundGroups: (foundGroupsOut != nil) ? &groups : nil];

        if( (result.location == NSNotFound) || (result.location > searchPosition) ) {
            break;
        }
        lastResult = result;
        lastGroups = groups;
        NSAssert(result.location == NSNotFound || result.length > 0, @"Found match of length zero");
        currentPosition = result.location + 1;
    }
    while( true );

    // The groups of the match found, not of the one after it
    if( foundGroupsOut != nil ) {
        *foundGroupsOut = lastGroups;
    }

    NSAssert(lastResult.location == NSNotFound || lastResult.length > 0, @"Found match of length zero");
    return lastResult;
}

@end
