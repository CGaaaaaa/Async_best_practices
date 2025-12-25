## PR Checklist

- [ ] Did you add/modify tests for your change?
- [ ] Does the code compile? (`moon check`)
- [ ] Are infra/third-party calls wrapped with timeout + retry?
- [ ] Are long-running tasks protected or executed within TaskGroup?
- [ ] Is concurrency limited using semaphores where appropriate?
- [ ] Did you update README.mbt.md or other docs if needed?

If your change affects infra wrappers, please add/modify tests and update snapshots (`moon test --update`), then include the snapshot diff in the PR description.


