//
//  IFRecentFileCellInfo.h
//  Inform
//
//  Created by Toby Nelson in 2014
//

#import <Cocoa/Cocoa.h>

typedef NS_ENUM(int, IFRecentFileType) {
    IFRecentFile,
    IFRecentOpen,
    IFRecentCreateProject,
    IFRecentCreateExtension,
    IFRecentCopySample,
    IFRecentWebsiteLink,
    IFRecentSaveEPubs,
};

@interface IFRecentFileCellInfo : NSObject <NSCopying>

@property (atomic, readwrite, copy) NSString* title;
@property (atomic, readwrite, copy) NSImage* image;
@property (atomic, readwrite, copy) NSURL* url;
@property (atomic, readwrite) IFRecentFileType type;

- (instancetype)init NS_UNAVAILABLE;

- (instancetype)initWithTitle: (NSString *) title
                        image: (NSImage *) image
                          url: (NSURL *) url
                         type: (IFRecentFileType) type NS_DESIGNATED_INITIALIZER;

@end
