[![License](https://img.shields.io/:license-apache-blue.svg)](http://www.apache.org/licenses/LICENSE-2.0.html)
[![CII Best Practices](https://bestpractices.coreinfrastructure.org/projects/73/badge)](https://bestpractices.coreinfrastructure.org/projects/73)
[![Puppet Forge](https://img.shields.io/puppetforge/v/simp/crypto_policy.svg)](https://forge.puppetlabs.com/simp/crypto_policy)
[![Puppet Forge Downloads](https://img.shields.io/puppetforge/dt/simp/crypto_policy.svg)](https://forge.puppetlabs.com/simp/crypto_policy)
[![Build Status](https://travis-ci.org/simp/pupmod-simp-crypto_policy.svg)](https://travis-ci.org/simp/pupmod-simp-crypto_policy)

# pupmod-simp-crypto_policy

#### Table of Contents

<!-- vim-markdown-toc GFM -->

* [Description](#description)
* [Setup](#setup)
  * [What crypto_policy affects](#what-crypto_policy-affects)
* [Usage](#usage)
* [Reference](#reference)
* [Limitations](#limitations)
* [Development](#development)

<!-- vim-markdown-toc -->

## Description

Manage, and provide information about, the system-wide crypto policies.

See `update-crypto-policy(8)` for additional information.

## Setup

### What crypto_policy affects

Manages the system-wide crypto policy.

Applications may opt-in, or out, of usage by following the steps outlined in
`update-crypto-policy(8)`.

## Usage

    class { 'crypto_policy': }

## Reference

See [REFERENCE.md](./REFERENCE.md) for the full module reference.

## Limitations

SIMP Puppet modules are generally intended for use on Red Hat Enterprise
Linux and compatible distributions, such as CentOS. Please see the
[`metadata.json` file](./metadata.json) for the most up-to-date list of
supported operating systems, Puppet versions, and module dependencies.

## Development

Please read our [Contribution Guide](https://simp.readthedocs.io/en/stable/contributors_guide/index.html).

If you find any issues, they can be submitted to our
[JIRA](https://simp-project.atlassian.net).
