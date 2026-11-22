---
name: azure-devops-pr-creator
description: Creates a Pull Request in Azure DevOps from a local solution or project path, linked to a work item (any type - Task, User Story, Bug, etc.) provided by the user. Discovers all modified or relevant files within the given solution/project path, asks for a reviewer, and raises the PR with the correct title, description, linked work item, and reviewers set. Use whenever the user says "create a PR", "raise a pull request", "open a PR for my changes", "create PR for work item #NNN", or provides a solution path and wants a PR made. Trigger on any combination of: a work item number, a file/folder/solution path, and intent to create a PR.
---

# Azure DevOps PR Creator

## What this skill does

Takes a **work item number**, a **solution or project path** on disk, and one or more **reviewers**, then creates a properly structured Pull Request in Azure DevOps. It lists all files that exist within the given path (treating them as the files in scope for this PR), resolves the work item to derive a meaningful PR title and description, and sets the reviewer(s) before creating the PR.

This skill sits at the end of the development pipeline — after code has been written and committed to a feature branch — and formalises the handoff to peer review.

## Before you start: know the toolset

**Azure DevOps** — load with `tool_search` if not already available:

- `core_list_projects` — resolve org/project context
- `repo_list_repos_by_project` — discover available repositories if the repo isn't named
- `repo_list_branches_by_repo` — enumerate branches to identify the source branch
- `repo_get_branch_by_name` — confirm a specific branch exists
- `repo_list_directory` — list files/folders in a repo path (used if browsing the repo rather than local disk)
- `wit_work_item` (`get`) — read the work item to derive title and description context
- `search_workitem` — fallback if the user gives a title instead of an ID
- `core_get_identity_ids` — resolve reviewer name(s) to Azure DevOps identity IDs
- `repo_create_pull_request` — the final creation step
- `repo_update_pull_request_reviewers` — add reviewers after PR creation if not supported inline

**Local file system** — this skill reads the local solution/project path to enumerate files in scope. This requires file or bash access (Claude Code, Claude Desktop, or Cowork). If that access isn't available, ask the user to paste the list of files/folders directly.

## Inputs required

Collect all of these before proceeding. Ask once for anything not already given — group missing items into a single question rather than asking one at a time:

| Input | How to get it | Notes |
|---|---|---|
| **Work item number** | User provides | Any work item type: Task, User Story, Bug, Feature |
| **Solution / project path** | User provides | Local disk path or repo-relative path; used to enumerate files in scope |
| **Source branch** | User provides, or auto-detect from repo | The branch the PR is raised from (e.g. `feature/IAP-586`) |
| **Target branch** | User provides, or default to `main` / `develop` | Ask once if ambiguous; default to the repo's default branch |
| **Reviewer(s)** | User provides | One or more names or email addresses; resolve to Azure DevOps identity IDs |

Do not invent defaults for the work item number, path, or reviewer — these must always come from the user.

## Workflow

### 1. Collect inputs

Check what the user has already provided. If any of the required inputs above are missing, ask for them now — group everything into one question:

> "Before I create the PR, I need a few things:
> - **Work item number** (the Task/Story/Bug to link)
> - **Solution or project path** (so I can list the files in scope)
> - **Source branch** (the branch your changes are on)
> - **Reviewer(s)** — name or email of who should review this PR"

Do not proceed until all four are in hand.

### 2. Resolve org/project/repo context

Reuse from earlier in the conversation if already known.

- `core_list_projects` to confirm the project if needed.
- `repo_list_repos_by_project` if the repo name isn't clear from the branch name or path.
- Confirm the source branch exists with `repo_get_branch_by_name`.
- Establish the target branch — ask if ambiguous, otherwise default to the repo's configured default branch (usually `main` or `develop`).

### 3. Read the work item

Call `wit_work_item` (`get`) on the work item ID. Extract:

- **Title** — drives the PR title (see step 5 format)
- **Description** — key acceptance criteria or technical notes, summarised for the PR body
- **Work item type** — Task / User Story / Bug / Feature
- **State** — note it; a Closed or Done item linked to a new PR is worth flagging to the user
- **Area Path / Tags** — useful for PR tags or labels if the repo supports them

If the user gave a title instead of an ID, use `search_workitem` to find it; confirm with the user before proceeding if multiple plausible matches exist.

### 4. Enumerate files in scope

Read the provided solution or project path and list all files within it. The goal is to give the reviewer a clear picture of what's changing.

**If local file access is available:**
- Walk the directory tree under the given path.
- Exclude build artefacts and auto-generated files: `bin/`, `obj/`, `.vs/`, `*.user`, `*.suo`, `*.cache`, `node_modules/`, `packages/`.
- Group the results by folder for readability.

**If local file access is not available:**
- Use `repo_list_directory` to browse the equivalent path in the repository.
- Alternatively, ask the user to paste the file list directly.

Present the enumerated file list to the user in step 6 (preview) so they can confirm scope is correct before the PR is created.

### 5. Resolve reviewers

For each reviewer name or email the user provided:

- Call `core_get_identity_ids` to resolve to an Azure DevOps identity ID.
- If a name doesn't resolve, report it to the user and ask for the correct name or email before proceeding — never silently drop a reviewer.

### 6. Draft PR title and description

**Title format:**
```
[Work Item Type #ID] <Work Item Title>
```
Examples:
- `[Task #586] IAP Framework – Invoice Schedule Generation`
- `[Bug #421] Fix duplicate invoice generation on batch re-run`
- `[Story #533] Store IAP Contract on Customer Account`

**Description structure** (Markdown):

```markdown
## Summary
<2–3 sentences: what this PR implements, derived from the work item description or title>

## Work Item
- Linked: [<Type> #<ID>] <Title> — <Azure DevOps URL>

## Files Changed
<grouped file list from step 4>

## Notes
<Any context the reviewer needs: migration steps, config changes, known gaps, test instructions>
```

The Notes section is optional — include it only if the work item or the file list suggests something a reviewer needs to know upfront (e.g. a new batch job requires scheduler setup, or a DMF entity requires a data refresh).

### 7. Preview before creating

Show the user a compact preview — not a wall of text:

| Field | Value |
|---|---|
| **PR Title** | `[Task #586] IAP Framework – Invoice Schedule Generation` |
| **Source → Target** | `feature/IAP-586` → `main` |
| **Linked Work Item** | Task #586 — IAP Framework |
| **Reviewer(s)** | Mustansir Kapadia, Sridhar Nagandla |
| **Files in scope** | 14 files across 3 folders (see list below) |

Show the grouped file list beneath the table.

Then ask: **"Does this look right? Shall I create the PR?"**

Do not create the PR until the user explicitly confirms.

### 8. Create the PR

Once confirmed:

1. Call `repo_create_pull_request` with:
   - `title` — from step 6
   - `description` — from step 6 (Markdown body)
   - `sourceBranch` — user's feature branch
   - `targetBranch` — confirmed target
   - `workItemRefs` — the resolved work item ID

2. If the PR creation response doesn't support inline reviewers, call `repo_update_pull_request_reviewers` immediately after to add them. Never skip this step — a PR without reviewers defeats the purpose.

3. Capture the returned PR ID and URL.

### 9. Report back

Give the user:

- PR ID and direct URL
- Confirmation that the work item is linked
- Confirmation that reviewer(s) were added (or flag any that couldn't be resolved)
- One-line note if anything was left out (e.g. a reviewer didn't resolve — ask the user to add them manually via the URL)

## Handling ambiguity

- **Work item number not given:** Ask directly — this is mandatory and cannot be inferred.
- **Path given but doesn't exist locally:** Ask the user whether to browse the repo path instead, or paste the file list manually.
- **Source branch unclear:** List the recent branches from `repo_list_branches_by_repo` and ask the user to confirm; never guess.
- **Target branch unclear:** Default to the repo's configured default branch and state the assumption explicitly in the preview.
- **Reviewer name doesn't resolve:** Report the failure, ask for the correct identifier — never silently drop the reviewer or proceed without them.
- **Work item is already linked to an open PR:** Warn the user and ask whether to proceed — don't block, but don't hide it either.
- **Work item state is Closed/Done:** Note this in the preview and ask whether to proceed — a valid scenario (e.g. linking a hotfix to a resolved bug), but worth flagging.
- **Multiple repos in the project:** Ask the user which one — don't guess from the path alone.

## What not to do

- **Never create the PR before the preview step** — always confirm first.
- **Never silently drop a reviewer** — if one doesn't resolve, surface it and fix it before creating.
- **Never invent a work item ID or branch name** — these must come from the user or be explicitly confirmed via a tool lookup.
- **Never commit or push code** — this skill only creates the PR; it assumes the branch already exists and changes are already pushed.
- **Never include build artefacts or IDE noise** (`obj/`, `bin/`, `.vs/`, `*.user`) in the files-changed list — filter them out silently.
- **Never guess the target branch** — default to the repo default and state it plainly; ask if that default isn't determinable.
- **Don't skip the reviewer step** — a PR with no reviewers is incomplete by design.
