# Release Pins

Tracks every published `tuned-builds` release: which repo commit it was
built from, which exact `rapids-cmake` commit it was configured against
(`-Drapids-cmake-sha=...`, see `tuned/build.sh`), and which `zbrad/raft`
release it was built against (`resolve_raft_release()` in `tuned/build.sh`
downloads a specific raft release tag — see that repo's own
`tuned/docs/RELEASE_PINS.md` for what's *in* the raft side of a pairing).
Update this table as part of publishing a release — add a row before or
right after running `tuned/package.sh` (which packages *and* publishes
here, unlike raft's separate `package.sh`/`release.sh`).

Why this exists: `rapids-cmake` is fetched unpinned by default
(`RAPIDS.cmake` falls through to `RAPIDS_BRANCH`, which upstream sets to
`main` — an always-moving target). Two builds done at different times can
silently resolve different transitive dependency versions from it — hit
for real 2026-09-08: this repo's build (fresh) and `zbrad/raft`'s build
(a few hours earlier) disagreed on `rapids_logger` (0.3.0 vs 0.2.3),
breaking this repo's configure with a duplicate `rapids_logger::rapids_logger`
ALIAS target, regardless of whether raft was consumed via its published
release or a local install tree — the mismatch is about *when* each
repo's `rapids-cmake` fetch happened, not how raft gets consumed.
Pinning `rapids-cmake-sha` (kept identical to raft's own pin, by hand)
fixes new builds; this table is how anyone — including a future session —
can look at an already-published release and know exactly what it was
built against, or reproduce it later without re-deriving anything.

To fetch the exact rapids-cmake source a row references:
```
https://github.com/rapidsai/rapids-cmake/archive/<rapids-cmake sha>.zip
```
(the same URL `-Drapids-cmake-sha=<sha>` causes `RAPIDS.cmake` to fetch
internally — see that file's `rapids-cmake-value-to-clone` logic).

| Release tag | Commit (this repo) | rapids-cmake pin | Built against raft release | Date | Notes |
|---|---|---|---|---|---|
