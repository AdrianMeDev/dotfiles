# Windows-Setup manuell einrichten

Diese Anleitung richtet WezTerm, Zed, GlazeWM, Zebar, Flow Launcher und die
Schriftarten für Windows 11 mit Fedora unter WSL2 ein. Du installierst Programme
über ihre Installer, kopierst Konfigurationsdateien im Explorer und bearbeitest
sie im Texteditor. Die Setup- und Startskripte dieses Repositorys werden nicht
benötigt. Einzelne unten genannte Befehle werden direkt eingegeben; Lua-, JSON-
und YAML-Blöcke sind Inhalte von Konfigurationsdateien.

## 1. Vorbereitung und Sicherung

1. Das Repository lokal bereitstellen, zum Beispiel auf GitHub über **Code →
   Download ZIP** herunterladen und im Explorer vollständig entpacken.
2. Im Explorer **Anzeigen → Einblenden → Dateinamenerweiterungen** aktivieren.
   Neue Dateien dürfen nicht versehentlich `config.yaml.txt` oder `distro.lua.txt`
   heißen. Textdateien als UTF-8 speichern.
3. Vorhandene Konfigurationen aus den unten genannten Zielordnern in einen
   separaten Sicherungsordner kopieren. Bereits eingerichtete Programme vor dem
   Ersetzen ihrer Konfiguration vollständig beenden, auch über das Tray-Menü.
4. Pfade wie `%APPDATA%` direkt in die Explorer-Adresszeile eingeben. Fehlende
   Unterordner mit **Neu → Ordner** anlegen. Alle Quellpfade in dieser Anleitung
   beziehen sich auf den entpackten Repository-Ordner.

Das Desktop-Setup wird als normaler Windows-Benutzer eingerichtet. Nur die
Aktivierung von WSL oder einzelne Programm-Installer können Administratorrechte
anfordern.

## 2. Fedora unter WSL2 vorbereiten

Wenn Fedora bereits funktioniert, in Windows Terminal eingeben:

```text
wsl --list --verbose
```

Den exakten Fedora-Namen notieren, einschließlich Leerzeichen. In der Spalte
`VERSION` muss `2` stehen.

Falls WSL noch fehlt, Windows Terminal als Administrator öffnen, folgenden
Befehl einzeln ausführen und anschließend bei Aufforderung neu starten:

```text
wsl --install --no-distribution
```

Danach die verfügbaren Distributionen anzeigen:

```text
wsl --list --online
```

Fedora mit dem exakt dort angezeigten Namen installieren:

```text
wsl --install -d <Name-aus-der-Liste>
```

`<Name-aus-der-Liste>` einschließlich der Winkelklammern ersetzen. Fedora einmal
über das Startmenü öffnen und die Ersteinrichtung abschließen. Eine bestehende
WSL1-Installation lässt sich nach Sicherung ihrer Daten mit
`wsl --set-version "DEIN-FEDORA-NAME" 2` umstellen.
Die [Microsoft-Anleitung zu WSL](https://learn.microsoft.com/en-us/windows/wsl/install)
erläutert Voraussetzungen und Installation.

Die Linux-Entwicklungswerkzeuge und die gewünschte Standard-Shell werden innerhalb
von Fedora eingerichtet. Dieses Dokument behandelt das Windows-Desktop-Setup;
Node, Python, .NET und Projektabhängigkeiten sind davon getrennt.

## 3. Windows-Programme installieren

Die passenden Windows-Installer von den offiziellen Projektseiten herunterladen
und einzeln ausführen. Bereits vorhandene Programme müssen nicht erneut installiert
werden. Wenn angeboten, die Aufnahme in `PATH` aktivieren.

| Programm | Offizieller Download | Zweck |
| --- | --- | --- |
| WezTerm | [Windows-Installation](https://wezterm.org/install/windows.html) | Terminal für Fedora und lokale PowerShell |
| Zed | [Download](https://zed.dev/download) | Editor mit WSL-Unterstützung |
| GlazeWM | [Releases](https://github.com/glzr-io/glazewm/releases) | Tiling und Workspaces |
| Zebar | [Releases](https://github.com/glzr-io/zebar/releases) | Statusleiste |
| PowerShell 7 | [Windows-Installation](https://learn.microsoft.com/en-us/powershell/scripting/install/installing-powershell-on-windows) | Lokale Shell, ausführbar als `pwsh.exe` |
| Flow Launcher | [Download](https://www.flowlauncher.com/) | Suche mit `Alt+Leertaste` |

Der GlazeWM-Installer kann Zebar optional mitinstallieren. Wenn du das wählst,
ist kein zweiter Zebar-Installer nötig. Siehe die
[GlazeWM-Installationshinweise](https://github.com/glzr-io/glazewm#installation).
Für Flow den normalen Installer verwenden, keine portable Version.

GlazeWM und Zebar nach einer eventuellen automatischen Erstöffnung wieder über
ihre Tray-Menüs beenden. Deren Autostart erst in Schritt 9 einrichten.
Windows PowerShell 5.1 ersetzt PowerShell 7 nicht; beide dürfen parallel installiert
sein. Nach der Programminstallation ab- und anmelden, damit neue PATH-Einträge
auch im Desktop verfügbar sind.

## 4. JetBrains Mono Nerd Font installieren

1. [JetBrainsMono.zip aus Nerd Fonts v3.4.0](https://github.com/ryanoasis/nerd-fonts/releases/download/v3.4.0/JetBrainsMono.zip)
   herunterladen und entpacken.
2. Diese vier Dateien auswählen:
   - `JetBrainsMonoNerdFont-Regular.ttf`
   - `JetBrainsMonoNerdFont-Bold.ttf`
   - `JetBrainsMonoNerdFont-Italic.ttf`
   - `JetBrainsMonoNerdFont-BoldItalic.ttf`
3. Per Rechtsklick, gegebenenfalls **Weitere Optionen anzeigen**, **Installieren**
   wählen. Für die Installation nur für dich nicht **Für alle Benutzer installieren**
   verwenden. Alternativ jede Datei öffnen und in der Schriftvorschau installieren.
4. Unter **Einstellungen → Personalisierung → Schriftarten** nach
   `JetBrainsMono Nerd Font` suchen. Sind die Fonts bereits vorhanden, die
   Installation überspringen; eine vorhandene andere Version nur bewusst ersetzen.

Windows übernimmt Kopieren und Registrierung der Fonts. Keine Registry-Werte
von Hand anlegen und keinen Fonts-Schlüssel ersetzen. Falls eine Anwendung die
Schrift noch nicht erkennt, sie neu starten oder ab- und anmelden.

## 5. WezTerm konfigurieren

Den Ordner `%USERPROFILE%\.config\wezterm` anlegen und diese Dateien kopieren:

| Quelle im Repository | Ziel |
| --- | --- |
| `wezterm/.config/wezterm/wezterm.lua` | `%USERPROFILE%\.config\wezterm\base.lua` |
| `windows/wezterm/wezterm.lua` | `%USERPROFILE%\.config\wezterm\wezterm.lua` |

Im Zielordner zusätzlich `distro.lua` anlegen. Als Inhalt den in Schritt 2
ermittelten Namen einsetzen, zum Beispiel:

```lua
return "Fedora Linux"
```

Unter `%USERPROFILE%` die Datei `.wezterm.lua` anlegen. Eine vorhandene Datei
zuerst sichern, da WezTerm diesen Einstiegspunkt bevorzugt:

```lua
return dofile(require('wezterm').home_dir .. '/.config/wezterm/wezterm.lua')
```

WezTerm starten. Das erste Terminal soll in Fedora laufen. `Ctrl+T` öffnet einen
weiteren Tab in derselben Domain, `Ctrl+Shift+P` eine lokale PowerShell 7 und
`Ctrl+Shift+O` den WezTerm-Launcher. Die Fedora-Standard-Shell muss in Fedora selbst
konfiguriert sein. Details zur [WSL-Domain](https://wezterm.org/config/lua/WslDomain.html).

## 6. Zed konfigurieren

Zed einmal starten und wieder beenden. Unter `%APPDATA%\Zed` diese Dateien ablegen:

| Quelle im Repository | Ziel relativ zu `%APPDATA%\Zed` |
| --- | --- |
| `zed/.config/zed/settings.json` | `settings.json` |
| `zed/.config/zed/keymap.json` | `keymap.json` |
| `zed/.config/zed/themes/Neovim-custom.json` | `themes\Neovim-custom.json` |
| `zed/.config/zed/tasks.json` | `tasks.json` |

In der kopierten `settings.json` diesen Eintrag suchen:

```json
"terminal": { "shell": { "program": "zsh" } }
```

Durch folgenden Eintrag ersetzen, das umgebende JSON und seine Kommas erhalten:

```json
"terminal": { "shell": { "program": "pwsh.exe", "args": ["-NoLogo"] } }
```

In der kopierten `tasks.json` aus jedem Task die vollständige Zeile
`"shell": { "program": "zsh" },` entfernen. Andere Felder wie `command`, `args`
und `cwd` erhalten. Damit erzwingen Windows-Tasks keine lokal fehlende Zsh.
Die Task-Werkzeuge müssen jeweils in der Umgebung des Projekts installiert sein.

Für Fedora-Projekte in Zeds Command Palette (`Ctrl+Shift+P`) **projects: open wsl**
verwenden und Distribution sowie Projektordner wählen. Ein bloß im Explorer
geöffneter WSL-UNC-Pfad ersetzt diese Verbindung nicht. Im Projektterminal mit
`uname -a` und `pwd` prüfen, dass Befehle in Fedora laufen. Siehe
[Zeds WSL-Dokumentation](https://zed.dev/docs/remote-development#wsl-support).

## 7. Zebar-Dateien kopieren

Folgende Ordner anlegen und die Dateien kopieren:

| Quelle im Repository | Ziel |
| --- | --- |
| `windows/zebar/settings.json` | `%USERPROFILE%\.glzr\zebar\settings.json` |
| `windows/zebar/zpack.json` | `%USERPROFILE%\.glzr\zebar\dotfiles\zpack.json` |
| `windows/zebar/index.html` | `%USERPROFILE%\.glzr\zebar\dotfiles\index.html` |
| `windows/zebar/style.css` | `%USERPROFILE%\.glzr\zebar\dotfiles\style.css` |
| `windows/zebar/bar.mjs` | `%USERPROFILE%\.glzr\zebar\dotfiles\bar.mjs` |

Alle vier Widget-Dateien müssen direkt im Ordner `dotfiles` liegen. Im Widget
von `zpack.json` müssen diese Freigaben erhalten bleiben:

```json
"includeFiles": ["index.html", "style.css", "bar.mjs"]
```

Auch `htmlPath: "index.html"` und der JavaScript-Modulimport in `bar.mjs` bleiben
unverändert. Der erste Start braucht Internet für den JavaScript-Client von
`esm.sh`. Fehlende lokale Dateien oder Freigaben können zu HTTP-404-Fehlern führen.
Nach Änderungen an `zpack.json` Zebar vollständig beenden und neu starten.

## 8. GlazeWM ohne Startskript konfigurieren

`windows/glazewm/config.yaml` nach
`%USERPROFILE%\.glzr\glazewm\config.yaml` kopieren.

**In dieser Zielkopie** unter `general` die gesamte vorhandene
`startup_commands`-Zeile durch folgende Zeile ersetzen:

```yaml
  startup_commands: ['shell-exec zebar.exe startup']
```

Die zwei Leerzeichen vor `startup_commands` erhalten. Die übrigen Einstellungen,
insbesondere `shutdown_commands: []` und `config_reload_commands: []`, bleiben
bestehen. Damit startet GlazeWM Zebar direkt. Die Dateien `start-zebar.ps1` und
`start-glazewm.ps1` werden für diese Anleitung nicht kopiert oder ausgeführt.
Die [GlazeWM-Konfiguration](https://github.com/glzr-io/glazewm#config-general)
unterstützt solche Startbefehle.

GlazeWM über das Startmenü starten. Es verwendet den Standardpfad der
Konfiguration. Alternativ in einem neuen Windows-Terminal direkt eingeben:

```text
glazewm.exe start
```

Ist `zebar.exe` nicht auffindbar, zunächst neu anmelden. Wenn der Installer keinen
PATH-Eintrag eingerichtet hat, den tatsächlichen Pfad zu `zebar.exe` über die
Eigenschaften der Startmenü-Verknüpfung ermitteln und in der Startzeile verwenden,
zum Beispiel mit deinem realen Installationspfad:

```yaml
  startup_commands: ['shell-exec "C:\DEIN-INSTALLATIONSORDNER\zebar.exe" startup']
```

GlazeWM danach beenden und erneut starten. Für einen späteren manuellen Zebar-Start
nach dessen Beenden kann `zebar.exe startup` direkt im Windows-Terminal ausgeführt
werden; bei Bedarf den vollständigen EXE-Pfad verwenden.

Zebar nicht zusätzlich über einen eigenen Autostart starten. Vor einem vollständigen
GlazeWM-Neustart auch Zebar über sein Tray-Menü beenden: Der direkte Startbefehl
enthält nicht die Prozessprüfung der Repository-Startskripte. Ein Reload mit
`Alt+Shift+R` führt den Startbefehl dagegen nicht erneut aus.

## 9. Flow Launcher und Autostart einrichten

1. Flow Launcher im Startmenü öffnen und seine Einstellungen aufrufen.
2. Als globalen Hotkey **Alt+Leertaste** setzen.
3. **Start Flow Launcher on system startup** aktivieren.
4. **Hide on startup** aktivieren, damit beim Anmelden nur der Hintergrundprozess
   startet. Bei Bedarf die deutsche Übersetzung dieser Optionen verwenden.
5. Falls ein anderer Launcher dasselbe Kürzel nutzt, es dort freigeben.

Flow verwaltet seinen Autostart selbst. Die kopierte GlazeWM-Konfiguration
enthält bereits die Ausnahme für `Flow.Launcher`, damit das Suchfenster nicht
gekachelt wird. Der [Flow-Quellcode für Einstellungen](https://github.com/Flow-Launcher/Flow.Launcher/blob/dev/Flow.Launcher.Infrastructure/UserSettings/Settings.cs)
beschreibt Hotkey und Startoptionen.

Für GlazeWM genau **eine** Autostartmethode verwenden: Ist bereits ein funktionierender
GlazeWM-Autostart eingerichtet, keinen weiteren anlegen. Andernfalls:

1. `Win+R` drücken und `shell:startup` eingeben. Das öffnet deinen Benutzer-Autostartordner.
2. Dort über **Neu → Verknüpfung** eine Verknüpfung zur tatsächlich installierten
   `glazewm.exe` erstellen, mit dem Argument `start` hinter dem in Anführungszeichen
   eingeschlossenen EXE-Pfad. Beispiel mit zu ersetzendem Pfad:
   `"C:\DEIN-INSTALLATIONSORDNER\glazewm.exe" start`.
3. Die Verknüpfung zum Beispiel `GlazeWM` nennen. Keine Verknüpfung für Zebar
   anlegen; es wird durch GlazeWM gestartet.

Bei einem Wechsel vom skriptbasierten Setup dessen `Dotfiles-GlazeWM.vbs` im
Autostartordner nach Sicherung entfernen. Sonst würde zusätzlich das alte
Startskript ausgeführt. Bereits vorhandene andere GlazeWM-/Zebar-Autostarts in
**Einstellungen → Apps → Autostart** ebenfalls auf Doppelungen prüfen.

## 10. Funktion prüfen

Ab- und wieder anmelden. Danach prüfen:

| Prüfung | Erwartetes Ergebnis |
| --- | --- |
| `Alt+Leertaste`, `zed` eingeben | Flow zeigt Zed; `Enter` startet es |
| `Alt+Enter` | WezTerm startet in Fedora |
| `Ctrl+Shift+P` in WezTerm | Neuer lokaler PowerShell-Tab |
| `Alt+1` bis `Alt+9` | GlazeWM wechselt Workspaces |
| `Alt+Q` in einem Testfenster | Fenster schließt regulär, ggf. mit Speichern-Abfrage |
| `Alt+Shift+Leertaste` | Fokussiertes Fenster wechselt zwischen Tiling und schwebend |
| Zebar | Eine Leiste pro Monitor mit Workspaces, Uhr und Netzwerk |
| Zed-WSL-Projektterminal | `uname -a` zeigt Linux |
| Erneutes Anmelden | GlazeWM, Zebar und Flow starten ohne doppelte Leisten |

Die vollständige [Tastaturübersicht](README.md#tastatur) steht in der Windows-README.
Windows-GUI, echte Programmstarts und Autostart dieser manuellen Variante müssen
auf deinem Windows-Rechner geprüft werden; sie wurden hier nicht ausgeführt.

## Aktualisieren und zurücksetzen

Programme über ihre jeweilige Updatefunktion oder einen neuen offiziellen
Installer aktualisieren. Bei Konfigurationsänderungen Anwendungen beenden,
Zieldateien sichern und die Änderungen aus dem Repository manuell übernehmen.
**Nach erneutem Kopieren von `config.yaml` Schritt 8 wiederholen**, sonst verweist
sie wieder auf das Repository-Startskript. Ebenso bleiben die manuellen
WezTerm-Dateinamen und Zed-Anpassungen erforderlich.

GlazeWM-Konfigurationsänderungen mit `Alt+Shift+R` laden; bei Zebar-Paketänderungen
Zebar ganz beenden und direkt neu starten. Zur Wiederherstellung die betreffende
Anwendung schließen und ihre gesicherten Dateien zurückkopieren.

Zum Abschalten des Autostarts die GlazeWM-Verknüpfung aus `shell:startup` entfernen
und Flows eigene Autostartoption ausschalten. GlazeWM, Zebar und Flow bei Bedarf
zusätzlich über ihre Tray-Menüs beenden. Programme können anschließend über
**Einstellungen → Apps → Installierte Apps** deinstalliert werden.
