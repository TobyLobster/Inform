//
//  NSMutableString+IFMutableStringExtensions.h
//  Inform
//
//  Created by Toby Nelson on 05/02/2014.
//

#import <Cocoa/Cocoa.h>

// *******************************************************************************************
@interface NSMutableString (IFMutableStringExtensions)

-(void) replace:(NSString *) lpFind
           with:(NSString *) lpReplace;

@end
