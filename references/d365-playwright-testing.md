# D365 F&O Playwright testing — instructions for Claude

Follow this file when asked to test X++ changes with Playwright. Generate the tests, run them, and report the results.

## 1. Environment

| Item | Value |
|---|---|
| Playwright project | `C:\Playwright\d365-tests` |
| Environment files | `%USERPROFILE%\.claude\references\d365-environments\<name>.env`, one per environment, shared through the `.claude` git repo. Override the folder with `D365_ENV_DIR`. |
| Environment selector | `TEST_ENV` variable = the file name without `.env` |
| Auth state | `C:\Playwright\d365-tests\.auth\<name>.json`, one per environment, local only |
| Harness model | `<TEST MODEL NAME>` (test-only model, never part of a PR) |
| Harness prefix | `PwTest` |

### 1.1 Environment files

Each file holds the settings for one environment. To add one, copy `_template.env` to `<name>.env`. Example `dev1.env`:

```
ENV_TYPE=dev
D365_URL=https://usnconeboxax1aos.cloud.onebox.dynamics.com
D365_COMPANY=USMF
```

1. `ENV_TYPE` must be one of `dev`, `test`, `uat`, `prod`.
2. Never put secrets (passwords, client secrets, tokens) in these files. They are committed and shared, and only describe where to connect.
3. Use the environment the user names ("run against dev2" means `TEST_ENV=dev2`). If they name none, use the only `dev` file in the folder. If there are several, ask which one.
4. To list the available environments, read the `*.env` file names in the folder, skipping names that start with `_`.

### 1.2 `playwright.config.ts`

Create this file if it is missing. Requires `npm i -D dotenv`.

```ts
import { defineConfig } from '@playwright/test';
import * as dotenv from 'dotenv';
import * as fs from 'fs';
import * as os from 'os';
import * as path from 'path';

const envName = process.env.TEST_ENV;
if (!envName) throw new Error('TEST_ENV not set. Example: $env:TEST_ENV="dev1"');

// Shared environment definitions live in the .claude repo
const envDir = process.env.D365_ENV_DIR
  ?? path.join(os.homedir(), '.claude', 'references', 'd365-environments');
const envFile = path.join(envDir, `${envName}.env`);
if (!fs.existsSync(envFile)) throw new Error(`Environment file not found: ${envFile}`);
dotenv.config({ path: envFile, override: true, quiet: true });

const envType = process.env.ENV_TYPE;
if (envType === 'prod') throw new Error('Refusing to run against a prod environment.');
if (envType !== 'dev' && process.env.ALLOW_NON_DEV !== 'true')
  throw new Error(`ENV_TYPE=${envType}. Set ALLOW_NON_DEV=true to run against a non-dev environment.`);

export const authFile = path.join(__dirname, '.auth', `${envName}.json`);

export default defineConfig({
  testDir: './tests',
  timeout: 120_000,
  expect: { timeout: 30_000 },
  reporter: [['list'], ['html', { outputFolder: `playwright-report/${envName}` }]],
  outputDir: `test-results/${envName}`,
  use: {
    baseURL: process.env.D365_URL,
    ignoreHTTPSErrors: true,
    trace: 'retain-on-failure',
    screenshot: 'only-on-failure',
  },
  projects: [
    { name: 'setup', testMatch: /auth\.setup\.ts/ },
    { name: 'd365', testIgnore: /auth\.setup\.ts/, use: { storageState: authFile } },
  ],
});
```

`tests/auth.setup.ts` saves the login per environment:

```ts
import { test } from '@playwright/test';
import { authFile } from '../playwright.config';

test('login', async ({ page }) => {
  test.setTimeout(300_000);
  await page.goto(`/?cmp=${process.env.D365_COMPANY}`);
  await page.waitForURL(/dynamics\.com\/.*cmp=/i, { timeout: 300_000 });
  await page.context().storageState({ path: authFile });
});
```

`.gitignore` must contain `.auth/`, `test-results/` and `playwright-report/`.

## 2. Hard rules

1. Never run against an environment whose `ENV_TYPE` is `prod`. Never set `ALLOW_NON_DEV=true` yourself. Only the user sets it, in their own shell, for a non-dev run.
2. Never type credentials and never run `--project=setup`. If the run lands on `login.microsoftonline.com`, or `.auth/<name>.json` is missing, stop and tell the user to run:
   `$env:TEST_ENV="<name>"; npx playwright test --project=setup --headed`
3. Never commit, print or copy anything in `.auth/`.
4. Never create or edit a file in `references\d365-environments\` unless the user asks.
5. Test only code that has been built and synced on the target environment. For the local dev VM, check that the model build succeeded (`Metadata\<Model>\BuildModelResult.log`) and that the build is newer than your last X++ edit. For a remote environment, you cannot check this, so state in the report that the deployed build was assumed.
6. Harness classes go only in the harness model. Never add them to the feature model's `.rnrproj` or to a PR.
7. Never use fixed sleeps (`waitForTimeout`). Wait on a locator or on `expect`.
8. Records a test creates must carry a `PW` prefix in their key or description, and the test must delete them (or the harness must `ttsabort`).
9. Never weaken an assertion just to make a test pass. A failing test is a finding: report it.
10. Never hard-code a URL or company in a spec. Use `baseURL` (relative `page.goto`) and `process.env.D365_COMPANY`.

## 3. Workflow

1. **Understand the change.** Read the X++ diff and the requirement (work item, FDD or ticket). List the behaviours to prove.
2. **Derive test cases.** Cover at least one happy path, one negative or validation path, and one edge case per behaviour. Note the ticket ID for each.
3. **Pick a test type** for each case:
   | Case | Test type |
   |---|---|
   | Business logic, calculations, class methods, posting results | A. Harness class via `SysClassRunner` |
   | Form behaviour: field defaults, validation messages, enabled/visible controls, buttons | B. UI form test |
   | Batch jobs or integrations | A. Harness that calls the job's `run()` or service method synchronously, then checks the resulting data |
4. **Find the real control names.** Read the form XML in metadata for control names (`<Name>` under `<Controls>`). Do not guess from labels. If a name cannot be found, generate the test with `TODO verify selector` and say so in the report.
5. **Write the harness class** (type A) and build the harness model.
6. **Write the spec** in `tests/<TicketId>/<feature>.spec.ts`, using the helpers in `tests/helpers/d365.ts`.
7. **Run** the spec (section 7).
8. **On failure, triage** before reporting: is it a test or selector bug, an environment or auth problem, or a defect in the X++ code? Fix test bugs and rerun, at most 2 times. Never touch the X++ under test to make a test pass unless the user asked for fixes.
9. **Report** using the format in section 8.

## 4. Type A — harness class pattern

Each harness method writes one result line with a marker that the spec asserts on. Use `ttsabort` so test data never persists. If the scenario needs committed data, delete it at the end instead.

```xpp
/// Playwright harness for <TicketId>. Test-only model; never ship.
class PwTest<TicketId><Feature>
{
    public static void main(Args _args)
    {
        PwTest<TicketId><Feature> harness = new PwTest<TicketId><Feature>();
        harness.run();
    }

    public void run()
    {
        try
        {
            ttsbegin;

            // Arrange: create or find data with a PW prefix
            // Act: call the code under test
            // Assert: emit the observed values
            info(strFmt('PW-RESULT|case1|%1|%2', /*actual1*/ '', /*actual2*/ ''));

            ttsabort;
        }
        catch (Exception::Error)
        {
            info(strFmt('PW-ERROR|case1|%1', infolog.text(infologLine())));
        }
        info('PW-DONE');
    }
}
```

Rules:
1. Use exactly one `PW-RESULT|<case>|<values...>` line per case, pipe-separated, with no labels inside the values.
2. Always emit `PW-DONE` last, so the spec knows the class finished and did not hang.
3. For a negative case, catch the expected error and emit `PW-RESULT|<case>|ERROR|<message>`.
4. To run one case, add `_args.parm()` or a URL parameter only if needed. Otherwise use one class per ticket and one line per case.

URL to run a harness: `/?cmp=<Company>&mi=SysClassRunner&cls=<ClassName>`

## 5. Type B — UI form test pattern

1. Open forms by menu item: `/?cmp=<Company>&mi=<MenuItemName>`.
2. Selectors, in order of preference:
   1. `[data-dyn-controlname="<AOT control name>"]` (append ` input` for fields)
   2. `getByRole(...)` with an exact accessible name
   3. never CSS classes or positional XPath
3. After each action that triggers a server round trip, assert on the next expected state, such as a field value, a message, or a control becoming enabled.
4. Read messages with `expectMessage(page, text)`. It covers the message bar and infolog.

## 6. Helpers and spec template

`tests/helpers/d365.ts`: create it if it is missing. Reuse it, do not duplicate it.

```ts
import { Page, expect } from '@playwright/test';

export async function openMenuItem(page: Page, mi: string, cmp = process.env.D365_COMPANY!) {
  await page.goto(`/?cmp=${cmp}&mi=${mi}`);
  await assertLoggedIn(page);
}

export async function runClass(page: Page, cls: string, cmp = process.env.D365_COMPANY!) {
  await page.goto(`/?cmp=${cmp}&mi=SysClassRunner&cls=${cls}`);
  await assertLoggedIn(page);
  await expect(page.getByText('PW-DONE')).toBeVisible({ timeout: 120_000 });
}

export async function resultFor(page: Page, caseId: string): Promise<string[]> {
  const line = page.getByText(new RegExp(`PW-(RESULT|ERROR)\\|${caseId}\\|`)).first();
  await expect(line).toBeVisible();
  return (await line.innerText()).trim().split('|');   // [marker, case, v1, v2, ...]
}

export async function expectMessage(page: Page, text: string | RegExp) {
  await expect(page.getByText(text).first()).toBeVisible();
}

export function control(page: Page, name: string) {
  return page.locator(`[data-dyn-controlname="${name}"]`).first();
}

async function assertLoggedIn(page: Page) {
  if (/login\.microsoftonline\.com/.test(page.url()))
    throw new Error(`AUTH_EXPIRED: run $env:TEST_ENV="${process.env.TEST_ENV}"; npx playwright test --project=setup --headed`);
}
```

Spec template:

```ts
import { test, expect } from '@playwright/test';
import { runClass, resultFor, openMenuItem, control, expectMessage } from '../helpers/d365';

test.describe('<TicketId> <feature>', () => {

  test('<TicketId> case1: <expected behaviour>', async ({ page }) => {
    await runClass(page, 'PwTest<TicketId><Feature>');
    const [marker, , actual1, actual2] = await resultFor(page, 'case1');
    expect(marker).toBe('PW-RESULT');
    expect(actual1).toBe('<expected1>');
    expect(actual2).toBe('<expected2>');
  });

  test('<TicketId> case2: <form behaviour>', async ({ page }) => {
    await openMenuItem(page, '<MenuItemName>');
    await control(page, '<ControlName>').locator('input').fill('<value>');
    await expectMessage(page, /<expected message>/);
  });
});
```

Naming:
1. Name tests `<TicketId> <caseId>: <expected behaviour in plain words>`.
2. Use one `describe` per ticket and feature.

## 7. Running

Run from `C:\Playwright\d365-tests`. Always set `TEST_ENV` in the same command.

1. Run the ticket's specs:
   - PowerShell: `$env:TEST_ENV="<name>"; npx playwright test tests/<TicketId> --project=d365 --reporter=list`
   - Bash: `TEST_ENV=<name> npx playwright test tests/<TicketId> --project=d365 --reporter=list`
2. Rerun one failing test: the same command with `-g "<test title>"` in place of the path.
3. Run against several environments: run the command once per `TEST_ENV`, one after another, and report each separately.
4. If needed, read failure artifacts in `test-results\<name>\<test-folder>\`: `error-context.md`, the screenshot, and `trace.zip`.
5. Run commands in the background when a run may take more than 2 minutes.

## 8. Report format

```
Playwright: <passed>/<total> passed — <TicketId> — env <TEST_ENV> (<D365_URL>, <D365_COMPANY>)

| # | Case | Type | Result | Detail |
|---|------|------|--------|--------|
| 1 | case1: <behaviour> | A | PASS | |
| 2 | case2: <behaviour> | B | FAIL | expected "X", got "Y" — X++ defect at <file:line> |

Failures:
1. <case>: <test bug / environment / X++ defect>, evidence: <assertion message, screenshot path>
Unverified:
1. <selectors marked TODO, cases not automated and why>
Files:
- <spec path>, <harness class path>
```
