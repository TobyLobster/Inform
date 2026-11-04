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
-(NSString *) pathForResourcePath: (NSString *) relativePath {
    NSString* fullPath = [[NSBundle mainBundle] pathForResource: relativePath.lastPathComponent.stringByDeletingPathExtension
                                                         ofType: relativePath.pathExtension
                                                    inDirectory: relativePath.stringByDeletingLastPathComponent];
    if( fullPath == nil ) {
        NSLog(@"WARNING: Could not find resource at %@", relativePath);
    }
    return fullPath;
}

+(BOOL) customLoadNib:(NSString *)nibName owner:(id)owner
{
    return [[NSBundle mainBundle] loadNibNamed: nibName
                                         owner: owner
                               topLevelObjects: nil];
}

@end
