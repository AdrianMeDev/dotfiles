# Windows 11 mit Fedora unter WSL2

Dieses separate Setup installiert native Windows-Anwendungen: WezTerm, Zed,
GlazeWM, Zebar, Flow Launcher und PowerShell 7 über Winget sowie Ioskeley Mono und
Ioskeley Mono Term Nerd Font v2.1.0 mit allen Schnitten. Die Windows-Taskleiste bleibt erhalten. GlazeWM nähert COSMICs
Tiling mit neun vordefinierten Workspaces an; es ersetzt keinen vollständigen Desktop.

Für die Einrichtung ohne Setup- und Startskripte gibt es die separate
[Anleitung zur manuellen Installation](MANUAL.md).

## Voraussetzungen und Installation

Windows 11, Winget (App Installer), eingerichtetes WSL2 mit Fedora und Internetzugang
müssen vorhanden sein. Als normaler Windows-Benutzer ausführen; einzelne
Winget-Pakete können ihre eigene UAC-Abfrage anzeigen. In WSL muss Windows-Interop
aktiv sein. Der Fedora-Installer im Repository bleibt ein eigener Schritt.

In Windows PowerShell 5.1 oder PowerShell 7, aus dem Repository:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\windows\install.ps1 -DryRun
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\windows\install.ps1
```

Aus Fedora-WSL, auch aus einem Repository-Pfad mit Leerzeichen:

```bash
bash windows/install.sh -DryRun
bash windows/install.sh -Backup -Distro 'Fedora Linux'
```

Die Weiterleitung verwendet `wslpath` und `-File`, auch für `\\wsl.localhost\…`-
UNC-Pfade. Kein Laufwerkswechsel über `cmd.exe` ist erforderlich.

| Option | Wirkung |
| --- | --- |
| `-DryRun` | Voraussetzungen, WSL2 und Konfigurationskonflikte prüfen; Dateiplan und Pakete anzeigen. Keine Downloads, Dateien, Registry-Änderungen oder Paketinstallationen. |
| `-Backup` | Abweichende Dateien vor dem Ersetzen unmittelbar daneben sichern. |
| `-Distro 'Name'` | Exakten registrierten WSL-Namen wählen, etwa aus `wsl.exe --list --verbose`. Ohne Option muss genau ein Name „Fedora“ enthalten. Umbenannte Fedora-Distributionen explizit wählen. |
| `-NoAutostart` | Keinen GlazeWM-Autostarteintrag anlegen oder aktualisieren und Flow-Autostart nicht aktivieren. Ein bereits bestehender Eintrag bleibt bestehen; Entfernen siehe unten. |

Ein Dateikonflikt stoppt auch die Vorschau; zum Anzeigen geplanter Ersetzungen
`-DryRun -Backup` verwenden. Identische Dateien werden übersprungen. Verzeichnisse
an Dateizielen und Verknüpfungen in Zielpfaden werden abgelehnt. Die echte Installation
lädt die Font-Archive in ein temporäres Verzeichnis und prüft zusätzlich Font-Dateien
und Registry-Einträge, bevor sie Pakete oder Konfigurationen ändert. Die Vorschau
kann diese heruntergeladenen Font-Inhalte noch nicht vergleichen.

Nach erfolgreicher Installation ab- und anmelden: Dadurch werden Fonts und der
aktualisierte PATH aktiv und GlazeWM startet. Für einen manuellen Start in einer
neuen PowerShell:

```powershell
& "$env:USERPROFILE\.glzr\glazewm\start-glazewm.ps1"
```

## Ablage und Verhalten

Alle Laufzeitdateien werden kopiert und benötigen danach weder das Repository
noch eine laufende WSL. Lediglich Fedora-Terminals und Entwicklungsprojekte benötigen WSL.
Die Leiste lädt beim ersten Start den fest versionierten Zebar-JavaScript-Client
von `esm.sh`; Zebar cached externe Ressourcen. Ein vollständig netzloser Erststart
ist daher nicht vorgesehen.

| Ziel | Inhalt |
| --- | --- |
| `%USERPROFILE%\.wezterm.lua` | Einstiegspunkt, berücksichtigt die höhere Priorität dieser Datei |
| `%USERPROFILE%\.config\wezterm\` | Kopierte gemeinsame Basis, Windows-Anpassung und ausgewählte Distribution |
| `%APPDATA%\Zed\` | Theme, Vim-Keymap, Editor-Einstellungen und Tasks ohne erzwungenes `zsh` |
| `%USERPROFILE%\.glzr\glazewm\` | Tiling-Konfiguration und Startskripte |
| `%USERPROFILE%\.glzr\zebar\` | Zebar-Einstellungen und eigenes `dotfiles`-Widget-Paket |
| `%LOCALAPPDATA%\Microsoft\Windows\Fonts\` | Benutzer-Fonts; Registrierung unter `HKCU\Software\Microsoft\Windows NT\CurrentVersion\Fonts` |
| Windows-Autostartordner | `Dotfiles-GlazeWM.vbs`, startet GlazeWM ohne Konsolenfenster |

WezTerm verwendet Tokyo Night, die vorhandene Transparenz, Ioskeley Mono Term Nerd Font
und die bestehenden Tastenkürzel. Zed nutzt Tokyo Night und die normale Ioskeley-Mono-Familie.
Zeds Fenster erhält einen schwarzen Hintergrund mit 50 % Deckkraft; Editor, Terminal,
Agent-, Git- und Projekt-Panel bleiben darüber transparent. Edit Predictions nutzen
lokal Ollama mit `qwen2.5-coder:7b-base`. Das Modell muss in Ollama vorhanden sein
(`ollama pull qwen2.5-coder:7b-base`); automatische Vorschläge sind aktiviert.
Die [WSL-Domain](https://wezterm.org/config/lua/WslDomain.html) startet die gewählte
Distribution mit ihrer Standard-Shell. `Ctrl+T` öffnet Tabs in der aktuellen Domain;
in Fedora bleiben sie Fedora-Tabs. `Ctrl+Shift+P` öffnet lokale PowerShell 7.
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

Standard-Windows-Dialoge (`#32770`) schweben. Anwendungsspezifische Dialoge können
bei Bedarf über weitere `window_rules` ergänzt werden. Workspaces haben keine
feste Monitorzuordnung. Näheres in der [GlazeWM-Konfiguration](https://github.com/glzr-io/glazewm#config-workspaces).

## Flow Launcher

[Flow Launcher](https://www.flowlauncher.com/) wird über Winget als
`Flow-Launcher.Flow-Launcher` installiert. Nach dem Setup einmal **Flow Launcher**
im Windows-Startmenü öffnen. `Alt+Leertaste` öffnet danach die Suche; zum Beispiel
`wezterm` oder `zed` eingeben und mit `Enter` starten.

Der Installer setzt in `%APPDATA%\FlowLauncher\Settings\Settings.json` den Hotkey
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

## Zed-Projekte in Fedora

Lokale Windows-Terminals verwenden `pwsh.exe`. Für Entwicklungsprojekte in Fedora
in Zeds Command Palette **`projects: open wsl`** wählen, Distribution hinzufügen
und den Projektordner in Fedora öffnen. Für einen Windows-Ordner, der über WSL
bearbeitet werden soll, gibt es **`projects: open folder in wsl`**.
So laufen Terminal, Tasks und Sprachserver in Fedora; ein als lokaler UNC-Ordner
geöffnetes Projekt bietet diese Trennung nicht automatisch.
Siehe [Zed unter Windows](https://zed.dev/docs/windows) und
[WSL und Remote-Einstellungen](https://zed.dev/docs/remote-development#wsl-support).

Auf Fedora weiterhin das bestehende Setup installieren. Dort liegen Linux-Shell-
und Task-Einstellungen unter `~/.config/zed/`; Zed unterscheidet lokale UI- von
Server-Einstellungen. Zum Funktionstest im WSL-Projektterminal `uname -a` und
`pwd` ausführen und einen passenden Projekt-Task starten, etwa `Node: test`.
Die dafür benötigten Sprachwerkzeuge müssen in Fedora installiert sein.

## Aktualisieren, Wiederherstellen, Autostart abschalten

Nach Repository-Änderungen zuerst `-DryRun -Backup`, dann `-Backup` ausführen.
Gemeinsame WezTerm-/Zed-Dateien werden dabei erneut übernommen. Eigene Änderungen
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

Die PowerShell-Tests brauchen kein Pester. Sie verwenden temporäre Profile und
simulieren Winget, WSL, Font-Download und Registry. Geprüft werden Vorschau ohne
Dateischreibzugriffe/Paketaufrufe, Wiederholung, Backups, frühe Konfliktabbrüche,
fehlende Voraussetzungen, WSL1, mehrdeutige Namen, Leerzeichen und externe Exitcodes.
Python testet die WSL-Argumentweitergabe einschließlich UNC-Pfaden und Exitcodes.
Ein Lua-Verhaltenstest mit Neovim prüft WSL- und PowerShell-Domain sowie Tab-Kürzel.

**Unter Fedora nicht ausführbar und noch unter Windows zu prüfen:**

- Direkte Installation unter Windows PowerShell 5.1 und Aufruf aus echter WSL,
  jeweils auch aus einem Repository mit Leerzeichen/UNC-Pfad.
- Reale Winget-Installation, Font-Anzeige und Registry-Registrierung.
- Flow Launcher: erster Start, Alt+Leertaste, Autostart nach Anmeldung und frei
  schwebende Suche unter GlazeWM.
- WezTerm startet Fedora; neue Tabs bleiben dort; PowerShell-Kürzel startet lokal.
- Zed öffnet ein WSL-Projekt; Terminal, Task und Sprachserver laufen in Fedora.
- Tiling, Fokusrahmen, schwebende Dialoge, AltGr und alle Kürzel.
- Klicks auf leere/belegte Workspaces; mehrere Monitore, unterschiedliche DPI,
  Monitor-Ab-/Anstecken und weiterhin nutzbare Windows-Taskleiste.
- Anmelden, erneuter Start und Reload erzeugen genau eine Leiste pro Monitor;
  Abschalten des Autostarts und Wiederherstellung eines Backups funktionieren.

Der Windows-Registry-Integrationstest verwendet ausschließlich einen zufälligen
HKCU-Testschlüssel und entfernt ihn anschließend. Er prüft fehlende Schlüssel/Werte,
Wiederholung, Sicherungsfehler, Backup-Inhalt und den Erhalt fremder Einträge.
Unter Windows beide obigen Befehle ausführen, um PowerShell 5.1 und 7 abzudecken.
Unter Linux wird dieser Integrationstest ausdrücklich übersprungen.

Prüfstand dieser Änderung: Fünf portable Windows-Tests bestanden; der PowerShell-Test
wurde mangels `pwsh` übersprungen. ShellCheck, Bash-/Zsh-/JavaScript-Syntax,
strukturierte Konfigurationen und Secret-Scan bestanden. LuaJIT fehlt.
Im Gesamtlauf bleiben zwei bestehende Zsh-Fehler durch fehlende Programme im
reduzierten Test-PATH. tmux besteht außerhalb der Socket-Sandbox, WezTerm mit
direktem AppRun-Pfad. PowerShell-Parser, PowerShell-Verhaltenstests sowie die
Windows-Registry-Integration unter PowerShell 5.1 und 7 sind noch auszuführen.
