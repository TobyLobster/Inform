//
//  IFExtensionFileFinder.h
//  Inform
//
//  Moved out of IFProjectController in November 2026.
//

#import <Foundation/Foundation.h>

@class IFExtensionsManager;

NS_ASSUME_NONNULL_BEGIN

///
/// Finds the file of an extension that a source link or a search names: in full, if the file is there, or as its
/// author's name and its file's name ("Emily Short/Locksmith.i7x", in any case), among that author's extensions.
///
@interface IFExtensionFileFinder : NSObject

- (instancetype) init NS_UNAVAILABLE;

/// The file of the extension with this name, or nil if there's none
+ (nullable NSString*) fileForExtension: (NSString*) filename
                      extensionsManager: (IFExtensionsManager*) extensionsManager NS_SWIFT_UI_ACTOR;

@end

NS_ASSUME_NONNULL_END
