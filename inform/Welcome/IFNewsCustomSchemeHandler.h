//
//  IFNewsCustomSchemeHandler.h
//  Inform
//
//  Created by Toby Nelson on 21/06/2022.
//

#ifndef IFNewsCustomSchemeHandler_h
#define IFNewsCustomSchemeHandler_h

#import "WebKit/WebKit.h"

NS_ASSUME_NONNULL_BEGIN

@interface IFNewsCustomSchemeHandler : NSObject<WKURLSchemeHandler> {

}

-(instancetype) init;

@end

NS_ASSUME_NONNULL_END

#endif /* IFNewsCustomSchemeHandler_h */
