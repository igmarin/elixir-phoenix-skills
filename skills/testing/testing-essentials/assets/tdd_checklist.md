# TDD Checklist

Before writing any implementation code, verify:

## RED Phase
- [ ] Test file exists at correct path (`test/my_app/context_test.exs`)
- [ ] Test uses correct ExUnit case (`DataCase`, `ConnCase`, `ChannelCase`)
- [ ] `async: true` where safe (no shared mutable state)
- [ ] Test has a clear `describe` block and descriptive `test` name
- [ ] Test uses data fixtures (not seeded DB data)
- [ ] `mix test test/path/to/file_test.exs` FAILS
- [ ] Failure is for the correct reason (UndefinedFunctionError, not SyntaxError/File.Error)

## GREEN Phase
- [ ] Minimal implementation change proposed and user-approved
- [ ] Implementation is the smallest change to make the test pass
- [ ] `mix test test/path/to/file_test.exs` PASSES
- [ ] Only the target test is affected
- [ ] No unrelated code changes introduced

## REFACTOR Phase
- [ ] `mix test` passes full suite
- [ ] Code follows project conventions (pattern matching, pipe, with)
- [ ] No duplicated code in the new implementation
- [ ] `@doc` added to public functions

## QUALITY GATE (Before Commit)
- [ ] `mix format --check-formatted` passes
- [ ] `mix credo --strict` passes (no violations)
- [ ] `mix test` passes full suite
- [ ] `mix dialyzer` passes (no type warnings)
- [ ] All test names are descriptive and readable
- [ ] Fixture data is unique per test (uses `System.unique_integer()` or similar)
- [ ] Tests use `describe` blocks for logical grouping
- [ ] Edge cases tested (nil, empty, boundary values)
