import MCP

extension CallTool.Result {
    /// A successful tool result carrying `text` as plain text.
    static func success(_ text: String) -> CallTool.Result {
        CallTool.Result(content: [.text(text: text, annotations: nil, _meta: nil)], isError: false)
    }
    
    /// An error tool result carrying `text` as plain text.
    static func failure(_ text: String) -> CallTool.Result {
        CallTool.Result(content: [.text(text: text, annotations: nil, _meta: nil)], isError: true)
    }
}
