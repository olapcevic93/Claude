# D365FO / X++ Review Checklist

Use this list as a prompt for your review, not as a form to fill in. Only report items that actually apply to the change.

## Contents
1. Extensibility and overlayering
2. Naming and IWG conventions
3. Data access and performance
4. Transactions and error handling
5. Security
6. Labels, UI and forms
7. Tables and data model
8. Batch, integration and SysOperation
9. Code quality
10. PR hygiene

## 1. Extensibility and overlayering
- No overlayering of standard Microsoft objects. Changes to standard code must use extensions (`[ExtensionOf(...)]`, table, form or EDT extensions, event handlers).
- **Chain of Command:**
  - The class is `final` and named `<Object><Prefix>_Extension`.
  - `next` is called unconditionally in every wrapped method. It can't be skipped, except in methods marked `[Replaceable]`.
  - The wrapper doesn't change the method signature, and the default parameter values stay the same.
- Prefer CoC over pre/post event handlers for new code. Event handlers must be `static` and use the correct `DataEventHandler`, `FormEventHandler` or `PostHandlerFor` attributes.
- No `[Hookable(false)]` or `[Wrappable(false)]` workarounds, and no reflection or `DictClass` hacks to reach private members.
- New fields on standard tables go through a table extension. Consider whether a separate extension table would be better for wide tables such as CustTable and SalesTable.

## 2. Naming and IWG conventions
- New objects and fields on standard objects carry the agreed model prefix, for example `IWG` for IWG Application Foundation or `PRO` for ProCust FO. Flag objects without a prefix and objects placed in the wrong model.
- Class, method and variable names are clear and in camelCase or PascalCase as standard. No Hungarian leftovers, and no single-letter names outside loops.
- Branch and PR titles follow the BS / DFO / ENHANCE ticket convention and reference the work item.

## 3. Data access and performance
- **Set-based operations:** use `update_recordset`, `insert_recordset`, `delete_from` or `RecordInsertList` instead of row-by-row loops where the logic allows it. Check whether `skipDataMethods`, `skipDatabaseLog` or `skipEvents` are needed and justified, because they silently fall back to row-by-row processing otherwise.
- No `select` inside a `while select` loop when a join would work.
- **Existence checks:**
  - Use `select firstonly` for single-record lookups.
  - Select only the fields you need with a field list, especially on wide tables.
  - Don't count records just to check whether one exists.
- Use indexes: `where` clauses should match an index. Flag `like` with a leading wildcard, or filters on non-indexed fields on large tables.
- Use `forupdate` only when the record will actually be updated. Use `pessimisticlock` or `optimisticlock` deliberately.
- Use `crossCompany` only when intended. Flag missing `changecompany` or DataAreaId handling.
- Use caching appropriately, such as the table `CacheLookup` setting and `SysGlobalObjectCache`. No unbounded static caches.
- Avoid heavy logic in display methods on grids. Consider computed columns or cached display methods (`[SysClientCacheDataMethodAttribute]`).

## 4. Transactions and error handling
- Multi-record writes are wrapped in `ttsbegin` / `ttscommit`, and these are balanced on every code path.
- No user interaction (`Box`, dialogs) inside a transaction.
- **Exceptions:**
  - `try/catch` blocks catch specific exceptions.
  - Update conflicts are retried correctly (`Exception::UpdateConflict` with `appl.ttsLevel() == 0` and `retry`, capped).
  - Deadlocks are handled.
  - No swallowed exceptions (an empty `catch`, or `catch` with only `info`).
- `validateWrite`, `validateField` and `validateDelete` are used for validation instead of throwing from `insert` or `update` where possible.
- Error messages use labels and `error()` / `throw error(...)`. No hard-coded strings.

## 5. Security
- New menu items have privileges, and the privileges belong to duties or roles. No objects are left without security.
- No `SysAdmin`-only assumptions, and no bypassing security keys.
- Any `unchecked(Uncheck::XDS)`, `TableSecurityPermission` or `runAs` use is justified.
- No hard-coded credentials, connection strings, API keys, URLs or customer PII. Secrets should come from Key Vault or parameters.
- External calls (HTTP, .NET interop) validate their input and handle timeouts.

## 6. Labels, UI and forms
- All user-facing text uses labels (`@IWG:LabelId` style), including field labels, help text, info, warning and error messages, and menu items. There should be no literal strings.
- New labels exist in the model's label file with meaningful help text.
- Form extensions add controls in a sensible group and respect form patterns. Check the pattern validation.
- Enum values are appended at the end of extensible enums and never reordered.

## 7. Tables and data model
- New tables have a primary key or alternate key, a clustered index, correct relations (not only `EDT` relations), and a `DeleteAction` where relevant.
- Fields use EDTs rather than base types. String sizes come from the EDT.
- Table `TableGroup`, `CacheLookup`, `SaveDataPerCompany` and `ReplacementKey` are set deliberately.
- Data entities: staging is correct, keys are unique, `IsPublic` / `PublicEntityName` is set only if needed, and mapping and virtual field logic lives in `mapEntityToDataSource` / `postLoad`.
- For upgrades or data migration, check for a data upgrade script or a note about it.

## 8. Batch, integration and SysOperation
- Long-running work uses the SysOperation framework (controller, service, contract) or batch, not a `RunBase` dialog that blocks the client.
- Batch tasks are idempotent and can be re-run safely. Batch bundling or parallelism is considered for large volumes.
- Contracts use `[DataMemberAttribute]` and have sensible defaults.
- Integrations log errors usefully and don't leak payloads containing PII into logs.

## 9. Code quality
- No dead code, commented-out blocks, debugging `info()` calls or `breakpoint` statements left in.
- Methods are short and focused, with no copy-pasted blocks. Shared logic is extracted.
- `public`, `protected` and `internal` access is kept as narrow as possible.
- XML doc comments on public methods. Comments explain *why*, not *what*.
- Best Practice (BP) warnings are fixed or suppressed with a justification.
- Unit tests (SysTest) where the logic is non-trivial, if the team's practice is to include them.

## 10. PR hygiene
- The PR links a work item. The title and description say what changed and why.
- Only relevant files are included. No unrelated objects, build outputs, `.user` files or local config.
- The target branch is correct for the release path.
- Model descriptor changes (new dependencies) are intentional.
