# Developer Dotfiles (Linux, WSL2 und Windows 11)

Persönliches Developer-Setup mit GNU Stow und einem modularen Bash-Installer. Ein Befehl richtet
Shell, Dev-Tools, Editoren, Terminal, einheitliches Tokyo-Night-Theme, Agent-Config und (auf
Desktop-Systemen) Hyprland samt Corne-Tastatur ein. Vim-Keybindings und das reduzierte
Terminal-Layout bleiben erhalten. Keine Atomic-/rpm-ostree-Systeme.

| Plattform | Umfang | Einstieg |
| --- | --- | --- |
| **Arch / CachyOS** | alles, inkl. Hyprland-Desktop, Theme und Corne (Profil `desktop`) | `bootstrap.sh` |
| **Fedora** | alles, inkl. Hyprland (COPR `sdegler/hyprland`), Theme und Corne | `bootstrap.sh` |
| **Debian / Ubuntu** | nur CLI: kein `desktop`-/`theme`-Modul; Corne/Vial nur als AppImage | `bootstrap.sh` |
| **WSL2 Arch** (unter Windows 11) | Profil `headless`, kein systemd nötig; wird vom Windows-Bootstrap eingerichtet | `bootstrap.ps1` |
| **Windows 11** | WezTerm, Zed, GlazeWM, Zebar, Flow Launcher, Vial; plus WSL2 Arch | `bootstrap.ps1` |

Die Windows-Seite ist in [`windows/README.md`](windows/README.md) beschrieben
(manuelle Variante: [`windows/MANUAL.md`](windows/MANUAL.md)).
Tastenbelegung und Befehle auf einen Blick: [`CHEATSHEET.md`](CHEATSHEET.md).

## Installation

### Linux

Auf einem frischen Linux als normaler Benutzer mit sudo, Bash, curl und Internetzugang starten.
Git und Python werden bei Bedarf installiert, das Repository per HTTPS nach `~/dotfiles`
geklont und `dot install` ausgeführt. Ein vorheriger Klon ist nicht nötig.

```bash
# Vorschau ohne Installation oder Klon:
curl -fsSL https://raw.githubusercontent.com/AdrianMeDev/dotfiles/main/bootstrap.sh | bash -s -- --dry-run
# Installation:
curl -fsSL https://raw.githubusercontent.com/AdrianMeDev/dotfiles/main/bootstrap.sh | bash
```

`--repo URL`, `--dir PFAD` und `--branch NAME` steuern den Klon; weitere Optionen
wie `--profile headless`, `--extras java,rust` und `--backup` gehen an `dot install`
(`bash -s -- --backup`). Vorhandene Klone werden unverändert wiederverwendet, ohne Pull.
Die Vorschau vor dem Klonen zeigt nur die Bootstrap-Schritte; den vollständigen Modulplan
zeigt danach `~/dotfiles/install.sh --dry-run`.

Nach erfolgreicher Verlinkung fragt der Installer im Terminal:
`Login-Shell auf …/zsh umstellen? [j/N]`. Nur eine Bestätigung mit `j` oder `y` führt
`chsh -s` aus; danach neu anmelden. Ohne Terminal erscheint stattdessen der manuelle
Befehl. Ist zsh bereits Login-Shell, entfällt die Rückfrage.

### Windows 11

In Windows PowerShell 5.1 oder PowerShell 7, ohne vorheriges Klonen:

```powershell
irm https://raw.githubusercontent.com/AdrianMeDev/dotfiles/main/bootstrap.ps1 | iex
```

`bootstrap.ps1` installiert Git bei Bedarf, klont nach `$env:USERPROFILE\dotfiles`, richtet die
nativen Windows-Anwendungen ein und installiert per `wsl --install archlinux` eine Arch-WSL2-Instanz,
in der danach der Linux-Installer (`dot install`) läuft. Optionen (`-DryRun`, `-Backup`,
`-Extra vs`, `-NoWsl`, `-WslUser`) und die Vorschau stehen in [`windows/README.md`](windows/README.md);
danach heißt der Befehl `windows\dot.ps1 install|update|doctor`.

### Der `dot`-Befehl

Nach der Installation steht `dot` (Stow-Paket `dot`, `~/.local/bin/dot`) bereit:

| Befehl | Wirkung |
| --- | --- |
| `dot install [OPTIONEN]` | ruft `install.sh` mit den Optionen auf |
| `dot update [--dry-run] [--profile …]` | aktualisiert Systempakete, mise-Tools, Flatpaks, zsh-Plugins sowie Claude Code, pi und die Agent-Config |
| `dot doctor` | read-only; prüft Tool-Versionen, mise, Stow-Links, Hyprland/Waybar (Version, Lua-Config, fehlende Desktop-Tools), Vial/udev, Git-Identität, fnm-Überreste und Abweichungen der Agent-Config; Exit 1 bei `[FEHLER]` |
| `dot zed-template [--dry-run] [--backup] angular\|django\|dotnet <PFAD>` | kopiert eine Zed-Projektvorlage nach `<PFAD>/.zed/` |

Bestehende Konfigurationsdateien stoppen den Installer **vor** den Systemänderungen.
Nach Prüfung der gemeldeten Pfade kannst du sie sichern und ersetzen lassen:

```bash
./install.sh --dry-run --backup
./install.sh --backup
```

`--dry-run` lädt nichts herunter, fragt keine Identität ab und schreibt keine Dateien.
Die Distro-Familie (`arch`, `fedora`, `debian`) sowie das Profil (`desktop` oder `headless`)
werden automatisch erkannt. In WSL2, Containern oder ohne grafische Session wählt der
Installer standardmäßig `headless` (ohne Desktop- und Flatpak-Pakete); bei Bedarf lässt sich
das Profil explizit mit `--profile desktop` oder `--profile headless` überschreiben.
Unter WSL2 ist kein systemd nötig; auf Fedora unter WSL lässt DNF den von Windows
bereitgestellten Kernel beim Upgrade aus.
Auf nicht unterstützten Distributionen lassen sich reine Dotfiles verlinken, sofern Bash,
Python >= 3.11, Git und GNU Stow vorhanden sind:

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
| `system` | System-Update (`pacman`/`dnf`/`apt-get`), Compiler/Build-Werkzeuge, Git/GitHub CLI, Stow, zsh, tmux, zoxide, direnv, fzf, ripgrep, fd, bat, jq, btop/htop, tree, ShellCheck, shfmt (Arch/Debian), Clipboard, Podman, Flatpak (bei `desktop`) sowie auf Arch der AUR-Helfer |
| `desktop` | Hyprland-Stack aus der Manifest-Gruppe `hypr` (Hyprland, Waybar, fuzzel, mako, hyprlock, hypridle, hyprpaper, cliphist, grim, slurp, Portal, Polkit-Agent, gnome-keyring, pavucontrol, nmtui, Blueman); nur Arch/Fedora, nur Profil `desktop`, nicht unter WSL (Fedora über COPR `sdegler/hyprland`) |
| `tools` | mise und alle Dev-CLI-Tools über mise in der neuesten Version (Neovim >= 0.12, Node LTS, uv, Starship, tree-sitter, lazygit, ripgrep, fd, fzf, bat, delta, eza, yazi, tealdeer, just, lazydocker; Konfiguration: `mise/.config/mise/config.toml`), Extras `java`/`rust` |
| `apps` | .NET SDK 10 (Arch/Fedora), WezTerm, Zed, Claude Code (nativer Installer), pi (npm über mise-Node), optional Ollama (Extras `ollama`, `ollama-models`) |
| `flatpak` | Flathub für den Benutzer; ausgewählte optionale Desktop-Apps (nur bei `--profile desktop`) |
| `fonts` | Ioskeley Mono und Ioskeley Mono Term Nerd Font 2.1.0 im Benutzerverzeichnis |
| `theme` | GTK/Qt dunkel, Cursor, Icons und Wallpaper (siehe [Theme-Modul](#theme-modul)); gleiche Bedingungen wie `desktop` |
| `corne` | Vial-GUI (Arch: `vial-appimage` aus dem AUR; Fedora/Debian x86_64: entpacktes AppImage mit SHA-256-Prüfung nach `~/.local/opt/vial`) und `/etc/udev/rules.d/99-vial.rules`; nur Profil `desktop`, nicht unter WSL (siehe [Corne-Doku](docs/CORNE.md)) |
| `dotfiles` | Konfliktprüfung, Git-Identität, optionale Backups, Stow-Verlinkung und Login-Shell-Rückfrage |
| `agents` | rendert `agent-config/` nach `~/.claude` und `~/.pi/agent` (Claude-Frontmatter der Skills wird eingefügt, `claude-frontmatter.txt` nicht kopiert); abweichende Dateien nur mit `--backup` ersetzt, idempotent |

**Keyring:** `gnome-keyring` stellt den Secret Service (`org.freedesktop.secrets`) bereit. Ohne PAM-Integration im Display-Manager fragt es bei der ersten Nutzung (Brave, Zed, `gh`) nach einem Keyring-Passwort.

Die zentrale Paketliste liegt in `manifests/packages.tsv` (Gruppen `base` immer, `desktop` nur
bei `--profile desktop`, `dev` für gezielte Abfragen wie `.NET SDK` oder `wezterm`).
Auf Arch verwendet der Installer `paru` oder `yay`, falls vorhanden, und installiert sonst `paru`.
Auf Debian wird `.NET SDK` in `manifests/packages.tsv` übersprungen.
Ohne Optionen werden alle Module in dieser Reihenfolge ausgeführt.
Die zusätzlichen CLI-Werkzeuge sind `eza` (Dateilisten, zsh-Aliase `ls`/`ll`/`lt`),
`yazi` (Dateimanager), `tldr` (Kurzreferenzen über tealdeer), `just` (Projektaufgaben)
und `lazydocker` (Container-TUI; benötigt einen erreichbaren Docker-kompatiblen Socket).
Einzelne Module ziehen ihre Voraussetzungen nicht automatisch nach:

```bash
./install.sh --only system
./install.sh --only tools
./install.sh --only apps
./install.sh --profile headless --only system
./install.sh --extras java,rust,firefox,discord,spotify
./install.sh --only system --extras rpmfusion
```

Extras: `java` (21 über mise), `rust` (stable über rustup), `rpmfusion` (free/nonfree, nur Fedora;
auf Arch und Debian übersprungen), `firefox`, `discord`, `spotify`, `ollama` (Ollama installieren) und
`ollama-models` (zusätzlich die Modelle ziehen, Liste per `OLLAMA_MODELS` überschreibbar):
`./install.sh --only apps --extras ollama,ollama-models`. Die Agent-Config allein:
`dot install --only agents` (mit `--backup`, falls Dateien abweichen). Extras müssen bei `--only` zum
ausgewählten Modul passen. Es werden keine Apps ohne entsprechende Auswahl installiert. Podman läuft
rootless; es wird kein Docker-Daemon eingerichtet. Container nicht mit `sudo` starten.

Der Installer benutzt offizielle HTTPS-Installer für mise sowie für Zed auf Fedora und Debian (auf Arch
wird das Distro-Paket `zed` verwendet); alle übrigen Dev-Tools lädt mise.
Mit gesetztem `GITHUB_TOKEN` nutzt mise authentifizierte GitHub-Downloads (kein API-Rate-Limit).
Diese werden zuerst in ein temporäres Verzeichnis geladen und dann als Benutzer ausgeführt.
WezTerm wird aus einem verfügbaren Distro-Paket (Arch/Fedora) installiert; ohne solches Paket wird
auf x86_64 das stabile Upstream-AppImage ohne FUSE entpackt. Auf aarch64 ohne passendes
Paket stoppt dieses Modul mit einer Anleitung. Es gibt keinen automatischen Nightly-COPR-Wechsel.
Neovim kommt über mise; ein Release unter 0.12 wird für diese Konfiguration abgelehnt.
GitHub-Release-Downloads werden gegen den Asset-Digest geprüft, sofern Upstream einen liefert.

Wiederholungen erzeugen keine doppelten Links oder Shell-Initialisierungen. Der Systempaketmanager
aktualisiert Systempakete; bereits vorhandene externe Werkzeuge werden nicht automatisch neu installiert.
Node/Python-Major-Versionen, Distro-Pakete, LSPs und einige Upstream-Installer sind nicht auf
exakte Patchstände festgelegt: Das Setup ist wiederholbar, aber kein bitidentisches Systemabbild.
Neovims Plugin-Versionen stehen in `nvim-pack-lock.json`; Plugin-Updates bewusst prüfen und committen.

## Hyprland-Desktop

Das Stow-Paket `hypr/` verlinkt immer (auch headless) `~/.config/hypr`, `waybar`, `fuzzel`, `mako`
und `qt5ct`/`qt6ct`. Die GTK-Einstellungen (`gtk-3.0`/`gtk-4.0`) werden nicht verlinkt, sondern vom Theme-Modul kopiert (siehe unten). Die Pakete selbst installiert `./install.sh --only desktop`
(nur Arch/Fedora, Profil `desktop`, nicht unter WSL; auf Debian wird das Modul übersprungen).

### Lua-Konfiguration (Hyprland >= 0.57)

`hypr/.config/hypr/hyprland.lua` (mit `bindings.lua`) ist die **Lua-Konfiguration**. Sie benötigt
**Hyprland >= 0.57**: Ab dieser Version lädt der Compositor `hyprland.conf` nicht mehr und liest nur
noch `hyprland.lua`. Ein Überrest `~/.config/hypr/hyprland.conf` wird ignoriert und von `dot doctor`
gemeldet. `hyprlock.conf`, `hypridle.conf` und `hyprpaper.conf` bleiben dagegen hyprlang.
`dot install` warnt bei zu alter Version; `dot doctor` zeigt die Hyprland-/Waybar-Version, warnt bei
< 0.57 und prüft die Konfiguration mit `hyprland --verify-config` (falls vorhanden, sonst in einer
laufenden Session mit `hyprctl configerrors`). Fehlende Desktop-Tools werden als `[WARN]` gelistet.

Anmelden: im Display-Manager die Session **Hyprland** wählen. Eine vorhandene KDE-Session wird nicht
angetastet (Fallback: im Display-Manager wieder „Plasma“ wählen). Treiber und Monitoreinstellungen
verwaltet das Setup nicht.

### Keybinding-Vertrag

`manifests/keybindings.tsv` ist die einzige Quelle der Bindings (Aktion, Modus, Kombination,
Windows-Befehl). `hypr/.config/hypr/bindings.lua` und die GlazeWM-Config müssen sie exakt abbilden;
`tests/test_keybindings.py` prüft beide. Auf Windows gehören `lock` (`Win+L`), Zwischenablage-Verlauf und
Screenshot dem System (`os:`), der Launcher (`Alt+Space`) Flow Launcher (`flow:`); unter Linux liegt der
Lock auf `Alt+Shift+X`. **Keine Kollisionen:** Zed-Keymap und WezTerm-Konfigurationen dürfen keine
Kombination des Vertrags belegen (ebenfalls per Test geprüft), damit der Fenstermanager nie
Editor-/Terminal-Kürzel verschluckt. Neue Bindings zuerst in die TSV eintragen.

### Theme-Modul

`./install.sh --only theme` (Arch/Fedora, Profil `desktop`, nicht WSL) installiert adw-gtk3, Papirus,
qt5ct/qt6ct, Kvantum und den Bibata-Cursor (Arch: AUR; Fedora: Release-Archiv) und setzt per `gsettings`
Dunkelmodus, `adw-gtk3-dark`, `Papirus-Dark` und den Cursor. Das Wallpaper wird einmalig aus
`theme/tokens.toml` nach `~/.local/share/dotfiles/wallpaper.png` erzeugt (vorhandene Dateien bleiben).
GTK-/Qt-Konfiguration (`gtk-3.0`, `gtk-4.0`, `qt5ct`, `qt6ct`), Waybar, mako, fuzzel und Hyprland
beziehen Farben, Fonts, Deckkraft, Blur und Rahmen aus denselben Tokens; `tests/test_theme.py` prüft das.
Die GTK-Dateien (`settings.ini`, `gtk.css` in `theme/gtk-3.0` und `theme/gtk-4.0`) kopiert das Modul einmalig nach
`~/.config`, damit KDEs GTK-Sync nicht ins Repository schreibt: fehlende Ziele werden angelegt, alte Stow-Links
ersetzt, identische Dateien übersprungen. Abweichende Dateien (z. B. von KDE) bleiben unverändert und werden
nur mit `--backup` gesichert und ersetzt; unter Hyprland setzt `gsettings` die wichtigen Werte ohnehin.
Der Gesamtüberblick steht unter [Einheitliches Theme](#einheitliches-theme-themetokenstoml).

### Corne & Vial

`./install.sh --only corne` (Profil `desktop`, nicht unter WSL) installiert **Vial**
(Arch: `vial-appimage` aus dem AUR; Fedora/Debian auf `x86_64`: stabiles Upstream-AppImage mit
SHA-256-Prüfung nach `~/.local/opt/vial`, Wrapper `~/.local/bin/vial` und Desktop-Starter)
sowie `/etc/udev/rules.d/99-vial.rules` (lädt per `udevadm` neu; abweichende Regeln nur mit `--backup`).
Damit erkennt Vial den Corne ohne `sudo`. `dot doctor` prüft im Desktop-Profil `vial` und die udev-Regel.
Alle 6 Layer, die Vertrags-Akkorde und die Anleitung zum Laden von `corne_v4.vil` stehen in
[`docs/CORNE.md`](docs/CORNE.md); `tests/test_corne_layout.py` prüft die Erreichbarkeit aller
Bindings aus `manifests/keybindings.tsv`.

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

Node (LTS) und die übrigen Tools verwaltet mise; zsh aktiviert mise und beachtet
`.node-version`/`.nvmrc` auch in Unterverzeichnissen. uv wird ohne Shell-Hook verwendet;
pyenv, fnm und der CachyOS-spezifische Shell-Loader sind entfernt.
**Migration fnm → mise:** Beim nächsten `dot install` installiert mise Node; ein altes fnm
bleibt unangetastet, `dot doctor` meldet es als Überrest und kann manuell entfernt werden.

```zsh
mise use node@24      # projektbezogen, schreibt mise.toml
mise ls               # installierte Tools und Versionen
dot doctor            # Versionen und Probleme
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
Programme werden nur initialisiert, wenn sie installiert sind. Runtime-Pfade und mise stehen
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

WezTerm (Linux), tmux, Zed und das Neovim-Terminal verwenden zsh. Die Login-Shell stellt das
`dotfiles`-Modul nur nach ausdrücklicher Bestätigung im Terminal um (siehe [Installation](#linux));
ohne Terminal oder bei Ablehnung manuell: `chsh -s "$(command -v zsh)"`.

### Bestehende Fish-Installation umstellen

Zuerst zsh installieren (über das `system`-Modul), dann
`./install.sh --only dotfiles --backup` ausführen und ein neues Terminal öffnen.
Der Installer entfernt nach erfolgreicher Verlinkung ausschließlich bekannte alte Fish-Dateisymlinks,
die auf diesen Checkout zeigen, auch wenn deren Quelldateien bereits entfernt wurden.
Fremde Links, private Fish-Einstellungen, History und das installierte Fish-Paket bleiben erhalten.
`local.fish` bei Bedarf manuell in `local.zsh` übersetzen; Fish-Syntax kann nicht direkt geladen werden.
Vorhandene zsh-Konfigurationsdateien unter den neuen Stow-Zielen werden über den üblichen
Konflikt-/Backup-Ablauf behandelt. `--dry-run` verändert auch bei der Migration keine Dateien.

## Editoren und Terminal

**Zed:** Konfiguration aus dem Stow-Paket [`zed-config/`](zed-config/README.md) (`~/.config/zed/{settings,keymap,tasks,debug}.json`).
Tokyo Night mit vorhandener Transparenz, Ioskeley Mono im Editor und die
terminaloptimierte Nerd Font im integrierten Terminal. Vim-Modus, Space-Leader und Dock-Navigation bleiben.
Die Oberfläche nutzt einen 75-%-Tokyo-Night-Fensterhintergrund mit transparenten Editor- und Panel-Flächen.
Lokale Edit Predictions verwenden Ollama mit `qwen2.5-coder:7b-base`; das Modell muss
lokal geladen sein (`ollama pull qwen2.5-coder:7b-base`).
Web-Dateien (TS/JS/HTML/CSS) formatiert Prettier, TypeScript wendet zusätzlich ESLint-Fixes an;
Python nutzt basedpyright/Ruff, C# die C#-Extension mit Roslyn.
Die globale `tasks.json` enthält Claude Code, pi, lazygit, Git-Log, TODO-Suche und Ollama-Modelle.
Die Projekt-Tasks (`dev: run/build/test/lint/format` plus Angular-, Django-/pytest- bzw. dotnet-/EF-Aufgaben)
kommen mit `dot zed-template angular|django|dotnet <PFAD>` nach `<PFAD>/.zed/`; sie starten nur manuell und
erwarten passende Projektdateien im Worktree-Root (in Monorepos `cwd` anpassen).
Claude Code und pi laufen als ACP-Agents im Editor (Befehlspalette `zed: acp registry`);
sie starten nie automatisch. Details: [`zed-config/README.md`](zed-config/README.md).

**Agents (`agent-config/`):** das `agents`-Modul rendert die Konfiguration nach `~/.claude` (Claude Code,
Arbeit) und `~/.pi/agent` (pi, privat, lokal über Ollama). Beide teilen die Befehle `/grill`, `/plan-roadmap`,
`/plan-commits`, `/next`, `/explain`, `/explain-project`. `dot update` aktualisiert Claude Code, pi und die
Config, `dot doctor` meldet lokale Abweichungen. Anmeldung bei Claude einmalig mit `claude`.
Details: [`agent-config/README.md`](agent-config/README.md).

**Neovim:** eigenständige, deutsch kommentierte
[`init.lua`](nvim/.config/nvim/init.lua), konzeptionell an
[nvim-lite](https://github.com/radleylewis/nvim-lite) angelehnt, mit Zed-nahen Kürzeln und Tokyo Night.
Neun Plugins über `vim.pack`: Tokyo Night, fzf-lua, nvim-tree, Which-Key, Flash,
nvim-lspconfig, Mason, mason-lspconfig und nvim-treesitter. Completion, Statuszeile und Formatierung sind nativ.
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
Tokyo Night bleibt mit der vorhandenen Transparenz aktiv. Ioskeley Mono Term Nerd Font
erhält Fallbacks auf Ioskeley Mono und DejaVu Sans Mono.

Das Font-Modul installiert aus Ioskeley Mono 2.1.0 die normale unhinted Editor-Familie
und die terminaloptimierte Nerd-Font-Familie mit jeweils allen 20 Schnitten. Bereits
anderweitig installierte Fonts werden nicht entfernt. `fc-match 'Ioskeley Mono'` und
`fc-match 'IoskeleyMonoTerm Nerd Font Mono'` zeigen die tatsächlich gewählten Dateien.

**tmux:** Prefix `Ctrl-a`, `h/j/k/l` Pane-Navigation, `-` und `\` Splits,
`r` Reload, `S` Statusleiste umschalten. Statusleiste und Maus bleiben standardmäßig aus.
Copy-Mode: Prefix + `[`, `v` auswählen, `y` kopieren; unter Wayland mit `wl-copy`.

### Einheitliches Theme (`theme/tokens.toml`)

Palette (Tokyo Night, Variante Night), Ioskeley-Fonts, 75-%-Deckkraft, Blur und Rahmen liegen zentral in
[`theme/tokens.toml`](theme/tokens.toml). Neben WezTerm, Zed, Neovim, tmux, Starship, fzf/zsh, Claude Code und
pi werden auch die CLI-Tools über eigene Stow-Pakete abgestimmt: `bat` (`tokyonight_night`-Theme mit
automatischem `bat cache --build`), `lazygit`, `btop` (`tokyo-night`-Theme) und `yazi`. Auf dem Desktop kommen
Hyprland, Waybar, mako, fuzzel, GTK/Qt und das Wallpaper hinzu; unter Windows folgen GlazeWM/Zebar den
gleichen Werten. Neue Farben zuerst in die Tokens eintragen.

## Backups und Wiederherstellung

Kollidierende Dateien werden bei `--backup` nach
`~/.local/state/dotfiles/backups/ZEITSTEMPEL-ZUFALL/` verschoben. Das Verzeichnis ist privat (`700`)
und liegt außerhalb des Repos. Bestehende korrekte Links werden nicht gesichert oder erneut angelegt.
Die alte `~/.wezterm.lua` wird ebenfalls gesichert, da sie sonst die neue XDG-Konfiguration verdeckt.

Zum Entfernen der Links im Repo ausführen:

```bash
stow --dir "$PWD" --target "$HOME" --no-folding --delete \
  nvim zed-config wezterm zsh tmux starship git ssh mise dot bat lazygit btop yazi hypr
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
Theme-Paritätstests (`tests/test_theme.py`) prüfen alle Tools (Zed, WezTerm, Neovim, tmux,
Starship, fzf/zsh, bat/delta, lazygit, btop, yazi, Claude Code, pi) gegen `theme/tokens.toml`.
Fehlende optionale Prüfwerkzeuge werden als `SKIP` ausgewiesen. Mit tmux dessen Konfiguration auf einem separaten Socket.
zsh-Tests prüfen außerdem die Fish-Migration, Runtime-Reihenfolge, Sonderzeichen in Dateinamen,
Tastenbelegung sowie Plugin-Installation und Updates mit lokalen Git-Repositories.
`DOTFILES_ZSH_PLUGINS` kann auf einen Ordner mit den vier vorhandenen Plugin-Quellen zeigen:
Dann wird zusätzlich deren echter Start mit gesperrten Download-Befehlen und Vi-Initialisierung geprüft.
`DOTFILES_WEZTERM_BINARY` kann auf ein entpacktes AppImage zeigen, um die Keymap ohne Fenster zu laden.
`DOTFILES_NVIM_PLUGINS` kann auf vorhandene vertrauenswürdige Neovim-Plugin-Quellen (`opt/`) zeigen:
Der Offline-Test prüft dann Plugin-Konfiguration, Explorer, LSP-Aktivierung und Speichern/Formatter-Zuständigkeit mit abgeschalteten Downloads und Builds sowie simulierten LSP-Antworten. Der Cache muss die sieben aktuellen Plugins enthalten.

Für echte Distro-Tests gibt es eine Container-Matrix (`archlinux`, `fedora`, `debian`):

```bash
bash scripts/container-matrix.sh
# Einzelne Distro oder Engine wählen:
CONTAINER_ENGINE=docker bash scripts/container-matrix.sh arch debian
```

Ohne `CONTAINER_ENGINE` nutzt das Skript `podman` oder fällt auf `docker` zurück und führt
pro Container als normaler Benutzer aus: gepiptes `bootstrap.sh --dry-run` (git fehlt,
Familie erkannt, nichts unter `$HOME` geschrieben), zweimal `bootstrap.sh --repo /dotfiles`
(Git wird installiert, Bootstrap klont selbst nach `~/dotfiles`; keine Backups und beim
zweiten Lauf unveränderter Klon). Symlink-Ziele müssen im Klon liegen. Danach prüft sie
`dot`, `nvim` (>= 0.12), `node`, `uv`, `claude --version`, `pi --version` sowie
`eza`, `yazi`, `tldr`, `just` und `lazydocker` über `zsh -c`, die Dateien unter `~/.claude` und `~/.pi/agent`
(gerendertes Claude-Frontmatter, keine `claude-frontmatter.txt`), `dot update --dry-run`,
`dot update` und `dot doctor`. Auf Arch/Fedora prüft die Matrix zusätzlich die `hypr`-Links
(`hyprland.lua`, `bindings.lua`) und führt `desktop` und `theme` mit `--profile desktop --dry-run` aus
(schreibt nichts). Ist `GITHUB_TOKEN` gesetzt, wird er an die Container durchgereicht.
Die GitHub-Actions-CI (`.github/workflows/ci.yml`) führt sowohl `scripts/check.sh` als auch
die Container-Matrix für `arch`, `fedora` und `debian` automatisch aus.
Der Bootstrap klont den aktuellen Commit des eingebundenen Repos; nicht committete
Installationsänderungen werden nicht mitgeklont. Bei Git-Worktrees bindet die Matrix
auch das externe Git-Verzeichnis schreibgeschützt ein.
Grafische Editor- und Clipboard-Tests erfolgen weiterhin auf dem jeweiligen Zielsystem.

### Manuelle Abnahme auf einer frischen VM (noch offen)

Abhakbare Kurzfassung für VMs und Hardware: [`docs/ACCEPTANCE.md`](docs/ACCEPTANCE.md).

Pro Zielsystem mit VM-Snapshot als normaler Benutzer; Ergebnis und VM-Version manuell festhalten.

**Linux (CachyOS; Fedora und Debian ohne Schritte 5–6):**

1. Ohne `~/dotfiles` die `curl | bash`-Vorschau (`--dry-run`) und danach die Installation ausführen.
2. Git-Identität eingeben, zsh-Rückfrage bestätigen, ab- und anmelden.
   `getent passwd "$USER"` muss zsh als Login-Shell zeigen.
3. In zsh `eza --version`, `yazi --version`, `tldr --version`, `just --version`,
   `lazydocker --version`, `claude --version`, `pi --version` und `dot doctor` ausführen; `ls`/`ll`/`lt` prüfen.
4. `git -C ~/dotfiles status --short` und vorhandene Backups notieren, denselben Bootstrap erneut starten:
   keine neuen Backups, keine Repo-Änderungen. Danach `dot update` und `dot doctor` prüfen.
5. Hyprland und KDE anmelden; Bindings, Zwischenablage, Fonts und Tokyo-Night-Theme
   in WezTerm, Zed und Neovim prüfen.
6. Corne anschließen, `vial` ohne `sudo` starten, `corne_v4.vil` laden und alle
   Vertrags-Bindings über die Layer aus [`docs/CORNE.md`](docs/CORNE.md) testen.

**Windows 11:** `bootstrap.ps1` ausführen (zuerst `-DryRun`); WezTerm öffnet zsh in Arch-WSL, Zed öffnet ein
WSL-Projekt mit LSP, Claude läuft in WSL, GlazeWM-Bindings und Vial prüfen. Zweiter Lauf ändert nichts;
`windows\dot.ps1 update` und `doctor` laufen sauber (Details: [`windows/README.md`](windows/README.md)).

Installationsreferenzen: [mise](https://mise.jdx.dev/installing-mise.html), [uv](https://docs.astral.sh/uv/getting-started/installation/),
[Starship](https://starship.rs/guide/), [WezTerm](https://wezterm.org/install/linux.html),
[Zed](https://zed.dev/docs/linux), [Neovim](https://neovim.io/doc/user/pack/),
[.NET auf Fedora](https://learn.microsoft.com/en-us/dotnet/core/install/linux-fedora).
