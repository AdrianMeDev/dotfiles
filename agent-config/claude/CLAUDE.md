# Globale Anweisungen – Claude Code (Arbeit)

Projektspezifische Regeln (CLAUDE.md im Repo, `.editorconfig`, Linter, bestehender Code-Stil) haben immer Vorrang vor dieser Datei.

## Kommunikation
- Erklärungen an mich auf Deutsch. Code, Kommentare, Commit-Messages und PR-Texte auf Englisch, sofern das Projekt nichts anderes vorgibt.
- Sachlich und knapp. Annahmen, Risiken und offene Punkte ausdrücklich nennen statt sie stillschweigend zu entscheiden.
- **Knapp antworten:** keine Einleitung, die Aufgabe nicht wiederholen, keinen Diff nacherzählen, den ich selbst sehe, keine Abschlussfloskeln. Code, Befehle und Fehlermeldungen vollständig; drumherum so kurz wie möglich.
- Nach jeder Umsetzung: kurze Zusammenfassung – was geändert wurde, wo (`datei:zeile`), warum, und wie ich es teste. Für eine ausführliche Erklärung: `/explain`.

## Arbeitsweise
- Nicht-triviale Aufgaben: erst erkunden, dann einen Plan vorlegen und auf Freigabe warten (`/plan-commits`).
- Kleine, fokussierte Diffs. Kein Refactoring nebenbei, keine Formatierungsänderungen an unbeteiligten Dateien.
- Neue Abhängigkeiten nur nach Rückfrage (Lizenz, Wartungszustand, Größe).
- „Fertig“ heißt: baut, Tests grün, Lint sauber, neue Logik hat Tests. Berichte, welche Checks du ausgeführt hast und mit welchem Ergebnis.
- Git-, PR- und Ticket-Aktionen (`commit`, `push`, `merge`, `rebase`, `gh`/`glab` anlegen oder mergen) führe ausschließlich ich aus – keine Ausnahme, auch nicht auf Nachfrage. Zeige stattdessen den Befehl (Commits im Conventional-Commits-Format). Claude Code blockiert sie zusätzlich per `deny`.
- Fehlerursachen erst verstehen, dann beheben – keine Symptom-Workarounds (z. B. Tests abschalten, `any`, `# type: ignore`, `!`-Operator), ohne es zu begründen.

## Workflow: Roadmap → Plan → Schritt → Commit → `/next`
- Große Vorhaben (ganze App, großes Feature): erst `/plan-roadmap` – Meilensteine in `.agent/ROADMAP.md`.
- Aufgaben mit mehr als einem Commit bzw. der nächste Meilenstein: `/plan-commits` – Plan aus kleinen Schritten, **ein Schritt = ein Commit**, gespeichert in `.agent/plan.md`. Nichts umsetzen, bevor ich den Plan freigebe.
- `/next` setzt **genau einen** Schritt um, prüft ihn und **stoppt** dann mit Commit-Vorschlag. Ich prüfe und committe selbst; erst mein nächstes `/next` startet den nächsten Schritt.
- Ist ein Schritt fertig, aber nicht committet, beginnst du keinen neuen.

## Kontext sparsam nutzen
- Gezielt lesen: erst suchen (`rg`, Symbolnavigation), dann nur die relevanten Dateien bzw. Abschnitte lesen – nicht ganze Ordner.
- Lange Ausgaben (Tests, Builds, Logs) gefiltert ansehen, z. B. nur Fehler und die letzten Zeilen.
- Gedächtnis liegt lokal in `.agent/` (nicht im Git): `.agent/plan.md` (Plan, Status) und `.agent/notes.md` (Erkenntnisse, offene Punkte). Danach reicht das als Kontext.
- Budget: je Agent höchstens ca. 150k Token. Zwischen Schritten `/clear` – ich darf jederzeit.

## Compact instructions
Beim Komprimieren behalten: Stand von `.agent/plan.md` (aktueller Schritt, Status), neue Einträge in `.agent/notes.md`, offene Entscheidungen, aktuelle Fehlermeldungen und geänderte Dateien.
Weglassen: Erkundungs-Ausgaben, gelesene Dateiinhalte, erledigte Zwischenschritte.

## Sicherheit & Compliance
- Keine Secrets, Tokens, Zugangsdaten oder Kundendaten in Code, Logs, Testdaten, Commits oder Prompts. `.env`- und Secret-Dateien nicht lesen.
- Keine produktiven oder geteilten Systeme ansprechen. Migrations erzeugen ja, gegen geteilte Datenbanken anwenden nein.
- Eingaben validieren, parametrisierte Queries, Autorisierung serverseitig prüfen, keine sensiblen Daten in Fehlermeldungen.

## Stack-Konventionen (wenn das Projekt nichts anderes festlegt)

### Angular
- Standalone Components, Signals für Zustand, `inject()` statt Konstruktor-Injection, `ChangeDetectionStrategy.OnPush`.
- Neuer Control Flow (`@if`, `@for` mit `track`), strikt typisiert, kein `any`.
- RxJS nur wo Streams sinnvoll sind; Subscriptions mit `takeUntilDestroyed()` oder `toSignal()`.

### Django
- Views dünn halten, Logik in Models, Services oder Forms/Serializers.
- QuerySets effizient: `select_related`/`prefetch_related`, N+1 vermeiden.
- Migrations committen, bereits angewandte nie ändern. Konfiguration über Umgebungsvariablen.

### C# / .NET
- Nullable Reference Types an, durchgehend `async`/`await` (kein `.Result`/`.Wait()`), `CancellationToken` durchreichen.
- Dependency Injection über den Konstruktor, Options-Pattern für Konfiguration.
- EF Core: `AsNoTracking()` für reine Lesezugriffe, keine Queries in Schleifen.
