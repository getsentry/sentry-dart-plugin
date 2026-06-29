# Contributing to sentry-dart-plugin

We love pull requests from everyone. 
We suggest opening an issue to discuss bigger changes before investing on a big PR.

## Requirements

The project currently requires you run Dart version >= `2.12.0`.

## Run

To build:

```shell
dart compile aot-snapshot bin/sentry_dart_plugin.dart
```

To run:

```shell
dart run

// or

dartaotruntime bin/sentry_dart_plugin.aot
```

## CI

Build is automatically run against branches and pull requests via GH Actions.

# Pull Requests

If a PR should notify a linked issue after release, use a GitHub closing keyword in the PR
description, such as `Fixes #123`, `Closes #123`, or `Resolves #123`. Release notification
automation only comments on issues GitHub recognizes as closed by the released PR; mentioning an
issue without a closing keyword is not enough.

## Branch Naming

Use the format `git-username/type/short-description` for branch names.

* `git-username` should match your Git username or GitHub handle.
* `type` should be a conventional change type according to [conventional commits](https://www.conventionalcommits.org/) such as `feat`, `fix`, `docs`, `test`, or `chore`.
* `short-description` should be lowercase, hyphen-separated, and describe the change.

For example: `octocat/feat/add-http-timeout`.

## Changelog

Changelogs are generated automatically during the release process using
[craft](https://github.com/getsentry/craft). The policy is defined in
[`.github/release.yml`](.github/release.yml).

PR titles must follow [Conventional Commits](https://www.conventionalcommits.org/) format (e.g.,
`feat(scope): Add feature`, `fix: Handle null`) since craft uses them to categorize entries and
determine the semver bump. No manual changelog entries are needed. A changelog preview is posted on
each PR so you can verify how the entry will look before merging.

If a PR should be excluded from the changelog, apply the `skip-changelog` label.

If a PR should notify a linked issue after release, use a GitHub closing keyword in the PR
description, such as `Fixes #123`, `Closes #123`, or `Resolves #123`. Release notification
automation only comments on issues GitHub recognizes as closed by the released PR; mentioning an
issue without a closing keyword is not enough.

### Custom Changelog Entries from PR Descriptions

By default, the changelog entry for a PR is generated from its title. However, PR authors can
override this by adding a "Changelog Entry" section to the PR description. This allows for more
detailed, user-facing changelog entries without cluttering the PR title.

Add a markdown heading (level 2 or 3) titled "Changelog Entry" to your PR description, followed by
the desired changelog text:

```markdown
### Description

Add `foo` function, and add unit tests to thoroughly check all edge cases.

### Motivation & Context

Closes #123

### Changelog Entry

Add a new function called `foo` which prints "Hello, world!"
```

The text under "Changelog Entry" will be used verbatim in the changelog instead of the PR title. If
no such section is present, the PR title is used as usual.


# AI Use

You are welcome to use whatever tools you prefer for making a contribution. However, any changes you propose have to be reviewed and tested by you, a human, first, before you submit a pull request with them for the Sentry team to review. If we feel like that did not happen, we will close the PR outright. For example, we will not review visibly AI-generated PRs from an agent instructed to look for and "fix" open issues in the repo. This aligns with our SDK principle: [every line has an owner](https://develop.sentry.dev/sdk/getting-started/principles/#every-line-has-an-owner).
