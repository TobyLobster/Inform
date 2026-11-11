//
//  IFTestReport.h
//  Inform
//
//  Moved out of IFProjectController in November 2026.
//

#import <Foundation/Foundation.h>
#import "IFCompiler.h"

@class IFSkeinItem;

NS_ASSUME_NONNULL_BEGIN

///
/// What goes into the reports intest makes as an extension project's test cases are run: the code for a problem the
/// compiler found, how far down the skein the story was played, and, when only one test case was run, its report as
/// the combined one
///
NS_SWIFT_UI_ACTOR
@interface IFTestReport : NSObject

- (instancetype) init NS_UNAVAILABLE;

/// The code a report gives a problem the compiler found, of the type given: "i6" for Inform 6's, "i7" for any other,
/// and nil for none
+ (nullable NSString*) intestCodeForProblemType: (ECompilerProblemType) problemType;

/// How many knots the story was played through to reach the knot given: it and those above it, apart from the root
+ (int) skeinNodesToItem: (nullable IFSkeinItem*) item;

/// Puts a copy of the report at the first URL at the second, in place of what's there, as the combined report when
/// only one test case was run. If something's there that can't be removed, the report isn't copied. Each failure is
/// logged
+ (void) copyReport: (NSURL*) reportURL
      toCombinedURL: (NSURL*) combinedReportURL;

@end

NS_ASSUME_NONNULL_END
