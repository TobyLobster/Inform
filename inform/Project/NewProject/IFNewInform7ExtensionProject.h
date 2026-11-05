//
//  IFNewInform7ExtensionProject.h
//  Inform
//
//  Created by Toby Neson in 2015

#import <Foundation/Foundation.h>
#import "IFNewProjectProtocol.h"

NS_ASSUME_NONNULL_BEGIN

///
/// Project type that creates an empty Natural Inform project
///
/// (Actually, we use the file and the current user name to generate an initial heading for the game)
///
@interface IFNewInform7ExtensionProject : NSObject<IFNewProjectProtocol>

@end

NS_ASSUME_NONNULL_END
