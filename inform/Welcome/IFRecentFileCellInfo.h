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

@interface IFRecentFileCellInfo : NSObject <NSCopying> {
@private
    NSString *       title;
    NSImage *        image;
    IFRecentFileType type;
    NSURL*           url;
}

@property (readwrite, retain) NSString* title;
@property (readwrite, retain) NSImage* image;
@property (readwrite, retain) NSURL* url;
@property (readwrite) IFRecentFileType type;

- (id)initWithTitle: (NSString *) _title
              image: (NSImage *) _image
                url: (NSURL *) _url
               type: (IFRecentFileType) _type;

@end
