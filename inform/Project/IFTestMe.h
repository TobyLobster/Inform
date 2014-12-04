//
//  IFTestMe.h
//  Inform-xc2
//
//  Created by Andrew Hunter on 18/10/2009.
//  Copyright 2009 Andrew Hunter. All rights reserved.
//

#import <Cocoa/Cocoa.h>


///
/// Input source that can be used to send 'test me' to the target
///
@interface IFTestMe : NSObject {
	NSMutableArray* commands;
}

- (NSString*) nextCommand;

@end
