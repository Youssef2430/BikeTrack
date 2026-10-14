# Contributing

For bugs, include your Watch model, watchOS version, equipment model, and steps to reproduce. Do not attach personal health records or private account details.

See [development instructions](../documentation/DEVELOPMENT.md) for setup and repository layout. Run `swift test` for core changes and build the Watch app for app changes. For website changes, run `npm --prefix website run build` and include the generated `docs/` files.

Keep pull requests focused. Follow the existing Swift and website conventions, preserve third-party license notices, and leave signing credentials and private release records out of commits.

## Pull requests and required checks

All changes to `main` go through a pull request, including changes by the repository owner. `@yssf-c` owns every path in `.github/CODEOWNERS`; contributor PRs require that account's approval. PRs authored by `@yssf-c` do not need an additional reviewer. New commits dismiss stale approvals, and review conversations must be resolved.

The active GitHub ruleset requires code-owner review with **zero additional approving reviews**. This preserves the owner-author exception; setting the count to one would require another person to approve the owner's PRs. There are no bypass actors, so PRs, CI, and protection against force pushes and branch deletion also apply to admins. The ruleset is recorded in [main-ruleset.json](main-ruleset.json); editing that file does not automatically change GitHub settings.

Every PR must be up to date with `main` and pass:

- **Swift tests (debug/release):** Bluetooth parsing, workout metrics, timing, and analytics tests in both build configurations.
- **watchOS build:** compile the Watch app and all test targets, then build the release iOS distribution container with its embedded Watch app. Signing credentials are not needed.
- **Website validation:** rebuild Pages, check JavaScript syntax, validate local links/assets/anchors and public URLs, and reject outdated generated files.
- **Repository hygiene:** validate Actions workflows with actionlint and scan Git history with Gitleaks.
- **checks:** fail if any required job fails, is cancelled, or is skipped.

CI compilation does not exercise Watch UI interactions or HealthKit permissions. Run the simulator tests and physical-device checks in the development documentation for changes to those flows.
