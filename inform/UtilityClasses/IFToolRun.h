//
//  IFToolRun.h
//  Inform
//
//  Moved out of IFInBuild and IFInTest in November 2026.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

///
/// A run of one of Inform's tools, such as inbuild or intest, in the temporary folder. It waits for the tool to
/// finish, and keeps what it wrote.
///
@interface IFToolRun : NSObject

- (instancetype) init NS_UNAVAILABLE;
/// Runs the tool with the arguments given, and waits for it to finish
- (instancetype) initWithCommand: (nullable NSString*) command
                       arguments: (NSArray<NSString*>*) arguments NS_DESIGNATED_INITIALIZER;

/// What the tool wrote to stdout
@property (atomic, readonly, copy) NSData* standardOutput;
/// What the tool wrote to stderr
@property (atomic, readonly, copy) NSData* standardError;
/// The tool's exit code, or -1 if it couldn't be run, as when it isn't there, when stderr says why
@property (atomic, readonly) int exitCode;

@end

NS_ASSUME_NONNULL_END
