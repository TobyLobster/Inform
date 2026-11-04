//
//  NSBundle+IFBundleExtensions.h
//  Inform
//
//  Created by Toby Nelson on 05/02/2014.
//

#import <Cocoa/Cocoa.h>

// *******************************************************************************************
@interface NSBundle (IFBundleExtensions)
-(NSString *) pathForResourcePath: (NSString *) relativePath;
+(BOOL) customLoadNib:(NSString *)nibName owner:(id)owner;

@end
