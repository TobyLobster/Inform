//
//  IFNewsManager.m
//  Inform
//
//  Created by Toby Nelson on 20/06/2022.
//

#import <Foundation/Foundation.h>
#import "IFNewsManager.h"

@implementation IFNewsManager

-(instancetype) init {
    self = [super init];
    if( self ) {
        self.newsSchemeHandler = [[IFNewsCustomSchemeHandler alloc] init];
    }
    return self;
}

-(void)     getNewsWithCompletionHandler: (void (^)(NSString * _Nullable news, NSURLResponse * _Nullable response, NSError * _Nullable error)) completionHandler {
    __block NSString* latestNews = @"";

    NSDate* now = [NSDate date];

    // Do we have a recent cached news?
    // Step 1: Get timestamp of previous news
    NSDate* newsTimestamp = [[NSUserDefaults standardUserDefaults] objectForKey: @"newsTimestamp"];
    if (newsTimestamp != nil) {
        // Step 2: Check that it was recent
        NSCalendar *calendar = [NSCalendar currentCalendar];
        NSInteger components = (NSCalendarUnitDay | NSCalendarUnitMonth | NSCalendarUnitYear);

        // Extract the day itself for now, and the cached version
        NSDateComponents *nowComponents  = [calendar components:components fromDate:now];
        NSDateComponents *cachedComponents = [calendar components:components fromDate:newsTimestamp];

        NSDate *nowDate     = [calendar dateFromComponents:nowComponents];
        NSDate *cachedDate  = [calendar dateFromComponents:cachedComponents];

        NSComparisonResult result = [nowDate compare:cachedDate];
        if (result == NSOrderedSame) {
            // Step 3: Get cached news
            latestNews = [[NSUserDefaults standardUserDefaults] stringForKey: @"newsString"];
            [self gotNews: latestNews now:now completionHandler: completionHandler response: nil error: nil];
            return;
        }
    }

    // No - download latest news
    NSURL* url = [NSURL URLWithString:@"https://iftechfoundation.org/calendar/cal.txt"];

    self.task = [[NSURLSession sharedSession] dataTaskWithURL: url
                                            completionHandler: ^(NSData* data, NSURLResponse* response, NSError* error) {
        if (data != nil) {
            latestNews = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
            if (latestNews == nil) {
                latestNews = @"";
            }

            // Save latest news in cache
            [[NSUserDefaults standardUserDefaults] setObject: now forKey:@"newsTimestamp"];
            [[NSUserDefaults standardUserDefaults] setObject: latestNews forKey:@"newsString"];

            [self gotNews: latestNews now:now completionHandler: completionHandler response: response error: error];
        }
        else {
            // log but basically ignore any error downloading the news
            NSLog(@"%@", error);
            completionHandler(@"", response, error);
            return;
        }
    }];
    [self.task resume];
}

-(void)     gotNews: (NSString*) latestNews
                now: (NSDate*) now
  completionHandler: (void (^)(NSString * _Nullable news, NSURLResponse * _Nullable response, NSError * _Nullable error)) completionHandler
           response: (NSURLResponse*) response
              error: (NSError*) error {
    // Call the completion handler on the UI thread
    dispatch_queue_t queue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);
    dispatch_async(queue,
    ^{
        completionHandler(latestNews, response, error);
    });
}

@end
