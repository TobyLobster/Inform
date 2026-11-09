//
//  IFSourceHighlights.m
//  Inform
//
//  Moved out of IFProjectController in November 2026.
//

#import "IFSourceHighlights.h"

@implementation IFSourceHighlights {
    // Source highlighting (indexed by file)
    NSMutableDictionary*    lineHighlighting;
    BOOL                    temporaryHighlights;
}

- (instancetype) init {
    self = [super init];

    if (self) {
        lineHighlighting = [[NSMutableDictionary alloc] init];
    }

    return self;
}

- (NSArray<NSString*>*) files {
    return lineHighlighting.allKeys;
}

- (BOOL) hasTemporaryHighlights {
    return temporaryHighlights;
}

- (NSArray<NSArray<NSNumber*>*>*) highlightsInFile: (NSString*) file {
    return lineHighlighting[file];
}

- (void) highlightLine: (NSInteger) line
                inFile: (NSString*) file
                 style: (IFLineStyle) style {
    // Create a new line highlight for this file
    NSMutableArray* lineHighlight = lineHighlighting[file];

    if (lineHighlight == nil) {
        lineHighlight = [NSMutableArray array];
        lineHighlighting[file] = lineHighlight;
    }

    [lineHighlight addObject: @[@(line),
                                @(style)]];

    if (style >= IFLineStyle_Temporary && style < IFLineStyle_LastTemporary)
        temporaryHighlights = YES;
}

- (BOOL) removeHighlightsOfStyle: (IFLineStyle) style
                          inFile: (NSString*) file {
    NSMutableArray* lineHighlight = lineHighlighting[file];
    if (lineHighlight == nil) return NO;

    BOOL updated = NO;

    // Loop through each highlight, and remove any of this style
    int x;
    for (x=0; x<lineHighlight.count; x++) {
        if ([lineHighlight[x][1] intValue] == style) {
            [lineHighlight removeObjectAtIndex: x];
            updated = YES;
            x--;
        }
    }

    return updated;
}

- (void) temporaryHighlightsWereRemoved {
    temporaryHighlights = NO;
}

@end
