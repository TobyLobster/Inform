//
//  IFIntelSymbol.swift
//  Inform
//
//  Created by Andrew Hunter on 05/02/2005.
//  Copyright 2005 Andrew Hunter. All rights reserved.
//  Translated from Objective-C in November 2026. The interface is still IFIntelSymbol.h, and
//  IFSectionSymbolType is defined in IFIntelConstants.m.
//

import Cocoa

@objc @implementation extension IFIntelSymbol {

    // Our relation in the list of symbols
    @objc(nextSymbol) weak var next: IFIntelSymbol?
    @objc(lastSymbol) weak var last: IFIntelSymbol?

    // Our data
    /// Name of the symbol (as displayed in the index)
    var name: String?
    /// Type of the symbol (see above)
    var type: String?
    /// Level of the symbol in the tree (calculated)
    private var _level: Int32
    /// If \c IFSymbolDeltaLevel , level is relative to the level of the preceding symbol
    var relation: IFSymbolRelation
    /// If \c relation is \c IFSymbolDelta , the difference in levels, otherwise the absolute level
    var levelDelta: Int32

    // MARK: - Initialisation

    override init() {
        _level      = -1            // == Calculate
        relation    = .onLevel
        levelDelta  = 0

        super.init()
    }

    // MARK: - Symbol data

    var level: Int32 {
        get {
            if _level < 0 {
                if relation == .onLevel {
                    return levelDelta
                }

                // Relative level
                guard let last else {
                    return levelDelta < 0 ? 0 : levelDelta
                }

                let realLevel = last.level + levelDelta

                return realLevel < 0 ? 0 : realLevel
            }

            return _level
        }
        set {
            _level = newValue
        }
    }

    // MARK: - Debug

    public override var description: String {
        return "IFIntelSymbol '\(name ?? "(null)")' - delta \(levelDelta)"
    }

    // MARK: - Our relation to other symbols in the file

    var parent: IFIntelSymbol? {
        var parent = last
        let myLevel = level

        while let symbol = parent, symbol.level >= myLevel {
            parent = symbol.last
        }

        return parent
    }

    var child: IFIntelSymbol? {
        guard let child = next else { return nil }
        if child.level > level { return child }

        return nil
    }

    var sibling: IFIntelSymbol? {
        var sibling = next
        let myLevel = level

        while let symbol = sibling, symbol.level > myLevel { sibling = symbol.next }

        guard let sibling else { return nil }
        if sibling.level == myLevel { return sibling }

        if sibling.level < myLevel {
            if sibling.parent === parent { return sibling }
        }

        return nil
    }

    var previousSibling: IFIntelSymbol? {
        var sibling = last
        let myLevel = level

        while let symbol = sibling, symbol.level > myLevel { sibling = symbol.last }

        guard let sibling else { return nil }
        if sibling.level == level { return sibling }

        return nil
    }

    // MARK: - NSCoding

    // (This is required in order to use these objects in a menu, though is not especially useful in general)

    @objc(encodeWithCoder:)
    func encode(with encoder: NSCoder) {
        encoder.encode(name,                forKey: "name")
        encoder.encode(type,                forKey: "type")
        encoder.encodeCInt(_level,          forKey: "level")
        encoder.encodeCInt(relation.rawValue, forKey: "relation")
        encoder.encodeCInt(levelDelta,      forKey: "levelDelta")
        encoder.encode(next,                forKey: "nextSymbol")
        encoder.encode(last,                forKey: "lastSymbol")
    }

    public required init?(coder decoder: NSCoder) {
        name        = decoder.decodeObject(of: NSString.self, forKey: "name") as String?
        type        = decoder.decodeObject(of: NSString.self, forKey: "type") as String?
        _level      = decoder.decodeCInt(forKey: "level")
        relation    = IFSymbolRelation(rawValue: decoder.decodeCInt(forKey: "relation")) ?? .onLevel
        levelDelta  = decoder.decodeCInt(forKey: "levelDelta")

        // No point in loading these, as we can't retain them!
        //next = decoder.decodeObject(forKey: "nextSymbol")
        //last = decoder.decodeObject(forKey: "lastSymbol")

        super.init()
    }

    class var supportsSecureCoding: Bool {
        return true
    }
}
