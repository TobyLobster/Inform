//
//  IFNewsManager.h
//  Inform
//
//  Created by Toby Nelson on 20/06/2022.
//

#ifndef IFNewsManager_h
#define IFNewsManager_h

#import "IFNewsCustomSchemeHandler.h"

NS_ASSUME_NONNULL_BEGIN

NS_SWIFT_SENDABLE
@interface IFNewsManager : NSObject

/// A news manager that keeps the news in the user's defaults, and downloads it with the shared session
-(instancetype) init NS_SWIFT_UI_ACTOR;
/// A news manager that keeps the news in the given defaults, and downloads it with the given session
-(instancetype) initWithDefaults: (NSUserDefaults*) defaults
                         session: (NSURLSession*) session NS_DESIGNATED_INITIALIZER NS_SWIFT_UI_ACTOR;

/// What gives the news page the app's resources
@property (nonatomic, readonly, strong) IFNewsCustomSchemeHandler* newsSchemeHandler;

/// Gives today's news, downloading it if it hasn't been today, on another thread
-(void)     getNewsWithCompletionHandler: (void (^)(NSString * _Nullable news, NSURLResponse * _Nullable response, NSError * _Nullable error)) completionHandler;

@end

NS_ASSUME_NONNULL_END

#endif /* IFNewsManager_h */
