import Foundation
import SacramentKit

/// Builds the conducting sheet as HTML.
///
/// HTML rather than a hand-paginated SwiftUI view because scripts are variable-length text and
/// letting WebKit do the flow and page breaks is both far less code and a better result — the
/// output has real selectable, searchable text.
///
/// This is *your* copy, not the congregation's: it carries full scripts, private notes and
/// assignment statuses.
enum ConductingSheetHTML {

    static func document(
        for meeting: Meeting,
        templates: [ScriptTemplate],
        includePrivateNotes: Bool
    ) -> String {
        let dateText = meeting.date.formatted(.dateTime.weekday(.wide).month(.wide).day().year())

        var rows = ""
        for item in meeting.orderedItems {
            rows += section(for: item, in: meeting, templates: templates, includePrivateNotes: includePrivateNotes)
        }

        return """
        <!doctype html>
        <html><head><meta charset="utf-8">\(style)</head>
        <body>
          <header>
            <h1>\(escape(dateText))</h1>
            <p class="sub">\(escape(meeting.kind.displayName))\(meeting.unitName.isEmpty ? "" : " &middot; " + escape(meeting.unitName))</p>
            \(themeLine(meeting))
            <table class="leadership">\(leadershipRows(meeting))</table>
          </header>
          \(rows)
          <footer>Conducting notes — not the congregation's program.</footer>
        </body></html>
        """
    }

    // MARK: - Pieces

    private static func themeLine(_ meeting: Meeting) -> String {
        guard let theme = meeting.theme, !theme.isEmpty else { return "" }
        return "<p class=\"sub\">Theme: \(escape(theme))</p>"
    }

    private static func leadershipRows(_ meeting: Meeting) -> String {
        let people: [(String, Person?)] = [
            ("Presiding", meeting.presiding),
            ("Conducting", meeting.conducting),
            ("Chorister", meeting.chorister),
            ("Organist", meeting.organist),
        ]
        return people.compactMap { label, person in
            guard let person else { return nil }
            return "<tr><th>\(label)</th><td>\(escape(person.addressedName))</td></tr>"
        }.joined()
    }

    private static func section(
        for item: ProgramItem,
        in meeting: Meeting,
        templates: [ScriptTemplate],
        includePrivateNotes: Bool
    ) -> String {
        var body = ""

        if let hymn = item.hymn {
            body += "<p class=\"detail\">\(escape(hymn.displayLabel)) <span class=\"muted\">(\(escape(hymn.book.displayName)))</span></p>"
        }

        for assignment in item.orderedAssignments where assignment.isFilled {
            var line = "<p class=\"detail\">\(escape(assignment.role.displayName)): <strong>\(escape(assignment.displayName ?? ""))</strong>"
            if let calling = assignment.callingText, !calling.isEmpty {
                line += " &mdash; \(escape(calling))"
            }
            if let office = assignment.officeText, !office.isEmpty {
                line += " &mdash; \(escape(office))"
            }
            if let topic = assignment.topic, !topic.isEmpty {
                line += " &mdash; \(escape(topic))"
            }
            if assignment.needsFollowUp {
                line += " <span class=\"status\">\(escape(assignment.status.displayName))</span>"
            }
            if let phonetic = assignment.person?.phoneticSpelling, !phonetic.isEmpty {
                line += " <span class=\"muted\">[\(escape(phonetic))]</span>"
            }
            body += line + "</p>"
        }

        if !item.orderedEntries.isEmpty {
            body += "<ul class=\"checklist\">"
            for entry in item.orderedEntries {
                body += "<li>\(escape(entry.text))</li>"
            }
            body += "</ul>"
        }

        if let rendering = ScriptComposer.render(item, in: meeting, templates: templates) {
            body += "<div class=\"script\">\(html(for: rendering))</div>"
        }

        if includePrivateNotes, let notes = item.notes, !notes.isEmpty {
            body += "<p class=\"note\">\(escape(notes))</p>"
        }

        return """
        <section>
          <h2><span class="box"></span>\(escape(item.title))</h2>
          \(body)
        </section>
        """
    }

    /// Emphasized segments — the names — become bold, which is the one thing you must not misread.
    /// Newlines become paragraph breaks so the script keeps the shape it has on screen.
    private static func html(for rendering: ScriptRendering) -> String {
        rendering.segments.map { segment in
            let text = escape(segment.text).replacingOccurrences(of: "\n", with: "<br>")
            return segment.isEmphasized ? "<strong>\(text)</strong>" : text
        }.joined()
    }

    static func escape(_ value: String) -> String {
        value
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
    }

    // MARK: - Style

    private static let style = """
    <style>
      /* No @page margins: the print renderer owns the page box and its margins, and setting
         both makes the content narrower than it should be. */
      body {
        font: 11pt/1.45 -apple-system, "Helvetica Neue", sans-serif;
        color: #111; margin: 0;
      }
      header { border-bottom: 2px solid #111; padding-bottom: 8pt; margin-bottom: 12pt; }
      h1 { font-size: 18pt; margin: 0 0 2pt; }
      .sub { margin: 0; color: #555; font-size: 10pt; }
      table.leadership { margin-top: 6pt; border-collapse: collapse; font-size: 10pt; }
      table.leadership th {
        text-align: left; font-weight: 600; color: #555;
        padding-right: 10pt; white-space: nowrap;
      }
      /* Keep an item and its script on one page wherever it fits. */
      section { page-break-inside: avoid; margin-bottom: 11pt; }
      h2 { font-size: 12.5pt; margin: 0 0 3pt; display: flex; align-items: center; }
      .box {
        display: inline-block; width: 10pt; height: 10pt;
        border: 1pt solid #666; border-radius: 2pt; margin-right: 7pt; flex: none;
      }
      .detail { margin: 1pt 0 1pt 17pt; font-size: 10.5pt; }
      .script {
        margin: 4pt 0 0 17pt; padding-left: 9pt;
        border-left: 2pt solid #ccc; font-size: 11pt;
      }
      .checklist { margin: 2pt 0 2pt 17pt; padding-left: 14pt; }
      .checklist li { margin: 1pt 0; }
      .note { margin: 4pt 0 0 17pt; font-size: 9.5pt; color: #444; font-style: italic; }
      .muted { color: #777; }
      .status {
        font-size: 8.5pt; border: 0.5pt solid #b45; color: #b45;
        border-radius: 3pt; padding: 0 3pt;
      }
      footer {
        margin-top: 14pt; padding-top: 6pt; border-top: 0.5pt solid #ccc;
        color: #777; font-size: 9pt;
      }
    </style>
    """
}
