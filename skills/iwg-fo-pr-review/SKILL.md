---
name: iwg-fo-pr-review
description: Review an Azure DevOps pull request containing D365FO / X++ changes using the Azure DevOps MCP tools, and report findings in chat only (never posts comments or votes on the PR). Pulls the PR, its changed files and diffs, reads the linked work item (Task / User Story / Bug) and checks the code against both X++ best practices and the requirement. Use whenever the user says "review PR 1234", "review this pull request", "code review my PR", "check this PR", pastes a dev.azure.com pullrequest link, or asks what's wrong with / whether to approve a PR - even if they don't mention X++ or D365.
---

# IWG D365FO Pull Request Review (Azure DevOps)

Review a pull request in Azure DevOps and give the user a clear, prioritised review **in chat**. The user copies whatever they want into the PR themselves, so this skill is read-only against Azure DevOps.

## Why read-only

The user wants to stay in control of what reviewers and authors see. So do not call `repo_pull_request_thread_write`, `repo_pull_request_write` (including `vote`), or any work-item write tool, even if the review is clear-cut. If the user explicitly asks later in the conversation to post something, treat that as a separate request and confirm the exact text first.

## Data handling

Never copy customer PII (names, emails, phone numbers, addresses, bank details, and so on) from code, test data, config or work items into the review. If you find it hard-coded in the PR, flag it as a finding and refer to it generically, such as "a customer email address is hard-coded at line 42", without repeating the value.

## Workflow

### 1. Identify the PR

You need the **project**, **repository** and **PR ID**.
- From a URL like `https://dev.azure.com/{org}/{project}/_git/{repo}/pullrequest/{id}`, parse all three.
- If you were given only an ID, call `repo_pull_request` with `action: get`, the `pullRequestId` and the project if you know it. If the project is unknown, ask the user, or use `core_list_projects` and `repo_repository` (`action: list`) to narrow it down.
- If the user says "my PRs" or "PRs I'm reviewing", use `repo_pull_request` `action: list` with `created_by_me` or `i_am_reviewer`, show the list, and let them pick.

### 2. Get the PR, its files and the linked work items

Call `repo_pull_request` with `action: get`, `includeChangedFiles: true` and `includeWorkItemRefs: true`. From it, note:
- the title, description, author, source and target branches, status and draft flag
- `lastMergeSourceCommit` (the new code) and `lastMergeTargetCommit` (the base)
- the changed files and their change type (add, edit, delete, rename)
- the linked work item IDs

Also call `repo_pull_request_thread` `action: list` so you know which issues are already under discussion. You don't need to repeat those, but you can say "already raised in the existing thread" when relevant.

### 3. Read the requirement

For each linked work item, call `wit_work_item` (`action: get`, `expand: Relations` or `All`). Read the title, description, acceptance criteria and repro steps (for bugs). If it links to a parent User Story or Feature with the real requirement, fetch that too, but only one level up. If there is no linked work item, say so as a finding, because IWG PRs are expected to link one, and review the code on its own merits.

### 4. Build the diff for each changed file

The MCP has no diff endpoint, so reconstruct it:
- **Edited file**: `repo_file` `action: get_content` twice, with `version` set to the source commit and then the target commit (`versionType: Commit`). Compare them and focus on the changed regions, but read enough of the surrounding code to understand them.
- **Added file**: fetch the source version only. The whole file is new.
- **Deleted file**: fetch the target version and check that nothing else in the PR still depends on it.

D365FO metadata files are XML (`AxClass`, `AxTable`, `AxForm`, `...Extension`, and so on) with X++ inside `<Source><![CDATA[ ... ]]></Source>` blocks. Review the X++ in those blocks and the metadata properties that matter, such as table indexes and relations, field EDTs, labels, and security privileges and duties. Skip noise such as whitespace, element reordering and `.rnrproj` or descriptor churn unless it looks wrong.

For large PRs (more than about 25 files), start with the X++ class, table and form changes, then security, then label and resource files. Tell the user if you only skimmed part of it.

### 5. Review

Read `references/xpp-review-checklist.md` and apply it. Also check the code against the requirement:
- Does the change actually do what the work item asks, including every acceptance criterion?
- Is anything in the requirement missing from the code?
- Is anything in the code outside the requirement (scope creep, or unrelated files committed)?

Judge severity by the actual impact, not by how many rules were broken. A missing `ttsbegin` around a multi-record update is a blocker. A missing XML doc comment is a nit.

### 6. Report in chat

Use this structure:

```
## PR <id>: <title>
**Author:** <name> · **Branch:** <source> → <target> · **Work item:** <id + title, or "none linked">
**Verdict:** Approve | Approve with suggestions | Needs changes | Reject   (a recommendation only; nothing is posted)

### Summary
2-4 sentences: what the PR does and the overall quality.

### Requirement coverage
| Acceptance criterion / requirement | Covered? | Notes |

### Findings
#### 🔴 Blockers
- **<file path>:<line>** - <issue>. <why it matters>. **Suggested fix:** <concrete fix, with a short X++ snippet if helpful>
#### 🟠 Should fix
#### 🟡 Suggestions / nits

### Files reviewed
<list, noting any that were skipped or only skimmed>
```

Leave out empty severity sections. Keep each finding self-contained so the user can paste it into a PR comment as it is. Line numbers refer to the source (new) version of the file. Where the file is XML, give the method name as well as the line, because line numbers in AOT XML are hard for people to navigate.

End by asking whether the user wants to go deeper on any finding, or review another PR.
