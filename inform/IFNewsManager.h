//
//  IFNewsManager.h
//  Inform
//
//  Created by Toby Nelson on 20/06/2022.
//

#ifndef IFNewsManager_h
#define IFNewsManager_h

@interface IFNewsManager : NSObject

@property (atomic, readwrite, copy) NSURLSessionDataTask* _Nonnull task;

-(void)     getNewsWithCompletionHandler: (void (^_Nonnull)(NSString * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error)) completionHandler;

@end

#endif /* IFNewsManager_h */
