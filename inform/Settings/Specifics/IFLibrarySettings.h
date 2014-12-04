//
//  IFLibrarySettings.h
//  Inform
//
//  Created by Andrew Hunter on 10/10/2004.
//  Copyright 2004 Andrew Hunter. All rights reserved.
//

#import <Cocoa/Cocoa.h>

#import "IFSetting.h"

//
// The Inform 6 library to use.
//
@interface IFLibrarySettings : IFSetting {
    IBOutlet NSPopUpButton* libraryVersion;
}

@end
