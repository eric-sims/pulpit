# PulpitKit

The domain core of the sacrament meeting planner: models, script templating, the hymn catalog, and
the `.pulpitplan` interchange format.

Nothing here imports SwiftUI, UIKit, or SwiftData. That's deliberate — the package targets macOS
as well as iOS, so the entire domain layer builds and tests headless on a Mac with no simulator, no
Xcode project, and no code signing:

```bash
swift test
```

Persistence lives in the app target. The `@Model` types there are a thin mapping layer over these
value types, which keeps the schema free to drift without dragging the wire format with it.

## Layout

| Folder | Contents |
|---|---|
| `Model/` | Enums and value types: `MeetingKind`, `ItemKind`, `PronounSet`, `Hymn`, statuses |
| `Scripting/` | The template engine — parser, renderer, context, live preview |
| `Templates/` | Shipped script wording and the per-meeting-kind seed orders |
| `Catalog/` | Hymn catalog loader and placement validation |
| `Interchange/` | Versioned DTOs and the import/export codec |

## The hymn catalog

`Resources/hymns.json` holds **titles, numbers, and section membership only**. No lyrics, no music
— the 1985 hymnbook and the *Hymns—For Home and Church* arrangements are copyrighted. Titles and
numbers are facts, and they're all the app needs.

Verified 26 July 2026 against [singpraises.net](https://singpraises.net):

- **Hymns (1985)** — all 341, contiguous, sacrament section confirmed at 169–196.
- **Hymns—For Home and Church** — 72 hymns: 1001–1062 general, 1201–1210 seasonal.

The new hymnbook has no published topical sections yet, so its hymns carry
`sacramentSuitability: "unknown"` rather than a guess. `HymnValidator` never warns on `unknown` —
warning about data we don't have would only train the user to ignore warnings.

### Adding a released batch

1. Append entries to `Resources/hymns.json`.
2. Raise `catalogVersion` and update `verifiedOn`.
3. Update the expected counts in `HymnCatalogTests`.

**Outstanding:** the batch released 23 July 2026 (ten hymns, including *Great Is Thy Faithfulness*
and *To God Be the Glory*) is not yet in the catalog. The titles are published but no source has
yet mapped them to hymn numbers, and a wrong number is worse than a missing one.

## The interchange format

`Interchange.currentFormatVersion` is the compatibility commitment. The DTOs in `Interchange/` are
separate from persistence on purpose, and every field decodes with a default so a file written by
an older or newer build still imports.

Three behaviors worth knowing:

- **Unknown item kinds** import as `.custom` with the raw kind string preserved, so re-exporting
  doesn't destroy information the sending app understood.
- **A newer `formatVersion`** produces an `ImportNote`, not an error.
- **Private notes are excluded by default.** Roster notes have no field in the wire format at all.
