//
//  IFRecentFileCellInfo.m
//  Inform
//
//  Created by Toby Nelson 2014
//

#import "IFRecentFileCellInfo.h"

@implementation IFRecentFileCellInfo

- (instancetype)init { self = [super init]; return self; }

- (instancetype)initWithTitle: (NSString *) title
                        image: (NSImage *) image
                          url: (NSURL *) url
                         type: (IFRecentFileType) type {
    self = [super init];
    if( self ) {
        _title      = title;
        _image      = image;
        _url        = url;
        _type       = type;
    }
    return self;
}


- (id)copyWithZone:(NSZone *)zone
{
    IFRecentFileCellInfo *cellInfo = [[IFRecentFileCellInfo alloc] initWithTitle: _title
                                                                           image: _image
                                                                             url: _url
                                                                            type: _type];
    return cellInfo;
}

@end
