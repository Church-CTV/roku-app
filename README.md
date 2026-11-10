# Church CTV — Roku application

Permissions, commercial licensing, sales and support: see [SUPPORT.md](SUPPORT.md).

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

See `OMISSIONS.md` and `THIRD-PARTY-NOTICES.md`. License and contribution/security
policies require owner review before publication.
