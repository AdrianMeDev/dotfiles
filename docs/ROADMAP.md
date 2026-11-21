# Roadmap: Dotfiles – eine Dev-Umgebung für Linux und Windows 11
Updated: 2026-11-21

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

### M5 [ ] Einheitliches Theme: Terminal, Editoren, CLI
- **Goal:** Ein Theme-Vertrag gilt für alle Terminal-, Editor- und CLI-Tools.
- **Includes:** `theme/tokens.toml` (Palette, Fonts, Größen, Deckkraft, Blur, Rahmen/Radius), Theme-Paritätstest mit Ausnahmeliste, Zed zurück auf Tokyo Night + Ioskeley + Transparenz/Blur (neue Config nutzt One Dark/`.ZedMono`), WezTerm (0.75) und Zed auf einen Deckkraftwert, Neovim, tmux, Starship, fzf, bat/delta, lazygit, btop, yazi, Claude Code/pi
- **Done when:** Paritätstest grün; WezTerm, Zed und Neovim nebeneinander mit gleichen Farben, Fonts und gleicher Deckkraft
- **Depends on:** M2, M3
- **Size:** M, ~6 commits

### M6 [ ] Keybinding-Vertrag + Hyprland-Desktop
- **Goal:** Hyprland auf Arch/Fedora mit denselben Bindings wie GlazeWM und dem Theme aus M5.
- **Includes:** `manifests/keybindings.tsv` + Paritätstest, Stow-Paket `hypr/` (Hyprland mit Blur/Rahmen aus Tokens, Waybar wie Zebar, Launcher auf `Alt+Space` wie Flow, Mako, Hyprlock/Hypridle, Clipboard-Verlauf, Screenshot), `theme`-Modul (GTK/Qt dunkel, Cursor, Icons, Wallpaper), `desktop`-Modul nur auf Desktop-Profil, GlazeWM-Bindings an den Vertrag angleichen
- **Done when:** auf CachyOS in die Hyprland-Session einloggen, alle Vertrags-Bindings funktionieren, GTK-/Qt-Apps dunkel im Tokyo-Night-Look; beide Paritätstests grün; KDE-Session startet weiterhin
- **Depends on:** M1, M5
- **Size:** L, ~8 commits

### M7 [ ] Windows nativ neu aufbauen
- **Goal:** `bootstrap.ps1` richtet Windows 11 mit einem Befehl ein, im selben Look, und hält es aktuell.
- **Includes:** winget-Liste (WezTerm, Zed, GlazeWM, Zebar, Flow, PowerShell 7, Git, .NET SDK, Ollama, Claude Code), Extra `vs`, Zed- und Agent-Config nativ, Theme aus Tokens (Dark Mode, GlazeWM-Rahmen/Transparenz, Zebar, Flow-Theme, WezTerm-Acrylic), `dot.ps1 install|update|doctor` (gezieltes `winget upgrade`), Pester-Tests + Windows-CI-Runner
- **Done when:** frische Win11-VM: `bootstrap.ps1` liefert die Windows-Seite komplett und optisch wie Linux; `dot.ps1 update` aktualisiert sie; CI grün
- **Depends on:** M3, M4, M5, M6
- **Size:** L, ~8 commits

### M8 [ ] WSL2-Arch-Integration
- **Goal:** Der Windows-Bootstrap richtet WSL Arch ein und startet darin den Linux-Installer.
- **Includes:** `wsl --install archlinux`, Benutzer + sudo, `.wslconfig` (mirrored networking für Ollama), WezTerm-Default-Domain Arch, Zed Remote-WSL, `dot.ps1 update` aktualisiert auch WSL
- **Done when:** frische Win11-VM: ein Befehl → WezTerm öffnet zsh in Arch, Zed öffnet ein WSL-Projekt mit LSP, Claude läuft in WSL
- **Depends on:** M2, M7
- **Size:** M, ~5 commits

### M9 [ ] Ein-Befehl-Bootstrap + Zusatztools
- **Goal:** Ein Befehl auf frischem CachyOS oder Windows, ohne vorher manuell zu klonen.
- **Includes:** `bootstrap.sh` (curl|bash, HTTPS-Clone nach `~/dotfiles`, startet `dot install`), zsh als Login-Shell (mit Rückfrage), Zusatztools: eza, yazi, tealdeer, just, lazydocker/podman-tui
- **Done when:** frischer Container und frische CachyOS-VM: ein Befehl → komplette Umgebung; zweiter Lauf ändert nichts
- **Depends on:** M2, M3, M4, M5, M6, M8
- **Size:** M, ~4 commits

### M10 [ ] Corne
- **Goal:** Vial installiert, Corne ohne root nutzbar, Layout zum Vertrag passend.
- **Includes:** `corne`-Modul (Vial: AUR bzw. AppImage mit Digest-Prüfung, udev-Regel; Windows: Vial-Release), `corne_v4.vil` um Layer für WM-/Navigations-/Zahlen-Bindings ergänzen, Layer-Doku
- **Done when:** Vial erkennt den Corne unter Linux ohne sudo und unter Windows; neues Layout geladen, alle Vertrags-Bindings mit dem Corne erreichbar
- **Depends on:** M6
- **Size:** S, ~4 commits

### M11 [ ] Doku + Cheatsheet
- **Goal:** README und CHEATSHEET beschreiben den neuen Stand vollständig.
- **Includes:** README neu (Bootstrap, Distros, `dot`, Windows, Theme), `windows/README.md`/`MANUAL.md` aktualisieren, `zed-config/`/`agent-config/`-READMEs angleichen, CHEATSHEET: Hyprland = GlazeWM, `dot`, Zed/Agents, Corne-Layer
- **Done when:** jedes Binding im CHEATSHEET steht im Vertrag (Test), Installationsanleitung auf frischer VM nachvollzogen
- **Depends on:** M1, M2, M3, M4, M5, M6, M7, M8, M9, M10
- **Size:** S, ~3 commits

## Definition of done (every milestone)
- `bash scripts/check.sh` grün (ShellCheck, Syntax, Secret-Scan, Python-Tests; Pester, falls pwsh vorhanden)
- Container-Matrix grün für betroffene Distros; `--dry-run` schreibt nichts
- Wiederholter Lauf ist idempotent, bestehende Dateien nur mit `--backup` ersetzt
- Neue/geänderte Configs halten Keybinding- und Theme-Vertrag ein (sobald vorhanden)
- Keine Secrets oder privaten Daten im Repo; betroffene README-Abschnitte aktualisiert

## Changelog
- 2026-11-21: roadmap created
- 2026-11-21: einheitliches Theme ergänzt (Entscheidung #10, neuer M5, Theme-Anteile in M6/M7), Meilensteine neu nummeriert
- 2026-11-21: Depends on/Size wieder als eigene Bullets, Abhängigkeiten ohne Bereiche (baton-kompatibel)
- 2026-11-21: M1 Multi-Distro-Kern abgeschlossen
- 2026-11-21: M2 Tools über mise + `dot`-Befehl abgeschlossen (Container-Matrix prüft install → update → doctor)
- 2026-11-21: M3 Zed integrieren abgeschlossen (Zed-Config via Stow `zed-config`, `dot zed-template`, Distro-Paket auf Arch, Windows-Pfade und Container-Matrix aktualisiert)
- 2026-11-21: M4 Agent-Config integrieren abgeschlossen (`agents`-Modul, Claude Code, pi, optional Ollama, `dot update`/`dot doctor`, Container-Matrix prüft Agents und Idempotenz)
