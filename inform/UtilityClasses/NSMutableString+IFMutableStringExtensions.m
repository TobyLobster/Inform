//
//  NSMutableString+IFMutableStringExtensions.m
//  Inform
//
//  Created by Toby Nelson on 05/02/2014.
//
//

#import "NSMutableString+IFMutableStringExtensions.h"

// *******************************************************************************************
@implementation NSMutableString (IFMutableStringExtensions)

-(void) replace:(NSString *) lpFind
           with:(NSString *) lpReplace
{
    NSRange lWholeRange = NSMakeRange(0, [self length]);
    if(lpReplace == nil ) lpReplace = @"";
    [self replaceOccurrencesOfString: lpFind
                          withString: lpReplace
                             options: (NSStringCompareOptions)0
                               range: lWholeRange];
}

@end
