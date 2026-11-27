 Roadmap: Dotfiles – eine Dev-Umgebung für Linux und Windows 11
Updated: 2026-11-27

## Vision
Mit einem Befehl entsteht auf einem frischen CachyOS/Arch, Fedora, Debian/Ubuntu oder Windows 11 (+ WSL2 Arch)
die komplette persönliche Dev-Umgebung: Shell, Editoren, Runtimes, KI-Agents, Tiling-WM und Corne.
Bedienung (Bindings) und Aussehen (Theme, Fonts, Blur) sind privat unter Linux und auf der Arbeit unter Windows gleich;
alles wird in der neuesten Version installiert und mit `dot update` aktualisiert.

## Scope
- **MVP:**
  - `install.sh` für Arch/CachyOS, Fedora, Debian/Ubuntu (Debian nur CLI + Dev-Tools) und WSL2 Arch
  - `bootstrap.ps1` für Windows 11: winget-Apps, WSL Arch und Linux-Installer darin
  - `dot install | update | doctor` auf beiden Plattformen
  - Zed-Config (inkl. Projektvorlagen) und Agent-Config (Claude Code, pi) im Setup integriert
  - Hyprland (Linux) und GlazeWM (Windows) mit identischem, testgesichertem Keybinding-Vertrag
  - Einheitliches Theme (Tokyo Night, Ioskeley, Deckkraft/Blur) für alle Tools, testgesichert
  - Vial + udev für den Corne, Layout an den Vertrag angepasst; README und CHEATSHEET aktualisiert
- **Agent-Workflow v2 (M12–M18):** Ideen aus mattpocock/skills (MIT) angepasst übernehmen – `/grill` + Glossar/ADR,
    `/refine` (Prompt-Refiner), `/fix`, `/inspect` (Standards + Spec), `/diagnose`, `/retro`; alle KI-Dateien lokal unter `.agent/`,
    Git-Schreibaktionen nur durch den Menschen, ≤ ~150k Token pro Agent durch Dateien als Gedächtnis
- **Later:** Secrets/SSH-Keys über einen Passwortmanager, Visual Studio/Rider-Settings, macOS, Fedora Atomic
- **Not planned:** Desktop auf Debian, KDE-/Treiber-/Monitor-Einstellungen verwalten, bitidentische Builds

## Architecture
- **Stack:** Bash + Python ≥ 3.11 (Linux), PowerShell 5.1/7 (Windows), GNU Stow, mise, pacman/paru · dnf · apt, winget
- **Components:**
  ```
  bootstrap.sh (curl|bash)      bootstrap.ps1 (irm|iex)
        │ clone ~/dotfiles            │ winget-Apps, Windows-Configs + Theme, wsl --install archlinux
        ▼                             ▼
  install.sh / dot ──────────── (in WSL) install.sh
   ├ detect   Distro-Familie (arch|fedora|debian), WSL, Desktop-Profil
   ├ pkg      einheitliche Schnittstelle über pacman+paru | dnf | apt
   ├ system   Basis- und Build-Pakete         ├ tools    mise: CLI-Tools + Runtimes (latest)
   ├ apps     Zed, WezTerm, Ollama, Claude, pi ├ desktop  Hyprland-Stack (nur Arch/Fedora, kein WSL)
   ├ fonts    Ioskeley                         ├ theme    GTK/Qt, Cursor, Icons, Wallpaper
   ├ agents   agent-config rendern + kopieren  ├ dotfiles Stow + Konflikt-/Backup-Logik (links.py)
   ├ corne    Vial + udev-Regel                └ update   pkg upgrade · mise up · flatpak · Plugins · Agents
  ```
- **Core data:** `manifests/packages.tsv` (logischer Name → Paketname je Distro), `mise/config.toml` (Tools),
  `manifests/keybindings.tsv` (Aktion → Linux-/Windows-Binding), `theme/tokens.toml` (Palette, Fonts, Deckkraft, Blur, Rahmen),
  Stow-Pakete, `zed-config/`, `agent-config/`
- **Agent-Workflow (M12+):**
  ```
  /refine ─► .agent/prompts/<slug>.md ─┬► /plan-roadmap ─► .agent/ROADMAP.md (oder docs/ROADMAP.md)
  /grill  ─► .agent/GLOSSARY.md, adr/  ├► /plan-commits ─► .agent/plan.md ─► /next (fork) ─► Mensch committet
                                       └► /fix (1 Commit)            ▲ /diagnose (fork)
  /inspect (2 Subagents) ─► .agent/reviews/   /retro ─► .agent/retro/ ─► Vorschläge für agent-config/
  Gemeinsame Regeln: Referenz-Skill agent-workspace · Gedächtnis: .agent/notes.md + Plan-Log
  ```
- **Integrations:** GitHub Releases/API, mise-Registry, AUR, Flathub, winget, WSL, Ollama, Claude Code, pi

## Decisions
| # | Decision | Why | Alternative |
|---|---|---|---|
| 1 | Systempaketmanager nur für System, Build-Basis und Desktop; Dev-CLI-Tools + Runtimes über **mise** | überall gleiche, neueste Versionen (auch auf Debian), ein Update-Befehl | native Pakete je Distro |
| 2 | Node über mise statt fnm (`.nvmrc`/`.node-version` aktiv); Python bleibt bei uv | ein Versionsmanager weniger | fnm behalten |
| 3 | Linux-WM **Hyprland**, Modifier = linkes Alt wie in GlazeWM; KDE bleibt als Fallback-Session | erstklassig auf CachyOS, Text-Config (Stow), Blur passt zum transparenten Theme, GlazeWM-Befehle 1:1 abbildbar | Sway (stabiler, i3-nah, kein Blur) |
| 4 | Keybinding-Vertrag als TSV + Paritätstest gegen Hyprland-, GlazeWM-, Zed- und WezTerm-Config | Gleichheit wird geprüft, ohne Generator-Komplexität | Configs aus Vorlage generieren |
| 5 | Ein Einstieg `dot` (Linux) / `dot.ps1` (Windows) mit identischen Verben | leicht zu merken, Update = ein Befehl | getrennte Skripte pro Modul |
| 6 | `zed-config/` wird einzige Zed-Quelle (Stow-Paket), Duplikat `zed/` entfällt; Windows liest daraus | aktuell zwei identische Kopien | beide synchron halten |
| 7 | Agent-Config wird gerendert und kopiert, nicht verlinkt; Abweichungen zeigt `dot doctor` an | Claude Code/pi schreiben selbst in `settings.json` (z. B. `/model`) → Repo sonst ständig dirty | Symlinks |
| 8 | WSL-Distro **Arch Linux** (offizielles Image), GUI-Apps nativ unter Windows (Zed Remote-WSL, WezTerm WSL-Domain) | identischer Pfad wie CachyOS | Fedora wie bisher |
| 9 | Windows-C#: .NET SDK + Zed + Claude Code nativ; Visual Studio Community als Extra `vs` | schlanker Standard, VS nur bei Bedarf | VS immer installieren |
| 10 | **Theme-Vertrag** `theme/tokens.toml`: Tokyo Night (Night), Ioskeley Mono / Term Nerd Font, ein Deckkraft- und Blur-Wert; Tools nutzen ihr natives Tokyo-Night-Theme, sonst die Token-Werte; Paritätstest prüft | einheitlicher Look ohne Generator, gleiches Muster wie #4 | tinted-theming/Base16-Generator |
| 11 | KI-Artefakte lokal unter `.agent/` (Plan, Roadmap, Glossar, ADRs, Prompts, Reviews, Retro, Notizen), ausgeschlossen über `git rev-parse --git-path info/exclude`; `.agent-plan.md` → `.agent/plan.md` mit Lese-Fallback | nichts KI-Generiertes landet ungewollt im Repo; Pfad funktioniert auch in Worktrees | committen nach `docs/`, `.gitignore` |
| 12 | Git-/Tracker-Schreibaktionen (`git commit/push/merge/rebase`, `gh pr\|issue create`, `glab`) in Claude per `deny`, in pi als Regel; `next-all` wird nicht ausgeliefert, eine lokale Kopie wird toleriert | Git bleibt allein beim Menschen, hart erzwungen statt nur erbeten | `ask` wie bisher |
| 13 | Matt-Skills als eigene, angepasste Kopien in `agent-config/skills/` (MIT-Hinweis), kein Plugin | Plugin setzt auf GitHub-Tracker und ändert sich per Auto-Update | `claude plugin install` |
| 14 | Gemeinsame Konventionen in einem Referenz-Skill `agent-workspace`, Skills verweisen darauf | Regeln einmal pflegen, nur bei Bedarf im Kontext | alles in CLAUDE.md (immer geladen) |
| 15 | Kontextbudget ≤ ~150k über Struktur: `next`/`diagnose` im Fork, Review-Achsen als frische Subagents, Erkenntnisse in Dateien, `/clear` zwischen Schritten | Leistung bleibt hoch, jeder Schritt startet ohne Altlast | Auto-Compact, lange Sitzungen |
| 16 | `/inspect` (statt `/review`) läuft in der Hauptsession ohne `context: fork` und startet die zwei Achsen per Agent-Tool als frische Subagents (parallel, Typ `general-purpose`, Modell sonnet; Haupt-Skill sonnet/medium, er orchestriert nur und schreibt den Bericht); pi: Achsen nacheinander mit frischem Lesen. Name `inspect`, weil `/review` in Claude Code eingebaut ist | Subagents starten keine weiteren Subagents (Claude-Code-Doku zu Subagents), ein Fork von `next` kann also nicht prüfen; Hauptsession-Skills können mehrere Agent-Aufrufe in einer Nachricht parallel starten; kein Namenskonflikt mit `/review` und Skill `code-review` | `/review` als Name, Prüfung im Fork |
| 17 | Der Fehlersuche-Skill heißt `diagnose` statt `debug`; die TDD-Leitlinie ist der Referenz-Skill `tdd` (`user-invocable: false`), auf den `next`, `fix` und `diagnose` verweisen | `/debug` ist in Claude Code eingebaut (wie `/review`); eine Quelle für die Test-Regeln statt Kopien in drei Skills | Name `debug`, TDD-Regeln in jedem Skill wiederholt |

## Risks & unknowns
| Risk | Impact | Mitigation |
|---|---|---|
| Hyprland ändert Config-Syntax („immer neueste Version“) | Desktop nach Update kaputt | Config-Prüfung in Tests und `dot doctor`, KDE-Fallback-Session, Update zeigt Changelog-Hinweis |
| Alt-Bindings kollidieren mit Apps (Zed, Menüs) oder mit reservierten Windows-Tasten | uneinheitliche Bedienung | Vertrag prüft Kollisionen mit Zed/WezTerm-Keymaps; Spike als erster Schritt in M6 |
| Nicht jedes Tool kann Blur/Transparenz/eigene Farben (Claude Code nur eingebaute Themes, Blur hängt von Compositor bzw. Windows-Backdrop ab) | Look nicht überall 100 % gleich | dokumentierte Ausnahmeliste im Theme-Test, nächstliegende Variante (z. B. Acrylic unter Windows) |
| Firmen-Windows: winget/WSL eingeschränkt, Proxy, Managed Settings für Claude | Bootstrap bricht ab | `-DryRun` + Vorabprüfung, klare Fehlermeldungen, User-Scope-Installationen bevorzugen |
| Neueste Versionen statt Pins | weniger reproduzierbar | Neovim-Lockfile bleibt, `dot update` listet Versionsänderungen, mise-Lockfile optional |
| GUI, Windows und Hardware (Corne) nicht im Container testbar | Fehler erst am Zielsystem | Container-Matrix für Linux-CLI, Pester + Windows-Runner für DryRun, manuelle Abnahmeliste |
| Bestehende Fedora-only-Tests (`tests/test_install.py`) | Umbau bricht Tests | Tests in M1 auf Distro-Matrix umstellen, bevor Module wachsen |
| Ein geforkter Skill (`next`) kann keine weiteren Subagents starten (bestätigt, Entscheidung #16) | `/inspect` mit zwei Achsen nicht aus `next` heraus möglich | `/inspect` läuft in der Hauptsession, `next` schlägt es am Meilensteinende nur vor |
| pi: 32k Kontext, keine Subagents, keine `deny`-Regeln | neue Skills sprengen den Kontext oder umgehen die Git-Sperre | Skills kurz halten, Fallback „Achsen nacheinander“, Regel in `pi/AGENTS.md`; Container-Test prüft Skill-Größe |
| `next-all`/`handoff` kommen evtl. zusätzlich per claude.ai-Sync (`anthropic-skills:`) | alter Commit-Workflow bleibt aufrufbar | `deny` greift trotzdem; `dot doctor` meldet fremde Skills, Entfernen in claude.ai manuell |
| Retro auf Session-Logs (`~/.claude/projects/*.jsonl`) ist sehr groß | Retro sprengt selbst das Budget | Retro liest primär `.agent/notes.md`, Plan-Log, Reviews; Logs nur gefiltert (Fehler, teure Tool-Calls) |
| Umzug `.agent-plan.md` → `.agent/plan.md` | laufende Pläne in Projekten werden nicht gefunden | Lese-Fallback auf den alten Pfad, Hinweis zum Verschieben |

## Milestones

### M1 [x] Multi-Distro-Kern
- **Goal:** `install.sh` läuft auf Arch/CachyOS, Fedora und Debian/Ubuntu statt nur auf Fedora.
- **Includes:** `detect` (Familie, WSL, Profil desktop/headless), `pkg`-Abstraktion (paru bzw. yay vorhanden, sonst paru bootstrappen), `manifests/packages.tsv`, `system`-Modul pro Familie, Fedora-Sperre entfernen, Tests umbauen, Podman-Container-Matrix + GitHub-Actions-CI
- **Done when:** `./install.sh --only system` läuft real in `archlinux`-, `fedora`- und `debian`-Containern grün; `--dry-run` auf diesem CachyOS zeigt einen Arch-Plan
- **Depends on:** –
- **Size:** L, ~7 commits

### M2 [x] Tools über mise + `dot`-Befehl
- **Goal:** Alle Dev-Tools in neuester Version über mise; Installation, Update und Diagnose über `dot`.
- **Includes:** globale mise-Config (Neovim, Node LTS, uv, Starship, tree-sitter, lazygit, ripgrep, fd, fzf, bat, delta …), Migration fnm → mise in zsh, `dot install|update|doctor`, Update-Pfad pro Familie
- **Done when:** frischer Container → `dot install` → `nvim`, `node`, `uv` vorhanden; `dot update` aktualisiert System, mise und Plugins; `dot doctor` zeigt Versionen und Probleme
- **Depends on:** M1
- **Size:** M, ~6 commits

### M3 [x] Zed integrieren
- **Goal:** Die neue Zed-Config ist Teil des Setups – Linux per Stow, Windows aus derselben Quelle.
- **Includes:** `zed-config/` als einzige Quelle, `zed/` entfernen, eigenen Installer ablösen, `dot zed-template angular|django|dotnet PFAD`, Windows-Installer-Pfade anpassen, Zed-Paket je Distro
- **Done when:** nach `dot install` sind die Zed-Dateien verlinkt, `dot zed-template dotnet /tmp/x` legt `.zed/` an, Windows-Tests grün
- **Depends on:** M2
- **Size:** S, ~4 commits

### M4 [x] Agent-Config integrieren
- **Goal:** Claude Code, pi und Ollama werden installiert und mit der Agent-Config versorgt.
- **Includes:** `agents`-Modul (Skills mit Claude-Frontmatter rendern, kopieren mit Backup, idempotent), Claude Code (nativer Installer), pi (npm über mise-Node), Ollama + Modelle optional, `dot update` aktualisiert die Agents, `dot doctor` meldet lokale Abweichungen
- **Done when:** frischer Container → `~/.claude` und `~/.pi/agent` befüllt; zweiter Lauf erzeugt keine Backups; `claude --version` und `pi --version` laufen
- **Depends on:** M2
- **Size:** M, ~5 commits

### M5 [x] Einheitliches Theme: Terminal, Editoren, CLI
- **Goal:** Ein Theme-Vertrag gilt für alle Terminal-, Editor- und CLI-Tools.
- **Includes:** `theme/tokens.toml` (Palette, Fonts, Größen, Deckkraft, Blur, Rahmen/Radius), Theme-Paritätstest mit Ausnahmeliste, Zed zurück auf Tokyo Night + Ioskeley + Transparenz/Blur (neue Config nutzt One Dark/`.ZedMono`), WezTerm (0.75) und Zed auf einen Deckkraftwert, Neovim, tmux, Starship, fzf, bat/delta, lazygit, btop, yazi, Claude Code/pi
- **Done when:** Paritätstest grün; WezTerm, Zed und Neovim nebeneinander mit gleichen Farben, Fonts und gleicher Deckkraft
- **Depends on:** M2, M3
- **Size:** M, ~6 commits

### M6 [x] Keybinding-Vertrag + Hyprland-Desktop
- **Goal:** Hyprland auf Arch/Fedora mit denselben Bindings wie GlazeWM und dem Theme aus M5.
- **Includes:** `manifests/keybindings.tsv` + Paritätstest, Stow-Paket `hypr/` (Hyprland mit Blur/Rahmen aus Tokens, Waybar wie Zebar, Launcher auf `Alt+Space` wie Flow, Mako, Hyprlock/Hypridle, Clipboard-Verlauf, Screenshot), `theme`-Modul (GTK/Qt dunkel, Cursor, Icons, Wallpaper), `desktop`-Modul nur auf Desktop-Profil, GlazeWM-Bindings an den Vertrag angleichen
- **Done when:** auf CachyOS in die Hyprland-Session einloggen, alle Vertrags-Bindings funktionieren, GTK-/Qt-Apps dunkel im Tokyo-Night-Look; beide Paritätstests grün; KDE-Session startet weiterhin
- **Depends on:** M1, M5
- **Size:** L, ~8 commits

### M7 [x] Windows nativ neu aufbauen
- **Goal:** `bootstrap.ps1` richtet Windows 11 mit einem Befehl ein, im selben Look, und hält es aktuell.
- **Includes:** winget-Liste (WezTerm, Zed, GlazeWM, Zebar, Flow, PowerShell 7, Git, .NET SDK, Ollama, Claude Code), Extra `vs`, Zed- und Agent-Config nativ, Theme aus Tokens (Dark Mode, GlazeWM-Rahmen/Transparenz, Zebar, Flow-Theme, WezTerm-Acrylic), `dot.ps1 install|update|doctor` (gezieltes `winget upgrade`), Pester-Tests + Windows-CI-Runner
- **Done when:** frische Win11-VM: `bootstrap.ps1` liefert die Windows-Seite komplett und optisch wie Linux; `dot.ps1 update` aktualisiert sie; CI grün
- **Depends on:** M3, M4, M5, M6
- **Size:** L, ~8 commits

### M8 [x] WSL2-Arch-Integration
- **Goal:** Der Windows-Bootstrap richtet WSL Arch ein und startet darin den Linux-Installer.
- **Includes:** `wsl --install archlinux`, Benutzer + sudo, `.wslconfig` (mirrored networking für Ollama), WezTerm-Default-Domain Arch, Zed Remote-WSL, `dot.ps1 update` aktualisiert auch WSL
- **Done when:** frische Win11-VM: ein Befehl → WezTerm öffnet zsh in Arch, Zed öffnet ein WSL-Projekt mit LSP, Claude läuft in WSL
- **Depends on:** M2, M7
- **Size:** M, ~5 commits

### M9 [x] Ein-Befehl-Bootstrap + Zusatztools
- **Goal:** Ein Befehl auf frischem CachyOS oder Windows, ohne vorher manuell zu klonen.
- **Includes:** `bootstrap.sh` (curl|bash, HTTPS-Clone nach `~/dotfiles`, startet `dot install`), zsh als Login-Shell (mit Rückfrage), Zusatztools: eza, yazi, tealdeer, just, lazydocker/podman-tui
- **Done when:** frischer Container und frische CachyOS-VM: ein Befehl → komplette Umgebung; zweiter Lauf ändert nichts
- **Depends on:** M2, M3, M4, M5, M6, M8
- **Size:** M, ~4 commits

### M10 [x] Corne
- **Goal:** Vial installiert, Corne ohne root nutzbar, Layout zum Vertrag passend.
- **Includes:** `corne`-Modul (Vial: AUR bzw. AppImage mit Digest-Prüfung, udev-Regel; Windows: Vial-Release), `corne_v4.vil` um Layer für WM-/Navigations-/Zahlen-Bindings ergänzen, Layer-Doku
- **Done when:** Vial erkennt den Corne unter Linux ohne sudo und unter Windows; neues Layout geladen, alle Vertrags-Bindings mit dem Corne erreichbar
- **Depends on:** M6
- **Size:** S, ~4 commits

### M11 [x] Doku + Cheatsheet
- **Goal:** README und CHEATSHEET beschreiben den neuen Stand vollständig.
- **Includes:** README neu (Bootstrap, Distros, `dot`, Windows, Theme), `windows/README.md`/`MANUAL.md` aktualisieren, `zed-config/`/`agent-config/`-READMEs angleichen, CHEATSHEET: Hyprland = GlazeWM, `dot`, Zed/Agents, Corne-Layer
- **Done when:** jedes Binding im CHEATSHEET steht im Vertrag (Test), Installationsanleitung auf frischer VM nachvollzogen
- **Depends on:** M1, M2, M3, M4, M5, M6, M7, M8, M9, M10
- **Size:** S, ~3 commits

### M12 [x] Lokale `.agent/`-Ablage + Git-Sperre
- **Goal:** Alle KI-Dateien liegen lokal unter `.agent/`, und Agents können nichts committen, pushen oder Tickets anlegen.
- **Includes:** Referenz-Skill `agent-workspace` (Layout, Exclude-Helfer, Format `notes.md`, Git-Regel, Kontextbudget), `plan-roadmap`/`plan-commits`/`next` auf `.agent/` umstellen (Fallback alter Pfad), `deny`-Regeln in `claude/settings.json`, Regel in `pi/AGENTS.md` und `CLAUDE.md`, `next-all` in `LEGACY` von `scripts/agents.py`, `dot doctor` meldet fremde Skills, Tests/Container-Check anpassen
- **Done when:** in einem Testprojekt schreibt `/plan-commits` nach `.agent/plan.md` und `.agent/` steht in `info/exclude`; `git commit` durch Claude wird abgelehnt; `bash scripts/check.sh` grün
- **Depends on:** M4
- **Size:** M, ~6 commits

### M13 [x] `/grill` mit Glossar und ADRs
- **Goal:** Ein Interview in Runden schärft Pläne und baut nebenbei Glossar und ADRs auf.
- **Includes:** Skill `grill` (grilling + domain-modeling: Frontier-Runden mit Empfehlung, Fakten selbst nachschlagen, `.agent/GLOSSARY.md` + `.agent/adr/` inline, ADR nur bei schwer umkehrbar + überraschend + echter Abwägung), `plan-roadmap` nutzt Grill-Runden statt fester Fragenliste, `plan-commits`/`next` lesen das Glossar
- **Done when:** `/grill` an einer Beispielidee: nummerierte Runden mit Empfehlung, Glossareintrag im Format mit `_Avoid_`; `/plan-roadmap` fragt in Runden
- **Depends on:** M12
- **Size:** M, ~4 commits

### M14 [x] Prompt-Refiner `/refine` + `/fix`
- **Goal:** Aus eigenem Prompt + Kontext (Ticket, Pfade) entsteht im Dialog ein optimaler Prompt für Roadmap, Plan oder Fix.
- **Includes:** Skill `refine` (Ziel `roadmap|commits|fix`, Grill-Runden, Vorlage je Ziel: Ziel, Kontext, Akzeptanzkriterien, Grenzen, Glossarbegriffe; Ausgabe `.agent/prompts/<slug>.md`), `plan-roadmap`/`plan-commits`/`fix` nehmen einen Prompt-Pfad an, Skill `fix` (kleine Korrektur, Test zuerst, ein Commit-Vorschlag, stoppt), pi-Prompts
- **Done when:** `/refine fix "<Ticket-Text>"` stellt Fragen und schreibt eine Prompt-Datei; `/fix .agent/prompts/<slug>.md` setzt um, prüft und stoppt mit Commit-Vorschlag
- **Depends on:** M13
- **Size:** M, ~5 commits

### M15 [x] `/inspect` auf zwei Achsen
- **Goal:** Änderungen werden getrennt gegen Standards und gegen Spec (Planschritt/Meilenstein/Prompt) geprüft.
- **Includes:** Spike Subagents aus Skill/Fork, Skill `inspect` (Fixpunkt, Standards-Quellen + Fowler-Smell-Liste, Spec aus `.agent/plan.md`/Roadmap/Prompt, zwei frische Subagents, Bericht nach `.agent/reviews/<datum>-<slug>.md`, nicht zusammenmischen), pi-Fallback nacheinander, `pi/prompts/review.md` durch `inspect.md` ersetzen, `next` schlägt `/inspect` nach dem letzten Schritt vor
- **Done when:** `/inspect main` auf einem Branch liefert getrennte Abschnitte „Standards“ und „Spec“ und eine Datei unter `.agent/reviews/`
- **Depends on:** M12
- **Size:** M, ~4 commits

### M16 [x] `/diagnose` + TDD-Leitlinie
- **Goal:** Schwere Fehler werden diszipliniert eingegrenzt; `next` und `fix` arbeiten rot-grün-refactor.
- **Includes:** Skill `diagnose` nach diagnosing-bugs (rote Feedback-Schleife → minimieren → Hypothesen → instrumentieren → fix → Regressionstest), läuft im Fork, Befunde in `.agent/notes.md`; TDD-Leitlinie (gute/schlechte Tests) als Referenz-Skill `tdd` für `next`/`fix`
- **Done when:** `/diagnose` an einem eingebauten Fehler: reproduzierender Test zuerst, Ursache in `notes.md`, Fix + Regressionstest
- **Depends on:** M12
- **Size:** S, ~3 commits

### M17 [~] `/retro` + Kontextbudget sichtbar
- **Goal:** Nach Meilenstein oder Sitzung kommen konkrete Verbesserungen für Skills, Checks und Steuerdateien – sortiert nach Schwere.
- **Includes:** Skill `retro` (Kategorien Navigation, automatische Checks, Standards, CLAUDE.md-Größe, Tool-Ökonomie, No-Ops, Informationszugang; Quellen `notes.md`, Plan-Log, Reviews, gefilterte Logs; Ausgabe `.agent/retro/`, ändert nichts selbst), Referenz writing-for-agents, Statusline mit Kontextverbrauch, Budget-Hinweis in `next`/`plan-commits`
- **Done when:** `/retro` nach einem Meilenstein liefert priorisierte Vorschläge mit Zielpfad in `agent-config/`; Statusline zeigt Kontext in %
- **Depends on:** M15
- **Size:** M, ~4 commits

### M18 [ ] Workflow-Doku + Router
- **Goal:** Der neue Ablauf ist auf einen Blick verständlich und der passende Skill schnell gefunden.
- **Includes:** `agent-config/README.md` (Ablauf, `.agent/`-Layout, Git-Regel, Kontextstrategie), Skill `flow` (welcher Skill passt wann, kurz), CHEATSHEET-Abschnitt Agents, MIT-Hinweis für übernommene Inhalte
- **Done when:** README und CHEATSHEET nennen jeden Skill; `/flow "kleiner Bug im Login"` empfiehlt `/refine fix` → `/fix`
- **Depends on:** M13, M14, M15, M16, M17
- **Size:** S, ~3 commits

## Definition of done (every milestone)
- `bash scripts/check.sh` grün (ShellCheck, Syntax, Secret-Scan, Python-Tests; Pester, falls pwsh vorhanden)
- Container-Matrix grün für betroffene Distros; `--dry-run` schreibt nichts
- Wiederholter Lauf ist idempotent, bestehende Dateien nur mit `--backup` ersetzt
- Neue/geänderte Configs halten Keybinding- und Theme-Vertrag ein (sobald vorhanden)
- Keine Secrets oder privaten Daten im Repo; betroffene README-Abschnitte aktualisiert
- Agent-Skills (ab M12): laufen in Claude Code und pi, keine Git-Schreibaktion, schreiben nur unter `.agent/`, `dot install --only agents` idempotent

## Changelog
- 2026-11-21: roadmap created
- 2026-11-21: einheitliches Theme ergänzt (Entscheidung #10, neuer M5, Theme-Anteile in M6/M7), Meilensteine neu nummeriert
- 2026-11-21: Depends on/Size wieder als eigene Bullets, Abhängigkeiten ohne Bereiche (baton-kompatibel)
- 2026-11-21: M1 Multi-Distro-Kern abgeschlossen
- 2026-11-21: M2 Tools über mise + `dot`-Befehl abgeschlossen (Container-Matrix prüft install → update → doctor)
- 2026-11-21: M3 Zed integrieren abgeschlossen (Zed-Config via Stow `zed-config`, `dot zed-template`, Distro-Paket auf Arch, Windows-Pfade und Container-Matrix aktualisiert)
- 2026-11-21: M4 Agent-Config integrieren abgeschlossen (`agents`-Modul, Claude Code, pi, optional Ollama, `dot update`/`dot doctor`, Container-Matrix prüft Agents und Idempotenz)
- 2026-11-21: M5 Einheitliches Theme: Terminal, Editoren, CLI abgeschlossen (`theme/tokens.toml`, Theme-Paritätstests, Zed/WezTerm/Neovim/tmux/Starship/fzf/bat/delta/lazygit/btop/yazi/Claude Code/pi, Container-Matrix prüft Theme-Links, `bat`-Cache und pi-Theme)
- 2026-11-21: M6 Keybinding-Vertrag + Hyprland-Desktop abgeschlossen (`manifests/keybindings.tsv` + Paritätstests, Stow-Paket `hypr/` mit Lua-Config für Hyprland >= 0.57, `desktop`- und `theme`-Modul, `dot doctor` und Container-Matrix prüfen Hyprland)
- 2026-11-21: M7 done (Native Windows 11 setup with bootstrap.ps1 and dot.ps1)
- 2026-11-21: M8 WSL2-Arch-Integration abgeschlossen (`wsl --install archlinux`, `windows/wsl-bootstrap.sh`, `.wslconfig` mit `networkingMode=mirrored`, WezTerm-Arch-Domain, Zed Remote-WSL, `dot.ps1 update`/`doctor` für WSL, Arch-Container-Check)
- 2026-11-21: M9 Ein-Befehl-Bootstrap + Zusatztools implementiert (Linux `curl | bash`, Windows `irm | iex`, zsh-Rückfrage, eza/yazi/tealdeer/just/lazydocker, Bootstrap-Containerprüfungen); frische CachyOS-VM-Abnahme siehe README, manuelle Freigabe offen.
- 2026-11-21: M10 Corne abgeschlossen (`corne`-Modul mit Vial + udev-Regel, Windows-Vial-Release in `%LOCALAPPDATA%\Vial` + `dot.ps1 update`/`doctor`, `corne_v4.vil` mit 6 Layern und Vertragsparität in `tests/test_corne_layout.py`, Doku in `docs/CORNE.md`, `README.md` und `windows/README.md`).
- 2026-11-21: M11 Doku + Cheatsheet abgeschlossen (README/`windows/README.md`/Config-READMEs aktualisiert, CHEATSHEET mit Hyprland = GlazeWM, `dot`, Zed + Agents, mise/CLI-Tools und Corne-Layern; `tests/test_keybindings.py` prüft alle WM-Bindings im CHEATSHEET gegen `manifests/keybindings.tsv`; frische-VM-Abnahme laut README-Checkliste manuell offen)
- 2026-11-21: Review-Nachbesserungen (gsettings-Fallback im theme-Modul, `-NoWsl` ohne WSL-Abfrage, konsolenbreiten-unabhängiger Pester-Test, manuelle Abnahme-Checkliste `docs/ACCEPTANCE.md`)
- 2026-11-27: Agent-Workflow v2 geplant (M12–M18, Entscheidungen #11–#15) nach Recherche von mattpocock/skills
- 2026-11-27: M12 Lokale `.agent/`-Ablage + Git-Sperre abgeschlossen (Skill `agent-workspace`, Pläne unter `.agent/`, `deny`-Regeln für git/gh/glab, `next-all` entfernt, `dot doctor` meldet fremde Skills)
- 2026-11-27: `next-all` nicht mehr ausgeliefert, lokale Kopie bleibt bei `dot install` erhalten
- 2026-11-27: M13 `/grill` mit Glossar und ADRs abgeschlossen (Skill `grill`, `plan-roadmap` fragt in Runden, `plan-commits`/`next` lesen das Glossar)
- 2026-11-27: M14 `/refine` + `/fix` abgeschlossen (Skills `refine` und `fix`, Prompt-Pfad als Eingabe für `plan-roadmap`/`plan-commits`, pi-Prompts, Doku)
- 2026-11-27: M15 `/inspect` auf zwei Achsen abgeschlossen (Skill `inspect` mit getrennten Achsen Standards/Spec, zwei frische Subagents in Claude Code, pi nacheinander, Bericht unter `.agent/reviews/`, `next` schlägt `/inspect` vor, `/review` in `/inspect` umbenannt; manuelle Abnahme `/inspect main` offen)
- 2026-11-27: M16 `/diagnose` + TDD-Leitlinie abgeschlossen (Skills `diagnose` im Fork und `tdd` als Referenz, `next`/`fix` arbeiten rot-grün-refactor, pi-Prompt, Doku; `/debug` in `/diagnose` umbenannt, Entscheidung #17; manuelle Abnahme `/diagnose` an eingebautem Fehler offen)
