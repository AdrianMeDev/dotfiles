# Dotfiles-Spickzettel

**Schnellnavigation:** [Zed](#zed) · [Vim-Basis](#vim-grundlagen-für-zed-und-neovim) ·
[Neovim](#neovim) · [zsh/fzf](#zsh-und-fzf) · [tmux](#tmux) ·
[WezTerm](#wezterm) · [Git](#git) · [CLI-Tools](#cli-werkzeuge) ·
[Windows](#windows-glazewm-und-flow-launcher) · [Lernroutine](#lernroutine)

## Legende

| Schreibweise             | Bedeutung                                       |
| ------------------------ | ----------------------------------------------- |
| `Space f f`              | Tasten nacheinander drücken                     |
| `Ctrl-W h`               | `Ctrl` und `W` zusammen, danach `h`             |
| `Ctrl+Shift+X`           | Tasten gleichzeitig drücken                     |
| `Prefix`                 | In tmux: `Ctrl-A` drücken und loslassen         |
| `h/j/k/l`                | links / unten / oben / rechts                   |
| Normal / Insert / Visual | Vim-Modus; `Esc` / `i` / `v` wechselt den Modus |

> In Zed und Neovim ist der Leader `Space`. Die Leader-Kürzel gelten im
> Normalmodus. Kurz `Space` halten zeigt in beiden Editoren die Folgetasten.

## Tägliche Kurzfassung

| Ziel                             | Kürzel oder Befehl                                         |
| -------------------------------- | ---------------------------------------------------------- |
| Projekt-Terminal öffnen          | `tp PFAD`                                                  |
| Schnell in bekanntes Verzeichnis | `z NAME` oder interaktiv `zi`                              |
| Datei im Terminal suchen/öffnen  | `fe`                                                       |
| Datei in Zed/Neovim suchen       | `Space Space`                                              |
| Text im Projekt suchen           | `Space /`                                                  |
| Explorer umschalten              | `Space e`                                                  |
| Speichern                        | `Space w`                                                  |
| Code-Action / Rename / Format    | `Space c a` / `Space c r` / `Space c f`                    |
| Nächste / vorige Diagnose        | `Space x n` / `Space x p`                                  |
| Terminal umschalten / neu        | `Space t t` / `Space t n`                                  |
| Split navigieren                 | `Ctrl-W h/j/k/l`                                           |
| Git-Überblick                    | `gs`, dann `gd` und `gds`                                  |
| Interaktiv stagen                | `git add -p`                                               |
| Commit erstellen                 | `gc -m "Nachricht"`                                        |
| Branch wechseln/erstellen        | `gsw NAME` / `gsw -c NAME`                                 |
| Letzte Commits                   | `gl`                                                       |
| Shell-History durchsuchen        | `Ctrl-R`                                                   |
| Datei in Shell einfügen          | `Ctrl-T` mit versteckten, `Ctrl-F` ohne versteckte Dateien |

Ein typischer Arbeitsstart:

```bash
z projekt
tp
gs
zed .                     # oder: nvim .
```

Ein typischer kleiner Git-Zyklus:

```bash
gs
gd
git add -p
gds
gc -m "Kurze Beschreibung"
git push
```

## Zed

Die folgenden Kürzel kommen direkt aus `zed/.config/zed/keymap.json`.

### Dateien, Suche und Buffer

| Kürzel                     | Aktion                                        |
| -------------------------- | --------------------------------------------- |
| `Space Space`, `Space f f` | Datei suchen                                  |
| `Space f g`, `Space /`     | Projektweit suchen                            |
| `Space f s`                | Projektsymbole suchen                         |
| `Space f o`                | Outline der aktuellen Datei                   |
| `Space e`                  | Project Panel umschalten                      |
| `Space f e`                | Aktuelle Datei im Project Panel zeigen        |
| `Space b b`                | Zwischen aktueller und voriger Datei wechseln |
| `Space b n` / `Space b p`  | Nächster / voriger Buffer                     |
| `Space b d`                | Aktiven Buffer schließen                      |
| `Space b o`                | Alle anderen Buffer schließen                 |
| `Space b r`                | Geschlossenen Buffer wieder öffnen            |
| `Space p`                  | Command Palette                               |
| `Space w`                  | Speichern                                     |

### Code, Diagnosen und Git

| Kürzel                    | Aktion                                |
| ------------------------- | ------------------------------------- |
| `Space c a`               | Code-Action                           |
| `Space c r`               | Symbol umbenennen                     |
| `Space c f`               | Datei formatieren                     |
| `Space c u`               | Verwendungen/Referenzen suchen        |
| `Space c l`               | Language Server neu starten           |
| `Space x x`               | Projekt-Diagnosen                     |
| `Space x f`               | Diagnosen der aktuellen Datei         |
| `Space x n` / `Space x p` | Nächste / vorige Diagnose             |
| `Space x i`               | Inline-Diagnosen umschalten           |
| `Space g g`               | Git Panel umschalten                  |
| `Space g b`               | Inline Git Blame umschalten           |
| `Space g d`               | Diff des Hunks/der Auswahl umschalten |

### Terminal, Splits, UI und Tasks

| Kürzel            | Aktion                                 |
| ----------------- | -------------------------------------- |
| `Space t t`       | Unteres Terminal umschalten            |
| `Space t n`       | Neues Terminal                         |
| `Space t v`       | Terminal-Vi-Modus umschalten           |
| `Space s h/j/k/l` | Split links/unten/oben/rechts          |
| `Space u a`       | Alle Docks umschalten                  |
| `Space u c`       | Alle Docks schließen                   |
| `Space u h/j/l`   | Linkes/unteres/rechtes Dock umschalten |
| `Space u z`       | Editor maximieren                      |
| `Space u i`       | Inlay-Hints umschalten                 |
| `Space u n`       | Relative Zeilennummern umschalten      |
| `Space r r`       | Task auswählen und starten             |
| `Space r l`       | Letzten Task erneut starten            |
| `Space j`         | Zu sichtbarem Wort springen            |

Verfügbare Tasks: `Node: start`, `Node: test`, `Node: build`, `Python: pytest`,
`Django: runserver (localhost)`, `.NET: build`, `.NET: test` und `.NET: watch`.

### Docks, Agent und Visual Mode

| Kontext             | Kürzel                     | Aktion                               |
| ------------------- | -------------------------- | ------------------------------------ |
| Dock/Terminal/Panel | `Ctrl-W h/j/k/l`           | Fokus bewegen                        |
| Dock/Terminal/Panel | `Ctrl-W Q` oder `Ctrl-W C` | Aktives Dock schließen               |
| Normal              | `Space a a`                | Agent Panel umschalten               |
| Normal              | `Space a c`                | neuen Claude-Terminal-Thread starten |
| Normal              | `Space a n`                | neuen Zed-Agent-Thread starten       |
| Normal              | `Space a p`                | Edit Predictions umschalten          |
| Insert              | `Ctrl+Alt+P`               | Edit Predictions umschalten          |
| Visual              | `S`, danach Zeichen        | Auswahl umschließen, etwa mit `(`    |
| Visual              | `Space a s`                | Auswahl an Agent-Thread übergeben    |

## Vim-Grundlagen für Zed und Neovim

Diese Standardtasten sind die gemeinsame Basis beider Editoren.

### Modi und Bewegung

| Kürzel              | Aktion                                     |
| ------------------- | ------------------------------------------ |
| `Esc`               | Normalmodus                                |
| `i` / `a`           | vor / nach dem Cursor einfügen             |
| `I` / `A`           | am Zeilenanfang / -ende einfügen           |
| `o` / `O`           | neue Zeile darunter / darüber              |
| `v` / `V`           | zeichenweise / zeilenweise Auswahl         |
| `h j k l`           | links / unten / oben / rechts              |
| `w` / `b` / `e`     | Wort vor / zurück / zum Wortende           |
| `0` / `^` / `$`     | Zeilenanfang / erstes Zeichen / Zeilenende |
| `gg` / `G`          | Dateianfang / Dateiende                    |
| `Ctrl-D` / `Ctrl-U` | halbe Seite runter / hoch                  |
| `%`                 | zum passenden Klammerzeichen               |

### Bearbeiten, Suchen und Wiederholen

| Kürzel                   | Aktion                                        |
| ------------------------ | --------------------------------------------- |
| `x`                      | Zeichen löschen                               |
| `dd` / `D`               | Zeile / bis Zeilenende löschen                |
| `yy` / `Y`               | Zeile kopieren                                |
| `p` / `P`                | nach / vor dem Cursor einfügen                |
| `cw` / `ciw`             | Wort ab Cursor / ganzes Wort ändern           |
| `ci"`, `ci(`             | Inhalt in Anführungszeichen / Klammern ändern |
| `u` / `Ctrl-R`           | rückgängig / wiederherstellen                 |
| `.`                      | letzte Änderung wiederholen                   |
| `/TEXT`, dann `n` / `N`  | suchen, nächster / voriger Treffer            |
| `*` / `#`                | Wort unter Cursor vorwärts / rückwärts suchen |
| `>` / `<` im Visual Mode | Auswahl ein-/ausrücken                        |

Praktisches Vim-Muster: `Operator + Bewegung`, zum Beispiel `d w` (bis zum
nächsten Wort löschen), `c $` (bis Zeilenende ändern) oder `y i (` (Inhalt der
Klammern kopieren). Eine Zahl wiederholt: `3dd`, `5j`, `2w`.

## Neovim

Die Leader-Kürzel sind absichtlich fast identisch zu Zed.

### Eigene Kürzel

| Kürzel                     | Aktion                                       |
| -------------------------- | -------------------------------------------- |
| `Space Space`, `Space f f` | Datei mit fzf-lua suchen                     |
| `Space f g`, `Space /`     | Text im Arbeitsverzeichnis suchen            |
| `Space f s` / `Space f o`  | Projekt- / Dateisymbole                      |
| `Space f b`                | Offene Buffer auswählen                      |
| `Space e` / `Space f e`    | Explorer umschalten / Datei zeigen           |
| `Space b b`                | Vorige Datei                                 |
| `Space b n/p/d`            | Nächster / voriger / Buffer schließen        |
| `Space c a/r/f/u`          | Code-Action / Rename / Format / Verwendungen |
| `gd`                       | Zur Definition                               |
| `Space j`                  | Zu sichtbarem Wort springen                  |
| `Space x x/f`              | Workspace- / Datei-Diagnosen                 |
| `Space x n/p/i`            | Nächste / vorige / Inline-Diagnosen          |
| `Space s h/j/k/l`          | Split links/unten/oben/rechts                |
| `Ctrl-W h/j/k/l`           | Split fokussieren                            |
| `Ctrl-W Q` oder `Ctrl-W C` | Split schließen                              |
| `Space u n/i`              | relative Zeilen / Inlay-Hints umschalten     |
| `Space t t/n`              | Letztes Terminal umschalten / neues Terminal |
| `Esc Esc` im Terminal      | Terminal-Normalmodus                         |
| `Space w` / `Space p`      | Speichern / Befehle suchen                   |
| `Esc` im Normalmodus       | Suchmarkierung löschen                       |

### Completion und Wartung

| Kürzel/Befehl               | Aktion                              |
| --------------------------- | ----------------------------------- |
| `Ctrl-Space` im Insert Mode | LSP-Completion anfordern            |
| `Ctrl-N` / `Ctrl-P`         | nächsten / vorigen Vorschlag wählen |
| `Ctrl-Y`                    | Vorschlag übernehmen                |
| `:Mason`                    | Language Server verwalten           |
| `:checkhealth`              | Installation prüfen                 |
| `:checkhealth vim.lsp`      | LSP-Probleme prüfen                 |
| `:lua vim.pack.update()`    | Plugin-Updates prüfen               |
| `:TSUpdate`                 | Treesitter-Parser aktualisieren     |

Suche und Dateiauswahl starten ab Neovims `:pwd`. Bei Bedarf mit `:cd PFAD`
wechseln oder Neovim direkt im Projekt-Root starten.

## zsh und fzf

### Shell-Keybindings

| Kürzel                       | Aktion                                                         |
| ---------------------------- | -------------------------------------------------------------- |
| `Esc` / `i`                  | Vi-Normalmodus / Insert Mode                                   |
| `Ctrl-R`                     | History mit fzf durchsuchen                                    |
| `Ctrl-T`                     | Datei inklusive versteckter Dateien suchen und einsetzen       |
| `Ctrl-F`                     | sichtbare Datei suchen und einsetzen                           |
| `Ctrl-Links` / `Ctrl-Rechts` | wortweise bewegen                                              |
| `Pfeil hoch/runter`          | History passend zum bisherigen Text                            |
| `Ctrl-\`                     | Autosuggestions ein-/ausschalten                               |
| `Tab`                        | Completion-Menü; erneut drücken/navigieren, mit `Enter` wählen |

Im fzf-Fenster:

| Kürzel                              | Aktion                                            |
| ----------------------------------- | ------------------------------------------------- |
| tippen                              | Treffer filtern; Leerzeichen trennt Suchbegriffe  |
| `Pfeil hoch/runter` oder `Ctrl-K/J` | Auswahl bewegen                                   |
| `Enter`                             | Auswahl übernehmen                                |
| `Esc` oder `Ctrl-C`                 | abbrechen                                         |
| `Tab` / `Shift-Tab`                 | bei Mehrfachauswahl markieren / Markierung zurück |

### Eigene Funktionen und Aliase

| Befehl                          | Wirkung                                               |
| ------------------------------- | ----------------------------------------------------- |
| `mkcd PFAD`                     | Verzeichnis erstellen und hineinwechseln              |
| `croot`                         | ins Root des aktuellen Git-Worktrees wechseln         |
| `fe`                            | Projektdatei mit fzf suchen und in `$EDITOR` öffnen   |
| `tp [PFAD]`                     | tmux-Projektsitzung erstellen/öffnen/wechseln         |
| `..`, `...`                     | eine / zwei Ebenen hoch                               |
| `ll`                            | ausführliche Dateiliste inklusive versteckter Dateien |
| `gs`                            | `git status --short --branch`                         |
| `gd` / `gds`                    | unstaged / staged Diff                                |
| `gl`                            | kompakter Git-Graph der letzten 20 Commits            |
| `ga ...` / `gc ...` / `gsw ...` | `git add` / `git commit` / `git switch`               |
| `pps` / `pc ...`                | `podman ps` / `podman compose`                        |
| `uvr ...` / `uvs`               | `uv run ...` / `uv sync`                              |
| `zplugin-install`               | optionale zsh-Plugins installieren                    |
| `zplugin-update`                | installierte zsh-Plugins aktualisieren                |

## tmux

Der konfigurierte Prefix ist `Ctrl-A`, nicht der tmux-Standard `Ctrl-B`.
`Prefix -` bedeutet: `Ctrl-A` loslassen, dann `-` drücken.

### Eigene Kürzel

| Kürzel                 | Aktion                                   |
| ---------------------- | ---------------------------------------- |
| `Prefix -`             | horizontal teilen: neues Pane unten      |
| `Prefix \`             | vertikal teilen: neues Pane rechts       |
| `Prefix h/j/k/l`       | Pane links/unten/oben/rechts fokussieren |
| `Prefix Shift-H/J/K/L` | Pane wiederholt vergrößern/verkleinern   |
| `Prefix c`             | neues Fenster im aktuellen Verzeichnis   |
| `Prefix r`             | Konfiguration neu laden                  |
| `Prefix Shift-S`       | versteckte Statusleiste umschalten       |
| `Prefix Ctrl-A`        | echtes `Ctrl-A` an Anwendung senden      |

### Wichtige tmux-Standardkürzel

| Kürzel                                  | Aktion                                      |
| --------------------------------------- | ------------------------------------------- |
| `Prefix d`                              | Sitzung verlassen; Prozesse laufen weiter   |
| `Prefix s`                              | Sitzungen wählen                            |
| `Prefix w`                              | Fensterliste                                |
| `Prefix n` / `Prefix p`                 | nächstes / voriges Fenster                  |
| `Prefix 1` … `9`                        | Fenster direkt wählen                       |
| `Prefix ,`                              | Fenster umbenennen                          |
| `Prefix x`                              | aktuelles Pane nach Rückfrage schließen     |
| `Prefix &`                              | aktuelles Fenster nach Rückfrage schließen  |
| `Prefix [`                              | Copy Mode öffnen; mit Vi-Tasten bewegen     |
| Copy Mode: `v`, dann Bewegung, dann `y` | markieren und ins System-Clipboard kopieren |
| `tmux ls`                               | laufende Sitzungen anzeigen                 |
| `tmux attach -t NAME`                   | Sitzung wieder öffnen                       |
| `tmux kill-session -t NAME`             | genau eine Sitzung beenden                  |

Sitzungen lassen sich komfortabel mit `tp` öffnen und wechseln. Alternativ dienen
`Prefix s` oder `tmux switch-client -t NAME` dazu.

## WezTerm

WezTerm verwaltet die äußeren Tabs; tmux verwaltet Projektprozesse und Panes.

| Kürzel                        | Aktion                                      |
| ----------------------------- | ------------------------------------------- |
| `Ctrl+1` … `Ctrl+9`           | Tab direkt wählen                           |
| `Ctrl+T`                      | Tab in aktueller Domain öffnen              |
| `Ctrl+Shift+W`                | Tab nach Rückfrage schließen                |
| `Ctrl+Tab` / `Ctrl+Shift+Tab` | nächster / voriger Tab                      |
| `Ctrl+Shift+O`                | Launcher/Workspace-Menü                     |
| `Ctrl+Shift+X`                | Copy Mode                                   |
| `Ctrl+Shift+Space`            | Quick Select für sichtbare URLs/Pfade/Text  |
| `Ctrl+Alt+D`                  | Pane unten teilen                           |
| `Ctrl+Alt+Shift+D`            | Pane rechts teilen                          |
| `Ctrl+Alt+h/j/k/l`            | WezTerm-Pane fokussieren                    |
| `Ctrl+Shift+P`                | nur Windows: lokale PowerShell in neuem Tab |

Die Standardkürzel `Ctrl+Shift+C` und `Ctrl+Shift+V` kopieren und fügen ein.
`Ctrl+Shift+1` bis `9` sind absichtlich deaktiviert.

## Git

### Mentales Modell

```text
Arbeitsverzeichnis --git add--> Staging Area --git commit--> lokale Historie --git push--> Remote
       ^                    git restore --staged             <--git fetch--
       +------------------------- git restore
```

Vor jeder größeren Aktion zuerst `git status`. Vor jedem Commit `git diff` und
`git diff --staged`. In diesem Setup ist `git pull` auf Fast-Forward-only gestellt:
Git erzeugt beim Pull niemals unbemerkt einen Merge-Commit.

### Alltag

| Ziel                              | Befehl                                                |
| --------------------------------- | ----------------------------------------------------- |
| Status                            | `git status --short --branch` oder `gs`               |
| Änderungen ansehen                | `git diff` oder `gd`                                  |
| Staged-Änderungen ansehen         | `git diff --staged` oder `gds`                        |
| Alles / Datei / interaktiv stagen | `git add .` / `git add DATEI` / `git add -p`          |
| Aus Staging nehmen                | `git restore --staged DATEI` oder `git unstage DATEI` |
| lokale Datei verwerfen            | `git restore DATEI` **(Änderung geht verloren)**      |
| Commit                            | `git commit -m "Nachricht"`                           |
| letzten Commit korrigieren        | `git commit --amend`                                  |
| Historie                          | `git lg`, `git last`, `git log -- DATEI`              |
| Branches                          | `git branches`                                        |
| Branch wechseln                   | `git switch NAME`                                     |
| Branch erstellen                  | `git switch -c NAME`                                  |
| Remote-Stand laden                | `git fetch --prune`                                   |
| linearen Pull ausführen           | `git pull`                                            |
| erstmals pushen                   | `git push -u origin NAME`                             |
| danach pushen                     | `git push`                                            |

### Stash: Arbeit kurz weglegen

```bash
git stash push -u -m "WIP: kurze Beschreibung"  # inkl. untracked Dateien
git stash list
git stash show -p 'stash@{0}'                    # Inhalt prüfen
git stash apply 'stash@{0}'                      # anwenden, Stash behalten
git stash pop                                    # neuesten anwenden und entfernen
git stash drop 'stash@{0}'                       # gezielt löschen
```

Ohne `-u` bleiben neue, noch nicht getrackte Dateien liegen. `apply` ist zum
Ausprobieren sicherer als `pop`, weil der Stash erhalten bleibt.

### Merge: Historie zusammenführen

Merge benutzen, wenn die tatsächliche Branch-Struktur sichtbar bleiben soll oder
der Branch mit anderen geteilt wird.

```bash
git switch main
git pull
git merge feature-name
git push
```

Bei Konflikten:

```bash
git status                         # Konfliktdateien finden
# Dateien bearbeiten, <<<<<<< / ======= / >>>>>>> auflösen
git add DATEI
git commit                         # Merge abschließen
# Alternative: git merge --abort   # vollständig abbrechen
```

### Rebase: eigene Commits auf eine neue Basis setzen

Rebase eignet sich besonders für einen eigenen, noch nicht gemeinsam bearbeiteten
Feature-Branch. Nicht die veröffentlichte gemeinsame `main`-Historie umschreiben.

```bash
git switch feature-name
git fetch origin
git rebase origin/main
```

Bei jedem Konflikt:

```bash
git status
# Konflikt lösen
git add DATEI
git rebase --continue
# Alternativen: git rebase --skip  oder  git rebase --abort
```

War der Feature-Branch schon gepusht, hat Rebase seine Commit-IDs geändert:

```bash
git push --force-with-lease
```

`--force-with-lease` schützt fremde neue Remote-Commits. Niemals gedankenlos
`git push --force` verwenden.

### Merge oder Rebase?

| Situation                                                 | Empfehlung                                    |
| --------------------------------------------------------- | --------------------------------------------- |
| geteilter Branch, Historie soll unverändert bleiben       | Merge                                         |
| eigener Feature-Branch vor dem Pull Request aktualisieren | Rebase auf `origin/main`                      |
| unsicher oder Branch wird von anderen benutzt             | Merge                                         |
| Konfliktaktion abbrechen                                  | `git merge --abort` bzw. `git rebase --abort` |

## CLI-Werkzeuge

### Finden, Lesen und Verarbeiten

| Werkzeug    | Häufige Befehle                                                       |
| ----------- | --------------------------------------------------------------------- |
| ripgrep     | `rg 'TEXT'`, `rg -n 'TEXT' PFAD`, `rg -g '*.ts' 'TEXT'`, `rg --files` |
| fd          | `fd NAME`, `fd -e py`, `fd -H NAME` (inkl. hidden), `fd -t d NAME`    |
| fzf         | `BEFEHL \| fzf`; interaktive Auswahl aus einer Liste                  |
| bat         | `bat DATEI`, `bat -n DATEI`, `bat -p DATEI`                           |
| jq          | `jq . DATEI.json`, `BEFEHL \| jq '.feld'`                             |
| tree        | `tree -a -L 2`, `tree -d`                                             |
| btop / htop | interaktive Prozess- und Systemübersicht; `q` beendet                 |

Nützliche Kombinationen:

```bash
rg -l 'TODO' | fzf
fd -e json -x jq empty
git log --oneline | fzf
```

### Verzeichnisse und Umgebungen

| Werkzeug | Häufige Befehle                                                     |
| -------- | ------------------------------------------------------------------- |
| zoxide   | `z NAME`, `z teil/pfad`, `zi`                                       |
| direnv   | `.envrc` anlegen, dann `direnv allow`; mit `direnv deny` sperren    |
| starship | rendert automatisch den Prompt; `starship explain` erklärt ihn      |
| mise     | `mise use java@21`, `mise ls`, `mise exec java@21 -- java -version` |
| fnm      | `fnm install 24`, `fnm use 24`, `fnm list`, `fnm default 24`        |

Node wird von fnm, Python von uv und optionale Java-Versionen werden von mise
verwaltet. Node/Python deshalb nicht zusätzlich über mise aktivieren.

### Projekte und Runtimes

| Bereich    | Häufige Befehle                                                                            |
| ---------- | ------------------------------------------------------------------------------------------ |
| Node/npm   | `npm install`, `npm run`, `npm test`, `npm run build`, `npm start`                         |
| uv/Python  | `uv init`, `uv add PAKET`, `uv sync`, `uv run pytest`, `uv run python DATEI.py`            |
| Django     | `uv run python manage.py runserver`, `uv run python manage.py migrate`                     |
| .NET       | `dotnet build`, `dotnet test`, `dotnet run`, `dotnet watch run`                            |
| Podman     | `podman ps`, `podman images`, `podman run ...`, `podman compose up`, `podman compose down` |
| GitHub CLI | `gh auth status`, `gh repo view`, `gh pr create`, `gh pr view --web`, `gh pr checks`       |

Podman läuft rootless: Container nicht mit `sudo` starten.

## Windows: GlazeWM und Flow Launcher

Alle GlazeWM-Kürzel verwenden ausdrücklich das **linke** `Alt`; `AltGr` bleibt frei.

| Kürzel                              | Aktion                                               |
| ----------------------------------- | ---------------------------------------------------- |
| `Alt+1` … `9`                       | Workspace wechseln                                   |
| `Alt+Shift+1` … `9`                 | Fenster auf Workspace verschieben                    |
| `Alt+h/j/k/l` oder `Alt+Pfeile`     | Fokus bewegen                                        |
| zusätzlich `Shift`                  | Fenster in diese Richtung verschieben                |
| `Alt+Enter`                         | WezTerm öffnen                                       |
| `Alt+Space`                         | Flow Launcher öffnen                                 |
| `Alt+Q`                             | Fenster regulär schließen                            |
| `Alt+R`, dann `h/j/k/l` oder Pfeile | Resize Mode; `Esc`, `Enter` oder `Alt+R` beendet ihn |
| `Alt+F`                             | Vollbild umschalten                                  |
| `Alt+Shift+Space`                   | Floating umschalten                                  |
| `Alt+Shift+R`                       | GlazeWM-Konfiguration neu laden                      |
| `Alt+Shift+P`                       | Tiling und globale Kürzel pausieren/fortsetzen       |

## Dotfiles warten

| Ziel                      | Befehl                                                    |
| ------------------------- | --------------------------------------------------------- |
| sichere Vorschau          | `./install.sh --dry-run`                                  |
| Vorschau mit Backups      | `./install.sh --dry-run --backup`                         |
| komplette Installation    | `./install.sh --backup`                                   |
| nur Dotfiles verlinken    | `./install.sh --only dotfiles --backup`                   |
| Extras installieren       | `./install.sh --extras java,rust,firefox,discord,spotify` |
| Prüfungen starten         | `bash scripts/check.sh`                                   |
| Secrets vor Commit prüfen | `python3 scripts/check-secrets.py --history`              |

Vor einem Dotfiles-Commit:

```bash
python3 scripts/check-secrets.py --history
git diff
git status --short
```

## Lernroutine

Nicht alles gleichzeitig lernen. Eine sinnvolle Reihenfolge:

1. Eine Woche nur `Space Space`, `Space /`, `Space e`, `Space w` und
   `Space c a/r/f` verwenden.
2. Danach Vim-Bewegungen und `Operator + Bewegung` bewusst ohne Pfeiltasten üben.
3. Dann `tp`, `Prefix -`, `Prefix \` und tmux-Pane-Navigation ergänzen.
4. Git-Commits immer mit `gs` → `gd` → `git add -p` → `gds` → `gc` vorbereiten.
5. Erst danach Merge und Rebase an einem Test-Branch üben; bei Unsicherheit mit
   `--abort` zum Ausgangspunkt zurückkehren.
