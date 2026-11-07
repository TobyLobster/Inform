//
//  IFNewsCustomSchemeHandler.swift
//  Inform
//
//  Created by Toby Nelson on 21/06/2022.
//  Translated from Objective-C in November 2026. The interface is still IFNewsCustomSchemeHandler.h.
//

import Cocoa
import UniformTypeIdentifiers
import WebKit

@objc @implementation extension IFNewsCustomSchemeHandler {
    @objc(webView:startURLSchemeTask:)
    func webView(_ webView: WKWebView,
                 start urlSchemeTask: any WKURLSchemeTask) {
        // check for 'inform:' scheme aka. protocol
        guard let url = urlSchemeTask.request.url,
              url.scheme?.lowercased() == "inform" else {
            return
        }

        // Might as well load the whole file at once
        // A URL with no path, such as "inform:", or "inform:file.html" with no slash, asks for the resources
        var urlPath = (url as NSURL).path ?? ""
        var path: String?

        // Note: first character will always be '/', hence the 'substring' thing
        if !urlPath.isEmpty {
            urlPath = (urlPath as NSString).substring(from: 1)
        }

        // Give nothing outside the resources folder (a URL's path can go up out of it, as NSURL decodes "..%2F")
        if (urlPath as NSString).pathComponents.contains("..") {
            urlSchemeTask.didFailWithError(NSError(domain: NSURLErrorDomain,
                                                   code: NSURLErrorNoPermissionsToReadFile,
                                                   userInfo: nil))
            return
        }

        // Try using pathForResource:ofType:
        // Advantage of this is that it will allow for localisation at some point in the future
        let resourcePath = urlPath as NSString
        path = Bundle.main.path(forResource: (resourcePath.lastPathComponent as NSString).deletingPathExtension,
                                ofType: resourcePath.pathExtension,
                                inDirectory: resourcePath.deletingLastPathComponent)

        // Check if the file is in an asset catalog.
        var assetCheckPath = resourcePath.deletingPathExtension
        if (assetCheckPath as NSString).ends(withCaseInsensitive: "@2x") {
            assetCheckPath = (assetCheckPath as NSString).replacing("@2x", with: "")
        }
        let img = NSImage(named: assetCheckPath)

        if path == nil, let img {
            //Just output TIFF: it uses the least amount of code:
            let urlData = img.tiffRepresentation ?? Data()
            //Which means a TIFF MIME type. Regardless of extension.
            let ourType = "image/tiff"

            // Create the response
            let response = URLResponse(url: url,
                                       mimeType: ourType,
                                       expectedContentLength: urlData.count,
                                       textEncodingName: nil)

            urlSchemeTask.didReceive(response)  // We have a response
            urlSchemeTask.didReceive(urlData)   // We loaded the data
            urlSchemeTask.didFinish()           // We finished loading
            return
        }

        if path == nil {
            // If that fails, then just append to the resourcePath of the main bundle
            path = Bundle.main.resourcePath.map { $0 + "/" + urlPath }
        }

        // Error out if we can't find the path to the resource
        guard let path else {
            urlSchemeTask.didFailWithError(NSError(domain: NSURLErrorDomain,
                                                   code: NSURLErrorBadURL,
                                                   userInfo: nil))
            return
        }

        // Check that the file exists and is not a directory
        var isDir: ObjCBool = true
        let fileExists = FileManager.default.fileExists(atPath: path,
                                                        isDirectory: &isDir)
        if !fileExists {
            urlSchemeTask.didFailWithError(NSError(domain: NSURLErrorDomain,
                                                   code: NSURLErrorFileDoesNotExist,
                                                   userInfo: nil))
            return
        }

        if isDir.boolValue {
            urlSchemeTask.didFailWithError(NSError(domain: NSURLErrorDomain,
                                                   code: NSURLErrorFileIsDirectory,
                                                   userInfo: nil))
            return
        }

        // Load up the data
        guard let urlData = NSData(contentsOfFile: path) as Data? else {
            // Failed to load for some other reason
            urlSchemeTask.didFailWithError(NSError(domain: NSURLErrorDomain,
                                                   code: NSURLErrorCannotOpenFile,
                                                   userInfo: nil))
            return
        }

        // Work out the MIME type
        let pathExtension = (path as NSString).pathExtension
        var ourType = UTType(filenameExtension: pathExtension,
                             conformingTo: .data)?.preferredMIMEType

        if ourType == nil {
            ourType = "text/html"
            if pathExtension == "gif" {
                ourType = "image/gif"
            } else if pathExtension == "jpeg" ||
                      pathExtension == "jpg" {
                ourType = "image/jpeg"
            } else if pathExtension == "png" {
                ourType = "image/png"
            } else if pathExtension == "tiff" ||
                      pathExtension == "tif" {
                ourType = "image/tiff"
            }
        }

        // Create the response
        let response = URLResponse(url: url,
                                   mimeType: ourType,
                                   expectedContentLength: urlData.count,
                                   textEncodingName: nil)

        urlSchemeTask.didReceive(response)
        urlSchemeTask.didReceive(urlData)
        urlSchemeTask.didFinish()
    }

    @objc(webView:stopURLSchemeTask:)
    func webView(_ webView: WKWebView,
                 stop urlSchemeTask: any WKURLSchemeTask) {
    }
}
