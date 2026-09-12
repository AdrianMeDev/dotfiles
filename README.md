# Fedora COSMIC Dotfiles

Persönliches Developer-Setup mit GNU Stow und einem modularen Bash-Installer.
Die vorhandenen Vim-Keybindings und das reduzierte Terminal-Layout bleiben erhalten.
Ziel ist **klassisches Fedora COSMIC mit DNF**, kein Atomic-/rpm-ostree-System.
Der Desktop selbst, Treiber und Monitor-/Theme-Einstellungen werden nicht umgestellt.

## Installation

Auf dem frisch installierten Fedora zuerst Git installieren, dieses Repository klonen
und als normaler Benutzer starten. HTTPS-Klonen funktioniert auch vor der SSH-Einrichtung.

```bash
sudo dnf install -y git
# Dieses Repository nach ~/dotfiles klonen, dann:
cd ~/dotfiles
./install.sh --dry-run
./install.sh
```

Bestehende Konfigurationsdateien stoppen den Installer **vor** den Systemänderungen.
Nach Prüfung der gemeldeten Pfade kannst du sie sichern und ersetzen lassen:

```bash
./install.sh --dry-run --backup
./install.sh --backup
```

`--dry-run` lädt nichts herunter, fragt keine Identität ab und schreibt keine Dateien.
Auf CachyOS ist die vollständige Fedora-Vorschau erlaubt; die Systeminstallation wird abgelehnt.
Nur Dotfiles lassen sich auch auf anderen Linux-Systemen mit Bash, Python >= 3.11,
Git und GNU Stow verlinken:

```bash
./install.sh --only dotfiles --dry-run --backup
./install.sh --only dotfiles --backup
```

Es werden einzelne Dateien verlinkt, keine ganzen Config-Verzeichnisse.
Damit landen nachträglich erzeugte Editor-Caches oder Fish-Variablen nicht automatisch im Repo.
Das Layout setzt `XDG_CONFIG_HOME` auf dem Standardpfad `~/.config` voraus.
Fremde Verzeichnis-Symlinks müssen vorab manuell aufgelöst werden; der Installer folgt ihnen nicht.

## Module und Pakete

| Modul | Inhalt |
| --- | --- |
| `system` | DNF-Update, Compiler/Build-Werkzeuge, Git/GitHub CLI, Stow, Fish, tmux, zoxide, direnv, fzf, ripgrep, fd, bat, jq, btop/htop, tree, ShellCheck, shfmt, Clipboard, Podman und Flatpak |
| `development` | Starship, fnm + Node 24, tree-sitter CLI, mise, uv + Python 3.14, .NET SDK 10, Neovim >= 0.12, WezTerm und Zed |
| `flatpak` | Flathub für den Benutzer; ausgewählte optionale Desktop-Apps |
| `fonts` | JetBrains Mono Nerd Font 3.4.0 im Benutzerverzeichnis |
| `dotfiles` | Konfliktprüfung, Git-Identität, optionale Backups und Stow-Verlinkung |

Die Paketlisten liegen in `manifests/`. Ohne Optionen werden alle Module in dieser Reihenfolge ausgeführt.
Einzelne Module ziehen ihre Voraussetzungen nicht automatisch nach:

```bash
./install.sh --only system
./install.sh --only development
./install.sh --extras java,rust,firefox,discord,spotify
./install.sh --only system --extras rpmfusion
```

Extras: `java` (21 über mise), `rust` (stable über rustup), `rpmfusion` (free/nonfree),
`firefox`, `discord`, `spotify`. Extras müssen bei `--only` zum ausgewählten Modul passen.
Es werden keine Apps ohne entsprechende Auswahl installiert. Podman läuft rootless;
es wird kein Docker-Daemon eingerichtet. Container nicht mit `sudo` starten.

Der Installer benutzt offizielle HTTPS-Installer für fnm, mise, uv, Starship und Zed.
Diese werden zuerst in ein temporäres Verzeichnis geladen und dann als Benutzer ausgeführt.
WezTerm wird aus einem verfügbaren Fedora-Paket installiert; ohne solches Paket wird
auf x86_64 das stabile Upstream-AppImage ohne FUSE entpackt. Auf aarch64 ohne passendes
Paket stoppt dieses Modul mit einer Anleitung. Es gibt keinen automatischen Nightly-COPR-Wechsel.
Neovim wird bei Bedarf aus dem stabilen offiziellen Linux-Archiv installiert;
ein Release unter 0.12 wird für diese Konfiguration abgelehnt.
GitHub-Release-Downloads werden gegen den Asset-Digest geprüft, sofern Upstream einen liefert.

Wiederholungen erzeugen keine doppelten Links oder Shell-Initialisierungen. DNF aktualisiert
Systempakete; bereits vorhandene externe Werkzeuge werden nicht automatisch neu installiert.
Node/Python-Major-Versionen, Fedora-Pakete, LSPs und einige Upstream-Installer sind nicht auf
exakte Patchstände festgelegt: Das Setup ist wiederholbar, aber kein bitidentisches Systemabbild.
Neovims bestehende Plugin-Lockdatei wird übernommen; Plugin-Updates bewusst prüfen und committen.

## Git und private Einstellungen

Beim Verlinken fragt der Installer fehlenden Git-Benutzernamen und E-Mail im Terminal ab.
Eine vollständige bestehende globale Identität einschließlich Includes wird übernommen.
Bei erneuter Ausführung bleibt sie erhalten. Ohne Terminal wird nichts erzwungen;
fehlende Angaben können später mit `./install.sh --only dotfiles` ergänzt werden.

Die Identität steht ausschließlich in **`~/.gitconfig-local`**, einer regulären Datei mit
Modus `600` außerhalb des Repos. Die versionierte Git-Konfiguration bindet sie zuletzt ein.
Git benötigt eine explizite Identität (`user.useConfigOnly`); `git pull` verwendet Fast-Forward-only.
Private Includes und weitere Git-Einstellungen aus einem Altbestand bei Bedarf aus dem Backup
in die lokale Datei übernehmen. Der Installer übernimmt daraus automatisch nur Name und E-Mail.

| Lokale Datei | Zweck |
| --- | --- |
| `~/.gitconfig-local` | Git-Identität und persönliche Overrides |
| `~/.gitconfig-work.local` | Optionale Firmenidentität über `includeIf` |
| `~/.ssh/config.local` | Eigene Hosts und Schlüsselpfade; `chmod 600` setzen |
| `~/.config/fish/local.fish` | Maschinenspezifische Shell-Einstellungen |

Neutrale Vorlagen stehen in `examples/`. Eine alte SSH-Konfiguration wird bei Konflikten
gesichert; benötigte Hosts danach in `~/.ssh/config.local` übernehmen. Private Schlüssel
separat verschlüsselt übertragen oder neu erzeugen. Der Installer kopiert keine Schlüssel,
Anmeldedaten, Agent-Sitzungen oder Firmenkonfigurationen ins Repository.

Nicht übernommen: `fish_variables`, History, Caches, installierte Neovim-Plugins, Desktop-Zustand,
Flatpak-App-Daten und automatisch erzeugte App-Starter. Das vorhandene Corne-Layout bleibt
als `corne_v4.vil` erhalten; es enthält derzeit keine belegten Textmakros.

Vor jedem Commit:

```bash
python3 scripts/check-secrets.py --history
git diff
git status --short
```

Der Scanner prüft versionierte und nicht ignorierte neue Dateien sowie optional die Git-Historie.
Er zeigt nur Pfad und Fundart. Er ist heuristisch und ersetzt keine Prüfung eigener Änderungen.
Ignore-Regeln schützen nicht vor `git add -f` oder bereits versionierten Geheimnissen.

## Shell und Runtimes

Fish initialisiert fnm nach mise und wechselt Node anhand von `.node-version`/`.nvmrc`
auch in Unterverzeichnissen. mise aktiviert kein Node oder Python. uv wird ohne Shell-Hook
verwendet; pyenv und der CachyOS-spezifische Shell-Loader sind entfernt.

```fish
fnm install 24
fnm use 24
uv init
uv add django
uv run python manage.py runserver
# Nach Installation des Java-Extras:
mise exec java@21 -- java -version
# Für ein Java-Projekt: schreibt eine projektbezogene mise.toml
mise use java@21
```

Java ist mit dem Extra installiert, wird aber erst durch die Projektauswahl aktiviert.
Angular CLI, ESLint, Django und pytest sind Projektabhängigkeiten; keine globalen Framework-Versionen
werden erzwungen. Zum Beispiel Angular über `npm exec --package=@angular/cli -- ng new APP` anlegen.
Die native tree-sitter CLI (>= 0.26.1) wird für Neovim unabhängig von Node nach `~/.local/bin`
installiert. Damit bleibt sie auch beim Wechsel der Node-Version verfügbar.

| Funktion / Kürzel | Aktion |
| --- | --- |
| `mkcd PFAD` | Verzeichnis anlegen und hineingehen |
| `croot` | Zur Wurzel des Git-Worktrees wechseln |
| `fe` | Projektdatei mit fzf auswählen und in `$EDITOR` öffnen |
| `tp [PFAD]` | tmux-Projektsitzung erstellen/öffnen; innerhalb tmux Sitzung wechseln |
| `gs`, `gd`, `gds`, `gl` | Git-Status, Diff, Staged-Diff, Graph |
| `ga`, `gc`, `gsw` | Git add, commit, switch mit eigenen Argumenten |
| `pps`, `pc` | Podman-Prozesse und Compose |
| `uvr`, `uvs` | uv run und uv sync |
| `..`, `...`, `ll` | Navigation und Dateiliste |

fzf verwendet seine Fish-Standardbindings (u. a. Ctrl-r für History), zoxide bietet `z`/`zi`.
Programme werden nur initialisiert, wenn sie installiert sind. Die Login-Shell wird nicht geändert.
WezTerm startet Fish auf Linux, sofern verfügbar. Optional selbst umstellen: `chsh -s /usr/bin/fish`.

## Editoren und Terminal

**Zed:** vorhandenes Theme „Neovim custom“, Vim-Modus, Space-Leader und Dock-Navigation bleiben.
TypeScript/JavaScript behalten ESLint statt Prettier. Python nutzt basedpyright/Ruff,
C# die C#-Extension mit Roslyn. `Space r r` bietet npm-, pytest-, Django- und dotnet-Tasks an.
Tasks starten nur manuell und erwarten passende Projektdateien/Abhängigkeiten im Worktree-Root.
In Monorepos `.zed/tasks.json` mit passendem `cwd` im Projekt anlegen.
Claude wird nicht automatisch gestartet; vorhandene Agent-Keybindings bleiben für manuelle Nutzung.

**Neovim:** bestehendes Kickstart mit `vim.pack` und Lockdatei, Neovim >= 0.12 erforderlich.
Mason installiert Lua-, Angular-/TypeScript-, HTML-, ESLint-, Python- und OmniSharp-Sprachserver
sowie StyLua/Ruff beim ersten Start. Dafür sind Internet, Node und .NET erforderlich.
Lua/Python werden beim Speichern formatiert; JS/TS erhalten keine zusätzliche globale Prettier-Regel.
Neu: `Space e` Zeilendiagnose, `Space w` speichern, `Space t t` Terminal,
`Space g f` ESLint-Fixes. Bestehende Kickstart-Suchbindings bleiben erhalten.
Prüfen: `:checkhealth`, `:Mason`, `:checkhealth vim.lsp`; projektkompatible Angular-Abhängigkeiten installieren.

**WezTerm:** bestehende Tab-/Split-Bindings bleiben, `Ctrl-Shift-x` öffnet Copy-Mode,
`Ctrl-Shift-Space` Quick Select. Die PowerShell-Taste existiert nur unter Windows.
JetBrains Mono Nerd Font erhält einen DejaVu-Fallback.

**tmux:** Prefix `Ctrl-a`, `h/j/k/l` Pane-Navigation, `-` und `\` Splits,
`r` Reload, `S` Statusleiste umschalten. Statusleiste und Maus bleiben standardmäßig aus.
Copy-Mode: Prefix + `[`, `v` auswählen, `y` kopieren; unter Wayland mit `wl-copy`.

## Backups und Wiederherstellung

Kollidierende Dateien werden bei `--backup` nach
`~/.local/state/dotfiles/backups/ZEITSTEMPEL-ZUFALL/` verschoben. Das Verzeichnis ist privat (`700`)
und liegt außerhalb des Repos. Bestehende korrekte Links werden nicht gesichert oder erneut angelegt.
Die alte `~/.wezterm.lua` wird ebenfalls gesichert, da sie sonst die neue XDG-Konfiguration verdeckt.

Zum Entfernen der Links im Repo ausführen:

```bash
stow --dir "$PWD" --target "$HOME" --no-folding --delete \
  nvim zed wezterm fish tmux starship git ssh mise
```

Anschließend die benötigten Dateien aus dem gemeldeten Backup an ihre ursprünglichen Pfade
zurückkopieren. Lokale private Dateien bleiben erhalten. Stow entfernt keine installierten Programme.
Ein Installationsabbruch rollt Paketinstallationen nicht zurück; Modulfehler beheben und denselben
Aufruf wiederholen. Backups bleiben auch bei einem späteren Fehler verfügbar.

## Prüfung

```bash
bash scripts/check.sh
```

Prüft Bash/ShellCheck, Fish, LuaJIT-Syntax, JSONC/TOML und den Secret-Scan. Python-Integrationstests
verwenden temporäre Home-Verzeichnisse und prüfen echtes Stow, Backups, Wiederholungen,
Symlink-Konflikte, Pfade mit Leerzeichen, Git-Abfrage und Paketmanager-Fehler.
Fehlende optionale Prüfwerkzeuge werden als `SKIP` ausgewiesen. Mit vorhandenem fnm prüft die Suite
auch den rekursiven Node-Versionswechsel; mit tmux dessen Konfiguration auf einem separaten Socket.
`DOTFILES_WEZTERM_BINARY` kann auf ein entpacktes AppImage zeigen, um die Keymap ohne Fenster zu laden.
`DOTFILES_NVIM_PLUGINS` kann auf vorhandene vertrauenswürdige Neovim-Plugin-Quellen (`opt/`) zeigen:
Der Offline-Start prüft dann die Plugin-Konfiguration mit abgeschalteten Downloads und Builds.

Eine vollständige Fedora-Installation und grafische Editor-/Clipboard-Tests müssen auf dem Zielsystem
erfolgen. Die lokale Prüfung auf CachyOS ersetzt keine Fedora-VM-Abnahme.

Installationsreferenzen: [fnm](https://github.com/Schniz/fnm),
[mise](https://mise.jdx.dev/installing-mise.html), [uv](https://docs.astral.sh/uv/getting-started/installation/),
[Starship](https://starship.rs/guide/), [WezTerm](https://wezterm.org/install/linux.html),
[Zed](https://zed.dev/docs/linux), [Neovim](https://neovim.io/doc/user/pack/),
[.NET auf Fedora](https://learn.microsoft.com/en-us/dotnet/core/install/linux-fedora).
