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

@interface IFNewsManager : NSObject

@property (atomic, readwrite) IFNewsCustomSchemeHandler* newsSchemeHandler;

-(void)     getNewsWithCompletionHandler: (void (^)(NSString * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error)) completionHandler;

@end

NS_ASSUME_NONNULL_END

#endif /* IFNewsManager_h */
