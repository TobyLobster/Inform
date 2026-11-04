//
//  NSString+IFStringExtensions.m
//  Inform
//
//  Created by Toby Nelson on 05/02/2014.
//
//

#import "NSString+IFStringExtensions.h"
#import "NSMutableString+IFMutableStringExtensions.h"

static NSCharacterSet* whitespace;
static NSCharacterSet* nonWhitespace;

// *******************************************************************************************
@implementation NSString (IFStringAdditions)

+(void) initialize {
    whitespace           = [NSCharacterSet whitespaceAndNewlineCharacterSet];
    nonWhitespace        = [NSCharacterSet whitespaceAndNewlineCharacterSet].invertedSet;
}

- (BOOL)containsSubstring:(NSString *) string
                  options:(NSStringCompareOptions) options
{
    NSRange range = [self rangeOfString:string options:options];
    return range.location != NSNotFound;
}

- (BOOL)containsSubstring:(NSString *) string
{
    return [self containsSubstring: string
                           options: (NSStringCompareOptions)0];
}

-(BOOL)endsWith:(NSString *)string
{
    return [self hasSuffix:string];
}

-(BOOL)endsWithCaseInsensitive:(NSString *)string
{
    return [self.lowercaseString hasSuffix:string.lowercaseString];
}

-(BOOL)startsWith:(NSString *)string
{
    return [self hasPrefix:string];
}

-(BOOL)startsWithCaseInsensitive:(NSString *)string
{
    return [self.lowercaseString hasPrefix:string.lowercaseString];
}

-(BOOL) isEqualToStringCaseInsensitive:(NSString *)string
{
    return [self caseInsensitiveCompare:string] == NSOrderedSame;
}

-(NSString *)substringFrom:(NSInteger)from to:(NSInteger)to
{
    NSString *rightPart = [self substringFromIndex:from];
    return [rightPart substringToIndex:to-from];
}

-(NSString *)stringByTrimmingWhitespace
{
    return [self stringByTrimmingCharactersInSet: whitespace];
}

-(NSString*) trailingWhitespace
{
    // Search backwards from the end of the string for a non-whitespace character
    for(NSInteger i = self.length - 1; i >= 0; i--) {
        if( ![whitespace characterIsMember: [self characterAtIndex:i]]) {
            return [self substringFromIndex:i+1];
        }
    }
    return self;
}

-(NSString*) leadingWhitespace
{
    // Find the first non-whitespace character
    NSRange first = [self rangeOfCharacterFromSet: nonWhitespace];
    if( first.location == NSNotFound) {
        return self;
    }
    return [self substringToIndex:first.location];
}

-(NSString*) stringByRemovingTrailingWhitespace
{
    NSString* trailing = self.trailingWhitespace;
    return [self substringToIndex: self.length - trailing.length];
}

-(NSString*) stringByRemovingLeadingWhitespace
{
    NSString* leading = self.leadingWhitespace;
    return [self substringFromIndex: leading.length];
}

-(NSString *)stringByTrimmingCharactersInString:(NSString*) charactersToTrim
{
    return [self stringByTrimmingCharactersInSet:[NSCharacterSet characterSetWithCharactersInString: charactersToTrim]];
}

-(NSString *) stringByReplacing:(NSString *) lpFind
                           with:(NSString *) lpReplace
{
    NSMutableString *lpMutableString = [NSMutableString stringWithString:self];
    NSRange lWholeRange = NSMakeRange(0, lpMutableString.length);
    
    [lpMutableString replaceOccurrencesOfString: lpFind
                                     withString: lpReplace
                                        options: (NSStringCompareOptions)0
                                          range: lWholeRange];
    
    return [NSString stringWithString:lpMutableString];
}

- (NSInteger) indexOf:(NSString *)text {
    NSRange range = [self rangeOfString:text];
    if ( range.length > 0 ) {
        return range.location;
    } else {
        return NSNotFound;
    }
}

- (NSInteger) lastIndexOf:(NSString *)text {
    NSRange range = [self rangeOfString: text options: NSBackwardsSearch];
    if ( range.length > 0 ) {
        return range.location;
    } else {
        return NSNotFound;
    }
}

- (NSString *) stringByAppendingPathComponents: (NSString *)strComponents {
    if(strComponents == nil) {
        return self;
    }
    NSArray *strArray = [strComponents componentsSeparatedByString:@"/"];

    NSString* work = self;
    for (int i = 0; i < strArray.count; i++) {
        work = [work stringByAppendingPathComponent: strArray[i]];
    }
    return work;
}

@end
