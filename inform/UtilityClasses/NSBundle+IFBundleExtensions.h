//
//  NSBundle+IFBundleExtensions.h
//  Inform
//
//  Created by Toby Nelson on 05/02/2014.
//

#import <Cocoa/Cocoa.h>

// *******************************************************************************************
NS_ASSUME_NONNULL_BEGIN

@interface NSBundle (IFBundleExtensions)
+(BOOL) customLoadNib:(NSString *)nibName owner:(nullable id)owner;

@end

NS_ASSUME_NONNULL_END
