//
//  IFNewsCustomSchemeHandler.h
//  Inform
//
//  Created by Toby Nelson on 21/06/2022.
//

#ifndef IFNewsCustomSchemeHandler_h
#define IFNewsCustomSchemeHandler_h

#import "WebKit/WebKit.h"

@interface IFNewsCustomSchemeHandler : NSObject<WKURLSchemeHandler> {

}

-(instancetype) init;

@end

#endif /* IFNewsCustomSchemeHandler_h */
