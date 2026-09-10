import Foundation
import Testing
@testable import traders_guild

/// Cursors placed in a query string must survive the trip.
///
/// Found by running the real app against the real backend: the marker list
/// returned 500 on every page after the first, while the thesis thread paged
/// correctly. The difference was not the endpoint — it was the cursor's shape.
struct CursorQueryEncodingTests {

    /// `.urlQueryAllowed` permits `+`, and `+` in a query string means a space.
    ///
    /// A timestamp cursor of `…415598+00:00` therefore arrives as
    /// `…415598 00:00`, which the server's ISO parser rejects with
    /// `ValueError: Unused components in ISO string`. Reproduced directly:
    /// percent-encoded returns 200, literal-plus returns 500, `Z` returns 200.
    @Test
    func aTimestampCursorHasItsPlusEscaped() {
        let cursor = "2026-09-09T17:20:49.415598+00:00"
        #expect(cursor.tgQueryEncoded == "2026-09-09T17:20:49.415598%2B00:00")
        #expect(
            !cursor.tgQueryEncoded.contains("+"),
            "a bare + would be read as a space and corrupt the timestamp"
        )
    }

    /// The reason this went unnoticed for so long. Thread cursors are Fernet
    /// tokens in base64url, an alphabet with `-` and `_` but no `+`, so they
    /// were correct by luck rather than by encoding. They must stay byte-exact:
    /// the server decrypts them and compares the embedded marker id.
    @Test
    func anOpaqueBase64URLCursorIsUnchanged() {
        let cursor = "gAAAAABqoabHNCArwx-_9zQmVsbG8"
        #expect(cursor.tgQueryEncoded == cursor)
    }

    /// A `Z`-spelled instant needs no escaping and must not acquire any.
    @Test
    func aZSpelledCursorIsUnchanged() {
        let cursor = "2026-09-09T17:20:49.415598Z"
        #expect(cursor.tgQueryEncoded == cursor)
    }

    /// Query delimiters are escaped too, so a cursor can never smuggle in
    /// another parameter.
    @Test
    func queryDelimitersCannotEscapeTheValue() {
        let hostile = "abc&limit=1?x#y"
        let encoded = hostile.tgQueryEncoded
        for delimiter in ["&", "=", "?", "#"] {
            #expect(!encoded.contains(delimiter), "\(delimiter) must be escaped")
        }
    }
}
