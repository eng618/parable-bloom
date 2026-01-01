## Brief overview

Guidelines for alpha development phase where backwards compatibility is not a priority, allowing for rapid iteration and breaking changes.

## Backwards compatibility

- Prioritize rapid development and architectural improvements over maintaining backwards compatibility
- Refactor code freely without concern for breaking existing integrations
- Remove deprecated code paths and legacy workarounds immediately
- Update dependencies and APIs without migration strategies

## Code cleanup

- Remove temporary backwards compatibility shims as soon as they're no longer needed
- Clean up TODO comments and placeholder code from initial development
- Eliminate unused imports, variables, and dead code
- Simplify complex workarounds once proper solutions are implemented

## Development speed

- Focus on getting features working correctly rather than perfectly
- Accept technical debt during alpha in favor of faster iteration
- Defer optimization and performance improvements until beta
- Use quick fixes over elegant solutions when time is critical

## Transition planning

- Document breaking changes for beta migration planning
- Track deprecated APIs that will need proper migration paths
- Plan for backwards compatibility restoration before beta release
- Remove this rule file when transitioning to beta development phase
