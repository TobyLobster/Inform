//
//  IFRecentFileCellInfo.m
//  Inform
//
//  Created by Toby Nelson 2014
//

#import "IFRecentFileCellInfo.h"

@implementation IFRecentFileCellInfo

@synthesize title;
@synthesize image;
@synthesize url;
@synthesize type;

- (id)initWithTitle: (NSString *) _title
              image: (NSImage *) _image
                url: (NSURL *) _url
               type: (IFRecentFileType) _type {
    self = [super init];
    if( self ) {
        self.title      = _title;
        self.image      = _image;
        self.url        = _url;
        type            = _type;
    }
    return self;
}

-(void) dealloc {
    [super dealloc];
}

- (id)copyWithZone:(NSZone *)zone
{
    IFRecentFileCellInfo *cellInfo = [[IFRecentFileCellInfo alloc] initWithTitle: [self title]
                                                                           image: [self image]
                                                                             url: [self url]
                                                                            type: [self type]];
    return cellInfo;
}

@end
