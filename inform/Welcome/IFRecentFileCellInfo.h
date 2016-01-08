//
//  IFRecentFileCellInfo.h
//  Inform
//
//  Created by Toby Nelson in 2014
//

#import <Cocoa/Cocoa.h>

typedef enum IFRecentFileType {
    IFRecentFile,
    IFRecentOpen,
    IFRecentCreateProject,
    IFRecentCreateExtension,
    IFRecentCopySample,
    IFRecentWebsiteLink,
    IFRecentSaveEPubs,
} IFRecentFileType;

@interface IFRecentFileCellInfo : NSObject <NSCopying>

@property (atomic, readwrite, strong) NSString* title;
@property (atomic, readwrite, strong) NSImage* image;
@property (atomic, readwrite, strong) NSURL* url;
@property (atomic, readwrite) IFRecentFileType type;

- (instancetype)init NS_UNAVAILABLE NS_DESIGNATED_INITIALIZER;

- (instancetype)initWithTitle: (NSString *) title
                        image: (NSImage *) image
                          url: (NSURL *) url
                         type: (IFRecentFileType) type NS_DESIGNATED_INITIALIZER;

@end
