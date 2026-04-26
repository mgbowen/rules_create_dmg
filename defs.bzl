"""Rules for creating macOS DMG files.

This module provides the `macos_dmg` rule, which packages a macOS application
bundle into a disk image (.dmg) using the `create-dmg` tool.
"""

load("@bazel_lib//lib:copy_file.bzl", "COPY_FILE_TOOLCHAINS", "copy_file_action")
load("@bazel_skylib//lib:paths.bzl", "paths")
load("@rules_apple//apple:providers.bzl", "AppleBundleInfo")

def _macos_dmg_impl(ctx):
    if AppleBundleInfo not in ctx.attr.src:
        fail("src must be a macos_application rule")

    src_bundle_info = ctx.attr.src[AppleBundleInfo]
    src_bundle_name = src_bundle_info.bundle_name
    src_file = ctx.file.src

    out_file = ctx.outputs.out
    if out_file == None:
        out_file = ctx.actions.declare_file(src_bundle_name + ".dmg")

    # The name of the unzipped bundle, e.g. `MyMacUtility.app`.
    bundle_dir_name = src_bundle_name + src_bundle_info.bundle_extension

    working_dir_name = ctx.label.name + "_working_dir"

    # macos_application() creates a .zip containing the app bundle. For
    # create-dmg to process it, we first need to unzip the bundle.
    unzipped_dir = ctx.actions.declare_directory(paths.join(working_dir_name, "unzipped_dir"))

    unzip_args = ctx.actions.args()
    unzip_args.add("x", src_file.path)
    unzip_args.add("-d", unzipped_dir.path)

    ctx.actions.run(
        inputs = [src_file],
        outputs = [unzipped_dir],
        executable = ctx.executable._zipper,
        arguments = [unzip_args],
        mnemonic = "UnzipApp",
        progress_message = "Unzipping %s" % src_file.short_path,
    )

    initial_dmg = ctx.actions.declare_file(paths.join(working_dir_name, src_bundle_name + ".dmg"))

    create_dmg_args = ctx.actions.args()
    create_dmg_args.add(paths.join(unzipped_dir.basename, bundle_dir_name))
    create_dmg_args.add("--no-code-sign")
    create_dmg_args.add("--overwrite")
    create_dmg_args.add("--no-version-in-filename")
    create_dmg_args.add(".")

    create_dmg_inputs = [unzipped_dir]
    if ctx.file.license_file != None:
        license_file = ctx.actions.declare_file(paths.join(working_dir_name, "license.txt"))
        create_dmg_inputs.append(license_file)
        copy_file_action(
            ctx,
            ctx.file.license_file,
            license_file,
        )

    ctx.actions.run(
        inputs = create_dmg_inputs,
        outputs = [initial_dmg],
        executable = ctx.executable._create_dmg_tool,
        arguments = [create_dmg_args],
        mnemonic = "CreateDmg",
        progress_message = "Creating DMG %s" % out_file.short_path,
        env = {
            "BAZEL_BINDIR": ctx.bin_dir.path,
            "JS_BINARY__CHDIR": paths.join(ctx.label.package, working_dir_name),
        },
        execution_requirements = {"no-sandbox": "1"},
    )

    ctx.actions.symlink(
        output = out_file,
        target_file = initial_dmg,
    )

    return [DefaultInfo(files = depset([out_file]))]

macos_dmg = rule(
    implementation = _macos_dmg_impl,
    attrs = {
        "src": attr.label(allow_single_file = True, mandatory = True),
        "out": attr.output(),
        "license_file": attr.label(allow_single_file = True),
        "_create_dmg_tool": attr.label(
            default = Label("//:create_dmg_tool"),
            executable = True,
            cfg = "exec",
        ),
        "_zipper": attr.label(
            default = Label("@bazel_tools//tools/zip:zipper"),
            cfg = "exec",
            executable = True,
        ),
    },
    toolchains = COPY_FILE_TOOLCHAINS,
)
