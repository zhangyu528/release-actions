# release-actions

Shared GitHub Actions for cross-platform Aiden pre-release pipelines.

## Available Actions

### `compute-next-prerelease-tag`

Computes the next sequential prerelease tag, respecting existing git tags.

```yaml
- uses: zhangyu528/release-actions/compute-next-prerelease-tag@main
  id: tag
  with:
    base_version: 'v0.1.0'
    channel: 'alpha'       # optional, default: alpha
# Outputs:
#   steps.tag.outputs.computed_tag  → v0.1.0-alpha.5
#   steps.tag.outputs.version       → 0.1.0-alpha.5
```

---

### `create-github-prerelease`

Creates a GitHub pre-release with auto-generated notes.

```yaml
- uses: zhangyu528/release-actions/create-github-prerelease@main
  id: release
  with:
    tag: 'v0.1.0-alpha.5'
    target_branch: 'main'  # optional, default: main
# Outputs:
#   steps.release.outputs.release_url
#   steps.release.outputs.release_upload_url
```

---

### `check-signpath-readiness`

Validates that all SignPath configuration variables are present before signing.

```yaml
- uses: zhangyu528/release-actions/check-signpath-readiness@main
  with:
    signpath_ready: ${{ vars.SIGNPATH_READY }}
    organization_id: ${{ vars.SIGNPATH_ORGANIZATION_ID }}
    project_slug: ${{ vars.SIGNPATH_PROJECT_SLUG }}
    signing_policy_slug: ${{ vars.SIGNPATH_SIGNING_POLICY_SLUG }}
    unsigned_artifact_cfg: ${{ vars.SIGNPATH_UNSIGNED_ARTIFACT_CFG }}
    installer_artifact_cfg: ${{ vars.SIGNPATH_INSTALLER_ARTIFACT_CFG }}
```

---

## Requirements

- PowerShell Core (`pwsh`) available on the runner
- `gh` CLI authenticated (for `create-github-prerelease`)
- `git` available on the runner (for `compute-next-prerelease-tag`)

## Used By

| Project | Platform |
|---------|----------|
| [aiden-windows](https://github.com/zhangyu528/aiden-windows) | Windows (win-x64) |
