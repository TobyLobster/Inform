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

typedef void (^IFFindInFilesProgressBlock)(int num, int total, int found);

///
/// NSTextView category that supports the new find dialog
///
@interface IFFindInFiles : NSObject

@property (atomic, readonly) int resultsCount;
@property (atomic, readonly, copy) NSArray<IFFindResult*> *results;
@property (atomic, readonly, strong) NSObject *searchResultsLock;

- (void) startFindInFilesWithPhrase: (NSString*)                    searchPhrase
                     withSearchType: (IFFindType)                   searchType
                        fromProject: (IFProject*)                   project
                      withLocations: (IFFindLocation)               locations
                  withProgressBlock: (IFFindInFilesProgressBlock)   progressBlock;

// Utility functions
+ (NSString*) getContextFromText: (NSString*) textString
                    withLocation: (NSUInteger) location
                       andLength: (NSUInteger) matchLength
             findingContextRange: (NSRange*) rangeOut;

@end

NS_ASSUME_NONNULL_END
