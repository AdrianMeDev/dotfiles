# Zed-Setup: Angular · Django · C# · Vim · lokale KI · Claude Code · pi

Komplette, tastaturzentrierte Zed-Konfiguration für Windows (inkl. WSL) und Linux.

```
zed-config/
├── .config/zed/
│   ├── settings.json   global: Vim, UI, Sprachen, LSP, Ollama, Agents, Edit Predictions
│   ├── keymap.json     global: Leader-Tasten (Leertaste), Panels, Debugger, KI
│   ├── tasks.json      global: Claude Code, pi, lazygit, Suche …
│   └── debug.json      global: Python-/Node-Datei debuggen
└── projects/
    ├── angular/.zed/{settings,tasks,debug}.json
    ├── django/.zed/{settings,tasks,debug}.json
    └── dotnet/.zed/{settings,tasks,debug}.json
```

## 1. Installation

| System | Globale Dateien landen in |
|---|---|
| Linux | `~/.config/zed/` → `dot install` (bzw. `./install.sh` aus dem Repo-Root) |
| Windows | `%APPDATA%\Zed\` → `.\bootstrap.ps1` / `.\windows\dot.ps1 install` (aus dem Repo-Root) |

`dot install` installiert außerdem Claude Code und pi (Modul `apps`) und wendet das einheitliche
Tokyo-Night- + Ioskeley-Theme (`theme/tokens.toml`) an.

**Windows + WSL:** Zed läuft unter Windows, WSL-Ordner werden als Remote-Projekt geöffnet
(`<space> p o` = *projects: open remote*, dort die WSL-Distribution wählen). Deshalb gehören die globalen Dateien nach
`%APPDATA%\Zed`. Die Projektvorlagen (`.zed/`) kopierst du **unter Linux/WSL** mit `dot zed-template`
ins Projekt (optional mit `--dry-run` und `--backup`):

```bash
dot zed-template angular ~/code/mein-frontend
dot zed-template django  ~/code/mein-backend
dot zed-template dotnet  ~/code/meine-api
```

Alle Werkzeuge, die im Projekt laufen (node, python/venv, dotnet, claude, pi, lazygit, ruff),
müssen bei WSL-Projekten **in WSL** installiert sein – Tasks, Terminal, LSPs, Debugger und
die ACP-Agents laufen dort.

## 2. Voraussetzungen

**Lokale KI (Ollama)** – Ollama läuft auf dem Rechner mit der Zed-Oberfläche (unter Windows
also Windows-Ollama; WSL-Ollama geht auch, da `localhost` weitergeleitet wird):

```bash
ollama pull qwen3-coder:30b       # Zed-Agent + Inline-Assistent (~20 GB, braucht GPU/viel RAM)
ollama pull qwen2.5-coder:7b      # Commit-Messages, Thread-Titel
ollama pull qwen2.5-coder:7b-base # Ghost-Text-Vervollständigung (FIM)
```

Weniger Hardware? In `settings.json` `qwen3-coder:30b` → `qwen2.5-coder:14b` ersetzen.
Modellwahl jederzeit mit `<space> a m`.

**Claude Code + pi als Agents im Editor (ACP):**

1. Befehlspalette → `zed: acp registry` → **Claude Agent** und **pi ACP** installieren.
2. Claude Code einmal im Terminal starten und einloggen (`claude`) – unter WSL in WSL.
   Im Agent-Thread geht auch `/login`.
3. pi installieren (`npm install -g @earendil-works/pi-coding-agent`) und Provider einrichten;
   pi kann ebenfalls dein lokales Ollama nutzen.

Dann: `<space> a c` = neuer Claude-Code-Thread, `<space> a p` = neuer pi-Thread.
Lieber klassisch im Terminal? `<space> a C` / `<space> a P` öffnet Claude Code / pi als
Terminal-Tab in der Mitte.

**Sprachen:** Extensions (Angular, Django, C#, …) installiert Zed beim ersten Start selbst.

- Angular: Node + Projekt-`node_modules` (Prettier/ESLint werden aus dem Projekt genutzt).
- Django: venv anlegen und mit `<space> c v` als Toolchain wählen; `ruff` und `debugpy`
  kommen von Zed, `django-language-server` von der Extension.
- C#: .NET SDK. **Debugger:** Zed bringt für .NET keinen Adapter mit. Installiere
  [zed-netcoredbg](https://github.com/qwadrox/zed-netcoredbg) als Dev-Extension
  (Repo klonen, Rust via rustup, dann `zed: install dev extension`).
  In `projects/dotnet/.zed/*.json` `MyApp.Api` und `net10.0` anpassen.

**Optional:** `lazygit`, `ripgrep`.

## 3. Tastatur-Spickzettel

Leader = **Leertaste** (im Normal-/Visual-Modus, in leerer Pane, im Projekt- und Outline-Panel).
Nach `<space>` kurz warten → Which-Key zeigt alle Optionen.

### Navigation
| Taste | Aktion |
|---|---|
| `<space><space>` / `ctrl-p` | Datei öffnen |
| `<space> /` | Projektweit suchen |
| `<space> ,` | offene Tabs |
| `<space> f s` / `f S` | Symbole in Datei / im Projekt |
| `shift-h` / `shift-l` | vorheriger / nächster Tab |
| `ctrl-h/j/k/l` | Pane/Panel wechseln (im Terminal: `ctrl-alt-h/j/k/l`) |
| `-` | aktuelle Datei im Projekt-Panel zeigen |
| `<space> e` / `<space> o` | Projekt-Panel / Outline |
| `<space> q` / `<space> Q` | Tab schließen / alle anderen |
| `<space> w v` / `w s` | Split rechts / unten |
| `<space> w z` | Zoom (Pane maximieren) |
| `<space> w x` | alle Docks schließen |
| `<space> p r` / `p o` | letzte Projekte / Remote-Projekt (WSL) öffnen |

Vim-Standards bleiben: `gd` Definition, `gy` Typ, `gI` Implementierung, `gA` Referenzen,
`K` Hover, `]d`/`[d` Diagnose, `]c`/`[c` Git-Hunks, `gcc` Kommentar, `ys`/`cs`/`ds` Surround.

### Projekt-Panel
`a` Datei · `A` Ordner · `r` umbenennen · `d` löschen · `x`/`y`/`p` ausschneiden/kopieren/einfügen
· `D` duplizieren · `/` in Ordner suchen · `q` schließen · `h/l` zu/auf · `o` öffnen

### Code
| Taste | Aktion |
|---|---|
| `<space> c a` | Code-Actions |
| `<space> c r` | Umbenennen |
| `<space> c f` | Formatieren |
| `<space> c d` | Diagnose-Übersicht |
| `<space> c h` | Inlay-Hints an/aus |
| `<space> c l` | Language-Server neu starten |
| `<space> c v` | Python-venv / Toolchain wählen |

### Run & Tasks (gleich in allen drei Projekttypen)
| Taste | Angular | Django | .NET |
|---|---|---|---|
| `<space> r r` | ng serve | runserver | dotnet watch run |
| `<space> r b` | ng build | manage.py check | dotnet build |
| `<space> r t` | ng test | manage.py test | dotnet test |
| `<space> r l` | ng lint | ruff check | dotnet format --verify |
| `<space> r f` | prettier | ruff format | dotnet format |

`<space> r n` Test/Runnable unter dem Cursor · `<space> r s` alle Tasks · `<space> r a` letzten Task
wiederholen · `<space> t t` Terminal · `<space> t n` neues Terminal

### Debug
| Taste | Aktion |
|---|---|
| `F4` / `<space> d d` | Debug-Session starten (Auswahl) |
| `F9` / `<space> d b` | Breakpoint |
| `<space> d l` | Log-Breakpoint |
| `F5` / `<space> d c` | Weiter |
| `F10` / `<space> d o` | Step over |
| `F11` / `<space> d i` | Step into |
| `shift-F11` / `<space> d u` | Step out |
| `shift-F5` / `<space> d s` | Stopp |
| `<space> d r` | letzte Session neu starten |
| `<space> d v` / `d e` / `d t` | Variablen / Konsole / Debug-Panel |

**Angular unter WSL:** Chrome unter Windows mit
`chrome.exe --remote-debugging-port=9222 --user-data-dir=%TEMP%\chrome-debug` starten und
„Angular: an Chrome anhängen“ wählen. Dafür in `%UserProfile%\.wslconfig` unter `[wsl2]`
`networkingMode=mirrored` setzen. Unter Linux reicht „Chrome starten“.

### KI
| Taste | Aktion |
|---|---|
| `<space> a a` | Agent-Panel |
| `<space> a n` | neuer Thread mit Zed-Agent (lokales Modell) |
| `<space> a c` | neuer **Claude Code**-Thread |
| `<space> a p` | neuer **pi**-Thread |
| `<space> a m` | Modell wählen |
| `<space> a i` | Inline-Assistent (im Visual-Modus auf Auswahl) |
| `<space> a s` | Auswahl in den Agent-Thread einfügen |
| `<space> a t` | Ghost-Text an/aus |
| `<space> a C` / `a P` | Claude Code / pi im Terminal-Tab |
| `ctrl-alt-l` / `alt-w` / `ctrl-alt-j` | Vorschlag ganz / Wort / Zeile annehmen (Insert-Modus) |
| `alt-\` | Vorschlag manuell anfordern |

### Git
`<space> g g` Panel · `g b` Inline-Blame · `g B` Blame · `g d` Diff · `g s` stagen ·
`g h` Hunk anzeigen · `g r` Hunk verwerfen · `g c` Commit (KI-Message via lokalem Modell) ·
`g p`/`g P` Push/Pull · `g f` Fetch · `g o` Branch · `g l` lazygit

### Sonstiges
Insert-Modus: `jk` → Normal · Visual: `J`/`K` Zeilen verschieben, `S` Surround ·
`<space> p s`/`p k`/`p t`/`p d` Settings/Keymap/Tasks/Debug-Tasks öffnen

## 4. Hinweise

- Die Agent-Berechtigungen (`agent.tool_permissions`) gelten für Zeds eigenen Agent: Lesende
  Befehle, Builds und Tests laufen ohne Nachfrage, `push`/`reset`/`sudo` fragen nach,
  `rm -rf /` und Force-Push sind gesperrt. Claude Code und pi nutzen ihre eigenen Regeln.
- Meldet Zed nach einem Update eine unbekannte Aktion in der Keymap, die betroffene Zeile
  löschen oder über `zed: open keymap` neu belegen. `dev: open key context view` zeigt,
  welcher Kontext gerade aktiv ist.
- Wenn ein ACP-Agent nicht startet: `dev: open acp logs`.
