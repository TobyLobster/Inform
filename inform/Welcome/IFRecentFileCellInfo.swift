//
//  IFRecentFileCellInfo.swift
//  Inform
//
//  Created by Toby Nelson on 28/09/2023.
//

import Foundation

@objc public enum IFRecentFileType:Int {
    case File
    case Open
    case CreateProject
    case CreateExtension
    case CopySample
    case WebsiteLink
    case SaveEPubs
}

@objc class IFRecentFileCellInfo : NSObject, NSCopying {

    @objc public var title:String!
    @objc public var image:NSImage?
    @objc public var url:NSURL?
    @objc public var type:IFRecentFileType = IFRecentFileType.File

    @objc init(title:String!, image:NSImage!, url:NSURL!, type:IFRecentFileType) {
        super.init()

        self.title      = title.copy() as? String
        self.image      = image?.copy() as? NSImage
        self.url        = url?.copy() as? NSURL
        self.type       = type
    }

    func copy(with zone: NSZone? = nil) -> Any {
        let cellInfo = IFRecentFileCellInfo(title: title,
                                            image: image,
                                            url: url,
                                            type: type)
        return cellInfo
    }
}
