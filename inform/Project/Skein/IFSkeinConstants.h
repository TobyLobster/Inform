//
//  IFSkeinConstants.h
//  Inform
//
//  Created by Toby Nelson in 2015
//


// Properties of the skein
static const float kSkeinBorder                      =  20.0f;   // Border around the edge of the skein view
static const float kSkeinItemPadding                 =  10.0f;   // Horizontal space between items
static const float kSkeinMinLevelHeight              =  34.0f;   // Height of each level of the skein
static const float kSkeinItemFrameWidthExtension     =   5.0f;   // How much the frame of the item extends beyond the bounds of the lozenge
static const float kSkeinItemFrameHeight             =  34.0f;   // Height of item's frame

// Properties of the report card
static const float kSkeinReportWidth                 = 410.0f;   // Width of the report card
static const float kSkeinReportOffsetY               =   5.0f;   // Offset of report card in Y
static const float kSkeinReportLeftBorder            =  15.0f;   // Minimum arrow length (distance between lozenge right edge and left edge of the report card)
static const float kSkeinReportRightBorder           =  10.0f;   // Distance between report card right edge and the next lozenge to the right of it.
static const float kSkeinReportInsideLeftBorder      =   3.0f;   // Border between the edge of the report card and the report text
static const float kSkeinReportInsideRightBorder     =  14.0f;   // Border between the edge of the report card and the report text
static const float kSkeinReportInsideTopBorder       =   6.0f;   // Border between the edge of the report card and the report text
static const float kSkeinReportInsideBottomBorder    =   6.0f;   // Border between the edge of the report card and the report text

// Properties of the report card items
static const float kDottedSeparatorLineThickness     =   1.0f;   // Thickness of the dotted line that separates the items on the report card
static const float kDottedSeparatorGapAboveLine      =   3.0f;   // Height of gap above each dotted separator line before text starts
static const float kDottedSeparatorGapBelowLine      =   3.0f;   // Height of gap below each dotted separator line before text starts

// Properties of the lozenge image
static const float kSkeinItemImageWidth              =  90.0f;
static const float kSkeinItemImageHeight             =  30.0f;
static const float kSkeinItemImageCommandLeftBorder  =  15.0f;   // Distance from lozenge image left edge to the start of the command
static const float kSkeinItemImageCommandRightBorder =  15.0f;   // Distance from right edge of command to the end of the lozenge image
static const float kSkeinItemImageTopBorder          =   2.0f;   // Pixels before the visible area starts
static const float kSkeinItemImageBottomBorder       =   4.0f;   // Pixels before the visible area starts
static const float kSkeinItemImageLeftBorder         =   5.0f;   // Pixels before the visible area starts
static const float kSkeinItemImageRightBorder        =   5.0f;   // Pixels before the visible area starts

// Properties of text
static const float kSkeinDefaultItemFontSize         =  12.0f;   // Standard font size for items (in points)
static const float kSkeinDefaultReportFontSize       =  10.0f;   // Standard font size for report card (in points)

// Properties of the linking lines
static const float kSkeinLinkThickness               =   2.5f;   // Thickness of the line for links

// Properties of the arrow
static const float kSkeinArrowLineThickness          =   1.0f;   // Thickness of dotted ine leading to the report card
static const float kSkeinArrowHeadHeight             =   5.0f;   // Vertical height of the arrow head
static const float kSkeinArrowHeadLength             =   5.0f;   // Length of arrowhead from point to base

// Animation timing
static const float kSkeinAnimationMultiplier         =   1.0f;   // Adjust overall animation timing
static const float kSkeinAnimationDuration           =   0.75f * kSkeinAnimationMultiplier;
static const float kSkeinAnimationReportFadeIn       =   0.2f  * kSkeinAnimationMultiplier;
static const float kSkeinAnimationReportFadeOut      =   0.2f  * kSkeinAnimationMultiplier;
static const float kSkeinAnimationArrowFadeIn        =   0.2f  * kSkeinAnimationMultiplier;
static const float kSkeinAnimationArrowFadeOut       =   0.01f * kSkeinAnimationMultiplier;
static const float kSkeinAnimationItemFadeIn         =   0.2f  * kSkeinAnimationMultiplier;

// Derived constants
static const float kSkeinLeftBorder   = kSkeinBorder;
static const float kSkeinRightBorder  = kSkeinBorder;
static const float kSkeinTopBorder    = kSkeinBorder;
static const float kSkeinBottomBorder = kSkeinBorder;
