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

@class IFSyntaxData;

///
/// Class to gather intelligence data on Natural Inform files
///
@interface IFNaturalIntel : NSObject<IFSyntaxIntelligence>

/// Hacky way to enable/disable indentation and other rewriting while undoing
+ (void) disableIndentation;
+ (void) enableIndentation;

@end
