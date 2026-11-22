---
name: "iwg-technical-design"
description: "Proposes a D365FO/FinOps technical solution design in chat from a requirement given as text, a Confluence (regusit.atlassian.net, space IE) or Jira link, or an uploaded document - always confirms the requirement/FDD and custom model with the user, and checks existing customizations in K:\\AosService\\PackagesLocalDirectory to suggest IWG Application Foundation (iwg) or ProCust FO (pro) per object. Never creates Azure DevOps work items. Trigger on FDD, D365FO, FinOps, AOT, or solution/technical design requests."
---

# IWG Technical Design (D365FO / FinOps)

## What this skill does

Take a D365FO/FinOps requirement - text pasted in the chat, a Confluence FDD or Jira link, an uploaded document (FDD, transcript, spec), or a slice of one - and **propose a technical solution design directly in the chat**. The design names real AOT objects (tables, classes, extensions, forms, entities, labels), accounts for what's already customized in the confirmed model on disk, and lays out the technical flow as plain-language pseudocode.

The output of this skill is the design itself, in the conversation. It is also the input the `iwg-fo-codegen` skill reads later, so keep the structure consistent (see step 7).

**Hard rules, no exceptions:**

1. **Never create or update work items.** No User Story, Task, Feature, comment, or link in Azure DevOps - and nothing written to Confluence or Jira. The user wants to review the design in chat; creating items would bypass that review. If the user later asks for work items, that is a separate, explicit request.
2. **Never write X++ code.** Not in the design, not as an example, not "to be clear." The technical flow is a numbered list of plain-English steps that names real classes/methods as identifiers - no braces, semicolons, method signatures, or attribute syntax. Code is the codegen skill's job, after the design is agreed.
3. **Always confirm the requirement source (FDD) and the custom model with the user** before designing. Suggest the model from where the objects already live (step 4), but the user confirms it - never carry one over silently from an earlier requirement.
4. **The AOS metadata path is fixed:** `K:\AosService\PackagesLocalDirectory`. Always use it - don't ask the user for a path and don't suggest alternatives. It's where the models live and where existing customizations are checked.

## Toolset

**Confluence & Jira (Atlassian, read-only)** - load via ToolSearch if deferred (`mcp__Atlassian__*` or `mcp__Atlassian_Rovo__*`):

- Site `https://regusit.atlassian.net/`, FDDs in the Confluence space with key **IE**.
- `searchConfluenceUsingCql`, `getPagesInConfluenceSpace` - find candidate FDD pages.
- `getConfluencePage` - read a Confluence FDD in full.
- `getJiraIssue`, `getJiraIssueRemoteIssueLinks` - read a Jira requirement and its linked pages.

**Local AOS metadata (the user's computer)** - `mcp__remote-devices__device_bash`, `device_list_dir`:

- Root: `K:\AosService\PackagesLocalDirectory`.
- Layout: `<Package>\Descriptor\<Model>.xml` describes each model; a model's objects sit in `<Package>\<Model>\AxTable\`, `AxTableExtension\`, `AxClass\`, `AxForm\`, `AxFormExtension\`, `AxDataEntityView\`, `AxEnum\`, `AxEdt\`, `AxLabelFile\`, `AxSecurityPrivilege\`, `AxSecurityDuty\`, `AxSecurityRole\`, etc. One XML file per object.
- Search and read on the device (grep/find/list) - don't stage metadata files into the cloud just to read them.
- If the computer isn't reachable, say so, continue with the design, and mark every "already customized?" judgement as "verify in model".

**Azure DevOps (read-only, optional)** - only if the user supplies a Feature URL/ID: `wit_work_item` (`get`) to read its Fit/Gap analysis. Never call any `*_write` tool.

**FinOps metadata MCP (optional)** - if one is connected, use it to verify standard object names. Never guess a standard name; if unverifiable, say "verify exact name in target environment".

## Workflow

### 1. Get and confirm the requirement source

The requirement can arrive in any of these forms - accept whichever the user gives:

- **Text in the message** - a requirement description pasted into the chat. Use it as-is.
- **Confluence link** - read it with `getConfluencePage`.
- **Jira link or issue key** (e.g. `IE-123`) - read it with `getJiraIssue`; also follow any linked Confluence FDD in its description or remote links (`getJiraIssueRemoteIssueLinks`).
- **A document** - an uploaded file (.docx, .pdf, .md, .txt, .xlsx) or a file in a connected folder. Read it with the matching skill (docx/pdf/xlsx) when text extraction needs it.
- **Only a topic, no source** - search Confluence space **IE** for matching pages, skim the best candidates, and present title + one line of context for each so the user can pick.

Before designing, play back in one or two lines what you understood the requirement to be and which source it came from, and ask the user to confirm. If a search finds nothing confident, ask for the text, link, or document instead of guessing. If several sources are given (e.g. a Jira story plus its FDD), treat the FDD as the detailed source and note any conflicts between them.

### 2. Establish the requirement scope

Identify the capability this design covers. If the FDD spans several unrelated capabilities, ask whether to design one now or all of them (one section per capability).

### 3. Check existing customizations in both custom models

Before suggesting a model or deciding anything is "new", look up the standard and custom objects the requirement touches in both IWG custom models under `K:\AosService\PackagesLocalDirectory` (find each model's package via `<Package>\Descriptor\<Model>.xml`):

| Model | Prefix |
|---|---|
| IWG Application Foundation | `iwg` |
| ProCust FO | `pro` |

For each object, record where it already lives:

- Extensions already present on the standard objects the requirement touches (e.g. `AxTableExtension\SalesTable.*.xml`, `AxClass\*_Extension.xml`) - note which model folder they sit in.
- Custom tables/classes/entities with related names or purpose (grep object names and label text for requirement keywords) - note their prefix (`iwg...` or `pro...`) and model.
- The label file ID each model uses, so new labels go in the existing file.

Reuse or extend what exists rather than duplicating it. Anything you can't verify gets flagged in the Notes.

### 4. Suggest the model and prefix, then confirm

Suggest a model **per object**, based on step 3:

- **Object already exists in ProCust FO** (a `pro`-prefixed object, or an extension already in the ProCust FO folder) → suggest **ProCust FO**, prefix `pro`, for that object and anything that directly extends it. Keeping changes next to the existing customization avoids splitting one piece of logic across two models.
- **Object already exists in IWG Application Foundation** (an `iwg`-prefixed object or extension there) → suggest **IWG Application Foundation**, prefix `iwg`.
- **Brand-new object with no related existing customization** → suggest **IWG Application Foundation**, prefix `iwg`.

So if every object is new or already `iwg`, the whole design goes to IWG Application Foundation. If some objects are already in ProCust FO, those objects stay in ProCust FO and the rest go to IWG Application Foundation. Show this as a short table (Object | Found in | Suggested model / prefix) so the user can see why.

Then ask the user to confirm or change the suggestion. The user's answer is final - never proceed on the suggestion alone. If the models on disk differ from the two above, list what you found and ask.

Ask for the requirement confirmation (step 1) and model confirmation together in one message where possible, to save the user a round trip.

### 5. Optional: read the Feature's Fit/Gap

If the user mentions or links an Azure DevOps Feature, read its description for a Fit/Gap analysis (standard vs. custom) and use it to inform step 6. Don't ask for a Feature if none is given - it isn't required.

### 6. Design the solution

1. **Classify each piece** as Extend (standard object), New (custom object), or Already Customized (existing object in the model to reuse/modify). Default to extending the nearest logical existing object over creating new ones. Start from the Fit/Gap classification if one exists.
2. **Name every object** per the conventions below. Include only artifact types the requirement actually needs.
3. **Write the technical flow as pseudocode** - numbered plain-language steps naming the real objects, with the hook point stated in words (which class intercepts which standard method, via which pattern).

If the FDD already names technical objects, reuse those names.

### 7. Present the design in chat

Use this structure every time so it's easy to review and so `iwg-fo-codegen` can pick it up:

```
## Technical Design: [capability]

**Source:** [FDD/Jira title + link, document name, or "requirement text in chat"]
**Model(s) / prefix:** [model] / [prefix] (list each model used if the design spans both)
**Metadata path:** K:\AosService\PackagesLocalDirectory

### Approach
2-3 sentences.

### AOT Objects
| Object type | Name | Model | New / Extended / Already customized | Purpose |

### Field-level detail
Per new or extended table: | Field | EDT / type | Purpose |

### Technical Flow
1. ... (pseudocode only)

### Security & labels
Privileges/duties needed; new labels and the label file they go in.

### Notes & open questions
DB sync, items to verify in the environment, assumptions, questions for the functional consultant.
```

Keep it compact: no restating the FDD, no filler rows. End by asking whether anything should be adjusted. Iterate on the design in chat if the user asks for changes.

## Handling ambiguity

- Requirement source unclear → ask once for the text, Confluence/Jira link, or document; never guess.
- Model/prefix → suggest per step 4 (existing ProCust FO objects → ProCust FO / `pro`; everything else → IWG Application Foundation / `iwg`), then always get the user's confirmation.
- Computer unreachable → design anyway, flag all customization checks as "verify in model".
- New vs. extend vs. existing unclear → take the conservative option (extend or reuse) and flag it in Notes.
- Standard object name uncertain → "verify exact name in target environment", never a fabricated name.
- Scope bigger than one capability → ask whether to design one or all.

## What not to do

- Don't create, update, or link any Azure DevOps work item, or write to Confluence/Jira.
- Don't write X++ code anywhere.
- Don't use or ask for any metadata path other than `K:\AosService\PackagesLocalDirectory`.
- Don't assume the requirement source or the custom model without the user's confirmation.
- Don't claim an object is or isn't already customized without checking both model folders.
- Don't put a new object that extends an existing ProCust FO customization into IWG Application Foundation (or vice versa) without flagging it and getting the user's OK.
- Don't propose editing standard objects directly - extensions only.

## AOT Naming & Pseudocode Conventions

These follow Microsoft's D365 F&O extension model: custom work sits in its own model (typically USR layer) and standard code is only ever extended, never edited.

**Nothing here, and nothing in a design, is real X++ code.** Names are identifiers only.

### Model & package structure

A custom model organizes artifacts by type, one folder per kind (`AxClass`, `AxTable`, `AxTableExtension`, `AxForm`, `AxFormExtension`, `AxDataEntityView`, `AxLabelFile`, `AxEnum`, `AxEdt`, security folders, etc.). An extension file is named after the base object plus the model, e.g. `<BaseTableName>.<Model>.xml`.

### The prefix

Every new artifact name - tables, classes, fields, EDTs, enums, forms - starts with the prefix of the model it belongs to, confirmed in step 4 (`iwg` for IWG Application Foundation, `pro` for ProCust FO). It's the most important naming decision and applies to everything below. The examples use `iwg`; a ProCust FO object would use `pro` in the same position.

### Artifact type → naming pattern

| Need | AOT artifact | Naming pattern | Example |
|---|---|---|---|
| New custom table | Table | `<Prefix><PurposeName>` | `iwgInventOnHandSum` |
| Add field(s) to a standard table | Table extension | `<BaseTable>.<Model>` file; field `<Prefix><FieldName>` | `SalesTable.IWGApplicationFoundation`, field `iwgApprovalStatus` |
| New business-logic class | Class | `<Prefix><PurposeName>` | `iwgAutoPostJournalService` |
| Extend a standard method (Chain of Command) | Class, extension-of pattern | `<Prefix><BaseClassOrArea>_Extension` | `iwgBankChequePrint_Extension` |
| React to a standard delegate/event | Class, event handler | `<Prefix><Purpose>EventHandler` | `iwgWHSShipmentEventHandler` |
| New or changed screen | Form / form extension | `<FormName>.<Model>` for an extension | `LedgerJournalTransDaily.IWGApplicationFoundation` |
| Integration / OData / DMF | Data entity (+ staging table) | `<Prefix><EntityName>`, staging suffixed `Staging` | `iwgInventOnHandSumStaging` |
| New enum | Enum | `<Prefix><EnumName>` | |
| New extended data type | EDT | `<Prefix><EdtName>` | |
| New UI string | Label in the model's label file | `@<LabelFileId>:<LabelId>` | `@iwg:SomeLabel` |
| New security surface | Role/duty/privilege | `<Prefix><Name>` | |
| Outbound event integration | Business event class | `<Prefix><EventName>BusinessEvent` | `iwgTransportationTenderBusinessEvent` |
| Singleton parameters table | Table with static lookup | `<Prefix>Parameters`, deletion blocked | `iwgIntegrationParameters` |

### Extension patterns (prose, not code)

- **Chain of Command** - a final extension class intercepts a standard method; may pre-validate, always calls through to the standard logic, may post-process. Additive, never a replacement.
- **Event handlers** - a static handler method subscribes to a standard delegate; custom logic runs alongside the standard behavior.
- **Business events** - a custom class extends the business-events base and registers against an event so external subscribers are notified.
- **Data entities** - the DMF/OData surface; back with a staging table when a separate landing zone is needed.
- **Parameters tables** - singleton; deletion blocked; accessed via a static lookup.

### Pseudocode rules for the Technical Flow

- Name real classes/methods/fields in backticks, as identifiers.
- State the hook point in words (which class, which standard method or delegate, which pattern).
- Describe what happens and in what order - not how to code it.

**Example** (Chain of Command):

1. `iwgSalesConfirmFormLetter_Extension` intercepts `SalesFormLetter.updateNow` via Chain of Command.
2. Before the standard logic: validate that [condition]; block or flag the confirmation if it fails.
3. Let the standard `updateNow` logic run.
4. After the standard logic: call `iwgComplianceCheck.run` with the sales record ID to [log/notify as the requirement needs].

### Notes worth including in a design

- New or changed tables need a database sync.
- Extensions are additive - never edit standard objects.
- A build plus best-practice checks is expected before the work counts as done.