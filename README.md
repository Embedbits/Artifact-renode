# Renode – Artifact

Portable binary distribution of **Renode**, Antmicro's open-source simulation and virtual development framework for embedded systems, together with **renode-test**, its Robot Framework based test runner used for integration/implementation testing of simulated firmware. This repository is consumed by the Embedbits Platform Artifact Handler to locate, download, verify, and configure Renode in downstream embedded projects.

This repository is split into three branches/refs by role — the `main` (`master`) branch you are reading now holds only this documentation; the handler scripts live on the `Core` branch, and versioned binaries are published as GitHub Releases anchored to the `Bin` branch.

---

## Repository contents

```
main / master
└── README.md                     ← This document — no other content

Core
└── ArtifactConfig.cmake          ← Renode integration logic (artifact init, version lookup, test helper)

Bin  (anchor branch — no tracked binary files)
└── (empty commits only; each release tag points here)
```

---

## Role in the platform

This repository is one of several artifact distributions within the Embedbits platform. The overall flow is:

```
GitHub (Embedbits)
──────────────────────────────────────────────────────────
Artifact-renode
  main / master →  README only (this document)
  Core          →  ArtifactConfig.cmake
  Bin           →  Anchor branch (empty commits)
  Releases      →  renode-<version>-<platform>.zip + .hash
                    tagged Bin/<version>-<platform>  (platform: Win / Unix)
```

`Renode_Importer.sh` publishes each Renode version as a **GitHub Release** — tagged `Bin/<version>-<platform>` — rather than as a file committed to the `Bin` branch. The `Bin` branch itself only carries empty anchor commits for the release tags to point at.

The Platform Artifact Handler in downstream projects references the `Core` branch as a Git submodule. At CMake configure time it reads `ArtifactConfig.cmake` to determine which release to fetch, then downloads and verifies the matching release asset for the current platform.

---

## Branch structure

| Branch / Ref | Content |
|---|---|
| `main` / `master` | This README only — no functional content |
| `Core` | `ArtifactConfig.cmake` handler script for consuming the artifact |
| `Bin` | Anchor branch only — no binaries are committed here |
| Release tag `Bin/<version>-<platform>` | GitHub Release carrying the actual `.zip` binary and its `.hash` checksum file as release assets, for `platform` ∈ `Win`, `Unix` |

> **Note:** The Embedbits Artifact Handler protocol itself is not tied to GitHub Releases — that is simply how the GitHub-hosted importer scripts happen to publish binaries. On a Git host without an equivalent Releases API, the handler also supports packaged binaries committed directly as tracked files on the `Bin` branch, tagged per version/platform (`Bin/<version>-<platform>`) instead of uploaded as release assets. The CMake handler resolves either form transparently.

> **⚠️ No macOS (DarwinARM) releases:** as of the current Renode release line, upstream only publishes macOS builds as `.dmg` disk images, not as a plain tar/zip archive. `Renode_Importer.sh` therefore does not import a `DarwinARM` platform until upstream ships a plain archive (or `.dmg` unpacking support is added to `Common.sh`).

---

## ⚠️ Fetching a release

Binaries are **not** stored as tracked files in `Bin` — clone the `Core` branch for the handler scripts, and download binaries as release assets for a specific tag instead of cloning the `Bin` branch.

```bash
# Core handler scripts
git clone --branch Core --single-branch --depth=1 <repository_url> renode-core

# Binary + checksum for one specific version/platform (GitHub Release asset)
gh release download Bin/1.16.1-Unix --repo Embedbits/Artifact-renode --pattern "renode-1.16.1-Unix.*"
```

---

## Included components

| Component | Description |
|---|---|
| `renode` | Main simulator/CLI: boots and runs simulated hardware platforms, scripting console, GDB server |
| `renode-test` | Robot Framework test runner: executes `.robot` integration/implementation test suites against a simulated target and produces XML/HTML reports |

---

## Usage

The artifact is installed automatically during the **Artifacts setup phase** via:

```bash
cmake -P Artifacts/Renode/ArtifactConfig.cmake
```

The script ensures the Renode binaries are available, unpacks the archive if needed, and adds both tools to the system `PATH` for subsequent build/test steps.

### Handler functions

```cmake
renode_ArtifactInit(ARTIFACT_BIN_PATH)
```
Initializes the artifact: locates the `renode` and `renode-test` binaries and exposes them via the `RENODE_EXECUTABLE` / `RENODE_TEST_EXECUTABLE` cache variables.

```cmake
renode_GetArtifactVersion()
```
Returns the version of the currently resolved Renode binaries (via `renode -v`).

```cmake
Renode_AddTest(TEST_NAME ROBOT_FILE)
```
Registers a CTest test that runs the given `.robot` suite through `renode-test`.

---

## Versioning

Artifact versions correspond directly to **official Renode release versions**:

```
1.14.0, 1.15.0, 1.15.3, 1.16.0, 1.16.1, ...
```

New versions are published by `Renode_Importer.sh` in the [`GithubArtifactsHandler`](https://github.com/Embedbits/GithubArtifactsHandler) repository, which downloads the official Renode portable binaries, packages them as `.zip` archives with SHA-256 verification, and publishes them as a GitHub Release tagged `Bin/<version>-<platform>` — the `Bin` branch itself only advances via an empty anchor commit that the tag points to.

---

## Notes

- **No installation required** — the `portable-dotnet` builds are self-contained (bundled .NET runtime), no separate .NET/mono install needed on the target machine.
- **Offline use** is supported once the artifact is cached locally.
- In **Azure DevOps pipelines**, caching the artifact folder is recommended to reduce build time.
- macOS (DarwinARM) is currently unsupported by the importer — see the note above.

---

## License

Renode is distributed under the **MIT License**.
For details, see: [https://github.com/renode/renode/blob/master/LICENSE](https://github.com/renode/renode/blob/master/LICENSE)

---

## Authors

- **Mr.Nobody** — [embedbits.com](https://embedbits.com)

Contributions are welcome! Please open a pull request.

---

## 🌐 Useful Links

- [Renode Official Site](https://renode.io/)
- [Renode GitHub Repository](https://github.com/renode/renode)
- [Renode GitHub Releases](https://github.com/renode/renode/releases)
- [Renode Testing Documentation](https://renode.readthedocs.io/en/latest/introduction/testing.html)
- [Azure DevOps](https://azure.microsoft.com/en-us/services/devops/)
- [Embedbits Github](https://github.com/Embedbits)
- [CC BY-NC 4.0 License](https://creativecommons.org/licenses/by-nc/4.0/)
