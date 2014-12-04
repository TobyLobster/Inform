//
//  main.m
//  Zoom
//
//  Created by Andrew Hunter on Wed Jun 25 2003.
//  Copyright (c) 2003 Andrew Hunter. All rights reserved.
//

#undef  DEBUG_BUILD

#import <Cocoa/Cocoa.h>

#include <sys/types.h>
#include <unistd.h>

#include "ifmetabase.h"

#ifdef DEBUG_BUILD
static void reportLeaks(void) {
    // List just the unreferenced memory
    char flup[256];
    sprintf(flup, "/usr/bin/leaks -nocontext %i", getpid());
    system(flup);
}
#endif

int main(int argc, const char *argv[])
{
#ifdef DEBUG_BUILD
	NSLog(@"Zoom: DEBUG BUILD");
    atexit(reportLeaks);
#endif
    return NSApplicationMain(argc, argv);
}
