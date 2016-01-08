//
//  IFTestCommands.h
//  Inform
//
//  Created by Toby Nelson 2015
//

#import <Cocoa/Cocoa.h>


///
/// Input source that can be used to send commands to the story
///
@interface IFTestCommands : NSObject

-(NSString*) nextCommand;
-(void) setCommands: (NSArray*) myCommands;

@end
