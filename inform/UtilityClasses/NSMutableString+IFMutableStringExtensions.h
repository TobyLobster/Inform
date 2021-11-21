//
//  NSMutableString+IFMutableStringExtensions.h
//  Inform
//
//  Created by Toby Nelson on 05/02/2014.
//

#import <Cocoa/Cocoa.h>

NS_ASSUME_NONNULL_BEGIN
// *******************************************************************************************
@interface NSMutableString (IFMutableStringExtensions)

-(void) replace:(NSString *) lpFind
           with:(nullable NSString *) lpReplace;

@end

NS_ASSUME_NONNULL_END
