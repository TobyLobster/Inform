//
//  IFSkeinBlessButton.h
//  Inform
//
//  Created by Toby Nelson in 2015
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

//
// Represents a bless/curse button on the report view in the skein
//
@interface IFSkeinBlessButton : NSButton

@property (atomic) BOOL blessState;

-(void) toggleBlessState;

@end

NS_ASSUME_NONNULL_END
