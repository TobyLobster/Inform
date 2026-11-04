//
//  NSMutableString+IFMutableStringExtensions.m
//  Inform
//
//  Created by Toby Nelson on 05/02/2014.
//
// String extensions inspired by http://benscheirman.com/2010/04/handy-categories-on-nsstring/
// and https://github.com/jwhitehorn/service_manual/blob/master/Service%20Manual/NSString%2BJRStringAdditions.m

#import "NSMutableString+IFMutableStringExtensions.h"

// *******************************************************************************************
@implementation NSMutableString (IFMutableStringExtensions)

-(void) replace:(NSString *) lpFind
           with:(NSString *) lpReplace
{
    NSRange lWholeRange = NSMakeRange(0, self.length);
    if(lpReplace == nil ) lpReplace = @"";
    [self replaceOccurrencesOfString: lpFind
                          withString: lpReplace
                             options: (NSStringCompareOptions)0
                               range: lWholeRange];
}

@end

