//
//  IFOutputSettings.h
//  Inform
//
//  Created by Andrew Hunter on 10/10/2004.
//  Copyright 2004 Andrew Hunter. All rights reserved.
//

#import <Cocoa/Cocoa.h>

#import "IFSetting.h"

///
/// The Z-Machine (or glulx) version settings
///
@interface IFOutputSettings : IFSetting

@property (atomic) BOOL createBlorbForRelease;

@end
