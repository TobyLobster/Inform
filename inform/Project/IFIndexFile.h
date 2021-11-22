//
//  IFIndexFile.h
//  Inform
//
//  Created by Andrew Hunter on Sun Jun 13 2004.
//  Copyright (c) 2004 Andrew Hunter. All rights reserved.
//

#import <Foundation/Foundation.h>


@interface IFIndexFile : NSObject<NSOutlineViewDataSource>

- (instancetype) init NS_UNAVAILABLE NS_DESIGNATED_INITIALIZER;
- (instancetype) initWithContentsOfFile: (NSString*) filename;
- (instancetype) initWithData: (NSData*) data NS_DESIGNATED_INITIALIZER; // Designated initialiser

// Getting info about a particular item
- (NSString*) filenameForItem: (id) item;
- (NSURL*)    fileURLForItem: (id) item;
- (int)       lineForItem: (id) item;
- (NSString*) titleForItem: (id) item;

// Can be used as a datasource for NSOutlineViews

@end
