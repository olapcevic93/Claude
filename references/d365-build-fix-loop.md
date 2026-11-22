# D365 F&O build-fix loop

Use only when this file is referenced in the request. Scripts are in `scripts\` next to this file.

## Tools
- Build: `powershell -NoProfile -ExecutionPolicy Bypass -File <this folder>\scripts\d365-build.ps1 -Model <Model>[,<Model2>] [-Labels] [-WithReferences] [-ShowWarnings]`
  - Detects UDE (XPPConfig json) or classic VM (AosService\PackagesLocalDirectory); override with `-MetadataPath` / `-FrameworkPath`.
  - Builds referenced custom models that have no compiled DLL first.
  - Exit 0 = no errors, 1 = build errors, 2 = tool or usage failure.
  - Error line: `ERROR <Model> | <object xml file> | dynamics://<Type>/<Object>/Method/<method> | (line,col) | <message>`. Line is relative to the method source, not the XML file.
  - Full logs: `<Metadata>\<Model>\BuildModelResult.log` and `.xml`.
  - Run in the background; a large model takes 30 s to several minutes.
- DB sync: `powershell -NoProfile -ExecutionPolicy Bypass -File <this folder>\scripts\d365-dbsync.ps1 -Tables <T1>,<T2>` (or `-TableExtensions`, `-Full`).
  - Classic VM: runs SyncEngine on the local DB, elevated prompt. Exit 0 = OK, 1 = failed.
  - UDE: exit 3 and prints the VS deploy steps; tell the user to deploy with "Synchronize database" ticked.
  - Run only after a successful build, and only when tables, views, entities or their extensions changed.

## Loop (after writing or changing X++ code or metadata)
1. Build every model touched by the change; add `-Labels` if label files changed.
2. Exit 0: go to step 7.
3. Read the first error first; later errors are often a cascade of it (undefined macro, missing type, invalid XML).
4. Fix the cause in source: open the object XML, find the method, correct it; keep the file valid XML and its original line endings.
5. Rebuild the same models.
6. Repeat 3-5 until exit 0.
7. If tables, views, entities or their extensions changed, run DB sync.
8. Report: models built, error count, warnings added by the change, sync result.

## Stop and report instead of looping
- The same error survives two fix attempts.
- Errors are in objects this change did not touch (pre-existing, or a dependency model not built).
- Exit code 2 (tool, path or environment problem).
