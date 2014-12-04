//
//  IFDebugSettings.h
//  Inform
//
//  Created by Andrew Hunter on 10/10/2004.
//  Copyright 2004 Andrew Hunter. All rights reserved.
//

#import <Cocoa/Cocoa.h>

#import "IFSetting.h"

//
// The 'debugging' settings object: things that are mostly useful to Graham
//
@interface IFDebugSettings : IFSetting {
    IBOutlet NSButton* donotCompileNaturalInform;
    IBOutlet NSButton* runBuildSh;
    IBOutlet NSButton* runLoudly;
	IBOutlet NSButton* debugMemory;
}

@end
