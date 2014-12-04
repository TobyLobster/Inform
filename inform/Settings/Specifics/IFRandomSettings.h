//
//  IFRandomSettings.h
//  Inform-xc2
//
//  Created by Andrew Hunter on 17/09/2009.
//  Copyright 2009 Andrew Hunter. All rights reserved.
//

#import <Cocoa/Cocoa.h>

#import "IFSetting.h"


///
/// Settings that control whether or not Natural Inform nobbles the Random Number Generator
///
@interface IFRandomSettings : IFSetting {
	IBOutlet NSButton* makePredictable;
}

@end
