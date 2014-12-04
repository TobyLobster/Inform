//
//  IFImageCahce.m
//  Inform
//
//  Created by Toby Nelson in 2014
//

#import "IFImageCache.h"
#import <Foundation/NSCache.h>
#import "NSBundle+IFBundleExtensions.h"

static NSCache *imageCache = nil;

@implementation IFImageCache

// Class initialize the cache - get's called implicitly automatically on startup
+ (void)initialize {
    if (self == [IFImageCache class]) {
        imageCache = [[NSCache alloc] init];
        //[imageCache setCountLimit:40];
    }
}

// Class dealloc - called explicitly from app delegate
+(void) dealloc {
    [imageCache release];
    imageCache = nil;
}

// We first look in the cache; if that fails, we create a new NSImage and put that in the cache.
+ (NSImage *)loadResourceImage:(NSString *)relativePath {
    NSImage *image = [imageCache objectForKey:relativePath];
    if (!image) {
        // Cache miss, get image
        NSString *path = [[NSBundle mainBundle] pathForResourcePath:relativePath];
        image = [[[NSImage alloc] initByReferencingFile:path] autorelease];

        if (image) {	// Insert image in cache
            [imageCache setObject:image forKey:relativePath];
        }
    }
    return image;
}

@end
