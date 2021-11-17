//
//  ZoomServer.h
//  ZoomCocoa
//
//  Created by Andrew Hunter on Wed Sep 10 2003.
//  Copyright (c) 2003 Andrew Hunter. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "ZoomProtocol.h"
#import "ztypes.h"
#import "file.h"

@class ZoomZMachine;

// Globals
extern NSRunLoop*         mainLoop;

extern ZoomZMachine*      mainMachine;

// Utility functions
extern ZFile* open_file_from_object(id<ZFile> file);
extern ZDWord get_size_of_file(ZFile* file);

extern BOOL zdisplay_is_fixed(int window);
