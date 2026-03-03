# release-actions

Shared GitHub Actions and reusable workflows for Aiden pre-release pipelines.

## Recommended Entry

Use reusable workflow: `.github/workflows/pre-release-entry.yml`.

Caller repositories only need one `uses` entry instead of calling each action step manually.

### Windows caller example

```yaml
jobs:
  prerelease:
    uses: zhangyu528/release-actions/.github/workflows/pre-release-entry.yml@main
    with:
      platform: windows
      base_version: ${{ inputs.base_version }}
      channel: ${{ inputs.channel }}
      windows_solution_path: Aiden.sln
      windows_icon_source: Aiden.TrayMonitor/Assets/aiden.ico
      windows_helper_script_sources: |
        Aiden.RuntimeAgent/scripts/download-vm.ps1
        Aiden.RuntimeAgent/scripts/download-collector.ps1
      windows_postinstall_launch_exe: Aiden.TrayMonitor.exe
      windows_autorun_exe: Aiden.RuntimeAgent.exe
    secrets:
      github_token: ${{ secrets.GITHUB_TOKEN }}
      signpath_api_token: ${{ secrets.SIGNPATH_API_TOKEN }}
```

Windows flow publishes built-in targets from solution: `Aiden.TrayMonitor` -> `artifacts/stage/tray`, `Aiden.RuntimeAgent` -> `artifacts/stage/agent`.
Windows install behavior is configurable via entry inputs: `windows_postinstall_launch_exe` and `windows_autorun_exe`.
Windows app build also writes release-computed version into binaries:
- `Version` and `InformationalVersion`: full semantic version (for example `0.1.0-rc.3`)
- `AssemblyVersion` and `FileVersion`: numeric 4-part version (for example `0.1.0.3`)

### macOS caller example

```yaml
jobs:
  prerelease:
    uses: zhangyu528/release-actions/.github/workflows/pre-release-entry.yml@main
    with:
      platform: macos
      base_version: ${{ inputs.base_version }}
      channel: ${{ inputs.channel }}
      macos_workspace_path: Aiden.xcworkspace
      macos_project_path: ''
      macos_scheme: Aiden
      macos_runtime_helper_sources: |
        scripts/download-vm.sh
        scripts/download-collector.sh
      macos_pkg_identifier: com.aiden.app
    secrets:
      github_token: ${{ secrets.GITHUB_TOKEN }}
      apple_id: ${{ secrets.APPLE_ID }}
      apple_app_password: ${{ secrets.APPLE_APP_PASSWORD }}
```

macOS app build also writes release-computed version into bundle build settings:
- `MARKETING_VERSION`: numeric `major.minor.patch` (for example `0.1.0`)
- `CURRENT_PROJECT_VERSION`: prerelease sequence or `0` (for example `3` for `0.1.0-rc.3`)
macOS installer/checksum output paths and staging layout are now internal defaults in release-actions.

## RC Signing Requirements

When `channel=rc`, signing steps are enabled automatically.

### Windows (`platform=windows`)

Required repository/org vars:
- `SIGNPATH_ORGANIZATION_ID`
- `SIGNPATH_PROJECT_SLUG`
- `SIGNPATH_SIGNING_POLICY_SLUG`
- `SIGNPATH_UNSIGNED_ARTIFACT_CFG`
- `SIGNPATH_INSTALLER_ARTIFACT_CFG`

Required secret:
- `SIGNPATH_API_TOKEN` (pass to reusable workflow as `signpath_api_token`)

### macOS (`platform=macos`)

Required repository/org vars:
- `APPLE_SIGNING_IDENTITY`
- `APPLE_INSTALLER_SIGNING_IDENTITY`
- `APPLE_TEAM_ID`

Required secrets:
- `APPLE_ID`
- `APPLE_APP_PASSWORD`

## Layout

- `.github/workflows/pre-release-entry.yml`: Single reusable pre-release entry
- `actions/common/*`: Cross-platform building blocks
- `actions/windows/*`: Windows-specific actions
- `actions/macos/*`: macOS-specific actions
- `examples/*`: End-to-end examples

## Examples

- Caller Windows single-entry: `examples/caller-windows-entry.yml`
- Caller macOS single-entry: `examples/caller-macos-entry.yml`
