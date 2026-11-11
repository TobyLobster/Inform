//
//  IFNewInform7ExtensionProject.h
//  Inform
//
//  Created by Toby Neson in 2015

#import <Foundation/Foundation.h>
#import "IFNewProjectProtocol.h"

NS_ASSUME_NONNULL_BEGIN

///
/// Project type that creates an extension project, whose extension is a copy of the extension given, or empty if
/// none is given or it can't be read
///
NS_SWIFT_UI_ACTOR
@interface IFNewInform7ExtensionProject : NSObject<IFNewProjectProtocol>

@end

NS_ASSUME_NONNULL_END
