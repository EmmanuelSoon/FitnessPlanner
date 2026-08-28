## Tools

adb is at: C:\Users\emman\AppData\Local\Android\Sdk\platform-tools\adb.exe

## Working Style

1. Ask, don't assume. If something is unclear, ask before writing a single line. Never make silent assumptions about intent, architecture, or requirements.
2. Simplest solution first. Always implement the simplest thing that could work. Do not add abstractions or flexibility that weren't explicitly requested.
3. Don't touch unrelated code. If a file or function is not directly part of the current task, do not modify it, even if you think it could be improved.
4. Flag uncertainty explicitly. If you are not confident about an approach or technical detail, say so before proceeding. Confidence without certainty causes more damage than admitting a gap.
5. I'm always open to ideas on better ways to do things. Please don't hesitate to suggest a better way, or one that has long lasting impact over a tactical change. (as a few examples)

## Planning Workflow

6. Before starting any non-trivial task — whether or not you are formally in Plan Mode — write a plan and add it to the plans folder first for the user to review, before implementation. All plans should be placed in the plans folder, named `NNN-DDMMYY-<title of plan>`. The plan should always be numbered after the last number. If the folder has `001-200526-xxx.md`, `002-200526-xxx.md`, the next one is `003-210526-xxx.md` even if the date is different.

## Git & Version Control

- Never commit or push without asking first, even if the changes look complete and correct.
- PR titles must use a Conventional Commits prefix (`feat:`, `fix:`, `chore:`, etc.) since this repo squash-merges — the PR title becomes the commit message.

## Testing Conventions

### TDD Workflow
- Always write failing tests BEFORE implementation, for new features and bug fixes
- Use AAA pattern: Arrange-Act-Assert
- One assertion per test when possible
- Exception: backfilling test coverage onto existing, already-implemented code (e.g. plan 016) does not follow red-green TDD — those tests are written against existing behavior and are expected to pass immediately, not fail first

### Test-First Rules
- New feature: write tests first. They should FAIL initially (no implementation exists). Only after tests are written, implement minimal code to pass.
- Bug fix: write a failing regression test that reproduces the bug first, then fix the code to make it pass.
- Refactor: no new tests required unless behavior changes, but all existing tests must stay green.

### Running Tests
- Run tests with `flutter test`
- Run the analyzer with `flutter analyze`
- Both should be green before considering a task done
