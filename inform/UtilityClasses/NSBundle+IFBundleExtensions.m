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
    NSString* fullPath = [[NSBundle mainBundle] pathForResource: [[relativePath lastPathComponent] stringByDeletingPathExtension]
                                                         ofType: [relativePath pathExtension]
                                                    inDirectory: [relativePath stringByDeletingLastPathComponent]];
    if( fullPath == nil ) {
        NSLog(@"WARNING: Could not find resource at %@", relativePath);
    }
    return fullPath;
}

+(BOOL) oldLoadNibNamed:(NSString *)nibName owner:(id)owner
{
    // I've isolated this deprecated function here (so we only get one compiler warning). To be removed at a later date.
    return [NSBundle loadNibNamed: nibName owner: owner];
}

@end
