# Church CTV — Roku application

Questions about this software: [open an issue](issues) - anyone with a GitHub account may, no approval and no fee. Permissions, commercial licensing, sales and support: [SUPPORT.md](SUPPORT.md). License: Church CTV Community Source License 1.0 ([LICENSE](LICENSE)), and what it does not claim is in [LICENSING-STATUS.md](LICENSING-STATUS.md).

A SceneGraph channel starter with configurable navigation, feed loading, playback,
settings, analytics and a QR-code component. This is a sanitized source snapshot,
not a production-ready distribution. Placeholder artwork is deliberately generic.

## Local setup

Use Node.js 24 and npm. Run `npm ci --ignore-scripts`, `npm test`,
`npm run build`, and `npm run validate`. The build writes `build/channel.zip`;
ImageMagick's `magick` command is optional and the build falls back to the
uncolored navigation image when unavailable. Tests primarily simulate behavior;
they do not prove Roku device compatibility. No device deployment runs in CI.

## Configuration and secrets

Review `config/default.json`, `config/schema.json`, and `manifest` before building.
Replace `example.invalid` URLs with endpoints you control, configure branding and
provide rights-cleared artwork. The bundled configuration is included in the
package: do not place passwords, tokens, signing keys or other secrets in it.
Analytics is disabled by default; enable it only after configuring an approved
endpoint and reviewing privacy obligations. Runtime config loading is implemented
in `source/ConfigLoader.bs` and `components/ConfigManager.brs`; validate the actual
integration for your server before relying on it.

Device profiles, signing and deployment automation are intentionally omitted.
For a separate deployment workflow, keep private hosts/users and credentials in
protected environment secrets or ignored local configuration, not source or
public variables. Signing keys are always secrets. Protect any
manual deployment with explicit approval and do not deploy from pull requests.
No deployment workflow is supplied or verified here.

See `OMISSIONS.md` and `THIRD-PARTY-NOTICES.md`. The QR component keeps its own
copyright and MIT-style notice inside `components/qrCode/qrCode.brs`; the single
installed production npm dependency has its text in `THIRD-PARTY-LICENSES.json`.
## License

This repository is licensed under the **Church CTV Community Source License,
Version 1.0** in `LICENSE` - source available, not OSI open source. In short: an
eligible church may run, modify and deploy it for its own worship and ministry
with no license fee, no channel or viewer cap and no obligation to buy hosting;
a church may hire ordinary technical help and use ordinary infrastructure;
anyone may build and run it locally to evaluate it or prepare a contribution;
and independent commercial operation, resale, white-label products and competing
managed hosting need separate rights from the owner. Deployed modifications carry
a share-back duty (section 7.2). Commercial and self-hosting licensing, and
church-eligibility confirmation, go to `dominick253@gmail.com`. Third-party
components keep their own licenses and notices, which are recorded but not
replaced by this license.

## Questions

Open an issue in this repository. Anyone may. Tell us the revision, the platform
and version, and what you expected versus what happened. Please keep credentials,
member or viewer data, customer names, private hostnames and unpatched security
problems out of public issues: security reports use the **Report a vulnerability**
form on the Security tab, and money, contract or permission matters go to
`dominick253@gmail.com`. There is no response-time promise; see `SUPPORT.md`.

