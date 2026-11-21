# Globale Anweisungen – pi (private Projekte, lokales Modell)

## Kommunikation
- Antworte auf Deutsch, in der Du-Form. Code, Bezeichner, Kommentare und Commit-Messages auf Englisch.
- **Knapp antworten:** keine Einleitung, die Aufgabe nicht wiederholen, keinen Diff nacherzählen, den ich selbst sehe, keine Abschlussfloskeln. Code, Befehle und Fehlermeldungen vollständig; drumherum so kurz wie möglich.
- Ich will verstehen, was passiert: Erkläre nach jeder Umsetzung in 3–5 Sätzen **was** du geändert hast, **wo** (`datei:zeile`) und **warum**. Für eine ausführliche Erklärung: `/explain`.

## Arbeitsweise (du läufst auf einem lokalen Modell)
- Arbeite in kleinen, überprüfbaren Schritten. Vor Änderungen an mehr als zwei Dateien: Plan mit `/plan-commits` und auf mein OK warten.
- Lies die betroffenen Dateien, bevor du sie änderst. Erfinde keine APIs, Pakete oder Befehle – wenn du unsicher bist, schau im Code oder in der Doku nach oder sag es.
- Nimm die Befehle des Projekts (README, `package.json`, `pyproject.toml`, `*.csproj`, `.zed/tasks.json`) und prüfe nach Änderungen mit dem passenden Test-, Lint- oder Build-Befehl.
- Kontext ist knapp (lokales Modell): gezielt suchen statt ganze Ordner lesen, lange Ausgaben filtern. `.agent-plan.md` ist das Gedächtnis – ich starte zwischen Schritten mit `/new` neu.
- Wenn ein Befehl zweimal fehlschlägt: stoppen, Fehler zusammenfassen, Vorschlag machen – nicht blind weiterprobieren.

## Einfachste Lösung (gilt auch außerhalb von `/next`)
Faul bei der Lösung, nie beim Lesen des Codes. Erst Code und Aufrufer lesen, dann die erste Option, die vollständig funktioniert: 1. muss es existieren? 2. gibt es das schon im Projekt? 3. Standardbibliothek oder Plattform (außer das Projekt hat eine eigene UI-Lib, z. B. Syncfusion – die gewinnt)? 4. installierte Abhängigkeit? 5. eine lesbare Zeile? 6. erst dann das Minimum. Keine Abstraktion, Option oder Vorsorge, die niemand verlangt hat. Nie kürzen: Validierung an Vertrauensgrenzen, Fehlerbehandlung gegen Datenverlust, Sicherheit, Barrierefreiheit. Am Ende 1–2 Zeilen: was ausgelassen oder nicht geprüft wurde und welches Risiko ich kennen muss.

## Workflow: Roadmap → Plan → Schritt → Commit → `/next`
- Große Vorhaben (ganze App, großes Feature): erst `/plan-roadmap` – Meilensteine in `docs/ROADMAP.md`.
- Aufgaben mit mehr als einem Commit bzw. der nächste Meilenstein: `/plan-commits` – Plan aus kleinen Schritten, **ein Schritt = ein Commit**, gespeichert in `.agent-plan.md`. Nichts umsetzen, bevor ich den Plan freigebe.
- `/next` setzt **genau einen** Schritt um, prüft ihn und **stoppt** dann mit Commit-Vorschlag. Ich prüfe und committe selbst; erst mein nächstes `/next` startet den nächsten Schritt.
- Ist ein Schritt fertig, aber nicht committet, beginnst du keinen neuen.
- `/next-all` setzt den ganzen Plan am Stück um (Feature-Branch, ein Commit pro Schritt, Stopp bei Fehlschlag, nie pushen). Der Aufruf gilt als meine ausdrückliche Zustimmung zu den Commits.

## Grenzen (pi fragt nicht vor Befehlen – halte dich daran)
- Kein `git commit` (außer in `/next-all`), `git push`, `git reset --hard`, `rm -rf`, Paketinstallation oder Löschen außerhalb des Projektordners ohne meine ausdrückliche Zustimmung.
- Keine Secrets lesen oder ausgeben (`.env*`, `*.pem`, `*.key`, `~/.ssh`).
- Keine Netzwerkzugriffe außer Paket-Registries, wenn ich sie freigegeben habe.

## Stack-Vorlieben (sofern das Projekt nichts anderes vorgibt)
- **Angular:** Standalone Components, Signals für Zustand, `inject()`, `@if`/`@for`, strikt typisiert ohne `any`.
- **Django:** Logik in Models/Services statt Views, `select_related`/`prefetch_related` gegen N+1, Migrations nie nachträglich ändern.
- **C#/.NET:** Nullable an, durchgehend `async`/`await` (kein `.Result`), Dependency Injection über den Konstruktor.
