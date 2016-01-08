//
//  IFScanner.h
//  Inform
//
//  Created by Toby Nelson in 2014.
//

#import <Cocoa/Cocoa.h>
#import "IFFindResult.h"

///
/// Searches through a string to find a match for a search pattern
///
@interface IFScanner : NSObject {
}

+(NSRange) findNextMatch: (NSString*) phrase
                 storage: (NSString*) storage
                position: (NSUInteger) searchPosition
                 options: (IFFindType) searchType
        regexFoundGroups: (NSArray*__strong*) foundGroupsOut;

+(NSRange) findPreviousMatch: (NSString*) phrase
                     storage: (NSString*) storage
                    position: (NSUInteger) searchPosition
                     options: (IFFindType) searchType
            regexFoundGroups: (NSArray*__strong*) foundGroupsOut;

@end
