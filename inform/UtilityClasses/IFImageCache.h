
#import <Cocoa/Cocoa.h>

@interface IFImageCache : NSObject {
}

+ (NSImage *)loadResourceImage:(NSString *)relativePath;

@end
