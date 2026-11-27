# pi (privat, lokal) + Claude Code (Arbeit) – Konfiguration, Commit-Workflow & Erklär-Skills

| | **pi** | **Claude Code** |
|---|---|---|
| Einsatz | private Projekte | Arbeit |
| Modell | lokal über Ollama (nichts verlässt den Rechner) | Claude (`sonnet`, bei Bedarf `/model opus`) |
| Sicherheit | **fragt nicht vor Befehlen** – Regeln stehen nur als Anweisung in `AGENTS.md` | Berechtigungsregeln: erlauben / nachfragen / verbieten |
| Befehle (gleich in beiden) | `/plan-roadmap` `/plan-commits` `/next` `/explain` `/explain-project` | `/plan-roadmap` `/plan-commits` `/next` `/explain` `/explain-project` |
| In Zed | `<space> a p` | `<space> a c` |

```
agent-config/
├── pi/                     → ~/.pi/agent/
│   ├── settings.json       Standard: Ollama + qwen3-coder:30b, Theme tokyo-night, Projekt-Vertrauen fragen
│   ├── models.json         Ollama-Modelle (Kontext, Tokens)
│   ├── AGENTS.md           globale Anweisungen (privat)
│   ├── themes/             tokyo-night.json (Tokyo Night)
│   └── prompts/            /plan-roadmap /plan-commits /next /explain /explain-project /review /commit
├── claude/                 → ~/.claude/
│   ├── settings.json       Modell, Theme (dark-ansi), Vim, Erklär-Stil, Berechtigungen
│   └── CLAUDE.md           globale Anweisungen (Arbeit)
├── skills/                 → in beide Tools (Englisch, antworten in deiner Sprache)
│   ├── agent-workspace/    Referenz: `.agent/`-Layout, Git-Regel, Kontextbudget (kein Befehl)
│   ├── plan-roadmap/       großes Feature / ganze App → Meilensteine (.agent/ROADMAP.md)
│   ├── plan-commits/       Aufgabe oder nächsten Meilenstein in Commit-große Schritte planen
│   ├── next/               genau einen Schritt umsetzen, dann für Commit stoppen
│   ├── explain/            Implementiertes verständlich erklären
│   └── explain-project/    ganzes Projekt erklären (Onboarding)
├── templates/PROJEKT-ANWEISUNGEN.md   Vorlage für CLAUDE.md / AGENTS.md im Projekt
└── install.ps1             Windows nativ: Standalone-Wrapper (Gesamtsetup: `bootstrap.ps1` / `windows/dot.ps1 install`)
```

## 1. Installieren

```bash
dot install --only agents            # Linux / WSL: Config nach ~/.claude und ~/.pi/agent
dot install --only agents --backup   # abweichende Dateien sichern und ersetzen
dot install                          # alles, inkl. Claude Code und pi (Modul apps)
```
Das Modul `agents` rendert die Skills (Claude-Frontmatter aus `claude-frontmatter.txt`) und ist
idempotent; `dot update` aktualisiert Tools und Agenten, `dot doctor` meldet lokale Abweichungen.
Ollama: `dot install --only apps --extras ollama,ollama-models`.
Windows nativ: `.\bootstrap.ps1` bzw. `.\windows\dot.ps1 install` aus dem Repo-Root (nur
Agent-Config ohne Gesamtsetup: `.\agent-config\install.ps1` als Standalone-Wrapper). **Arbeitest du
in WSL** (auch über Zed), installiere in WSL – dort laufen pi und Claude Code. Backups liegen
unter `~/.local/state/dotfiles/backups/`.

## 2. pi lokal einrichten

1. **Modelle laden:**
   ```bash
   ollama pull qwen3-coder:30b    # Standard, kann Tools benutzen
   ollama pull gpt-oss:20b        # optional: denkt vor dem Antworten nach
   ollama pull qwen2.5-coder:7b   # optional: schnell, für kleine Aufgaben
   ```
2. **Kontextlänge von Ollama erhöhen – wichtig!** pi spricht Ollama über die OpenAI-kompatible
   Schnittstelle an; dort gilt Ollamas Server-Einstellung. Ist sie zu klein, „vergisst“ das Modell
   Dateien und Anweisungen. Setze vor dem Start von Ollama:
   - Linux/WSL: `export OLLAMA_CONTEXT_LENGTH=32768` (z. B. in `~/.config/zsh/local.zsh` oder im systemd-Service)
   - Windows: Umgebungsvariable `OLLAMA_CONTEXT_LENGTH` = `32768` setzen, Ollama neu starten

   Der Wert muss zu `contextWindow` in `pi/models.json` passen.
3. **WSL + Ollama unter Windows:** `bootstrap.ps1` bzw. `windows/dot.ps1 install` konfiguriert
   `%UserProfile%\.wslconfig` automatisch mit `networkingMode=mirrored` unter `[wsl2]`, damit pi in
   WSL `localhost:11434` erreicht (alternativ manuell setzen oder Ollama direkt in WSL installieren).
4. **Test:** `pi` starten, `/model` zeigt die Ollama-Modelle (`Ctrl+S` speichert die Wahl als Standard).

**Weniger VRAM?** In `settings.json` `defaultModel` auf `qwen2.5-coder:7b` stellen.
**Sicherheit:** pi führt Befehle ohne Nachfrage aus und hat keine Sandbox. Für private Projekte
okay, wenn alles in Git ist; für fremde Repos pi in einem Container laufen lassen.

## 3. Claude Code für die Arbeit

- **Modell:** `sonnet` als Standard; für schwierige Aufgaben `/model opus`.
- **Stil:** Standard und knapp (Regel in `CLAUDE.md`). Erklärungen gibt es gezielt mit `/explain`.
  Wer beim Arbeiten mitlernen will: `/output-style explanatory` – kostet aber bei jeder Antwort mehr Tokens.
- **Berechtigungen** (`claude/settings.json`):
  - *läuft ohne Nachfrage:* git lesen, Build, Tests, Lint, Format für npm/Angular, Django/pytest/ruff, .NET
  - *fragt nach:* reset, checkout, Pakete installieren, Migrations anwenden, docker, kubectl
  - *verboten:* `git commit|push|merge|rebase` (auch `git -C <dir> …`), `gh pr create|merge`, `gh issue create`, `glab *`, sudo, Force-Push, `.env`/Secrets/Schlüssel und `~/.ssh`, `~/.aws`, `~/.azure`, `~/.kube` lesen
- **Firmenvorgaben gehen vor:** Verteilt deine Firma eigene Einstellungen (Managed Settings),
  überschreiben die diese Datei. `/status` zeigt, was aktiv ist.
- **Pro Projekt:** `templates/PROJEKT-ANWEISUNGEN.md` als `CLAUDE.md` ins Repo legen (oder `/init`
  ausführen und abgleichen). Persönliche Ausnahmen nur in `.claude/settings.local.json`.

## 4. Workflow: Roadmap → Plan → Schritt → Commit

Drei Ebenen, jede mit eigener Datei:

| Ebene | Befehl | Datei | Inhalt |
|---|---|---|---|
| Großes Ganzes | `/plan-roadmap <was>` | `.agent/ROADMAP.md` | Vision, Umfang, Architektur, Entscheidungen, Risiken, **Meilensteine** |
| Nächster Meilenstein | `/plan-commits` | `.agent/plan.md` | 3–8 Schritte, **ein Schritt = ein Commit** |
| Umsetzen | `/next` | Code + dein Commit | genau ein Schritt, dann Stopp |

```
/plan-roadmap Vereins-App: Mitglieder, Termine, Beiträge   → Fragen beantworten → Roadmap M0…M5
   Roadmap anpassen, dann committen ("docs: add roadmap") oder lokal behalten
/clear
/plan-commits        → nimmt automatisch den nächsten offenen Meilenstein (M0) → Schritte
/clear
/next → committen → /next → committen → …
   letzter Schritt: Meilenstein wird in der Roadmap auf [x] gesetzt (im selben Commit)
/clear
/plan-commits        → M1 …
```

- **`/plan-roadmap`** stellt zuerst bis zu 6 Fragen (Nutzer, MVP, Vorgaben, Stack, Hosting …), jeweils
  mit Vorschlag – „entscheide du“ geht auch. Meilensteine sind **vertikale Scheiben**: Jeder liefert
  etwas Benutzbares von der Datenbank bis zur Oberfläche, nicht „erst alle Models“. Bei einer neuen App
  ist **M0 das Gerüst**: Projekt anlegen, Lint, Tests, ein Durchstich, CI, Zed-Tasks.
- **Roadmap ändern:** `/plan-roadmap` erneut aufrufen – er aktualisiert statt neu anzufangen, erledigte
  Meilensteine bleiben, Änderungen landen im Changelog.
- **`/plan-commits` mit Argument:** `/plan-commits M3` plant einen bestimmten Meilenstein,
  `/plan-commits <freie aufgabe>` funktioniert weiter ohne Roadmap (Bugfix, Kleinkram).
- **Roadmap-Status per Commit:** Ist die Roadmap im Repo, setzt der erste Schritt den Meilenstein auf
  `[~]` und der letzte auf `[x]` – die Roadmap ändert sich also nie außerhalb eines Commits.
- In Claude Code läuft `/plan-roadmap` mit **Opus** und hohem Denkaufwand, weil Fehler in dieser Phase
  am teuersten sind. Das gilt nur für die Antwort auf den Aufruf; danach geht es mit Sonnet weiter.
- Die Roadmap bleibt bewusst kurz (unter ~150 Zeilen), weil sie bei jedem Meilenstein wieder gelesen
  wird. Details gehören in `.agent/plan.md`.

### Details zu `/plan-commits` und `/next`

```
/plan-commits Warenkorb mit Mengenänderung    → Plan, nichts wird umgesetzt
   (Plan anpassen: einfach sagen, was anders sein soll)
/next                                          → Schritt 1 umsetzen + prüfen → STOPP
   git diff  /  Zed <space> g g  → prüfen, dann selbst committen
/next                                          → prüft: committet? → Schritt 2 → STOPP
...
/next                                          → nach dem letzten Commit: Übersicht + PR-Text
```

- **Ein Schritt = ein Commit.** Jeder Schritt ist klein, hat einen Zweck, lässt das Projekt
  baubar mit grünen Tests und bringt seine eigene Commit-Message (Conventional Commits) mit.
- **Der Plan liegt in `.agent/plan.md`** im Projekt – lesbar und von Hand änderbar.
  `.agent/` steht in `info/exclude` (`git rev-parse --git-path info/exclude`), landet also nie im Repo. Dadurch überlebt
  er auch eine neue Session oder einen Wechsel zwischen pi und Claude Code.
  Status: `[ ]` offen · `[~]` umgesetzt, wartet auf Commit · `[x]` committet · `[-]` übersprungen.
- **Commit-Sperre:** Liegt ein Schritt fertig, aber noch nicht committet vor, startet `/next`
  nichts Neues, sondern zeigt dir die Commit-Befehle. Der Agent committet nie selbst.
- **Varianten:** `/next 4` springt zu Schritt 4 · `/next skip` überspringt den aktuellen ·
  „weiter ohne Commit“ hebt die Sperre einmalig auf. Passt der Plan unterwegs nicht mehr, stoppt
  der Agent und schlägt eine Plan-Änderung vor.
- Claude Code fragt beim ersten Mal pro Repo, ob es in `.git/info/exclude` schreiben darf – das ist gewollt.

### `.agent/`-Ablage und Git-Regel

Alles, was Agents erzeugen, liegt lokal unter `.agent/` im Projekt (nie im Repo):
`plan.md`, `ROADMAP.md`, `notes.md` (Befunde aus `/next`) und reserviert `GLOSSARY.md`, `adr/`,
`prompts/`, `reviews/`, `retro/`. Die Konventionen stehen einmal im Skill `agent-workspace`.

- **Git gehört dir:** Agents committen, pushen, mergen oder legen PRs/Tickets nie selbst an – sie
  zeigen nur die Befehle. Claude Code erzwingt das mit `deny`-Regeln (`claude/settings.json`);
  pi hat keine Sperre, dort gilt die Regel nur als Anweisung in `AGENTS.md`. Umgehungen über Aliase
  oder Skripte, die git aufrufen, sind nicht abgedeckt.
- **Alte Pfade:** `.agent-plan.md` und `docs/ROADMAP.md` werden weiter gelesen; geschrieben wird nur
  unter `.agent/`. Migration eines laufenden Plans: `mv .agent-plan.md .agent/plan.md`.
- **`next-all` wird nicht mehr ausgeliefert** (es committete selbst). Eine lokal installierte Kopie
  bleibt unangetastet und wird nicht gemeldet; `dot doctor` meldet andere Skills, die nicht aus dem
  Repo stammen (`synced/` ausgenommen), nur als Hinweis.

## 5. Verstehen: `/explain` und `/explain-project`

| Ziel | Befehl (pi und Claude Code gleich) |
|---|---|
| Was gerade umgesetzt wurde (z. B. der letzte Schritt) | `/explain` |
| Bestimmte Datei / Funktion / Commit / Plan-Schritt | `/explain src/app/cart/cart.service.ts` · `/explain HEAD~1` · `/explain step 2` |
| Einfacher / kürzer / tiefer | `/explain simpler` · `/explain short` · `/explain deeper` (deutsch geht auch) |
| Ganzes Projekt (neu im Repo) | `/explain-project` |
| Nur ein Bereich | `/explain-project backend` |

Beide springen auch von selbst an, wenn du „erklär mir das“ oder „ich bin neu in dem Projekt“ schreibst.
Sie ändern keinen Code und speichern nur auf Wunsch eine Markdown-Datei unter `docs/`.

**`/explain` liefert:** Kernaussage in einem Satz → Analogie → Ablauf mit `datei:zeile` (und
Diagramm) → wichtige Code-Stellen in Klartext → nötige Konzepte (z. B. Signals, QuerySets,
async/await) → warum so und welche Alternative → Stolperfallen → selbst ausprobieren
(Befehl/Breakpoint) → 3 Verständnisfragen mit Antworten am Ende.

**`/explain-project` liefert:** Zweck → Tech-Stack-Tabelle → Ordner-Landkarte → Architektur-Diagramm
→ ein Anwendungsfall Ende-zu-Ende → Muster und Konventionen → Starten/Testen/Debuggen mit den echten
Befehlen → Glossar → Lesereihenfolge → 3 Einstiegsaufgaben (gutes Futter für `/plan-commits`) →
offene Fragen fürs Team.

**Tipp:** Nach jedem `/next` und vor dem Commit `/explain` – so verstehst du jeden Commit, bevor er
in die Historie geht.

## 6. Weitere Befehle (nur pi)

`/review [pfad|fokus]` Code-Review · `/commit` Commit-Message vorschlagen (committet nicht selbst).
In Claude Code gibt es dafür die eingebauten `/review` bzw. „schreib mir eine Commit-Message“.

In pi sind die fünf Workflow-Befehle kleine Prompt-Vorlagen, die den gleichnamigen Skill laden;
`/skill:next` usw. funktioniert dort ebenfalls.

## 7. Tokens sparen (mehr aus dem Abo holen)

Der Verbrauch entsteht vor allem durch den **Kontext**: Claude Code schickt bei jeder Anfrage den
ganzen bisherigen Verlauf mit, inklusive gelesener Dateien und Testausgaben. Die Antworttexte sind
nur ein kleiner Teil. Deshalb setzt diese Konfiguration am Kontext an:

| Maßnahme | Wirkung |
|---|---|
| `/next` läuft in einem **frischen Subagenten** (`context: fork`, Sonnet, Effort `medium`) | Wie ein automatisches `/clear` pro Schritt: Dateien, Testausgaben und Fehlversuche bleiben im Subagenten, deine Session behält nur den kurzen Bericht |
| `/explain-project` läuft im **read-only Explore-Subagenten** | Die ganze Projekt-Erkundung belastet deine Session nicht |
| Plan in `.agent/plan.md` | Nach der Freigabe des Plans ist `/clear` jederzeit gefahrlos |
| Kein `Explanatory`-Stil, Knapp-Regel in `CLAUDE.md` | Weniger Text pro Antwort, ohne die Lesbarkeit zu verlieren |
| `Compact instructions` in `CLAUDE.md` | Wenn komprimiert wird, bleibt das Richtige erhalten |
| Standardmodell `sonnet` | Opus nur gezielt mit `/model opus` |

**Empfohlener Ablauf in Claude Code:**
```
/plan-commits <aufgabe>  → Plan anpassen, freigeben
/clear                   → Planungs-Erkundung verwerfen (Plan liegt in der Datei)
/next → committen → /next → committen → …   (jeder Schritt startet frisch)
/clear                   → vor der nächsten, unabhängigen Aufgabe
```

**Gewohnheiten, die am meisten bringen:**
- **`/clear` statt `/compact`**, wenn du nichts aus dem Verlauf brauchst: `/compact` muss den ganzen
  Verlauf lesen und ist selbst eine große Anfrage, `/clear` kostet nichts.
- **Nach längeren Pausen** lieber neu starten: Der Zwischenspeicher (Prompt-Cache) läuft ab, und die
  erste Nachricht danach verarbeitet den kompletten Kontext neu.
- **Konkret fragen** („Validierung in `login()` in `auth.ts`“) statt „verbessere das“ – das spart Suchen.
- **`/usage`** zeigt, was dein Kontingent frisst, mit Empfehlungen. Mit `f` setzt Claude einen Teil
  davon direkt um. `/context` zeigt, was den Kontext gerade füllt.
- Nach `/explain` ein `/clear`, wenn du danach etwas anderes machst.

**Und Caveman?** Das ist eine Skill, die Claude im Telegrammstil antworten lässt. Sie kürzt nur die
Antworttexte, nicht den Kontext. Unabhängige Messungen fanden 12–23 % weniger Ausgabe-Tokens, bei
einem Anteil der Ausgabe am Gesamtverbrauch von etwa 1–3 %. Die Skill selbst kostet zusätzlichen
Kontext pro Anfrage und beißt sich mit `/explain`. Die Knapp-Regel in `CLAUDE.md` holt den Großteil
davon ohne diese Nachteile.

**pi:** Lokal kostet ein Token nichts, aber ein kleiner Kontext macht das Modell schneller und
genauer. Starte zwischen den Schritten mit `/new` neu – `/next` liest alles Nötige aus `.agent/plan.md`.
