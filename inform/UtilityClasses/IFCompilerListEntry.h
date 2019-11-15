//
//  IFCompilerListEntry.h
//  Inform
//
//  Created by Toby Nelson on 17/02/2019.
//

@interface IFCompilerListEntry : NSObject {

    
}

@property (atomic, copy) NSString *    id;
@property (atomic, copy) NSString *    displayName;
@property (atomic, copy) NSString *    description;

- (instancetype) initWithId:(NSString*) id displayName:(NSString*) displayName description:(NSString*) description;

@end
