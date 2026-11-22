# Windows 11 mit Arch Linux unter WSL2

Dieses Setup richtet über `bootstrap.ps1` bzw. `windows/dot.ps1` native
Windows-Anwendungen (WezTerm, Zed, GlazeWM, Zebar, Flow Launcher, PowerShell 7,
Git, .NET SDK, Ollama und Claude Code) sowie eine Arch-Linux-WSL2-Instanz samt
Linux-Dotfiles mit einem Befehl ein. Die Windows-Taskleiste bleibt erhalten.
GlazeWM bildet mit neun Workspaces den Hyprland-Desktop unter Linux nach
(Vertrag: `manifests/keybindings.tsv`, Hyprland = GlazeWM); es ersetzt keinen
vollständigen Desktop. Außerdem werden Windows-Dark-Mode, das Flow-Theme und die
Agent-Konfigurationen für Claude Code und Pi nativ unter Windows eingerichtet.

Für die Einrichtung ohne Setup- und Startskripte gibt es die separate
[Anleitung zur manuellen Installation](MANUAL.md).

## Voraussetzungen und Installation

Windows 11, Winget (App Installer) und Internetzugang müssen vorhanden sein.
Als normaler Windows-Benutzer ausführen; einzelne Winget-Pakete oder `wsl --install`
können ihre eigene UAC-Abfrage anzeigen. Falls bereits eine WSL-Distribution
eingerichtet ist, muss Windows-Interop in WSL aktiv sein.

In Windows PowerShell 5.1 oder PowerShell 7, ohne vorheriges Klonen:

```powershell
irm https://raw.githubusercontent.com/AdrianMeDev/dotfiles/main/bootstrap.ps1 | iex
```

Der Bootstrap installiert Git bei Bedarf über Winget, klont per HTTPS nach
`$env:USERPROFILE\dotfiles` und startet `windows/dot.ps1 install`.
Ein vorhandener Klon wird ohne Pull wiederverwendet; ein anderes, nicht leeres
Zielverzeichnis wird abgelehnt. Anschließend liegen die Skripte im Klon.
Für eine Vorschau ohne Klon oder Installation lässt sich der geladene Code mit
Parametern ausführen (der Skriptdownload selbst benötigt Internet):

```powershell
& ([scriptblock]::Create((irm https://raw.githubusercontent.com/AdrianMeDev/dotfiles/main/bootstrap.ps1))) -DryRun
```

Ohne vorhandenen Klon zeigt diese Vorschau nur Git-/Klon-Schritte. Den vollständigen
Installationsplan nach dem Klonen prüfen; lokale Aufrufe aus dem Repository:

```powershell
cd "$env:USERPROFILE\dotfiles"
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\bootstrap.ps1 -DryRun
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\bootstrap.ps1
```

Mit `windows/dot.ps1` stehen dieselben Verben wie unter Linux zur Verfügung (`install`, `update`, `doctor`):

```powershell
pwsh -NoProfile -File .\windows\dot.ps1 install -DryRun
pwsh -NoProfile -File .\windows\dot.ps1 install -Backup
pwsh -NoProfile -File .\windows\dot.ps1 update
pwsh -NoProfile -File .\windows\dot.ps1 doctor
```

Aus einer bestehenden WSL-Distribution (auch aus einem Repository-Pfad mit Leerzeichen):

```bash
bash windows/install.sh -DryRun
bash windows/install.sh -Backup -Distro archlinux
```

Die Weiterleitung verwendet `wslpath` und `-File`, auch für `\\wsl.localhost\…`-
UNC-Pfade. Kein Laufwerkswechsel über `cmd.exe` ist erforderlich.

| Option | Wirkung |
| --- | --- |
| `-DryRun` | Voraussetzungen, WSL2 und Konfigurationskonflikte prüfen; Dateiplan und Pakete anzeigen. Keine Downloads, Dateien, Registry-Änderungen oder Paketinstallationen. |
| `-Backup` | Abweichende Dateien vor dem Ersetzen unmittelbar daneben sichern. |
| `-Extra vs` | Optionale Zusatzpakete installieren (z. B. Visual Studio Community). |
| `-Distro 'Name'` | Exakten registrierten WSL-Namen wählen, etwa aus `wsl.exe --list --verbose`. Standardmäßig wird `archlinux` verwendet (bzw. installiert, falls noch nicht vorhanden). |
| `-WslUser 'Name'` | Linux-Benutzernamen für die neue Arch-WSL2-Instanz festlegen (Standard: aktueller Windows-Benutzername in Kleinbuchstaben; `root` ist unzulässig). |
| `-NoWsl` | WSL2-Einrichtung (`wsl --install archlinux`, `windows/wsl-bootstrap.sh`, `.wslconfig`) sowie WSL-Updates/-Prüfungen in `dot.ps1 update`/`doctor` überspringen. |
| `-NoAutostart` | Keinen GlazeWM-Autostarteintrag anlegen oder aktualisieren und Flow-Autostart nicht aktivieren. Ein bereits bestehender Eintrag bleibt bestehen; Entfernen siehe unten. |

Ohne `-NoWsl` installiert `bootstrap.ps1` bzw. `dot.ps1 install` bei fehlender
Distribution automatisch `wsl --install archlinux`, richtet über
`windows/wsl-bootstrap.sh` als `root` den Benutzer (`wheel`, `NOPASSWD`-sudo, `zsh`),
`/etc/wsl.conf` (`[user] default=<WslUser>`) und den Linux-seitigen Klon unter
`~/dotfiles` ein, startet die Instanz neu (`wsl --terminate`) und führt darin
`./install.sh --profile headless` aus. Ein bestehender Klon bzw. eine bereits
eingerichtete Instanz bleibt idempotent erhalten; abweichende `/etc/sudoers.d/10-wheel`
oder `/etc/wsl.conf` werden nur mit `-Backup` ersetzt.

Ein Dateikonflikt stoppt auch die Vorschau; zum Anzeigen geplanter Ersetzungen
`-DryRun -Backup` verwenden. Identische Dateien werden übersprungen. Verzeichnisse
an Dateizielen und Verknüpfungen in Zielpfaden werden abgelehnt. Die echte Installation
lädt die Font-Archive in ein temporäres Verzeichnis und prüft zusätzlich Font-Dateien
und Registry-Einträge, bevor sie Pakete oder Konfigurationen ändert. Die Vorschau
kann diese heruntergeladenen Font-Inhalte noch nicht vergleichen.

**Tastaturlayout (manuell):** Der Corne und die Umlaut-Ebene (`RAlt+A/S/O/U`) setzen das
EurKEY-Layout voraus. Unter Windows wird es nicht automatisiert; Installer von
<https://eurkey.steffen.bruentjen.eu> herunterladen und EurKEY als Eingabemethode wählen.

Nach erfolgreicher Installation ab- und anmelden: Dadurch werden Fonts und der
aktualisierte PATH aktiv und GlazeWM startet. Für einen manuellen Start in einer
neuen PowerShell:

```powershell
& "$env:USERPROFILE\.glzr\glazewm\start-glazewm.ps1"
```

## Ablage und Verhalten

Alle Laufzeitdateien werden kopiert und benötigen danach weder das Repository
noch eine laufende WSL. Lediglich Arch-WSL-Terminals und Entwicklungsprojekte benötigen WSL.
Die Leiste lädt beim ersten Start den fest versionierten Zebar-JavaScript-Client
von `esm.sh`; Zebar cached externe Ressourcen. Ein vollständig netzloser Erststart
ist daher nicht vorgesehen.

| Ziel | Inhalt |
| --- | --- |
| `%USERPROFILE%\.wezterm.lua` | Einstiegspunkt, berücksichtigt die höhere Priorität dieser Datei |
| `%USERPROFILE%\.config\wezterm\` | Kopierte gemeinsame Basis, Windows-Anpassung und `WSL:archlinux` (bzw. gewählte Distribution) als Standard-Domain |
| `%USERPROFILE%\.wslconfig` | Setzt `networkingMode=mirrored` unter `[wsl2]`, damit WSL2 lokal unter Windows laufendes Ollama (`127.0.0.1:11434`) erreicht |
| `%APPDATA%\Zed\` | Aus `zed-config/.config/zed/`: Theme, Vim-Keymap, Editor-Einstellungen, Tasks, `debug.json` ohne erzwungenes `zsh` sowie vorregistrierte `wsl_connections` für Remote-WSL |
| `%USERPROFILE%\.glzr\glazewm\` | Tiling-Konfiguration und Startskripte |
| `%USERPROFILE%\.glzr\zebar\` | Zebar-Einstellungen und eigenes `dotfiles`-Widget-Paket |
| `%LOCALAPPDATA%\Microsoft\Windows\Fonts\` | Benutzer-Fonts; Registrierung unter `HKCU\Software\Microsoft\Windows NT\CurrentVersion\Fonts` |
| `%APPDATA%\FlowLauncher\Themes\TokyoNight.xaml` | Flow-Theme Tokyo Night aus `windows/flow/TokyoNight.xaml`; in `Settings.json` als `Theme` gesetzt |
| `%USERPROFILE%\.claude\` und `%USERPROFILE%\.pi\agent\` | Native Agent-Konfiguration aus `agent-config/` (Claude Code bzw. Pi; Skills, Templates, Claude-Frontmatter). Überschreibbar über `CLAUDE_CONFIG_DIR` und `PI_CODING_AGENT_DIR` |
| `HKCU\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize` | Windows Dark Mode: `AppsUseLightTheme` und `SystemUsesLightTheme` = 0 (ohne Administratorrechte; bei abweichenden Werten sichert `-Backup` den Schlüssel als `.reg` unter `%LOCALAPPDATA%\dotfiles\backup`) |
| `%LOCALAPPDATA%\Vial\` | Portables Vial-Release (`Vial.exe`, `.version`-Marker) plus Startmenü-Verknüpfung `Vial.lnk` |
| Windows-Autostartordner | `Dotfiles-GlazeWM.vbs`, startet GlazeWM ohne Konsolenfenster |

WezTerm verwendet Tokyo Night, die vorhandene Transparenz (unter Windows zusätzlich
`win32_system_backdrop = 'Acrylic'`), Ioskeley Mono Term Nerd Font
und die bestehenden Tastenkürzel. Zed nutzt Tokyo Night und die normale Ioskeley-Mono-Familie.
Zeds Fenster erhält einen Tokyo-Night-Hintergrund mit 75 % Deckkraft; Editor, Terminal,
Agent-, Git- und Projekt-Panel bleiben darüber transparent. Edit Predictions nutzen
lokal Ollama mit `qwen2.5-coder:7b-base`. Das Modell muss in Ollama vorhanden sein
(`ollama pull qwen2.5-coder:7b-base`); automatische Vorschläge sind aktiviert.
Durch `networkingMode=mirrored` in `.wslconfig` ist Windows-Ollama auch aus Arch WSL2 heraus erreichbar.
Die [WSL-Domain](https://wezterm.org/config/lua/WslDomain.html) (`WSL:archlinux`) startet Arch Linux
mit `zsh` als Standard-Shell. `Ctrl+T` öffnet Tabs in der aktuellen Domain;
in Arch bleiben sie Arch-Tabs. `Ctrl+Shift+P` öffnet lokale PowerShell 7.
`Ctrl+1–9` wechselt Tabs; `Ctrl+Shift+O` öffnet den Launcher mit PowerShell-Eintrag.

GlazeWM startet Zebar über einen einmaligen Startup-Hook mit Prozessprüfung und
Mutex. Ein Reload startet keine zweite Leiste. Zusätzliche manuell eingerichtete
Autostarts für GlazeWM/Zebar sollten deaktiviert werden. GlazeWM beendet beim
Schließen keine separat gestarteten Zebar-Prozesse. Die obere Lücke reserviert
Platz für die 32 Pixel hohe Leiste; die untere Windows-Taskleiste bleibt nutzbar.
Die Leiste erscheint auf jedem Monitor und zeigt alle neun Nummern: belegte
Workspaces hell mit Unterstrich, auf diesem Monitor angezeigte mit dunklem Hintergrund,
den fokussierten blau. Ein Klick öffnet einen neuen Workspace auf dem angeklickten
Monitor; bereits aktive Workspaces behalten ihren Monitor. Datum/Uhrzeit stehen
mittig, Netzwerk und vorhandener Akku rechts. Ohne Akku bleibt dessen Feld leer.

## Tastatur

Alle globalen Alt-Kürzel verwenden ausdrücklich **linkes Alt**. Rechtes Alt/AltGr
wird durch GlazeWM nicht belegt; es gibt keine globale Tastaturumstellung.

| Kürzel | Aktion |
| --- | --- |
| `Alt+1–9` | Workspace wechseln |
| `Alt+Shift+1–9` | Fenster auf Workspace verschieben |
| `Alt+Pfeile` oder `Alt+H/J/K/L` | Fokus links/unten/oben/rechts |
| zusätzlich `Shift` | Fenster in diese Richtung verschieben |
| `Alt+Enter` | WezTerm öffnen |
| `Alt+Leertaste` | Flow Launcher öffnen (Apps, Dateien, Befehle) |
| `Alt+Q` | Fokussiertes Fenster regulär schließen (ggf. mit Speichern-Abfrage) |
| `Alt+R`, danach Pfeile oder `H/J/K/L` | Größe ändern; `Esc`, `Enter` oder `Alt+R` beendet den Modus |
| `Alt+F` | Vollbild umschalten |
| `Alt+Shift+Space` | Schwebendes Fenster umschalten |
| `Alt+Shift+R` | GlazeWM-Konfiguration neu laden |
| `Alt+Shift+P` | Tiling und Kürzel pausieren/fortsetzen |
| `Win+L` | Bildschirm sperren (Windows) |
| `Win+V` | Zwischenablage-Verlauf (Windows) |
| `Win+Shift+S` | Screenshot-Ausschnitt (Windows) |

Die Bindings stammen aus `manifests/keybindings.tsv` (Hyprland = GlazeWM, per Test
geprüft). Drei Aktionen gehören unter Windows dem System und werden nicht von GlazeWM
belegt: `Win+L` (Sperren; unter Linux `Alt+Shift+X`), `Win+V` (Zwischenablage-Verlauf)
und `Win+Shift+S` (Screenshot). Flow Launcher besitzt `Alt+Leertaste`.

Standard-Windows-Dialoge (`#32770`) schweben. Anwendungsspezifische Dialoge können
bei Bedarf über weitere `window_rules` ergänzt werden. Workspaces haben keine
feste Monitorzuordnung. Näheres in der [GlazeWM-Konfiguration](https://github.com/glzr-io/glazewm#config-workspaces).

## Flow Launcher

[Flow Launcher](https://www.flowlauncher.com/) wird über Winget als
`Flow-Launcher.Flow-Launcher` installiert. Nach dem Setup einmal **Flow Launcher**
im Windows-Startmenü öffnen. `Alt+Leertaste` öffnet danach die Suche; zum Beispiel
`wezterm` oder `zed` eingeben und mit `Enter` starten.

Der Installer kopiert `TokyoNight.xaml` nach `%APPDATA%\FlowLauncher\Themes\` und setzt in
`%APPDATA%\FlowLauncher\Settings\Settings.json` das Theme `TokyoNight`, den Hotkey
auf `Alt + Space`, aktiviert den Windows-Autostart und blendet das Suchfenster beim
Start aus. Flow selbst richtet den Autostart beim nächsten Start ein. Mit
`-NoAutostart` bleibt die vorhandene Flow-Autostarteinstellung erhalten; bei einer
Neuinstallation gilt Flows Standard (aus). Den Flow-Autostart bei Bedarf direkt in
Flows Einstellungen abschalten. Es wird kein zusätzlicher Startup-Hook angelegt.

Andere Flow-Einstellungen und Plugins bleiben erhalten. Abweichende verwaltete
Werte erfordern wie andere Dateikonflikte `-Backup`. Vor einer Aktualisierung Flow
über sein Tray-Menü beenden, damit es die Änderungen nicht überschreibt. Die
Integration verwendet die reguläre Winget-Installation, keine portable Instanz.

GlazeWM ignoriert Flow-Fenster, damit die Suche frei über den Anwendungen erscheint.
Nach der Aktualisierung `Alt+Shift+R` drücken. `Alt+Shift+Leertaste` bleibt das
GlazeWM-Kürzel für schwebende Fenster. Falls PowerToys Run, Command Palette oder
Raycast laufen, dort `Alt+Leertaste` freigeben.

## Zed-Projekte in Arch (WSL2)

Lokale Windows-Terminals verwenden `pwsh.exe`. Für Entwicklungsprojekte in Arch WSL2
ist die Distribution in Zeds `settings.json` über `wsl_connections` bereits vorregistriert;
in Zeds Command Palette **`projects: open wsl`** wählen und den Projektordner in Arch
öffnen. Für einen Windows-Ordner, der über WSL bearbeitet werden soll, gibt es
**`projects: open folder in wsl`**.
So laufen Terminal, Tasks und Sprachserver in Arch Linux; ein als lokaler UNC-Ordner
geöffnetes Projekt bietet diese Trennung nicht automatisch.
Siehe [Zed unter Windows](https://zed.dev/docs/windows) und
[WSL und Remote-Einstellungen](https://zed.dev/docs/remote-development#wsl-support).

Auf Arch WSL2 richtet `bootstrap.ps1` bzw. `dot.ps1 install` das bestehende Setup
automatisch ein (`install.sh --profile headless`). Dort liegen Linux-Shell- und
Task-Einstellungen unter `~/.config/zed/`; Zed unterscheidet lokale UI- von
Server-Einstellungen. Zum Funktionstest im WSL-Projektterminal `uname -a` und
`pwd` ausführen und einen passenden Projekt-Task starten, etwa `Node: test`.
Die dafür benötigten Sprachwerkzeuge werden über `mise` bzw. Arch-Pakete in WSL bereitgestellt.

## Aktualisieren, Wiederherstellen, Autostart abschalten

Nach Repository-Änderungen oder für regelmäßige Updates zuerst Vorschau, dann Aktualisierung ausführen:

```powershell
pwsh -NoProfile -File .\windows\dot.ps1 update -DryRun
pwsh -NoProfile -File .\windows\dot.ps1 update -Backup
pwsh -NoProfile -File .\windows\dot.ps1 doctor
```

`dot.ps1 update` aktualisiert die Windows-Pakete (`winget`), ein installiertes portables **Vial**
(`%LOCALAPPDATA%\Vial`, nur bei neuerer Release-Version), übernimmt geänderte
Konfigurationen und ruft anschließend in Arch WSL2 automatisch `dot update` auf
(mit `-NoWsl` wird der WSL-Teil übersprungen). `dot.ps1 doctor` prüft analog
Windows-Werkzeuge, Vial (`.version` und `Vial.exe`), Konfigurationen sowie `dot doctor` in WSL.
Für den Corne und das Layout `corne_v4.vil` siehe [`docs/CORNE.md`](../docs/CORNE.md). Eigene Änderungen
an kopierten Dateien erzeugen beim nächsten Lauf einen Konflikt und werden mit
`-Backup` gesichert. Winget prüft jedes Paket mit `list --id <Paket-ID> --exact --source winget`
und überspringt vorhandene Pakete. Nur bei „keine Anwendung gefunden“ wird mit
`--no-upgrade` installiert. Bereits-installiert-/Kein-Update-Rückgabecodes werden
durch eine erneute Bestandsprüfung bestätigt. Vorhandene Pakete bleiben
installiert; Programmupdates gezielt über `winget upgrade --id <Paket-ID> --exact`
ausführen. Ein Fehler stoppt den Installer mit Exitcode 1; bereits installierte
Pakete werden nicht zurückgerollt. Danach Ursache beheben und erneut ausführen.

Danach mit `Alt+Shift+R` die GlazeWM-Konfiguration neu laden. Zebar über sein
Tray-Menü vollständig beenden und anschließend erneut starten:

```powershell
& "$env:USERPROFILE\.glzr\glazewm\start-zebar.ps1"
```

Erst der vollständige Zebar-Neustart übernimmt die `includeFiles`-Freigaben für
`index.html`, `style.css` und `bar.mjs`; ein GlazeWM-Reload allein genügt nicht.

Backups heißen `<Datei>.backup-<UTC-Zeit>-<ID>`. Anwendungen schließen, passendes
Backup wählen und zurückkopieren, zum Beispiel:

```powershell
Get-ChildItem "$env:USERPROFILE\.glzr\glazewm\config.yaml.backup-*"
Copy-Item -LiteralPath 'C:\Users\NAME\.glzr\glazewm\config.yaml.backup-ZEIT-ID' `
  -Destination "$env:USERPROFILE\.glzr\glazewm\config.yaml" -Force
```

Fonts werden ausschließlich für den aktuellen Benutzer unter HKCU registriert;
dafür sind weder HKLM noch Administratorrechte nötig. Fehlende Schlüssel und Werte
werden angelegt, identische Werte übersprungen und fremde Einträge erhalten.
Zugriffsfehler stoppen die Installation.

Bei abweichenden Font-Registry-Werten sichert `-Backup` den Fonts-Schlüssel als
`Fonts.backup-<ID>.reg` im Font-Verzeichnis. Bei einer Wiederherstellung zuerst die
Font-Dateien zurückkopieren und die geprüfte `.reg`-Datei mit `reg.exe import <Pfad>`
importieren. Sie enthält den gesamten damaligen Benutzer-Fonts-Schlüssel; Import
führt Werte zusammen und entfernt keine später hinzugekommenen Werte. Neu angelegte
Dateien haben kein Backup. Nach Font-Änderungen ab-/anmelden.

Autostart deaktivieren:

```powershell
Remove-Item -LiteralPath "$env:APPDATA\Microsoft\Windows\Start Menu\Programs\Startup\Dotfiles-GlazeWM.vbs"
```

Danach zukünftige Installer-Läufe mit `-NoAutostart` ausführen. Laufendes GlazeWM
und Zebar über ihre Tray-Menüs beenden. Die Programme und Konfigurationen bleiben
installiert. Erneutes Installieren ohne `-NoAutostart` aktiviert den Eintrag wieder.

## Prüfungen

```bash
bash scripts/check.sh
```

```powershell
powershell.exe -NoProfile -File .\windows\check.ps1
pwsh -NoProfile -File .\windows\check.ps1
```

`windows/check.ps1` prüft die Syntax und führt die Pester-5-Tests aus
`windows/tests/` aus (`Invoke-Pester -CI`; Pester >= 5.0 muss installiert sein, sonst
bricht das Skript ab). Sie verwenden temporäre Profile und
simulieren Winget, WSL, Font-Download und Registry. Geprüft werden Vorschau ohne
Dateischreibzugriffe/Paketaufrufe, Wiederholung, Backups, frühe Konfliktabbrüche,
fehlende Voraussetzungen, WSL1, mehrdeutige Namen, Leerzeichen und externe Exitcodes.
Python testet die WSL-Argumentweitergabe einschließlich UNC-Pfaden und Exitcodes.
Ein Lua-Verhaltenstest mit Neovim prüft WSL- und PowerShell-Domain sowie Tab-Kürzel.

**Unter Linux nicht ausführbar und noch auf einer frischen Win11-VM zu prüfen:**

- Ein-Befehl-Setup über `bootstrap.ps1` (unter PowerShell 5.1 und 7) sowie Aufruf aus
  WSL (`windows/install.sh`), jeweils auch aus einem Pfad mit Leerzeichen/UNC-Pfad.
- `wsl --install archlinux`, Benutzeranlage (`-WslUser`), `windows/wsl-bootstrap.sh`,
  `.wslconfig` (`networkingMode=mirrored`) sowie Überspringen mit `-NoWsl`.
- Reale Winget-Installation, Font-Anzeige und Registry-Registrierung.
- Flow Launcher: erster Start, Alt+Leertaste, Autostart nach Anmeldung und frei
  schwebende Suche unter GlazeWM.
- WezTerm öffnet `zsh` in Arch (`WSL:archlinux`); neue Tabs bleiben in Arch;
  `Ctrl+Shift+P` startet lokale PowerShell 7.
- Zed öffnet ein Arch-WSL-Projekt über Remote-WSL; Terminal, Task und Sprachserver
  laufen in Arch Linux.
- Windows Dark Mode, Flow-Theme `TokyoNight`, WezTerm-Acrylic und die nativen Agent-Konfigurationen
  (`%USERPROFILE%\.claude`, `%USERPROFILE%\.pi\agent`) sind sichtbar bzw. vorhanden.
- Claude Code läuft in WSL (`claude --version`); Ollama unter Windows ist bei Bedarf
  über `networkingMode=mirrored` aus WSL erreichbar.
- `windows/dot.ps1 update` aktualisiert sowohl Windows als auch Arch WSL2;
  `windows/dot.ps1 doctor` meldet keinen Fehler.
- Tiling, Fokusrahmen, schwebende Dialoge, AltGr und alle Kürzel.
- Klicks auf leere/belegte Workspaces; mehrere Monitore, unterschiedliche DPI,
  Monitor-Ab-/Anstecken und weiterhin nutzbare Windows-Taskleiste.
- Anmelden, erneuter Start und Reload erzeugen genau eine Leiste pro Monitor;
  Abschalten des Autostarts und Wiederherstellung eines Backups funktionieren.
- Corne anschließen, **Vial** über das Startmenü starten (`%LOCALAPPDATA%\Vial`),
  `corne_v4.vil` laden und alle Vertrags-Bindings aus [`docs/CORNE.md`](../docs/CORNE.md) testen.

Der Windows-Registry-Integrationstest verwendet ausschließlich einen zufälligen
HKCU-Testschlüssel und entfernt ihn anschließend. Er prüft fehlende Schlüssel/Werte,
Wiederholung, Sicherungsfehler, Backup-Inhalt und den Erhalt fremder Einträge.
Unter Windows beide obigen Befehle ausführen, um PowerShell 5.1 und 7 abzudecken.
Unter Linux wird dieser Integrationstest ausdrücklich übersprungen.
