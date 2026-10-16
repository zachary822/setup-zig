# setup-zig

A GitHub Action that installs a Zig compiler and adds it to the `PATH` for later steps.

The action reads [index.json](https://ziglang.org/download/index.json), selects the build for the runner OS and architecture, does a check of the SHA-256 checksum, and extracts it into the runner tool cache.

## Usage

```yaml
steps:
  - uses: actions/checkout@v4
  - uses: zachary822/setup-zig@v1
    with:
      version: 0.15.2
  - run: zig build test
```

## Inputs

| Name        | Required | Default                                     | Description                                                   |
| ----------- | -------- | ------------------------------------------- | ------------------------------------------------------------- |
| `version`   | yes      |                                             | A key from `index.json`, for example `0.15.2` or `master`.    |
| `index-url` | no       | `https://ziglang.org/download/index.json`   | The download index to use, for example a mirror.              |

## Outputs

| Name      | Description                                                        |
| --------- | ------------------------------------------------------------------ |
| `version` | The exact installed version (resolves `master` to a dev version).  |
| `zig-dir` | The directory that contains the `zig` executable.                  |

## Supported runners

Linux, macOS and Windows on x86_64 and aarch64. The action also supports 32-bit x86 and ARM if the Zig release has a build for them. The runner must have `bash`, `curl`, `jq`, `tar` and (on Windows) `unzip`. All GitHub-hosted runners have these tools.
