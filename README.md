# Fedora COSMIC Dotfiles

Persönliches Developer-Setup mit GNU Stow und einem modularen Bash-Installer.
Die vorhandenen Vim-Keybindings und das reduzierte Terminal-Layout bleiben erhalten.
Ziel ist **Fedora Workstation/COSMIC mit DNF** oder eine Fedora-Distribution unter WSL2,
kein Atomic-/rpm-ostree-System.
Der Desktop selbst, Treiber und Monitor-/Theme-Einstellungen werden nicht umgestellt.

Für **Windows 11 mit Fedora unter WSL2** gibt es ein separates
[Windows-Setup mit WezTerm, Zed, GlazeWM, Zebar und Flow Launcher](windows/README.md).

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
Fedora unter WSL2 wird unterstützt; der Installer benötigt dort kein systemd und DNF lässt den
von Windows bereitgestellten Kernel beim Upgrade aus. Die grafische COSMIC-Desktopumgebung ist
für WSL kein Installationsziel.
Nur Dotfiles lassen sich auch auf anderen Linux-Systemen mit Bash, Python >= 3.11,
Git und GNU Stow verlinken:

```bash
./install.sh --only dotfiles --dry-run --backup
./install.sh --only dotfiles --backup
```

Es werden einzelne Dateien verlinkt, keine ganzen Config-Verzeichnisse.
Damit landen nachträglich erzeugte Editor-Caches oder Shell-History nicht automatisch im Repo.
Das Layout setzt `XDG_CONFIG_HOME` auf dem Standardpfad `~/.config` voraus.
Fremde Verzeichnis-Symlinks müssen vorab manuell aufgelöst werden; der Installer folgt ihnen nicht.

## Module und Pakete

| Modul | Inhalt |
| --- | --- |
| `system` | DNF-Update, Compiler/Build-Werkzeuge, Git/GitHub CLI, Stow, zsh, tmux, zoxide, direnv, fzf, ripgrep, fd, bat, jq, btop/htop, tree, ShellCheck, shfmt, Clipboard, Podman und Flatpak |
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
Neovims Plugin-Versionen stehen in `nvim-pack-lock.json`; Plugin-Updates bewusst prüfen und committen.

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
| `~/.config/zsh/local.zsh` | Maschinenspezifische Shell-Einstellungen |

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

zsh initialisiert fnm nach mise und wechselt Node anhand von `.node-version`/`.nvmrc`
auch in Unterverzeichnissen. mise aktiviert kein Node oder Python. uv wird ohne Shell-Hook
verwendet; pyenv und der CachyOS-spezifische Shell-Loader sind entfernt.

```zsh
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

Die modulare zsh-Konfiguration basiert auf [radleylewis/zsh](https://github.com/radleylewis/zsh)
(MIT; Lizenz liegt im zsh-Paket). Der bestehende Starship-Prompt und die Kürzel bleiben erhalten;
frühere Fish-Abkürzungen sind jetzt Aliase. zoxide bietet `z`/`zi`.
Programme werden nur initialisiert, wenn sie installiert sind. Runtime-Pfade, mise und fnm stehen
auch nichtinteraktiven Tasks zur Verfügung. Prompt, Plugins und Tasten werden nur interaktiv geladen.

`~/.zshenv` setzt `ZDOTDIR` auf `~/.config/zsh`; eine Änderung an `/etc` ist nicht nötig.
History (100.000 Einträge, zwischen Sitzungen geteilt) liegt unter `$XDG_STATE_HOME/zsh/history`,
der Completion-Cache unter `$XDG_CACHE_HOME/zsh`. Nicht gesetzte XDG-Pfade erhalten ihre Standardwerte.
Private Anpassungen gehören nach `~/.config/zsh/local.zsh` (Vorlage: `examples/zsh-local.zsh.example`).
Sie werden zuletzt geladen, auch für nichtinteraktive Tasks; interaktive Befehle entsprechend schützen.

Plugins werden ausschließlich auf ausdrücklichen Aufruf nach `$XDG_DATA_HOME/zsh/plugins` geladen:

```zsh
zplugin-install  # fehlende Plugins installieren; danach eine neue zsh öffnen
zplugin-update   # vorhandene Plugins per git pull --ff-only aktualisieren
```

Verwendet werden `zsh-autosuggestions`, `zsh-history-substring-search`, `zsh-vi-mode` und
`fast-syntax-highlighting`. Shell-Starts bleiben offline und funktionieren ohne diese Plugins.
Die vom Highlighting benötigte Theme-Datei wird aus dem lokalen Plugin in den Cache kopiert.
Fehlgeschlagene Downloads lassen sich mit `zplugin-install` wiederholen. Ein bereits vorhandenes,
unvollständiges Plugin-Verzeichnis muss vorher manuell beiseitegeschoben werden.

| Taste | Aktion |
| --- | --- |
| `Esc` / `i` | Vi-Normalmodus / Einfügemodus |
| `Ctrl-R` | fzf-History-Suche |
| `Ctrl-T` / `Ctrl-F` | Dateisuche mit / ohne versteckte Dateien |
| `Ctrl-Links` / `Ctrl-Rechts` | Wortweise bewegen |
| `↑` / `↓` | History-Teilstringsuche; ohne Plugin Präfixsuche |
| `Ctrl-\` | Vorschläge ein-/ausschalten (mit Autosuggestions-Plugin) |

fzf nutzt fd und bat, sofern vorhanden; ohne sie gibt es Dateisuche mit verfügbaren Ersatzwerkzeugen
und ohne Vorschau. Eigene Bindings werden nach der Vi-Plugin-Initialisierung gesetzt.

WezTerm (Linux), tmux, Zed und das Neovim-Terminal verwenden zsh. Die Login-Shell wird nicht geändert.
Optional selbst umstellen: `chsh -s "$(command -v zsh)"`.

### Bestehende Fish-Installation umstellen

Zuerst zsh installieren (auf Fedora über das `system`-Modul), dann
`./install.sh --only dotfiles --backup` ausführen und ein neues Terminal öffnen.
Der Installer entfernt nach erfolgreicher Verlinkung ausschließlich bekannte alte Fish-Dateisymlinks,
die auf diesen Checkout zeigen, auch wenn deren Quelldateien bereits entfernt wurden.
Fremde Links, private Fish-Einstellungen, History und das installierte Fish-Paket bleiben erhalten.
`local.fish` bei Bedarf manuell in `local.zsh` übersetzen; Fish-Syntax kann nicht direkt geladen werden.
Vorhandene zsh-Konfigurationsdateien unter den neuen Stow-Zielen werden über den üblichen
Konflikt-/Backup-Ablauf behandelt. `--dry-run` verändert auch bei der Migration keine Dateien.

## Editoren und Terminal

**Zed:** vorhandenes Theme „Neovim custom“, Vim-Modus, Space-Leader und Dock-Navigation bleiben.
TypeScript/JavaScript behalten ESLint statt Prettier. Python nutzt basedpyright/Ruff,
C# die C#-Extension mit Roslyn. `Space r r` bietet npm-, pytest-, Django- und dotnet-Tasks an.
Tasks starten nur manuell und erwarten passende Projektdateien/Abhängigkeiten im Worktree-Root.
In Monorepos `.zed/tasks.json` mit passendem `cwd` im Projekt anlegen.
Claude wird nicht automatisch gestartet; vorhandene Agent-Keybindings bleiben für manuelle Nutzung.

**Neovim:** eigenständige, deutsch kommentierte
[`init.lua`](nvim/.config/nvim/init.lua), konzeptionell an
[nvim-lite](https://github.com/radleylewis/nvim-lite) angelehnt, mit Zed-nahen Kürzeln und Farben.
Sieben Plugins über `vim.pack`: fzf-lua, nvim-tree, Which-Key, nvim-lspconfig,
Mason, mason-lspconfig und nvim-treesitter. Completion, Statuszeile und Formatierung sind nativ.
Neovim >= 0.12, Git, fzf, ripgrep und fd werden vorausgesetzt. Für Parser kommen C-Compiler
und die native tree-sitter CLI hinzu; das Development-Modul installiert Letztere.

Beim ersten Start lädt `vim.pack` die Plugins nach Bestätigung. Mason installiert die acht
eingerichteten Sprachserver, Treesitter die aufgeführten Parser. Dafür werden Internet,
Node/npm, Python/uv und .NET benötigt. `:Mason` zeigt Fortschritt und Installationsfehler;
bei Fehlern dort erneut installieren. Nach abgeschlossener Installation funktioniert der Start offline.
Angular-Projekte benötigen passende TypeScript-/Angular-Abhängigkeiten in `node_modules`,
JS/TS-Projekte eine eigene ESLint-Installation und -Konfiguration. C# verwendet weiterhin
OmniSharp (Zed verwendet Roslyn); Lua erhält Unterstützung beim Bearbeiten der Config.

Beim Speichern sowie mit `Space c f` gilt: JS/TS nur ESLint-Fixes, Python zuerst
Ruff-Importsortierung und dann Ruff-Formatierung, HTML und C# ihr jeweiliger LSP,
Lua der Lua-LSP. Kein Prettier. Jede LSP-Anfrage wartet höchstens zwei Sekunden;
fehlende Server verhindern das Speichern nicht. Beim Speichern werden außerdem nachgestellte
Leerzeichen entfernt und ein abschließender Zeilenumbruch gesetzt (auch in Markdown).
Binärdateien und spezielle Buffer sind davon ausgenommen. Python/C# verwenden vier,
JS/TS/HTML/Lua zwei Leerzeichen; Projekt-/Dateityp-Einstellungen können das anpassen.

| Neovim-Kürzel | Aktion |
| --- | --- |
| `Space Space`, `Space f f` | Dateien suchen |
| `Space f g`, `Space /` | Text im aktuellen Arbeitsverzeichnis suchen |
| `Space f s`, `Space f o` | Projekt-/Dateisymbole |
| `Space e`, `Space f e` | Explorer umschalten / aktuelle Datei zeigen |
| `Space b b`, `b n`, `b p`, `b d` | Vorherige Datei / nächster / vorheriger / Buffer schließen |
| `Space f b` | Offene Buffer auswählen |
| `Space c a`, `c r`, `c f`, `c u` | Code-Action / Umbenennen / Formatieren / Verwendungen |
| `gd`, `K` | Definition / LSP-Dokumentation |
| `Space x x`, `Space x f` | Bekannte Diagnosen / Diagnosen der aktuellen Datei |
| `Space x n`, `x p`, `x i` | Nächste / vorherige / Inline-Diagnosen umschalten |
| `Space s h/j/k/l` | Split links/unten/oben/rechts |
| `Space t t`, `Space t n` | Letztes Terminal umschalten / neues Terminal |
| `Esc Esc` im Terminal | Terminal-Normalmodus |
| `Ctrl-w h/j/k/l`, `Ctrl-w q` | Fenster wechseln / schließen, auch aus dem Terminal |
| `Space u n`, `Space u i` | Relative Zeilennummern / Inlay-Hints umschalten |
| `Space w`, `Space p` | Speichern / Befehle suchen |
| `Ctrl-Space`, `Ctrl-n/p`, `Ctrl-y` im Insert-Modus | Completion anfordern / wählen / übernehmen |

Bei verkürzten Tabellenangaben gehört `Space` jeweils dazu. Which-Key zeigt nach 300 ms
die verfügbaren Folgetasten. Suche arbeitet ab `:pwd`; Neovim im Projektverzeichnis starten
oder `:cd PFAD` verwenden. Diagnosen enthalten nur die von Sprachservern bereits gemeldeten
Befunde. Zed-spezifische Agent-, Task-, Dock- und Git-Panel-Funktionen sind nicht nachgebaut.
`Space e` öffnet jetzt den Explorer und `Space Space` die Dateisuche; die alten Kickstart-
Suchkürzel unter `Space s` entfallen zugunsten der Zed-Splits.

Zum Erweitern direkt in der `init.lua`:

- **Plugin:** URL zur Liste in Abschnitt 2 hinzufügen und darunter dessen `setup {}` aufrufen.
- **Sprache:** etwa `gopls = {}` in `servers` ergänzen. Mason installiert und aktiviert den
  Server. Für Formatierung zusätzlich `go = 'gopls'` in `formatters` und für Syntaxfarben
  `'go'` in `parsers` aufnehmen.
- **Taste:** etwa `map('n', '<leader>fh', fzf.help_tags, { desc = 'Hilfe suchen' })` ergänzen.

Plugin-Updates bewusst mit `:lua vim.pack.update()` anstoßen, die Vorschau prüfen und mit
`:write` übernehmen; anschließend `:TSUpdate` ausführen und die geänderte
`nvim-pack-lock.json` prüfen/committen. Sprachserver werden über `:Mason` separat verwaltet
und sind nicht durch die Plugin-Lockdatei festgelegt. Prüfen: `:checkhealth`,
`:checkhealth vim.lsp`, `:Mason`. Alte Plugin-Downloads und Mason-Pakete werden beim Umbau
nicht gelöscht. Die entfernten Kickstart-Dateien werden nicht mehr geladen; die neuen
Dateien erreichen bestehende Stow-Dateilinks direkt.

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
  nvim zed wezterm zsh tmux starship git ssh mise
```

Anschließend die benötigten Dateien aus dem gemeldeten Backup an ihre ursprünglichen Pfade
zurückkopieren. Lokale private Dateien bleiben erhalten. Stow entfernt keine installierten Programme.
Ein Installationsabbruch rollt Paketinstallationen nicht zurück; Modulfehler beheben und denselben
Aufruf wiederholen. Backups bleiben auch bei einem späteren Fehler verfügbar.

## Prüfung

```bash
bash scripts/check.sh
```

Prüft Bash/ShellCheck, zsh, LuaJIT-Syntax, JSONC/TOML und den Secret-Scan. Python-Integrationstests
verwenden temporäre Home-Verzeichnisse und prüfen echtes Stow, Backups, Wiederholungen,
Symlink-Konflikte, Pfade mit Leerzeichen, Git-Abfrage und Paketmanager-Fehler.
Fehlende optionale Prüfwerkzeuge werden als `SKIP` ausgewiesen. Mit vorhandenem fnm prüft die Suite
auch den rekursiven Node-Versionswechsel; mit tmux dessen Konfiguration auf einem separaten Socket.
zsh-Tests prüfen außerdem die Fish-Migration, Runtime-Reihenfolge, Sonderzeichen in Dateinamen,
Tastenbelegung sowie Plugin-Installation und Updates mit lokalen Git-Repositories.
`DOTFILES_ZSH_PLUGINS` kann auf einen Ordner mit den vier vorhandenen Plugin-Quellen zeigen:
Dann wird zusätzlich deren echter Start mit gesperrten Download-Befehlen und Vi-Initialisierung geprüft.
`DOTFILES_WEZTERM_BINARY` kann auf ein entpacktes AppImage zeigen, um die Keymap ohne Fenster zu laden.
`DOTFILES_NVIM_PLUGINS` kann auf vorhandene vertrauenswürdige Neovim-Plugin-Quellen (`opt/`) zeigen:
Der Offline-Test prüft dann Plugin-Konfiguration, Explorer, LSP-Aktivierung und Speichern/Formatter-Zuständigkeit mit abgeschalteten Downloads und Builds sowie simulierten LSP-Antworten. Der Cache muss die sieben aktuellen Plugins enthalten.

Eine vollständige Fedora-Installation und grafische Editor-/Clipboard-Tests müssen auf dem Zielsystem
erfolgen. Die lokale Prüfung auf CachyOS ersetzt keine Fedora-VM-Abnahme.

Installationsreferenzen: [fnm](https://github.com/Schniz/fnm),
[mise](https://mise.jdx.dev/installing-mise.html), [uv](https://docs.astral.sh/uv/getting-started/installation/),
[Starship](https://starship.rs/guide/), [WezTerm](https://wezterm.org/install/linux.html),
[Zed](https://zed.dev/docs/linux), [Neovim](https://neovim.io/doc/user/pack/),
[.NET auf Fedora](https://learn.microsoft.com/en-us/dotnet/core/install/linux-fedora).
