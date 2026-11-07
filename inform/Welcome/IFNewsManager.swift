//
//  IFNewsManager.swift
//  Inform
//
//  Created by Toby Nelson on 20/06/2022.
//  Translated from Objective-C in November 2026. The interface is still IFNewsManager.h.
//

import Foundation

@objc @implementation extension IFNewsManager {
    /// Where the news is kept, with when it was downloaded
    private final let defaults: UserDefaults
    /// What downloads the news
    private final let session: URLSession
    private final let _newsSchemeHandler: IFNewsCustomSchemeHandler

    var newsSchemeHandler: IFNewsCustomSchemeHandler {
        return _newsSchemeHandler
    }

    override convenience init() {
        self.init(defaults: UserDefaults.standard,
                  session: URLSession.shared)
    }

    init(defaults newDefaults: UserDefaults,
         session newSession: URLSession) {
        defaults = newDefaults
        session = newSession
        _newsSchemeHandler = IFNewsCustomSchemeHandler()
        super.init()
    }

    func getNewsWithCompletionHandler(_ completionHandler: @escaping @Sendable (String?, URLResponse?, (any Error)?) -> Void) {
        let now = Date()

        // Do we have a recent cached news?
        // Step 1: Get timestamp of previous news
        if let newsTimestamp = defaults.object(forKey: "newsTimestamp") as? Date {
            // Step 2: Check that it was recent
            let calendar = Calendar.current
            let components: Set<Calendar.Component> = [.day, .month, .year]

            // Extract the day itself for now, and the cached version
            let nowComponents    = calendar.dateComponents(components, from: now)
            let cachedComponents = calendar.dateComponents(components, from: newsTimestamp)

            let nowDate     = calendar.date(from: nowComponents)
            let cachedDate  = calendar.date(from: cachedComponents)

            if nowDate == cachedDate {
                // Step 3: Get cached news
                let latestNews = defaults.string(forKey: "newsString")
                gotNews(latestNews, completionHandler: completionHandler, response: nil, error: nil)
                return
            }
        }

        // No - download latest news
        let url = URL(string: "https://iftechfoundation.org/calendar/cal.txt")!

        let task = session.dataTask(with: url) { data, response, error in
            // A server's error page isn't news
            var serverFailed = false
            if let response = response as? HTTPURLResponse {
                let status = response.statusCode
                serverFailed = (status < 200) || (status >= 300)
            }

            if let data, !serverFailed {
                let latestNews = NSString(data: data, encoding: String.Encoding.utf8.rawValue) as String? ?? ""

                // Save latest news in cache
                self.defaults.set(now, forKey: "newsTimestamp")
                self.defaults.set(latestNews, forKey: "newsString")

                self.gotNews(latestNews, completionHandler: completionHandler, response: response, error: error)
            } else {
                // log but basically ignore any error downloading the news
                let failure: Any? = error ?? response
                NSLog("%@", failure.map { "\($0)" } ?? "(null)")
                completionHandler("", response, error)
                return
            }
        }
        task.resume()
    }

    private final func gotNews(_ latestNews: String?,
                               completionHandler: @escaping @Sendable (String?, URLResponse?, (any Error)?) -> Void,
                               response: URLResponse?,
                               error: (any Error)?) {
        // Call the completion handler on another thread, as the download's is
        DispatchQueue.global(qos: .default).async {
            completionHandler(latestNews, response, error)
        }
    }
}
