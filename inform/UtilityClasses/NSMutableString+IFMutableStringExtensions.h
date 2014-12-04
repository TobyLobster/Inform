//
//  NSMutableString+IFMutableStringExtensions.h
//  Inform
//
//  Created by Toby Nelson on 05/02/2014.
//
// String extensions inspired by http://benscheirman.com/2010/04/handy-categories-on-nsstring/
// and https://github.com/jwhitehorn/service_manual/blob/master/Service%20Manual/NSString%2BJRStringAdditions.m

#import <Cocoa/Cocoa.h>

// *******************************************************************************************
@interface NSMutableString (IFMutableStringExtensions)

-(void) replace:(NSString *) lpFind
           with:(NSString *) lpReplace;

@end
