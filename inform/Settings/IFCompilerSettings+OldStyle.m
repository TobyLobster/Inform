//
//  IFCompilerSettings+OldStyle.m
//  Inform
//
//  Moved from IFProjectFile.m in November 2026.
//

#import "IFCompilerSettings+OldStyle.h"

@implementation IFCompilerSettings (OldStyle)

+ (IFCompilerSettings*) settingsFromOldStyleData: (NSData*) settingsData {
	NSString* creator = nil;
	int version = -1;
	IFCompilerSettings* settings = nil;

	@try {
		// It was written with NSArchiver, which is deprecated, but only NSUnarchiver can read it
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
		NSUnarchiver* theCoder = [[NSUnarchiver alloc] initForReadingWithData: settingsData];
#pragma clang diagnostic pop

		// Decode the file
		creator = [theCoder decodeObject];
		[theCoder decodeValueOfObjCType: @encode(int) at: &version size:sizeof(int)];
		settings = [theCoder decodeObject];
	} @catch (NSException* exception) {
		// A damaged archive raises
		NSLog(@"Could not read old-style settings: %@", exception.reason);
	}

	if (creator == nil || version != 1 || settings == nil) {
		// We don't understand this file
		return [[IFCompilerSettings alloc] init];
	}

	return settings;
}

@end
