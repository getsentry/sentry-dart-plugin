> [!IMPORTANT]
> This release bundles [Sentry CLI v3](https://github.com/getsentry/sentry-cli/blob/master/CHANGELOG.md#300). Sentry SaaS users don't need to change anything.
>
> **Self-hosted** users need Sentry 24.11.1 or newer. If your Sentry URL is only set in `.sentryclirc`, also set `url` in the plugin config or `SENTRY_URL`, otherwise uploads go to sentry.io.
>
> To stay on Sentry CLI v2, set `sentry_cli_version: 2.58.6` and delete the cached `sentry-cli` binary in `.dart_tool/pub/bin/sentry_dart_plugin/` (or your `bin_dir`).
