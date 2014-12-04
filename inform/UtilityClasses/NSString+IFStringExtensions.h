//
//  NSString+IFStringExtensions.h
//  Inform
//
//  Created by Toby Nelson on 05/02/2014.
//
// String extensions inspired by http://benscheirman.com/2010/04/handy-categories-on-nsstring/
// and https://github.com/jwhitehorn/service_manual/blob/master/Service%20Manual/NSString%2BJRStringAdditions.m

#import <Cocoa/Cocoa.h>

// *******************************************************************************************
@interface NSString (IFStringAdditions)

- (BOOL)containsString:(NSString *)string;
- (BOOL)containsString:(NSString *)string
               options:(NSStringCompareOptions)options;

-(BOOL)endsWith:(NSString *)string;
-(BOOL)startsWith:(NSString *)string;
-(BOOL) isEqualToStringCaseInsensitive:(NSString *)string;

-(NSString *)substringFrom:(NSInteger)from
                        to:(NSInteger)to;

-(NSString *)stringByTrimmingWhitespace;

-(NSString *) stringByReplacing:(NSString *) lpFind
                           with:(NSString *) lpReplace;

@end
