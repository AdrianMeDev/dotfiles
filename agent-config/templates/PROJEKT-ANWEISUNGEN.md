# <Projektname>

<!--
  Vorlage für Projekt-Anweisungen.
  Arbeit (Claude Code): als CLAUDE.md ins Projekt-Root legen und committen.
  Privat (pi):          als AGENTS.md ins Projekt-Root legen (pi liest auch CLAUDE.md).
  Tipp: In Claude Code erzeugt /init einen ersten Entwurf – danach mit dieser Struktur abgleichen.
  Kurz halten: nur, was der Agent nicht selbst aus dem Code ablesen kann.
-->

## Überblick
<1–3 Sätze: Was macht das Projekt, für wen?>

## Befehle
| Zweck | Befehl |
|---|---|
| Starten | `<z. B. npx ng serve / python manage.py runserver / dotnet watch run --project src/App>` |
| Tests | `<…>` |
| Einzelner Test | `<…>` |
| Lint | `<…>` |
| Format | `<…>` |
| Build | `<…>` |

## Architektur
- `<ordner>/` – <wofür>
- `<ordner>/` – <wofür>
- Datenfluss: <z. B. Angular → /api (Django REST) → PostgreSQL>

## Konventionen
- <z. B. Neue Features als eigener Ordner unter src/app/features/<name>>
- <z. B. API-Antworten immer über Serializer, nie Model direkt>
- <z. B. Commit-Scope = Feature-Name>

## Nicht anfassen
- <z. B. generierte Dateien unter src/api/generated/ – werden per `npm run gen:api` erzeugt>
- <z. B. bereits angewandte Migrations>

## Bekannte Eigenheiten
- <z. B. Tests brauchen laufenden Docker-Container `db`>
