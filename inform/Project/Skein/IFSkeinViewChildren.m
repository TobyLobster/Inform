//
//  IFSkeinViewChildren.m
//  Inform
//
//  Created by Toby Nelson in 2015
//

#import <Foundation/Foundation.h>
#import <QuartzCore/QuartzCore.h>
#import "IFSkeinViewChildren.h"
#import "IFSkein.h"
#import "IFSkeinItem.h"
#import "IFSkeinLayout.h"
#import "IFSkeinLayoutItem.h"
#import "IFSkeinItemView.h"
#import "IFSkeinArrowView.h"
#import "IFSkeinReportView.h"
#import "IFSkeinView.h"
#import "IFUtility.h"
#import "IFSkeinConstants.h"
#import "Inform-Swift.h"

static const int    kAnimationSteps             = 30;
/// Link view thickness (include one pixel transparent border)
static const CGFloat  kSkeinLinkViewThickness     = kSkeinLinkThickness + 2.0f;

static const CGFloat  kSkeinLinkViewHalfThickness = kSkeinLinkViewThickness * 0.5f;
/// Height of the arrow view
static const CGFloat  kSkeinArrowViewHeight       = kSkeinArrowHeadHeight + 2.0f;
/// Move link lines below the top of the lozenge
static const CGFloat  kSkeinLinkFromOffsetY       = kSkeinLinkThickness * 0.5f;

static const CGFloat  kAngleEpsilon               = 0.001f;
static const CGFloat  kPositionEpsilon            = 0.01f;

@implementation IFSkeinViewChildren {
    /// Dictionary of 'IFSkeinItemView's keyed on item's uniqueId.
    NSMutableDictionary*    itemViews;
    /// Dictionary of 'IFSkeinLinkView's keyed on item's uniqueId.
    NSMutableDictionary*    linkViews;
    /// Dictionary of 'IFSkeinArrowView's keyed on item's uniqueId.
    NSMutableDictionary*    arrowViews;
    IFSkeinView*            skeinView;
    IFSkeinReportView*      reportView;
    CFTimeInterval          currentTimeInterval;
}

-(instancetype) initWithSkeinView:(IFSkeinView*) theSkeinView {
    self = [super init];

    if( self ) {
        itemViews  = [[NSMutableDictionary alloc] init];
        linkViews  = [[NSMutableDictionary alloc] init];
        arrowViews = [[NSMutableDictionary alloc] init];
        reportView = [[IFSkeinReportView alloc] init];
        reportView.delegate = self;
        skeinView  = theSkeinView;
        currentTimeInterval = CACurrentMediaTime();

        [skeinView addSubview: reportView];
    }
    return self;
}

-(void) addSubtreeItems: (IFSkeinLayoutItem*) root
                     to: (NSMutableDictionary*) array {
    array[@(root.item.uniqueId)] = root;
    for( IFSkeinLayoutItem* child in root.children ) {
        [self addSubtreeItems: child to: array];
    }
}

-(NSDictionary*) allItemsFromLayout:(IFSkeinLayout*) layout {
    NSMutableDictionary* layoutItems = [[NSMutableDictionary alloc] init];
    if( layout.rootLayoutItem != nil ) {
        [self addSubtreeItems: layout.rootLayoutItem to: layoutItems];
    }
    return layoutItems;
}

-(void) createItemViewFromLayoutItem: (IFSkeinLayoutItem*) layoutItem
                                 key: (NSNumber*) key {
    IFSkeinItemView* resultView = [[IFSkeinItemView alloc] initWithFrame: layoutItem.boundingRect];
    [skeinView addSubview: resultView];            // Add item to skein view
    itemViews[key] = resultView; // Add item to dictionary

    [self updateItemView: resultView fromLayoutItem: layoutItem animate: NO fadeIn: YES];
}

-(void) createLinkViewFromLayoutItem: (IFSkeinLayoutItem*) layoutItem
                                 key: (NSNumber*) key
                              layout: (IFSkeinLayout*) layout {
    if( layoutItem.item.parent == nil ) {
        return;
    }
    IFSkeinLinkView* newLink = [[IFSkeinLinkView alloc] init];
    [skeinView addSubview: newLink];                // Add link to skein view
    linkViews[key] = newLink;     // Add link to dictionary

    [self updateLinkView: newLink
                  layout: layout
          fromLayoutItem: layoutItem
                 animate: NO
                  fadeIn: YES];
}

-(void) createArrowViewFromLayoutItem: (IFSkeinLayoutItem*) layoutItem
                                  key: (NSNumber*) key
                               layout: (IFSkeinLayout*) layout {
    IFSkeinArrowView* newArrow = [[IFSkeinArrowView alloc] init];
    [skeinView addSubview: newArrow];               // Add link to skein view
    arrowViews[key] = newArrow;   // Add link to dictionary

    [self updateArrowView: newArrow
                   layout: layout
           fromLayoutItem: layoutItem
                  animate: NO];
}

-(void) updateItemView: (IFSkeinItemView*) itemView
        fromLayoutItem: (IFSkeinLayoutItem*) layoutItem
               animate: (BOOL) animate
                fadeIn: (BOOL) fadeIn {

    CAKeyframeAnimation * thePositionAnimation = [CAKeyframeAnimation animationWithKeyPath: @"position"];
    NSMutableArray* positionValues = [[NSMutableArray alloc] initWithCapacity: kAnimationSteps+1];
    NSPoint startPosition = itemView.frame.origin;
    NSPoint finalPosition = layoutItem.boundingRect.origin;

    id x = itemView.layer.presentationLayer;
    if( [x isKindOfClass:[CALayer class]] ) {
        CALayer* actualLayer = (CALayer*) x;
        startPosition = actualLayer.frame.origin;
    }

    if( !itemView.layer.geometryFlipped ) {
        finalPosition.y = itemView.superview.bounds.size.height - finalPosition.y;
    }

    // Performance optimisation. If it's not moving, don't animate it.
    if( (fabs(startPosition.x - finalPosition.x) < kPositionEpsilon) &&
        (fabs(startPosition.y - finalPosition.y) < kPositionEpsilon)) {
        animate = NO;
    }

    if( animate ) {
        for( int step = 0; step <= kAnimationSteps; step++) {
            CGFloat t = (CGFloat) step / (CGFloat) kAnimationSteps;
            t = easeOutCubic(t);
            NSPoint pos = NSMakePoint( lerp(t, startPosition.x, finalPosition.x),
                                       lerp(t, startPosition.y, finalPosition.y) );
            [positionValues addObject: @(pos)];
        }
        thePositionAnimation.values = positionValues;
        thePositionAnimation.calculationMode = kCAAnimationLinear;

        [itemView.layer addAnimation: thePositionAnimation
                              forKey: @"positionItemAnimation"];
    }

    if( fadeIn ) {
        CGFloat delay = kSkeinAnimationDuration;
        [self fadeInView: itemView
                   delay: delay
                duration: kSkeinAnimationItemFadeIn
                 animate: animate
             fromCurrent: NO];
    }

    itemView.frame      = layoutItem.boundingRect;
    itemView.layoutItem = layoutItem;

    // Only redraw if state hash has changed
    unsigned long hash = itemView.drawnStateHash;
    if( (hash == 0) || (hash != layoutItem.drawStateHash) ) {
        [itemView setNeedsDisplay: YES];
        [itemView display];
    }
}

-(CGFloat) layerAngle: (CALayer*) layer {
    return atan2(layer.transform.m12, layer.transform.m11);
}

-(void) updateLinkView: (IFSkeinLinkView*) linkView
                layout: (IFSkeinLayout*) layout
        fromLayoutItem: (IFSkeinLayoutItem*) layoutItem
               animate: (BOOL) animate
                fadeIn: (BOOL) fadeIn {
    if( layoutItem.item.parent == nil ) {
        return;
    }
    NSRect childRect    = layoutItem.lozengeRect;
    NSRect parentRect   = layoutItem.parent.lozengeRect;

    // We draw a line FROM->TO.
    //  FROM = The top centre of the child lozenge
    //    TO = The middle of the parent lozenge
    // The line animates over time from 'Start' (the current position) to 'Final' the final desired position

    // Get current position and end point
    CGFloat startLength = linkView.frame.size.width;
    CGFloat startAngle  = [self layerAngle: linkView.layer];

    NSPoint startFrom = linkView.frame.origin;

    id x = linkView.layer.presentationLayer;
    if( [x isKindOfClass:[CALayer class]] ) {
        CALayer* actualLayer = (CALayer*) x;
        startFrom   = actualLayer.position;
        startLength = actualLayer.bounds.size.width;
        startAngle  = [self layerAngle:actualLayer];
    }

    if( !linkView.layer.geometryFlipped ) {
        startAngle = -startAngle;
    }

    NSPoint startTo   = NSMakePoint( startFrom.x + startLength * cos(startAngle),
                                     startFrom.y + startLength * sin(startAngle) );

    // Get desired final point
    NSPoint finalFrom  = NSMakePoint( NSMidX(childRect),
                                      NSMinY(childRect) + kSkeinLinkFromOffsetY );
    NSPoint finalTo    = NSMakePoint( NSMidX(parentRect),
                                      NSMidY(parentRect) );
    NSPoint finalDelta = NSMakePoint( finalTo.x - finalFrom.x, finalTo.y - finalFrom.y );
    CGFloat   finalLength       = round(sqrt((finalDelta.x * finalDelta.x) + (finalDelta.y * finalDelta.y)));
    CGFloat   finalAngleRadians = atan2(finalDelta.y, finalDelta.x);

    if( !linkView.layer.geometryFlipped ) {
        finalAngleRadians = -finalAngleRadians;
    }

    // Adjust final points from centre of line to edge of view (by moving a short distance along the normal).
    if( finalLength > 0.001f ) {
        NSPoint normal = NSMakePoint(-finalDelta.y * kSkeinLinkViewHalfThickness / finalLength,
                                      finalDelta.x * kSkeinLinkViewHalfThickness / finalLength);
        finalFrom.x -= normal.x;
        finalFrom.y -= normal.y;
        finalTo.x -= normal.x;
        finalTo.y -= normal.y;
    }

    finalFrom = NSMakePoint(round(finalFrom.x), round(finalFrom.y));
    finalTo   = NSMakePoint(round(finalTo.x), round(finalTo.y));

    // Performance optimisation. If it's not moving, don't animate it.
    if( (fabs(startFrom.x - finalFrom.x) < kPositionEpsilon) &&
        (fabs(startFrom.y - finalFrom.y) < kPositionEpsilon) &&
        (fabs(startTo.x - finalTo.x) < kPositionEpsilon) &&
        (fabs(startTo.y - finalTo.y) < kPositionEpsilon) ) {
        animate = NO;
    }

    if( animate ) {
        // Create a key frame animation
        CAAnimationGroup * theGroupAnimation  = [[CAAnimationGroup alloc] init];
        CAKeyframeAnimation * thePositionAnimation  = [CAKeyframeAnimation animationWithKeyPath: @"position"];
        CAKeyframeAnimation * theSizeAnimation      = [CAKeyframeAnimation animationWithKeyPath: @"bounds.size.width"];
        CAKeyframeAnimation * theAngleAnimation     = [CAKeyframeAnimation animationWithKeyPath: @"transform.rotation"];

        NSMutableArray* positionValues  = [[NSMutableArray alloc] initWithCapacity: kAnimationSteps+1];
        NSMutableArray* sizeValues      = [[NSMutableArray alloc] initWithCapacity: kAnimationSteps+1];
        NSMutableArray* angleValues     = [[NSMutableArray alloc] initWithCapacity: kAnimationSteps+1];

        CGFloat length = 0.0f;
        CGFloat angleRadians = 0.0f;
        for( int step = 0; step <= kAnimationSteps; step++) {
            CGFloat t = (CGFloat) step / (CGFloat) kAnimationSteps;
            t = easeOutCubic(t);
            NSPoint from = NSMakePoint( lerp(t, startFrom.x, finalFrom.x),
                                        lerp(t, startFrom.y, finalFrom.y) );
            NSPoint to = NSMakePoint( lerp(t, startTo.x, finalTo.x),
                                      lerp(t, startTo.y, finalTo.y) );

            if( !linkView.layer.geometryFlipped ) {
                from.y = linkView.superview.frame.size.height - from.y;
                to.y   = linkView.superview.frame.size.height - to.y;
            }

            NSPoint delta = NSMakePoint( to.x - from.x, to.y - from.y );

            length       = sqrt((delta.x * delta.x) + (delta.y * delta.y));
            angleRadians = atan2(delta.y, delta.x);

            NSRect frame = NSMakeRect( from.x, from.y, length, round(kSkeinLinkViewThickness) );
            [positionValues addObject: @(frame.origin)];
            [sizeValues     addObject: @(length)];
            [angleValues    addObject: @(angleRadians)];
        }

        thePositionAnimation.values = positionValues;
        thePositionAnimation.calculationMode = kCAAnimationLinear;

        theSizeAnimation.values = sizeValues;
        theSizeAnimation.calculationMode = kCAAnimationLinear;

        theAngleAnimation.values = angleValues;
        theAngleAnimation.calculationMode = kCAAnimationLinear;

        theGroupAnimation.animations = @[thePositionAnimation, theSizeAnimation, theAngleAnimation];

        [linkView.layer addAnimation: theGroupAnimation
                              forKey: @"groupLinkAnimation"];
    }

    if( fadeIn ) {
        CGFloat delay = kSkeinAnimationDuration;
        [self fadeInView: linkView
                   delay: delay
                duration: kSkeinAnimationItemFadeIn
                 animate: animate
             fromCurrent: NO];
    }

    linkView.frame = NSMakeRect( finalFrom.x, finalFrom.y, round(finalLength), round(kSkeinLinkViewThickness) );

    CGFloat rot = RADIANS_TO_DEGREES(finalAngleRadians);

    // Set final frame rotation (but for performance - only if it's changed)
    if( fabs(linkView.frameRotation-rot) > kAngleEpsilon ) {
        linkView.frameRotation = rot;
    }
}

-(void) fadeOutView: (NSView*) view
              delay: (NSTimeInterval) delay
           duration: (NSTimeInterval) duration
            animate: (BOOL) animate
        fromCurrent: (BOOL) fromCurrent {
    if( animate ) {
        CGFloat startOpacity = 1.0f;
        if( fromCurrent ) {
            // Get current opacity, even when in mid animation
            id x = view.layer.presentationLayer;
            if( [x isKindOfClass: [CALayer class]] ) {
                CALayer* actualLayer = (CALayer*) x;
                startOpacity = actualLayer.opacity;
            } else {
                startOpacity = view.layer.opacity;
            }
        }

        if( startOpacity > 0.0f ) {
            CABasicAnimation* fadeAnim = [CABasicAnimation animationWithKeyPath:@"opacity"];
            fadeAnim.fromValue  = [NSNumber numberWithFloat: startOpacity];
            fadeAnim.toValue    = @0.0f;
            fadeAnim.duration   = duration;
            CFTimeInterval localLayerTime = [view.layer convertTime: currentTimeInterval fromLayer:nil];
            fadeAnim.beginTime  = localLayerTime + delay;
            if( delay > 0.0f ) {
                fadeAnim.fillMode = kCAFillModeBackwards;
            }
            [view.layer addAnimation:fadeAnim forKey:@"opacity"];
        }
    }

    view.layer.opacity = 0.0f;
}

-(void) fadeInView: (NSView*) view
             delay: (NSTimeInterval) delay
          duration: (NSTimeInterval) duration
           animate: (BOOL) animate
       fromCurrent: (BOOL) fromCurrent {
    if( animate ) {
        CGFloat startOpacity = 0.0f;

        // Get current opacity
        if( fromCurrent ) {
            // Get current opacity, even when in mid animation
            id x = view.layer.presentationLayer;
            if( [x isKindOfClass: [CALayer class]] ) {
                CALayer* actualLayer = (CALayer*) x;
                startOpacity = actualLayer.opacity;
            } else {
                startOpacity = view.layer.opacity;
            }
        }

        if( startOpacity < 1.0f ) {
            CABasicAnimation* fadeAnim = [CABasicAnimation animationWithKeyPath:@"opacity"];
            fadeAnim.fromValue  = @(startOpacity);
            fadeAnim.toValue    = @(1.0);
            fadeAnim.duration   = duration;
            CFTimeInterval localLayerTime = [view.layer convertTime: currentTimeInterval fromLayer:nil];
            fadeAnim.beginTime  = localLayerTime + delay;
            if( delay > 0.0f ) {
                fadeAnim.fillMode = kCAFillModeBackwards;
            }
            [view.layer addAnimation:fadeAnim forKey:@"opacity"];
        }
    }

    view.layer.opacity = 1.0f;
}

-(void) updateArrowView: (IFSkeinArrowView*) arrowView
                 layout: (IFSkeinLayout*) layout
         fromLayoutItem: (IFSkeinLayoutItem*) layoutItem
                animate: (BOOL) animate {
    if( arrowView == nil ) {
        return;
    }

    if( layoutItem.onSelectedLine == NO ) {
        [self fadeOutView: arrowView
                    delay: 0.0f
                 duration: kSkeinAnimationArrowFadeOut
                  animate: animate
              fromCurrent: YES];
        return;
    }

    NSRect rect = layoutItem.lozengeRect;

    // Get desired final point
    NSPoint finalFrom  = NSMakePoint( NSMaxX(rect), NSMidY(rect) );
    NSPoint finalTo    = NSMakePoint( layout.reportPosition.x, finalFrom.y );

    NSRect newFrame = NSMakeRect( finalFrom.x,
                                  floor(finalFrom.y - kSkeinArrowViewHeight*0.5),
                                  finalTo.x - finalFrom.x,
                                  kSkeinArrowViewHeight );

    // Does arrow move?
    if( !NSEqualRects(arrowView.frame, newFrame)) {
        // Arrow moves - fade out at old position and fade back in at new position
        [self fadeOutView: arrowView
                    delay: 0.0f
                 duration: kSkeinAnimationArrowFadeOut
                  animate: animate
              fromCurrent: YES];

        [self fadeInView: arrowView
                   delay: kSkeinAnimationDuration - kSkeinAnimationReportFadeIn
                duration: kSkeinAnimationReportFadeIn
                 animate: animate
             fromCurrent: NO];
        
        arrowView.frame = newFrame;
        [arrowView setNeedsDisplay: YES];
        [arrowView display];
    }
    else {
        // Arrow does not move - just fade in if needed
        [self fadeInView: arrowView
                   delay: kSkeinAnimationDuration - kSkeinAnimationReportFadeIn
                duration: kSkeinAnimationReportFadeIn
                 animate: animate
             fromCurrent: YES];
    }
}


static NSComparisonResult compareViewOrder(id viewA, id viewB, void *context)
{
    // Order the subviews so that all links(IFSkeinLinkView) appear below all items(IFSkeinItemView)
    int kindA = 0;
    kindA    += [viewA isKindOfClass: [IFSkeinReportView class]] ? 4 : 0;
    kindA    += [viewA isKindOfClass: [IFSkeinItemView class]]   ? 2 : 0;
    kindA    += [viewA isKindOfClass: [IFSkeinArrowView class]]  ? 1 : 0;
    int kindB = 0;
    kindB    += [viewB isKindOfClass: [IFSkeinReportView class]] ? 4 : 0;
    kindB    += [viewB isKindOfClass: [IFSkeinItemView class]]   ? 2 : 0;
    kindB    += [viewB isKindOfClass: [IFSkeinArrowView class]]  ? 1 : 0;

    if( kindA > kindB ) {
        return NSOrderedDescending;
    }
    if( kindA < kindB ) {
        return NSOrderedAscending;
    }

    return NSOrderedSame;
}

- (void) updateChildrenWithLayout: (IFSkeinLayout*) layout
                          animate: (BOOL) animate {
    // Preliminaries: Gather layout items into an array
    NSDictionary* layoutItems = [self allItemsFromLayout: layout];

    // Preliminaries: Store current time (used for animation)
    currentTimeInterval = CACurrentMediaTime();

    // 1. Remove views no longer in the layout
    for( NSNumber* key in itemViews.allKeys ) {
        if( layoutItems[key] == nil ) {
            [itemViews[key] removeFromSuperview];       // Remove item  from skein view
            [linkViews[key] removeFromSuperview];       // Remove link  from skein view
            [arrowViews[key] removeFromSuperview];      // Remove arrow from skein view
            [itemViews removeObjectForKey: key];        // Remove item  from dictionary
            [linkViews removeObjectForKey: key];        // Remove link  from dictionary
            [arrowViews removeObjectForKey: key];       // Remove arrow from dictionary
        }
    }

    // 2. Add any new views found in the layout
    for( NSNumber* key in layoutItems ) {
        IFSkeinLayoutItem* layoutItem = layoutItems[key];

        if( itemViews[key] == nil ) {
            // Create new view
            [self createItemViewFromLayoutItem: layoutItem key: key];
            [self createLinkViewFromLayoutItem: layoutItem key: key layout: layout];
            [self createArrowViewFromLayoutItem:layoutItem key: key layout: layout];
        }
        else {
            // Update view based on layout item
            [self updateItemView: itemViews[key] fromLayoutItem: layoutItem animate: animate fadeIn: NO];
            [self updateLinkView: linkViews[key] layout: layout fromLayoutItem: layoutItem animate: animate fadeIn: NO];
            [self updateArrowView: arrowViews[key] layout: layout fromLayoutItem: layoutItem animate: animate];
        }
    }

    /*
    BOOL debugCheck = ([layoutItems count] == ([linkViews count]+1) || (([layoutItems count] == 0) && ([linkViews count]==0)));
    if( !debugCheck ) {
        NSLog(@"Found %lu Layout Items: ", (unsigned long)[layoutItems count]);
        for (NSNumber* key in layoutItems) {
            IFSkeinLayoutItem* layoutItem = layoutItems[key];
            NSLog(@"    Layout Item %d, %lu (command '%@')", [key intValue], layoutItem.item.uniqueId, layoutItem.item.command);
        }
        NSLog(@"Found %lu Link Views: ", (unsigned long)[linkViews count]);
        [linkViews enumerateKeysAndObjectsUsingBlock:^(id key, id value, BOOL *stop) {

        }];
        for (NSNumber* key in linkViews) {
            NSLog(@"    Link View %d", key.intValue);
        }
    }
    */

    NSAssert([layoutItems count] == [itemViews count],     @"updateChildrenWithLayout failed to match items");
    NSAssert([layoutItems count] == ([linkViews count]+1) ||
             (([layoutItems count] == 0) && ([linkViews count]==0)), @"updateChildrenWithLayout failed to match links");

    // 3. Position report subView
    if( layout.selectedItem == nil ) {
        [self fadeOutView: reportView
                    delay: 0.0f
                 duration: kSkeinAnimationReportFadeOut
                  animate: animate
              fromCurrent: YES];
        reportView.frame = NSZeroRect;
    }
    else {
        NSRect reportFrame = NSMakeRect( layout.reportPosition.x,
                                         layout.reportPosition.y,
                                         reportView.frame.size.width,
                                         reportView.frame.size.height );

        BOOL reportChangedPosition = !NSEqualPoints(reportView.frame.origin, reportFrame.origin);
        if( reportChangedPosition ) {
            [self fadeInView: reportView
                       delay: kSkeinAnimationDuration - kSkeinAnimationReportFadeIn
                    duration: kSkeinAnimationReportFadeIn
                     animate: animate
                 fromCurrent: NO];
        }
        reportView.frame = reportFrame;
    }

    // 4. Sort subviews z-order so that all the links appear below all the items
    [skeinView sortSubviewsUsingFunction: compareViewOrder
                                 context: nil];
}

- (void) updateReportDetails {
    reportView.rootTree = skeinView.layoutTree.rootLayoutItem;
    [reportView updateReportDetails];
}

- (NSArray*) reportDetails {
    return reportView.reportDetails;
}

- (IFSkeinLayoutItem*) layoutItemForItem: (IFSkeinItem*) item {
    IFSkeinItemView * itemView = itemViews[@(item.uniqueId)];
    return itemView.layoutItem;
}

- (IFSkeinItemView*) itemViewForItem: (IFSkeinItem*) item {
    return itemViews[@(item.uniqueId)];
}

-(NSRect) rectForItem:(IFSkeinItem*) item {
    IFSkeinItemView * itemView = itemViews[@(item.uniqueId)];
    NSRect result = NSZeroRect;
    if( itemView ) {
        result = itemView.frame;

        if( itemView.layoutItem.onSelectedLine ) {
            NSRect reportRect = [reportView rectForItem: itemView.layoutItem];
            reportRect = NSMakeRect( reportRect.origin.x + reportView.frame.origin.x,
                                     reportRect.origin.y + reportView.frame.origin.y,
                                     reportRect.size.width,
                                     reportRect.size.height );
            result = NSUnionRect( reportRect, result );
        }
    }
    return result;
}

-(void) setItemBlessed:(IFSkeinItem*) item bless:(BOOL) bless {
    [skeinView setItemBlessed: item bless: bless];
}

-(void) fontSizePreferenceChanged {
    // Adjust attributes of the items to the new text size
    [IFSkeinItemView adjustAttributesToFontSize];
    [IFSkeinReportView adjustAttributesToFontSize];

    reportView.forceResizeDueToFontSizeChange = YES;
}

@end
