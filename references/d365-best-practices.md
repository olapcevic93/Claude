# D365 F&O / X++ best practices and naming conventions

Applies to every new or changed object in a custom model.
- **When writing code:** follow every rule.
- **When reviewing code:** use the rules as a checklist; report only items that apply to the change.

## Contents
0. Placeholders
1. General naming rules
2. Object naming
3. Boolean fields
4. Extensibility and extensions
5. Labels
6. Tables and data model
7. Forms and UI
8. Data access and performance
9. Transactions and error handling
10. Security
11. Batch, integration and SysOperation
12. Code quality
13. Projects, path length and PR hygiene
14. Reference model

## 0. Placeholders

| Placeholder | Meaning | Example (PeopleCert) |
|---|---|---|
| `{Model}` | Custom model name. All work for the client goes in this model. | `PeopleCert` |
| `{Prefix}` | Object prefix of that model (for example `PC`, `IWG`, `PRO`). | `PC` |
| `{LabelFile}` | Label file ID of that model. | `PeopleCert` |

1. Take the values from the target model's descriptor (`Metadata\{Model}\Descriptor\{Model}.xml`) and existing objects in the model.
2. If the model or prefix is unknown or ambiguous, ask the user before creating objects.
3. Examples below use `PeopleCert` / `PC`. Substitute the real values.
4. Review: flag objects without the prefix and objects placed in the wrong model.

## 1. General naming rules

| Rule | Detail |
|---|---|
| Prefix | Every new object name starts with `{Prefix}`. |
| Object names | PascalCase: `PCWorkerShiftSchedule`. |
| Method names | camelCase, never prefixed: `calculateCustomerBalance()`. |
| Variable names | camelCase, descriptive. No Hungarian notation, no single-letter names outside loop counters. |
| Abbreviations | Only widely known ones (`Id`, `Qty`, `FTE`). |
| Reserved words | Never use X++ reserved keywords as names. |
| Descriptive | The name states the purpose of the object. |

## 2. Object naming

| Object type | Pattern | Example |
|---|---|---|
| Project | `{Prefix}_[Initials]_[TaskNumber]_[TaskDescription]` | `PC_OL_030_SalesOrderInvoiceDocument` |
| Table | `{Prefix}[TableName]` | `PCWorkerShiftSchedule` |
| Field in a new (prefixed) table | `[FieldName]`, no prefix | `EmployeeId`, `WorkDate`, `ShiftType` |
| Table extension | `[Table].{Model}` | `CustTable.PeopleCert` |
| Field in a table extension | `{Prefix}[FieldName]` | `PCOnBoarding`, `PCIsSupervisor` |
| Form | `{Prefix}[FormName]` | `PCWorkerShiftScheduleSetup` |
| Form extension | `[Form].{Model}` | `HcmPosition.PeopleCert` |
| Form control bound to a data source | `[DataSourceName]_[FieldName]` | `CustTable_PCComment`, `PCWorkerShiftSchedule_WorkDate` |
| Form control not bound to a data source | `{Prefix}[ControlName]` | `PCApproveButton` |
| Data source in a new form/query/view | Same as the table name | `PCWorkerShiftSchedule` |
| Data source added in a form/query/view extension | `{Prefix}[TableName]` | `PCPurchTable` |
| Same table added more than once | `{Prefix}[TableName][Reason]`, never a numeric suffix | `PCPurchTableAccountingMemo` |
| Business logic class | `{Prefix}[ClassName]` | `PCInvoicePosting` |
| Service class | `{Prefix}[ClassName]Service` | `PCShipmentTrackingService` |
| Data contract class | `{Prefix}[ClassName]Contract` | `PCShipmentFilterContract` |
| Controller class | `{Prefix}[ClassName]Controller` | `PCShipmentTrackingController` |
| Event handler class | `{Prefix}[ObjectName]EventHandler` | `PCSalesTableEventHandler` |
| Chain-of-command extension class | `[Object]_{Model}_Extension`, or `[Object]_{Model}_[Description]_Extension` when more than one is needed | `HcmPosition_PeopleCert_Extension`, `HcmWorkerV2_PeopleCert_FilterForWorkerPositionAndEmployment_Extension` |
| Security role | `{Prefix}[Name]Role` | `PCRebateManagerRole` |
| Security duty | `{Prefix}[Name]Duty` | `PCApproveRebatesDuty` |
| Security privilege | `{Prefix}[Name]Privilege` | `PCEditRebatesPrivilege` |
| Menu item | `{Prefix}[ObjectName]` (form, class, report) | `PCWorkerShiftSchedule` |
| Menu extension | `[Menu].{Model}` | `HRM.PeopleCert` |
| Label file | Existing `{LabelFile}` file; project-specific only when required: `{LabelFile}_[ProjectDescription]` | `PeopleCert_en` |

Notes:
- Standard fields shown on an extension (for example `Person`, `PersonnelNumber` on `CustTable`) keep their names; only new fields get the prefix.
- Bound control names inherit the prefix from the table or field automatically; do not add it again.

## 3. Boolean fields

Name the field as a yes/no question, then add the prefix when it is on an extension.

| Meaning | Wrong | Right |
|---|---|---|
| Record is active | `Active` | `PCIsActive` |
| Max FTE reached | `MaxFTE` | `PCIsMaxFTE` |
| User may approve | `Approve` | `PCCanApprove` |
| Process finished | `Finished` | `PCIsFinished` |
| Earnings created | `EarningsCreated` | `PCAreEarningsCreated` |

## 4. Extensibility and extensions

### 4.1 No overlayering
- Never overlayer standard Microsoft objects. Change standard behaviour only through extensions: `[ExtensionOf(...)]` classes, table/form/EDT/enum extensions, event handlers.
- No `[Hookable(false)]` / `[Wrappable(false)]` workarounds, no reflection or `DictClass` hacks to reach private members.

### 4.2 Extension objects
1. Before creating an extension, search `{Model}` for an existing extension of the same object. If one exists, add to it.
2. Never create a numbered or duplicate extension (`CustTable.PeopleCert1`, `CustTable.PeopleCert2`).
3. Never extend an object that belongs to `{Model}`. Change the object directly (edit `PCEssAddressWorkflow`, do not create `PCEssAddressWorkflow.PeopleCert`).
4. New fields on standard tables go through a table extension. For wide tables (`CustTable`, `SalesTable`) consider a separate extension table related 1:1.

### 4.3 Chain of command over event handlers
- Use chain of command to change standard behaviour. Use event handlers only when no wrappable method exists (delegates, data events with no method to wrap).
- CoC class rules:
  1. Class is `final` and named per section 2.
  2. `next` is called unconditionally in every wrapped method; it may be skipped only in methods marked `[Replaceable]`.
  3. Method signature and default parameter values are unchanged.
- Event handler rules: methods are `static` and use the correct attribute (`DataEventHandler`, `FormEventHandler`, `FormControlEventHandler`, `PreHandlerFor`, `PostHandlerFor`).

## 5. Labels

1. Every table, field, EDT, enum, form caption, menu item, help text and user message uses a label. No literal text in properties or code.
2. Before creating a label, search `{LabelFile}` and the standard label files for one with the same text; reuse it.
3. New labels go in the `{LabelFile}` label file and have meaningful help text where the property exists.
4. Messages in code:

```xpp
// No parameters
info(SysLabel::labelId2String2(literalStr("@PeopleCert:LabelId"), CompanyInfo::languageId()));

// With parameters (%1, %2 in the label text)
info(strFmt(SysLabel::labelId2String2(literalStr("@PeopleCert:LabelId"), CompanyInfo::languageId()), parm1, parm2));
```

The same pattern applies to `warning()`, `error()` and `throw error()`.

## 6. Tables and data model

- New tables have a primary key or alternate key, a clustered index, correct table relations (not only EDT relations), and a `DeleteAction` where relevant.
- Fields use EDTs, not base types. String sizes come from the EDT.
- `TableGroup`, `CacheLookup`, `SaveDataPerCompany` and `ReplacementKey` are set deliberately.
- Enum values are appended at the end of extensible enums and never reordered.
- Use existing standard enums and EDTs before creating new ones.
- Data entities: staging is correct, keys are unique, `IsPublic` / `PublicEntityName` set only when needed, mapping and virtual-field logic lives in `mapEntityToDataSource` / `postLoad`.
- Upgrades or data migration: a data upgrade script exists, or the PR notes why none is needed.

## 7. Forms and UI

- Form extensions add controls in a sensible group and respect the form pattern; pattern validation passes.
- Avoid heavy logic in display methods on grids. Use computed columns or cached display methods (`[SysClientCacheDataMethodAttribute]`).

## 8. Data access and performance

- **Set-based operations:** use `update_recordset`, `insert_recordset`, `delete_from` or `RecordInsertList` instead of row-by-row loops where the logic allows. Check whether `skipDataMethods`, `skipDatabaseLog` or `skipEvents` are needed and justified; without them overridden methods silently force row-by-row processing.
- No `select` inside a `while select` loop when a join would work.
- **Existence checks and lookups:**
  - Use `select firstonly` for single-record lookups.
  - Use a field list on wide tables; select only the fields needed.
  - Do not count records just to check whether one exists.
- `where` clauses match an index. Flag `like` with a leading wildcard and filters on non-indexed fields of large tables.
- Use `forupdate` only when the record is updated. Use `pessimisticlock` / `optimisticlock` deliberately.
- Use `crossCompany` only when intended. Handle `changecompany` and `DataAreaId` correctly.
- Use caching appropriately (`CacheLookup`, `SysGlobalObjectCache`). No unbounded static caches.

## 9. Transactions and error handling

- Multi-record writes are wrapped in `ttsbegin` / `ttscommit`, balanced on every code path.
- No user interaction (`Box`, dialogs) inside a transaction.
- **Exceptions:**
  - `catch` specific exceptions.
  - Retry update conflicts correctly: `Exception::UpdateConflict`, only when `appl.ttsLevel() == 0`, with a capped retry count.
  - Handle `Exception::Deadlock`.
  - No swallowed exceptions (empty `catch`, or `catch` with only `info`).
- Validate in `validateWrite`, `validateField`, `validateDelete` rather than throwing from `insert` / `update` where possible.
- Error messages use labels with `error()` / `throw error(...)` (section 5).

## 10. Security

- Every new menu item has a privilege (section 2 naming); every privilege belongs to a duty or role. No unsecured objects.
- No `SysAdmin`-only assumptions, no bypassing security keys.
- Any `unchecked(Uncheck::XDS)`, `TableSecurityPermission` or `runAs` use is justified in a comment.
- No hard-coded credentials, connection strings, API keys, tokens, URLs or customer PII in code or in the database. Secrets come from Key Vault or parameters.
- External calls (HTTP, .NET interop) validate input and set timeouts.

## 11. Batch, integration and SysOperation

- Long-running work uses SysOperation (controller, service, contract) or batch, not a blocking `RunBase` dialog.
- Use an existing standard batch framework before creating a new job.
- Batch tasks are idempotent and safe to re-run. Consider bundling or parallel tasks for large volumes.
- Contracts use `[DataMemberAttribute]` and have sensible defaults.
- Integrations log errors usefully and never write payloads containing PII to logs.

## 12. Code quality

- Use macros, enums and labels instead of literals.
- No dead code, commented-out blocks, debug `info()` calls or `breakpoint` statements.
- Methods are short and focused; no copy-pasted blocks, shared logic extracted.
- Access modifiers (`public`, `protected`, `internal`, `private`) as narrow as possible.
- XML doc comments on public methods. Comments explain *why*, not *what*.
- Best Practice (BP) warnings fixed, or suppressed with a justification.
- SysTest unit tests for non-trivial logic where the team includes them.

## 13. Projects, path length and PR hygiene

- Project naming per section 2. Every edited object is added to the project (`.rnrproj`).
- Windows limits a full file path to 260 characters, including all folders. Shorten the project task description or use abbreviations when the path approaches this limit.
- Branch and PR titles follow the BS / DFO / ENHANCE ticket convention and reference the work item.
- The PR links a work item; title and description state what changed and why.
- Only relevant files are included: no unrelated objects, build outputs, `.user` files or local config.
- Target branch is correct for the release path.
- Model descriptor changes (new dependencies) are intentional.

## 14. Reference model

When a case is not covered above, inspect `C:\Users\ognjl\.claude\references\models\IWG.7z` for precedent. Rules in this file take precedence over the reference model.
