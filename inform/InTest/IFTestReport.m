//
//  IFTestReport.m
//  Inform
//
//  Moved out of IFProjectController in November 2026.
//

#import "IFTestReport.h"
#import "IFSkeinItem.h"

@implementation IFTestReport

+ (NSString*) intestCodeForProblemType: (ECompilerProblemType) problemType {
    NSString* intestCode = nil;

    // Convert our problem type into an intest error code
    switch( problemType ) {
        case EProblemTypeNone:
        {
            break;
        }
        case EProblemTypeInform6:
        {
            intestCode = @"i6";
            break;
        }
        case EProblemTypeInform7:
        {
            intestCode = @"i7";
            break;
        }
        case EProblemTypeCBlorb:
        {
            intestCode = @"i7";
            break;
        }
        case EProblemTypeUnknown:
        {
            intestCode = @"i7";
            break;
        }
    }

    return intestCode;
}

+ (int) skeinNodesToItem: (IFSkeinItem*) activeItem {
    int skeinNodes = 0;
    while( (activeItem != nil) && (activeItem.parent != nil) ) {
        activeItem = activeItem.parent;
        skeinNodes++;
    }
    return skeinNodes;
}

+ (void) copyReport: (NSURL*) reportURL
      toCombinedURL: (NSURL*) combinedReportURL {
    // Copy from reportURL to combinedReportURL
    NSFileManager *fm = [NSFileManager defaultManager];
    NSError* err;
    if( [fm removeItemAtURL:combinedReportURL error: &err] ) {
        if (![fm copyItemAtURL:reportURL
                         toURL:combinedReportURL
                         error: &err] )
        {
            NSLog(@"Error copying file %@",err.localizedDescription);
        }
    }
    else {
        NSLog(@"Error removing file %@",err.localizedDescription);
    }
}

@end
