# Complexity Thresholds

| Metric | Threshold | Action |
|--------|-----------|--------|
| Function Length | > 20 lines | Extract function or private helper |
| Parameter Count | > 4 | Use keyword list or map |
| Module Length | > 400 lines | Extract context or sub-module |
| Nesting Depth | > 3 levels | Extract function or use `with` |
| Duplication | > 3 similar blocks | Extract shared module/function |
| Pipe Chain | > 5 pipes | Extract into named function |
| Public Functions | > 10 per module | Split into sub-modules or contexts |

## Refactoring Checklist

### Before Refactoring
- [ ] Write characterization test that documents current behavior
- [ ] `mix test test/path/to/char_test.exs` PASSES (behavior is captured)
- [ ] Identify inputs and outputs of the code being refactored
- [ ] Propose specific refactoring and get user approval

### During Refactoring
- [ ] Make ONE atomic transformation at a time
- [ ] Run characterization test after EACH change
- [ ] If test fails, the refactoring broke behavior — fix the code, not the test
- [ ] Move to next transformation only after tests pass

### After Refactoring
- [ ] `mix test` passes full suite (no regressions)
- [ ] New code follows Elixir conventions
- [ ] `mix credo --strict` passes
- [ ] `mix dialyzer` passes
- [ ] `@doc` updated for any renamed/extracted functions
- [ ] Removed any dead code or unused aliases

### Anti-patterns to Avoid
- Refactoring without characterization tests
- Changing behavior during refactoring
- Multiple logical changes in one step
- Skipping the full suite regression check
