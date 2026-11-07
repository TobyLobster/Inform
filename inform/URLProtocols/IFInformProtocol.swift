//
//  IFInformProtocol.swift
//  Inform
//
//  Created by Andrew Hunter on Sat Jun 05 2004.
//  Copyright (c) 2004 Andrew Hunter. All rights reserved.
//  Translated from Objective-C in November 2026. The interface is still IFInformProtocol.h.
//

import Cocoa
import UniformTypeIdentifiers

@objc @implementation extension IFInformProtocol {
    public override class func canInit(with request: URLRequest) -> Bool {
        // We respond to 'inform:///Foo' style URLs
        if let url = request.url as NSURL?,
           url.scheme == "inform" {
            if url.path != nil {
                return true
            }
        }
        return false
    }

    public override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        // No idea what this is supposed to do.
        // Docs pretty much say 'whatever you want'
        return request
    }

    public override func startLoading() {
        // canInitWithRequest: only answers a request with an inform: URL
        guard let url = request.url else {
            preconditionFailure("No URL to load")
        }

        // Might as well load the whole file at once
        // A URL with no path, which canInitWithRequest: doesn't answer, asks for the resources
        var urlPath = (url as NSURL).path ?? ""
        let host = (url as NSURL).host
        var path: String?

        // Note: first character will always be '/', hence the 'substring' thing
        if !urlPath.isEmpty {
            urlPath = (urlPath as NSString).substring(from: 1)
        }

        let components = (urlPath as NSString).pathComponents

        // Give nothing outside the resources or the documentation folder (a URL's path can go up out of them, as NSURL decodes "..%2F")
        if components.contains("..") {
            client?.urlProtocol(self,
                                didFailWithError: NSError(domain: NSURLErrorDomain,
                                                          code: NSURLErrorNoPermissionsToReadFile,
                                                          userInfo: nil))
            return
        }

        // Accept either the host or the path specifier containing 'extensions'
        if host?.lowercased() == "extensions" ||
            (components.count > 1 &&
             components[0].lowercased() == "extensions") {
            var skip = 0

            if host?.lowercased() != "extensions" {
                skip = 1
            }

            // Try the library directories
            var extensionPath = IFUtility.pathForInformExternalDocumentation()
            for pathComponent in components.dropFirst(skip) {
                extensionPath = (extensionPath as NSString).appendingPathComponent(pathComponent)
            }
            path = extensionPath

            if !FileManager.default.fileExists(atPath: extensionPath) {
                path = nil
            }
        } else {
            // Try using pathForResource:ofType:
            // Advantage of this is that it will allow for localisation at some point in the future
            let resourcePath = urlPath as NSString
            path = Bundle.main.path(forResource: (resourcePath.lastPathComponent as NSString).deletingPathExtension,
                                    ofType: resourcePath.pathExtension,
                                    inDirectory: resourcePath.deletingLastPathComponent)
        }

        // Check if the file is in an asset catalog.
        var assetCheckPath = (urlPath as NSString).deletingPathExtension
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

            client?.urlProtocol(self,
                                didReceive: response,
                                cacheStoragePolicy: .allowedInMemoryOnly)

            // We loaded the data
            client?.urlProtocol(self, didLoad: urlData)

            // We finished loading
            client?.urlProtocolDidFinishLoading(self)
            return
        }

        if path == nil {
            // If that fails, then just append to the resourcePath of the main bundle
            path = Bundle.main.resourcePath.map { $0 + "/" + urlPath }
        }

        guard let path else {
            // Doh - not a valid inform: URL
            client?.urlProtocol(self,
                                didFailWithError: NSError(domain: NSURLErrorDomain,
                                                          code: NSURLErrorBadURL,
                                                          userInfo: nil))
            return
        }

        // Check that the file exists and is not a directory
        var isDir: ObjCBool = true
        if !FileManager.default.fileExists(atPath: path,
                                           isDirectory: &isDir) {
            isDir = true
        }

        if isDir.boolValue {
            // Will also happen if the file doesn't exist: see above
            client?.urlProtocol(self,
                                didFailWithError: NSError(domain: NSURLErrorDomain,
                                                          code: NSURLErrorFileDoesNotExist,
                                                          userInfo: nil))
            // (Yeah, there's technically a difference between NSURLErrorFileDoesNotExist and
            // NSURLErrorFileIsDirectory. But I'm lazy here)
            return
        }

        // Load up the data
        guard let urlData = NSData(contentsOfFile: path) as Data? else {
            // Failed to load for some other reason
            client?.urlProtocol(self,
                                didFailWithError: NSError(domain: NSURLErrorDomain,
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

        client?.urlProtocol(self,
                            didReceive: response,
                            cacheStoragePolicy: .allowedInMemoryOnly)

        // We loaded the data
        client?.urlProtocol(self, didLoad: urlData)

        // We finished loading
        client?.urlProtocolDidFinishLoading(self)
    }

    public override func stopLoading() {
    }
}
