//
//  NSString+IFStringExtensions.h
//  Inform
//
//  Created by Toby Nelson on 05/02/2014.
//
// String extensions inspired by http://benscheirman.com/2010/04/handy-categories-on-nsstring/
// and https://github.com/jwhitehorn/service_manual/blob/master/Service%20Manual/NSString%2BJRStringAdditions.m
// and http://stackoverflow.com/questions/256460/nsstring-indexof-in-objective-c

#import <Cocoa/Cocoa.h>

// *******************************************************************************************
@interface NSString (IFStringAdditions)

- (BOOL)containsSubstring: (NSString *) string;
- (BOOL)containsSubstring: (NSString *) string
                  options: (NSStringCompareOptions) options;

-(BOOL) endsWith: (NSString *) string;
-(BOOL) startsWith: (NSString *) string;
-(BOOL) endsWithCaseInsensitive: (NSString *) string;
-(BOOL) startsWithCaseInsensitive: (NSString *) string;
-(BOOL) isEqualToStringCaseInsensitive: (NSString *) string;

-(NSString*) substringFrom: (NSInteger)from
                        to: (NSInteger)to;

@property (NS_NONATOMIC_IOSONLY, readonly, copy) NSString *stringByTrimmingWhitespace;
@property (NS_NONATOMIC_IOSONLY, readonly, copy) NSString *trailingWhitespace;
@property (NS_NONATOMIC_IOSONLY, readonly, copy) NSString *leadingWhitespace;
@property (NS_NONATOMIC_IOSONLY, readonly, copy) NSString *stringByRemovingLeadingWhitespace;
@property (NS_NONATOMIC_IOSONLY, readonly, copy) NSString *stringByRemovingTrailingWhitespace;

-(NSString*) stringByTrimmingCharactersInString: (NSString*) charactersToTrim;

-(NSString*) stringByReplacing: (NSString *) lpFind
                          with: (NSString *) lpReplace;

- (NSInteger) indexOf: (NSString *) text;
- (NSInteger) lastIndexOf: (NSString *) text;
- (NSString *) stringByAppendingPathComponents: (NSString *)strComponents;

@end
