//
//  IFCompilerListEntry.m
//  Inform
//
//  Created by Toby Nelson on 17/02/2019.
//

#import <Foundation/Foundation.h>

#import "IFCompilerListEntry.h"

@implementation IFCompilerListEntry

@synthesize id;
@synthesize displayName;
@synthesize description;

- (instancetype) initWithId:(NSString*) _id displayName:(NSString*) _displayName description:(NSString*) _description {
    self = [super init];

    if (self) {
        self.id = _id;
        self.displayName = _displayName;
        self.description = _description;
    }

    return self;
}

@end

