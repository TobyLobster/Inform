//
//  IFProjectPaneType.h
//  Inform
//
//  Moved out of IFProjectPane.h in November 2026.
//

#import <Foundation/Foundation.h>

typedef NS_ENUM(int, IFProjectPaneType) {
    IFSourcePane        = 1,
    IFErrorPane         = 2,
    IFGamePane          = 3,
    IFDocumentationPane = 4,
	IFIndexPane         = 5,
	IFSkeinPane         = 6,
    IFExtensionsPane    = 9,

	IFUnknownPane       = 256
};
