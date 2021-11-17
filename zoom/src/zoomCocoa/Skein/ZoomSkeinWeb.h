

#import "ZoomSkein.h"
#import "ZoomSkeinView.h"
#import <WebKit/WebKit.h>


// FIXME: Deprecations! WebDocumentRepresentation needs to be replaced.
// = WebKit interface (b0rked: webkit doesn't really support this) =

/// These classes are designed to allow a \c ZoomSkeinView to be embedded in a web view.
/// MIME type is application/x-zoom-skein
@interface ZoomSkein(ZoomSkeinWebDocRepresentation) <WebDocumentRepresentation>
@end

///  Using with the web kit
@interface ZoomSkeinView(ZoomSkeinViewWeb) <WebDocumentView>

@end
