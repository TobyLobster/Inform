//
//  IFFindInFiles.h
//  Inform
//
//  Created by Toby Nelson in 2014.
//

#import <Cocoa/Cocoa.h>
#import "IFFindResult.h"
#import "IFProject.h"

NS_ASSUME_NONNULL_BEGIN

typedef void (NS_SWIFT_UI_ACTOR ^IFFindInFilesProgressBlock)(int num, int total, int found);

///
/// Find in Files: searches a project's source, the extensions and the documentation, on another thread
///
@interface IFFindInFiles : NSObject

@property (atomic, readonly) int resultsCount;
@property (atomic, readonly, copy) NSArray<IFFindResult*> *results;
@property (atomic, readonly, strong) NSObject *searchResultsLock;

- (void) startFindInFilesWithPhrase: (NSString*)                    searchPhrase
                     withSearchType: (IFFindType)                   searchType
                        fromProject: (IFProject*)                   project
                      withLocations: (IFFindLocation)               locations
                  withProgressBlock: (IFFindInFilesProgressBlock)   progressBlock NS_SWIFT_UI_ACTOR;

// Utility functions
+ (NSString*) getContextFromText: (NSString*) textString
                    withLocation: (NSUInteger) location
                       andLength: (NSUInteger) matchLength
             findingContextRange: (NSRange*) rangeOut;

@end

NS_ASSUME_NONNULL_END
