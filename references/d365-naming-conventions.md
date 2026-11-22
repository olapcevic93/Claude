# D365 F&O naming conventions and best practices

Apply these rules to every new or changed object in a custom model.

## 0. Resolve the placeholders first

| Placeholder | Meaning | Example (PeopleCert) |
|---|---|---|
| `{Model}` | Custom model name. All work for the client goes in this model. | `PeopleCert` |
| `{Prefix}` | Object prefix of that model. | `PC` |
| `{LabelFile}` | Label file ID of that model. | `PeopleCert` |

- Take the values from the target model's descriptor (`Metadata\{Model}\Descriptor\{Model}.xml`) and existing objects in the model.
- If the model or prefix is unknown or ambiguous, ask the user before creating objects.
- All examples below use `PeopleCert` / `PC`. Substitute the real values.

## 1. General rules

| Rule | Detail |
|---|---|
| Prefix | Every new object name starts with `{Prefix}`. |
| Object names | PascalCase: `PCWorkerShiftSchedule`. |
| Method names | camelCase, never prefixed: `calculateCustomerBalance()`. |
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

## 4. Extensions

1. Before creating an extension, search `{Model}` for an existing extension of the same object. If one exists, add to it.
2. Never create a numbered or duplicate extension (`CustTable.PeopleCert1`, `CustTable.PeopleCert2`).
3. Never extend an object that belongs to `{Model}`. Change the object directly (for example edit `PCEssAddressWorkflow`, do not create `PCEssAddressWorkflow.PeopleCert`).

## 5. Chain of command over event handlers

- Use chain of command (`[ExtensionOf(...)]` class with `next`) to change standard behaviour.
- Use event handlers only when no wrappable method exists (delegates, data events with no method to wrap).

## 6. Labels

1. Every table, field, EDT, enum, form caption, menu item, help text and user message uses a label. No literal text in properties or code.
2. Before creating a label, search `{LabelFile}` and the standard label files for an existing one with the same text; reuse it.
3. Messages in code:

```xpp
// No parameters
info(SysLabel::labelId2String2(literalStr("@PeopleCert:LabelId"), CompanyInfo::languageId()));

// With parameters (%1, %2 in the label text)
info(strFmt(SysLabel::labelId2String2(literalStr("@PeopleCert:LabelId"), CompanyInfo::languageId()), parm1, parm2));
```

The same pattern applies to `warning()`, `error()` and `throw error()`.

## 7. Path length

Windows limits a full file path to 260 characters, including all folders. Shorten the project task description or use abbreviations when the project path approaches this limit.

## 8. Reference model

When a naming or best-practice case is not covered above, inspect `C:\Users\ognjl\.claude\references\models\IWG.7z` for precedent. Rules in this file take precedence over the reference model.
