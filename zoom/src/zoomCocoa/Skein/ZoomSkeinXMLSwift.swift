//
//  ZoomSkeinXML.swift
//  Zoom
//
//  Created by C.W. Betts on 10/10/21.
//

import Foundation

private extension String {
	func byEscapingXMLCharacters() -> String {
		let charArray = self.compactMap { theChar -> String? in
			switch theChar {
			case "\n":
				return "\n"
				
			case "&":
				return "&amp;"
				
			case "<":
				return "&lt;"
				
			case ">":
				return "&gt;"
				
			case "\"":
				return "&quot;"
				
			case "'":
				return "&apos;"
				
			case "\0" ..< " ":
				// Ignore (expat can't parse these)
				// TODO: But can NSXMLParser/libxml2?
				return nil
				
			default:
				return String(theChar)
			}
		}
		
		return charArray.joined()
	}
}

extension ZoomSkein {
	/// Creates an XML representation of the Skein.
	@objc public func xmlData() -> String {
		// Structure summary (note to me: write this up properly later)
		
		// <Skein rootNode="<nodeID>" xmlns="http://www.logicalshift.org.uk/IF/Skein">
		//   <generator>Zoom</generator>
		//   <activeItem nodeId="<nodeID" />
		//   <item nodeId="<nodeID>">
		//     <command/>
		//     <result/>
		//     <annotation/>
		//	   <commentary/>
		//     <played>YES/NO</played>
		//     <changed>YES/NO</changed>
		//     <temporary score="score">YES/NO</temporary>
		//     <children>
		//       <child nodeId="<nodeID>"/>
		//     </children>
		//   </item>
		// </Skein>
		//
		// nodeIDs are string uniquely identifying a node: any format
		// A node must not be a child of more than one item
		// All item fields are optional.
		// Root item usually has the command '- start -'

		var result =
#"""
<Skein rootNode="\#(rootItem.nodeIdentifier.uuidString)" xmlns="http://www.logicalshift.org.uk/IF/Skein">
   <generator>Zoom</generator>
   <activeNode nodeId="\#(activeItem.nodeIdentifier.uuidString)"/>

"""#
		
		var itemStack = [rootItem]
		
		while itemStack.count > 0 {
			// Pop from the stack
			let node = itemStack.removeLast()

			// Push any children of this node
			itemStack.append(contentsOf: node.children)
			
			// Generate the XML for this node
			result += #"  <item nodeId="\#(node.nodeIdentifier.uuidString)">\#n"#

			if let command = node.command?.byEscapingXMLCharacters() {
				result += #"    <command xml:space="preserve">\#(command)</command>\#n"#
			}
			if let result2 = node.result?.byEscapingXMLCharacters() {
				result += #"    <result xml:space="preserve">\#(result2)</result>\#n"#
			}
			if let annotation = node.annotation?.byEscapingXMLCharacters() {
				result += #"    <annotation xml:space="preserve">\#(annotation)</annotation>\#n"#
			}
			if let commentary = node.commentary?.byEscapingXMLCharacters() {
				result += #"    <commentary xml:space="preserve">\#(commentary)</commentary>\#n"#
			}

			result += "    <played>\(node.played ? "YES" : "NO")</played>\n"
			result += "    <changed>\(node.changed ? "YES" : "NO")</changed>\n"
			result += #"    <temporary score="\#(node.temporaryScore)">\#(node.isTemporary ? "YES" : "NO")</temporary>\#n"#
			
			if node.children.count > 0 {
				result.append("    <children>\n")
				
				for childNode in node.children {
					result += #"      <child nodeId="\#(childNode.nodeIdentifier.uuidString)"/>\#n"#
				}
				
				result.append("    </children>\n")
			}
			
			result.append("  </item>\n")
		}
		// Write footer
		result.append("</Skein>\n")
		
		return result
	}
}
