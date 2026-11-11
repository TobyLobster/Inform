//
//  main.m
//  Inform
//
//  Created by Andrew Hunter on Fri Aug 15 2003.
//  Copyright (c) 2003 Andrew Hunter. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "IFUtility.h"

int main(int argc, const char *argv[])
{
    [IFUtility stopTestHostWithLeftoverHome];

    return NSApplicationMain(argc, argv);
}
