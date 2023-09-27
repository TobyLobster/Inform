//
//  IFSkeinReportItemView.m
//  Inform
//
//  Created by Toby Nelson in 2015
//

#import "IFSkeinReportItemView.h"
#import "IFSkein.h"
#import "IFSkeinBlessButton.h"
#import "IFSkeinConstants.h"

static const CGFloat kBlessButtonWidth  = 13.0f;
static const CGFloat kBlessButtonHeight = 13.0f;

@implementation IFSkeinReportItemView

- (instancetype)init {
    self = [super init];
	
    if (self) {
        _blessButton = [[IFSkeinBlessButton alloc] init];
        _textView    = [[NSTextView alloc] init];

        _textView.editable                       = NO;
        _textView.drawsBackground                = NO;
        _textView.continuousSpellCheckingEnabled = NO;
        _textView.grammarCheckingEnabled         = NO;
        _textView.horizontallyResizable          = NO;
        _textView.verticallyResizable            = YES;
        _textView.textContainerInset             = NSZeroSize;
        _textView.minSize                        = NSMakeSize(kSkeinReportWidth - kSkeinReportInsideLeftBorder - kSkeinReportInsideRightBorder,
                                                             1.0f);
        [self addSubview: _textView];
        [self addSubview: _blessButton];

        _textHeight = 0.0f;
        _uniqueId = 0;
    }
    return self;
}

-(void) setAttributedString: (NSAttributedString*) string
                forceChange: (BOOL) forceChange {
    self.frame = NSMakeRect(0, 0, self.frame.size.width, self.frame.size.height);
    if( !forceChange && [_textView.textStorage isEqualTo: string] ) {
        return;
    }
    [_textView.textStorage setAttributedString: string];
    [_textView sizeToFit];

    _textHeight = _textView.frame.size.height;

    self.frame = NSMakeRect(self.frame.origin.x,
                               self.frame.origin.y,
                               kSkeinReportWidth,
                               _textHeight);
}

-(void) setFrame:(NSRect)frame {
    super.frame = frame;

    _textView.frame = NSMakeRect(kSkeinReportInsideLeftBorder,
                                 frame.size.height - _topBorderHeight - _textHeight,
                                 kSkeinReportWidth - kSkeinReportInsideLeftBorder - kSkeinReportInsideRightBorder,
                                _textHeight);
    _blessButton.frame = NSMakeRect(frame.size.width  - kBlessButtonWidth - 1.0f,
                                    1.0f,
                                    kBlessButtonWidth,
                                    kBlessButtonHeight);
}

@end
