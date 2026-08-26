# InsureGPTE Development Workflow

**Status:** Approved
**Effective date:** 2026-08-10

## Protected main branch

`main` is the stable integration and release branch. Routine development and
experimentation must not be performed directly on `main`.

## Test-level development

Each next-level feature begins on a dedicated test branch created from the
latest clean `main`, using a name such as:

```text
test/<feature-name>
```

The test branch should use an isolated Git worktree so development files,
generated previews, and uncommitted changes cannot alter the main checkout.

## Promotion sequence

1. Pull the latest remote `main` into the clean main checkout.
2. Create a dedicated `test/<feature-name>` branch and isolated worktree.
3. Implement database, RPC, frontend, testing, and documentation changes there.
4. Run the complete automated suite and feature-specific verification.
5. Complete controlled runtime testing in the trial/test environment.
6. Review the branch diff and confirm rollback readiness.
7. Push the test branch and open a pull request into `main`.
8. Merge only after successful testing and approval.
9. Pull the merged `main` and confirm a clean working tree.

Direct pushes to `main`, unreviewed runtime changes, and testing against the
production database are prohibited.
