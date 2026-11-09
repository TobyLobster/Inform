//
//  IFCompileCheck.m
//  Inform
//
//  Moved out of IFProjectController in November 2026.
//

#import "IFCompileCheck.h"

@implementation IFCompileCheck {
    BOOL testCaseChangedSinceLastSuccessfulCompile;
}

- (instancetype) init {
    self = [super init];

    if (self) {
        testCaseChangedSinceLastSuccessfulCompile = YES;
    }

    return self;
}

- (void) testCaseDidChange {
    testCaseChangedSinceLastSuccessfulCompile = YES;
}

- (void) compileDidSucceed {
    testCaseChangedSinceLastSuccessfulCompile = NO;
}

- (BOOL) timestampsInChronologicalOrder: (NSURL*) first
                                 second: (NSURL*) second {
    // If the datestamps both exist, and the first timestamp is earlier or equal to the second.
    NSDictionary*  firstAttributes = [[NSFileManager defaultManager] attributesOfItemAtPath: first.path  error: NULL];
    NSDictionary* secondAttributes = [[NSFileManager defaultManager] attributesOfItemAtPath: second.path error: NULL];

    if( firstAttributes && secondAttributes ) {
        NSDate* firstDate  = firstAttributes[NSFileModificationDate];
        NSDate* secondDate = secondAttributes[NSFileModificationDate];

        // Note that datestamps are only recorded to the second.
        if( [firstDate compare: secondDate] != NSOrderedDescending ) {
            return YES;
        }
    }
    return NO;
}

- (BOOL) needsCompileForcing: (BOOL) force
               alwaysCompile: (BOOL) alwaysCompile
              unsavedChanges: (BOOL) unsavedChanges
                   sourceURL: (NSURL*) sourceURL
                 settingsURL: (NSURL*) settingsURL
                   outputURL: (NSURL*) outputURL {
    BOOL needsToCompile = force;

    // If the debug setting to always compile is switched on, then always compile
    if(( !needsToCompile) && alwaysCompile) {
        needsToCompile = YES;
    }

    // If the document has unsaved changes, always save and compile
    if( !needsToCompile && unsavedChanges ) {
        needsToCompile = YES;
    }

    // If we have changed test case in an extension project, always save and compile
    if( !needsToCompile && testCaseChangedSinceLastSuccessfulCompile ) {
        needsToCompile = YES;
    }

    if( !needsToCompile ) {
        // If the source timestamp is later than the output timestamp, then we need to compile
        needsToCompile = ![self timestampsInChronologicalOrder: sourceURL
                                                        second: outputURL];

        if( !needsToCompile ) {
            // If the settings timestamp is later than the output timestamp, then we need to compile
            needsToCompile = ![self timestampsInChronologicalOrder: settingsURL
                                                            second: outputURL];
        }
    }

    return needsToCompile;
}

@end
