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
@interface IFFindInFiles : NSObject {
    BOOL            searching;
    NSMutableArray* searchItems;
    NSMutableArray* results;
    NSDictionary*   exampleInfo;
    NSArray*        codeInfo;
    NSArray*        definitionInfo;

    NSObject *      searchLock;
    NSObject *      searchItemsLock;
    NSObject *      searchResultsLock;
}

- (void) startFindInFilesWithPhrase: (NSString*)                    searchPhrase
                     withSearchType: (IFFindType)                   searchType
                        fromProject: (IFProject*)                   project
                      withLocations: (IFFindLocation)               locations
                  withProgressBlock: (IFFindInFilesProgressBlock)   progressBlock;
- (BOOL) isSearching;
- (int) resultsCount;
- (NSArray*) results;
- (NSObject*) searchResultsLock;
- (IFExampleInfo*) exampleInfoForRange:(NSRange) range;

// Utility functions
+ (NSString*) getContextFromText: (NSString*) textString
                    withLocation: (int) location
                       andLength: (int) matchLength
             findingContextRange: (NSRange*) rangeOut;

@end
