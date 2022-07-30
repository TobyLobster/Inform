//
//  IFSkeinConstants.h
//  Inform
//
//  Created by Toby Nelson in 2015
//


#pragma mark Properties of the skein
/// Border around the edge of the skein view
static const CGFloat kSkeinBorder                      =  20.0f;
/// Horizontal space between items
static const CGFloat kSkeinItemPadding                 =  10.0f;
/// Height of each level of the skein
static const CGFloat kSkeinMinLevelHeight              =  34.0f;
/// How much the frame of the item extends beyond the bounds of the lozenge
static const CGFloat kSkeinItemFrameWidthExtension     =   5.0f;
/// Height of item's frame
static const CGFloat kSkeinItemFrameHeight             =  34.0f;

#pragma mark Properties of the report card
/// Width of the report card
static const CGFloat kSkeinReportWidth                 = 410.0f;
/// Offset of report card in Y
static const CGFloat kSkeinReportOffsetY               =   5.0f;
/// Minimum arrow length (distance between lozenge right edge and left edge of the report card)
static const CGFloat kSkeinReportLeftBorder            =  15.0f;
/// Distance between report card right edge and the next lozenge to the right of it.
static const CGFloat kSkeinReportRightBorder           =  10.0f;
/// Border between the edge of the report card and the report text
static const CGFloat kSkeinReportInsideLeftBorder      =   3.0f;
/// Border between the edge of the report card and the report text
static const CGFloat kSkeinReportInsideRightBorder     =  14.0f;
/// Border between the edge of the report card and the report text
static const CGFloat kSkeinReportInsideTopBorder       =   6.0f;
/// Border between the edge of the report card and the report text
static const CGFloat kSkeinReportInsideBottomBorder    =   6.0f;

#pragma mark Properties of the report card items
/// Thickness of the dotted line that separates the items on the report card
static const CGFloat kDottedSeparatorLineThickness     =   1.0f;
/// Height of gap above each dotted separator line before text starts
static const CGFloat kDottedSeparatorGapAboveLine      =   3.0f;
/// Height of gap below each dotted separator line before text starts
static const CGFloat kDottedSeparatorGapBelowLine      =   3.0f;

#pragma mark Properties of the lozenge image
static const CGFloat kSkeinItemImageWidth              =  90.0f;
static const CGFloat kSkeinItemImageHeight             =  30.0f;
/// Distance from lozenge image left edge to the start of the command
static const CGFloat kSkeinItemImageCommandLeftBorder  =  15.0f;
/// Distance from right edge of command to the end of the lozenge image
static const CGFloat kSkeinItemImageCommandRightBorder =  15.0f;
/// Pixels before the visible area starts
static const CGFloat kSkeinItemImageTopBorder          =   2.0f;
/// Pixels before the visible area starts
static const CGFloat kSkeinItemImageBottomBorder       =   4.0f;
/// Pixels before the visible area starts
static const CGFloat kSkeinItemImageLeftBorder         =   5.0f;
/// Pixels before the visible area starts
static const CGFloat kSkeinItemImageRightBorder        =   5.0f;

#pragma mark Properties of text
/// Standard font size for items (in points)
static const CGFloat kSkeinDefaultItemFontSize         =  12.0f;
/// Standard font size for report card (in points)
static const CGFloat kSkeinDefaultReportFontSize       =  10.0f;

#pragma mark Properties of the linking lines
/// Thickness of the line for links
static const CGFloat kSkeinLinkThickness               =   2.5f;

#pragma mark Properties of the arrow
/// Thickness of dotted ine leading to the report card
static const CGFloat kSkeinArrowLineThickness          =   1.0f;
/// Vertical height of the arrow head
static const CGFloat kSkeinArrowHeadHeight             =   5.0f;
/// Length of arrowhead from point to base
static const CGFloat kSkeinArrowHeadLength             =   5.0f;

#pragma mark Animation timing
/// Adjust overall animation timing
static const NSTimeInterval kSkeinAnimationMultiplier         =   1.0;
static const NSTimeInterval kSkeinAnimationDuration           =   0.75 * kSkeinAnimationMultiplier;
static const NSTimeInterval kSkeinAnimationReportFadeIn       =   0.2  * kSkeinAnimationMultiplier;
static const NSTimeInterval kSkeinAnimationReportFadeOut      =   0.2  * kSkeinAnimationMultiplier;
static const NSTimeInterval kSkeinAnimationArrowFadeIn        =   0.2  * kSkeinAnimationMultiplier;
static const NSTimeInterval kSkeinAnimationArrowFadeOut       =   0.01 * kSkeinAnimationMultiplier;
static const NSTimeInterval kSkeinAnimationItemFadeIn         =   0.2  * kSkeinAnimationMultiplier;

#pragma mark Derived constants
static const CGFloat kSkeinLeftBorder   = kSkeinBorder;
static const CGFloat kSkeinRightBorder  = kSkeinBorder;
static const CGFloat kSkeinTopBorder    = kSkeinBorder;
static const CGFloat kSkeinBottomBorder = kSkeinBorder;
