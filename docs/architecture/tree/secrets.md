# `secrets/`

> **Kind:** Secret material (gitignored live values)  
> **Measured:** 56 tracked files — 14× `.md`, 3× `.json`, 2× `.gitkeep`, 2× `.yaml`, 2× `.p8`

## Shape

| Path | Files |
|---|---:|
| `secrets/sample/` | 54 |
| (files at the root) | 2 |

## Subsections

| Unit | Files | Page |
|---|---:|---|
| `secrets/sample/` | 54 | [sample](secrets/sample.md) |

## Docs in the tree

_Authored beside the code, where the module's own consumers read them._

| Path | |
|---|---|
| `secrets/sample/README.md` | secrets/sample/ — OSS-safe schema-as-code |
| `secrets/sample/SETUP_CHECKLIST.md` | Secrets Setup Checklist |

## Guides

_Authored in depth, living in this area's own directory._

- [Contributor Secrets Bootstrap](secrets/contributor-onboarding.md)
- [Secrets Management - Complete Guide](secrets/management.md)
- [Secrets Manager](secrets/manager.md)

<!-- tree-scaffold:end -->
## Significance

Secret material. `secrets/live/` is **gitignored and fork-owned**; `secrets/sample/` is the committed
shape a contributor copies from, so the layout is discoverable without any real value being present.

**Two intake paths, both deliberate.** An OSS fork copies `sample/` and fills it in. A
framework-managed project runs `/secrets pull`, which materialises from a SOPS+age vault to the
canonical paths declared in `secrets/LAYOUT.yaml`. Every consumer — Fastlane, the workflows, the dev
build — resolves through that layout rather than hardcoding a path, so moving a secret is one edit.

**A fork's own build-time keys still go through the layout — via app-profile, not a hand edit.**
`LAYOUT.yaml` is template-owned, so a fork never edits it. A `network.build_config_fields` row that
names a `secret_alias:` is projected by `syncForkConfig` into the generated `syncForkConfig:fork-secrets`
region of the fork-owned `secrets/fork-layout.yaml` as a `kind: value` row (`fork_build_config: true`),
which every reader merges on top of `LAYOUT.yaml`. That one row is what every reader needs:
`needs-generate` lists the alias in `secrets-manifest.yaml` (so `/secrets pull` materialises it), the
release workflow's `vault_plan` decrypts it into `secrets/live/build-config/`, and the generated
`BuildKonfig` field reads it with `readSecretValue()`. Without `secret_alias:` the field is read from
the env var / `local.properties` only, and a CI release compiles it as `""`. Add
`required_in_release: true` (and optionally `required_prefix:`) to make a release build fail instead;
`product-health` NAP-15 checks all of this stays generated.

The projection spans three sync units (`build-logic` writes the row, `deployment` consumes it, `scripts`
checks it), so a fork that syncs only some of them can hold half of it. Two guards make that loud instead
of an empty key: `syncForkConfig` fails on a `build_config_fields` key it does not know
(`unknownBuildConfigFieldKeys`, so a build-logic older than the app-profile cannot skip one), and
`build_secrets.rb` (`assert_build_config_secrets!`, run by `vault-plan` and `needs-generate`) refuses a
`secret_alias:` that has no layout row — the check ships in `deployment/`, beside the code that needs the row.

**A value must never reach a transcript or a log.** Metadata always suffices to prove materialisation:
`test -f`, `wc -c`, `shasum`. If a check appears to need the value itself, the check is wrong.
