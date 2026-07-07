# AGENTS.md

This file provides guidance to AI agents when working with code in this repository.

## What this module does

`pupmod-simp-crypto_policy` is a SIMP Puppet module that manages the
**system-wide cryptographic policy** on Enterprise Linux 8/9/10 via the
`update-crypto-policies` framework (see `update-crypto-policies(8)`). It sets the
global policy (`DEFAULT`, `FIPS`, `FUTURE`, `LEGACY`, …), applies **subpolicies**,
lets sites define their own **custom subpolicies**, and exposes the live system
state back to Puppet through a custom fact.

The module is compliance-oriented (tagged `NIST`, `STIG`, `disa_stig`, `fips`)
and is **FIPS-aware**: on a FIPS-enabled system it forces the `FIPS` policy unless
explicitly overridden, because setting a weaker policy there could break crypto
or lock you out.

> **Danger surface:** there are known issues with `crypto-policies < 20190000`
> that can render a FIPS system inaccessible, and `force_fips_override` can
> deliberately weaken a FIPS box. Treat changes to policy selection and the
> `update` exec with care.

### Business logic

**`crypto_policy` (`manifests/init.pp`)** — the public entry point.

- **`ensure`** — the global policy to enforce. Its default is computed:
  `FIPS` when `$facts['fips_enabled']`, otherwise the current
  `crypto_policy_state.global_policy` fact, falling back to `DEFAULT`. You may
  append subpolicies inline (`POLICY:SUB1:SUB2`) but the `subpolicies` /
  `custom_subpolicies` parameters are the preferred, clearer path.
- **`subpolicies`** (`Array[String]`) and **`custom_subpolicies`** (`Hash`) —
  extra subpolicies to apply. `custom_subpolicies` maps a name to
  `{ content, ensure }`; each becomes a `crypto_policy::subpolicy` (a `.pmod`
  file under `/usr/share/crypto-policies/policies/modules/`) created **before**
  the policy is applied. Entries with `ensure => absent`/`false` are filtered out
  of the enforced set.
- The effective policy string `$_ensure` is assembled as
  `<global>:<sub1>:<sub2>…`. **FIPS handling:** if `fips_enabled`, `$_ensure` is
  hard-forced to `'FIPS'` *unless* `force_fips_override` is true (in which case
  the requested policy is applied even on a FIPS system — the documented WARNING).
- **Validation** — before applying, the requested global policy and each
  subpolicy are checked against the fact's `global_policies_available` /
  `sub_policies_available` (with `custom_subpolicies` keys merged in, since the
  fact may not have picked them up yet); an unknown policy/subpolicy `fail()`s
  with the list of valid values. **This whole apply-and-validate block only runs
  when the `crypto_policy_state` fact is populated** (`$_ensure` +
  `global_policies_available` + `sub_policies_available` all non-`undef`/non-`false`) —
  `manage_installation` (default `true`) may still install packages; if it installs
  `update-crypto-policies`, enforcement won't occur until a later run when facts refresh.
- **Application** — writes `/etc/crypto-policies/config` (`0644`,
  `selinux_ignore_defaults => true` to stop SELinux-context flapping) containing
  just the policy string, and declares `class { 'crypto_policy::update': }` with
  `command => "/usr/bin/update-crypto-policies --set ${_ensure}"`. The config file
  `notify`'s `crypto_policy::update`. `custom_subpolicies` are ordered before the update
  (`before => Class['crypto_policy::update']`) but do **not** currently notify it, so
  changing only a `.pmod` file won't trigger an update.

**`crypto_policy::install` (`manifests/install.pp`, private — `assert_private()`)**
— manages the `crypto-policies` and `crypto-policies-scripts` packages,
`ensure => 'latest'` by default (the README warns older versions are unsafe on
FIPS). Only included when `manage_installation` is true.

**`crypto_policy::update` (`manifests/update.pp`)** — a helper class holding the
`exec { 'update global crypto policy': refreshonly => true }` that actually runs
`update-crypto-policies --set`. Warns (and does nothing) if the `crypto_policy_state`
fact is absent. It also guards on `$crypto_policy::_ensure`, but that variable is not
set anywhere in this module, so the exec never runs as written.
`update-crypto-policies` binary ignores `/etc/crypto-policies/config`, so the
explicit `--set` is required — do not "simplify" it away.

**`crypto_policy::subpolicy` (`manifests/subpolicy.pp`, define)** — manages a
single `${subpolicy_name}.pmod` file. `ensure` accepts `true`/`false`/`'present'`/
`'absent'`; when present, `content` is **required** (`fail()`s otherwise) and is
written verbatim — **no validation is performed on subpolicy content**, the caller
owns its correctness.

**`crypto_policy_state` fact (`lib/facter/crypto_policy_state.rb`)** — confined to
Linux with `update-crypto-policies` present. Returns a hash:
`global_policy` (from `--show`), `global_policy_applied` (from `--is-applied`),
`global_policies_available` (globbed `*.pol` files, with an EL8.0 directory
fallback), and `sub_policies_available` (globbed `*.pmod` files). This fact is the
source of truth the manifests validate against.

### Gotchas / non-obvious details

- **`validate_policy` is currently a dead parameter.** It is declared (default
  `true`) and documented as disabling `$ensure` validation, but nothing in
  `init.pp` references it — validation is actually gated on the *fact* being
  populated, not on this flag. Don't assume setting it changes behavior; wire it
  up if that's the intent.
- This module does **not** depend on `simp/simplib` and uses **no**
  `simp_options::*` lookup seam — unlike most SIMP modules it is essentially
  standalone. Don't add `simplib::lookup` defaults by reflex.

## Dependencies

- `puppetlabs/stdlib` (`>= 8.0.0 < 10.0.0`) — the **only** module dependency
  (provides `Stdlib::Absolutepath`).
- Runtime: **`openvox`** (`>= 8.0.0 < 9.0.0`) — note `metadata.json`
  `requirements` targets openvox, not stock `puppet`.
- Supported OS: RedHat/OracleLinux/Rocky/AlmaLinux **8/9/10** and CentOS **9/10**
  (EL7 already removed; see `metadata.json`).

## Repository layout

- `manifests/init.pp` — public `crypto_policy` class (policy selection, FIPS
  handling, validation, config-file application).
- `manifests/install.pp` — private package-install class.
- `manifests/update.pp` — non-private helper wrapping the `update-crypto-policies`
  exec.
- `manifests/subpolicy.pp` — `crypto_policy::subpolicy` define (`.pmod` files).
- `lib/facter/crypto_policy_state.rb` — the `crypto_policy_state` custom fact.
- `spec/classes/`, `spec/unit/facter/` — rspec-puppet + fact unit tests.
- `spec/acceptance/suites/default/` — beaker acceptance suite; `nodesets/` holds
  the (many) per-OS/docker node definitions.
- `REFERENCE.md` — generated Puppet Strings reference (do not hand-edit; regenerate).
- `metadata.json` — module metadata, dependencies, and supported OS matrix.

## Common commands

This module uses `puppetlabs_spec_helper (~> 8)` + `simp-rake-helpers (~> 5)` +
`simp-beaker-helpers (~> 2)`; rake tasks come from `Simp::Rake::Pupmod::Helpers`
(see `Rakefile`).

```sh
bundle install

# Unit tests (rspec-puppet + the fact spec)
bundle exec rake spec

# A single spec file
bundle exec rspec spec/unit/facter/crypto_policy_state_spec.rb

# Lint / style
bundle exec rake lint
bundle exec rake rubocop

# Regenerate REFERENCE.md after changing manifest docstrings
bundle exec puppet strings generate --format markdown --out REFERENCE.md

# Acceptance tests (beaker; needs a hypervisor/docker — see spec/acceptance/nodesets)
bundle exec rake beaker:suites[default]
```

## Conventions

- **Preserve the FIPS safety behavior.** On a FIPS-enabled node the module must
  keep forcing `FIPS` unless `force_fips_override` is explicitly set. Do not relax
  that guard.
- **Keep the explicit `--set`** in `crypto_policy::update` — writing
  `/etc/crypto-policies/config` alone is not sufficient on EL10.
- Validate against the fact: policy/subpolicy names are checked against
  `crypto_policy_state`, so new capabilities should keep the fact and the
  validation lists in sync.
- Subpolicy `content` is applied verbatim with no validation — document that the
  caller is responsible for its correctness.
- Keep manifest parameter `@param` docstrings current — `REFERENCE.md` is
  generated from them.
