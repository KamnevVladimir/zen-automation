import Foundation

extension String {
    func sanitized() -> String {
        return self.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    func truncate(to length: Int, addEllipsis: Bool = true) -> String {
        if self.count <= length {
            return self
        }
        
        let endIndex = self.index(self.startIndex, offsetBy: length)
        let truncated = String(self[..<endIndex])
        
        return addEllipsis ? truncated + "..." : truncated
    }
    
    func removeHTMLTags() -> String {
        return self.replacingOccurrences(
            of: "<[^>]+>",
            with: "",
            options: .regularExpression,
            range: nil
        )
    }
}

