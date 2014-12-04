//
//  NSString+IFStringExtensions.m
//  Inform
//
//  Created by Toby Nelson on 05/02/2014.
//
//

#import "NSString+IFStringExtensions.h"

// *******************************************************************************************
@implementation NSString (IFStringAdditions)

- (BOOL)containsString:(NSString *)string
               options:(NSStringCompareOptions)options
{
    NSRange rng = [self rangeOfString:string options:options];
    return rng.location != NSNotFound;
}

- (BOOL)containsString:(NSString *)string
{
    return [self containsString:string options:(NSStringCompareOptions)0];
}

-(BOOL)endsWith:(NSString *)string
{
    return [self hasSuffix:string];
}

-(BOOL)startsWith:(NSString *)string
{
    return [self hasPrefix:string];
}

-(BOOL) isEqualToStringCaseInsensitive:(NSString *)string
{
    return [self caseInsensitiveCompare:string] == 0;
}

-(NSString *)substringFrom:(NSInteger)from to:(NSInteger)to
{
    NSString *rightPart = [self substringFromIndex:from];
    return [rightPart substringToIndex:to-from];
}

-(NSString *)stringByTrimmingWhitespace
{
    return [self stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
}

-(NSString *) stringByReplacing:(NSString *) lpFind
                           with:(NSString *) lpReplace
{
    NSMutableString *lpMutableString = [NSMutableString stringWithString:self];
    NSRange lWholeRange = NSMakeRange(0, [lpMutableString length]);
    
    [lpMutableString replaceOccurrencesOfString: lpFind
                                     withString: lpReplace
                                        options: (NSStringCompareOptions)0
                                          range: lWholeRange];
    
    return [NSString stringWithString:lpMutableString];
}


@end
