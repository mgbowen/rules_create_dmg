# rules_create_dmg

Bazel rules for creating macOS DMG files using
[create-dmg](https://github.com/sindresorhus/create-dmg) by
[sindresorhus](https://github.com/sindresorhus).

This module provides a `macos_dmg` rule that automates the process of packaging
a macOS application bundle into a disk image.

## Installation

Add the following to your `MODULE.bazel`:

```starlark
bazel_dep(name = "rules_create_dmg", version = "1.0.0")
git_override(
    module_name = "rules_create_dmg",
    # You may wish to pin this to a specific commit using `commit = "..."`.
    branch = "main",
    remote = "https://github.com/mgbowen/rules_create_dmg.git",
)
```

## Usage

Load the rule and apply it to a `macos_application` target:

```starlark
load("@rules_apple//apple:macos.bzl", "macos_application")
load("@rules_create_dmg//lib:defs.bzl", "macos_dmg")

macos_application(
    name = "MyApp",
    bundle_id = "com.example.MyApp",
    infoplists = ["Info.plist"],
    minimum_os_version = "12.0",
    deps = [":main_lib"],
)

macos_dmg(
    name = "MyApp_dmg",
    src = ":MyApp",
    license_file = "LICENSE.txt",
)
```

## Reference

### macos_dmg

| Attribute | Description |
| :--- | :--- |
| `src` | **Mandatory.** A label pointing to a `macos_application` rule. |
| `out` | **Optional.** The name of the output DMG file. If not specified, it defaults to `{bundle_name}.dmg`. |
| `license_file` | **Optional.** A text file containing a license agreement that the user must accept before the DMG is mounted. |
