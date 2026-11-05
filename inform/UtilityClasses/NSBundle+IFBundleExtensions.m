//
//  NSBundle+IFBundleExtensions.m
//  Inform
//
//  Created by Toby Nelson on 05/02/2014.
//
//

#import "NSBundle+IFBundleExtensions.h"

// *******************************************************************************************
@implementation NSBundle (IFBundleExtensions)
+(BOOL) customLoadNib:(NSString *)nibName owner:(id)owner
{
    return [[NSBundle mainBundle] loadNibNamed: nibName
                                         owner: owner
                               topLevelObjects: nil];
}

@end
