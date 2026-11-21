# Globale Anweisungen – Codex (private Projekte)

Projektspezifische Regeln (AGENTS.md im Repo, `.editorconfig`, Linter, bestehender Code-Stil) haben immer Vorrang vor dieser Datei.

## Kommunikation
- Erklärungen an mich auf Deutsch. Code, Kommentare, Commit-Messages und PR-Texte auf Englisch, sofern das Projekt nichts anderes vorgibt.
- Sachlich und knapp. Annahmen, Risiken und offene Punkte ausdrücklich nennen statt sie stillschweigend zu entscheiden.
- **Knapp antworten:** keine Einleitung, die Aufgabe nicht wiederholen, keinen Diff nacherzählen, den ich selbst sehe, keine Abschlussfloskeln. Code, Befehle und Fehlermeldungen vollständig; drumherum so kurz wie möglich.
- Nach jeder Umsetzung: kurze Zusammenfassung – was geändert wurde, wo (`datei:zeile`), warum, und wie ich es teste. Für eine ausführliche Erklärung: `$explain`.

## Arbeitsweise
- Nicht-triviale Aufgaben: erst erkunden, dann einen Plan vorlegen und auf Freigabe warten (`$plan-commits`).
- Kleine, fokussierte Diffs. Kein Refactoring nebenbei, keine Formatierungsänderungen an unbeteiligten Dateien.
- Neue Abhängigkeiten nur nach Rückfrage (Lizenz, Wartungszustand, Größe).
- „Fertig“ heißt: baut, Tests grün, Lint sauber, neue Logik hat Tests. Berichte, welche Checks du ausgeführt hast und mit welchem Ergebnis.
- Kein `git commit`, `git push` oder PR ohne ausdrückliche Aufforderung. Commits im Conventional-Commits-Format. `$next-all` ist so eine Aufforderung: es committet selbst, aber nur auf einem Feature-Branch und pusht nie.
- Fehlerursachen erst verstehen, dann beheben – keine Symptom-Workarounds (z. B. Tests abschalten, `any`, `# type: ignore`, `!`-Operator), ohne es zu begründen.

## Einfachste Lösung (gilt auch außerhalb von `$next`)
Faul bei der Lösung, nie beim Lesen des Codes. Erst Code und Aufrufer lesen, dann die erste Option, die vollständig funktioniert: 1. muss es existieren? 2. gibt es das schon im Projekt? 3. Standardbibliothek oder Plattform (außer das Projekt hat eine eigene UI-Lib, z. B. Syncfusion – die gewinnt)? 4. installierte Abhängigkeit? 5. eine lesbare Zeile? 6. erst dann das Minimum. Keine Abstraktion, Option oder Vorsorge, die niemand verlangt hat. Nie kürzen: Validierung an Vertrauensgrenzen, Fehlerbehandlung gegen Datenverlust, Sicherheit, Barrierefreiheit. Am Ende 1–2 Zeilen: was ausgelassen oder nicht geprüft wurde und welches Risiko ich kennen muss.

## Workflow: Roadmap → Plan → Schritt → Commit → `$next`
- Große Vorhaben (ganze App, großes Feature): erst `$plan-roadmap` – Meilensteine in `docs/ROADMAP.md`.
- Aufgaben mit mehr als einem Commit bzw. der nächste Meilenstein: `$plan-commits` – Plan aus kleinen Schritten, **ein Schritt = ein Commit**, gespeichert in `.agent-plan.md`. Nichts umsetzen, bevor ich den Plan freigebe.
- `$next` setzt **genau einen** Schritt um, prüft ihn und **stoppt** dann mit Commit-Vorschlag. Ich prüfe und committe selbst; erst mein nächstes `$next` startet den nächsten Schritt.
- Ist ein Schritt fertig, aber nicht committet, beginnst du keinen neuen.
- `$next-all` setzt den ganzen Plan am Stück um: Feature-Branch, ein Commit pro Schritt, Stopp bei Fehlschlag. Kein Review zwischen den Schritten – Prüfung danach über `git log` und den Diff gegen die Basis.

## Kontext sparsam nutzen
- Gezielt lesen: erst suchen (`rg`, Symbolnavigation), dann nur die relevanten Dateien bzw. Abschnitte lesen – nicht ganze Ordner.
- Lange Ausgaben (Tests, Builds, Logs) gefiltert ansehen, z. B. nur Fehler und die letzten Zeilen.
- Nach einem freigegebenen Plan reicht `.agent-plan.md` als Gedächtnis – ich darf jederzeit `/clear` machen.

## Compact instructions
Beim Komprimieren behalten: Stand von `.agent-plan.md` (aktueller Schritt, Status), offene Entscheidungen, aktuelle Fehlermeldungen und geänderte Dateien.
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
