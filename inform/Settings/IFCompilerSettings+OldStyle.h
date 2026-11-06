//
//  IFCompilerSettings+OldStyle.h
//  Inform
//
//  Reading a project's old-style Settings file, in Objective-C, as Swift can neither silence the
//  deprecation of NSUnarchiver nor catch the exception that a damaged archive raises.
//

#import "IFCompilerSettings.h"

NS_ASSUME_NONNULL_BEGIN

@interface IFCompilerSettings (OldStyle)

/// The settings in an old-style Settings file, archived with NSArchiver before Settings.plist,
/// or the default settings if they can't be read
+ (IFCompilerSettings*) settingsFromOldStyleData: (nullable NSData*) settingsData;

@end

NS_ASSUME_NONNULL_END
