//
//  IFFindInFiles.h
//  Inform
//
//  Created by Toby Nelson in 2014.
//

#import <Cocoa/Cocoa.h>
#import "IFFindResult.h"
#import "IFProject.h"

typedef void (^IFFindInFilesProgressBlock)(int num, int total, int found);

extern NSObject *  gSearchLock;

@class IFExampleInfo;

///
/// NSTextView category that supports the new find dialog
///
@interface IFFindInFiles : NSObject

@property (atomic, getter=isSearching, readonly) BOOL searching;
@property (atomic, readonly) int resultsCount;
@property (atomic, readonly, copy) NSArray *results;
@property (atomic, readonly, strong) NSObject *searchResultsLock;

- (void) startFindInFilesWithPhrase: (NSString*)                    searchPhrase
                     withSearchType: (IFFindType)                   searchType
                        fromProject: (IFProject*)                   project
                      withLocations: (IFFindLocation)               locations
                  withProgressBlock: (IFFindInFilesProgressBlock)   progressBlock;

- (IFExampleInfo*) exampleInfoForRange:(NSRange) range;

// Utility functions
+ (NSString*) getContextFromText: (NSString*) textString
                    withLocation: (NSUInteger) location
                       andLength: (NSUInteger) matchLength
             findingContextRange: (NSRange*) rangeOut;

@end
