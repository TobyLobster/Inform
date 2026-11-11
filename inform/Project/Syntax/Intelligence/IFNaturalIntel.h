//
//  IFNaturalIntel.h
//  Inform
//
//  Created by Andrew Hunter on 05/02/2005.
//  Copyright 2005 Andrew Hunter. All rights reserved.
//

#import <Cocoa/Cocoa.h>

#import "IFIntelFile.h"
#import "IFSyntaxTypes.h"

NS_ASSUME_NONNULL_BEGIN

@class IFSyntaxData;

///
/// Class to gather intelligence data on Natural Inform files
///
NS_SWIFT_UI_ACTOR
@interface IFNaturalIntel : NSObject<IFSyntaxIntelligence>
@end

NS_ASSUME_NONNULL_END
