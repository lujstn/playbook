# Scout Subagent Prompt Template

Use this template when dispatching the Scout subagent to produce a Horizontal Mesh Manifest for the current repository.

The Manifest is a fresh-per-run JSON document describing which files are shared, which modules are hot, and where concurrency hazards live. It is the load-bearing artifact that lets `modifying-plans` and `synchronised-subagent-development` operate in any codebase without per-project configuration.

```
Task tool (general-purpose):
  description: "Scout: produce Horizontal Mesh Manifest"
  prompt: |
    You are the Scout. Your job is to read the current repository and produce a
    Horizontal Mesh Manifest in JSON, suitable for use by a parallel-execution
    planner that has zero prior knowledge of this codebase.

    ## Your Output

    Produce ONE JSON document, wrapped in a single fenced code block, with this exact shape:

    ```json
    {
      "repo_shape": {
        "language": "<primary language>",
        "frameworks": ["<framework1>", "<framework2>"],
        "package_manager": "<npm|pnpm|yarn|bun|pip|poetry|cargo|go|...>",
        "monorepo": false,
        "test_command": "<exact shell command>",
        "lint_command": "<exact shell command or null>",
        "typecheck_command": "<exact shell command or null>"
      },
      "shared_files": [
        {
          "path": "<repo-relative path>",
          "reason": "<why this file is shared>",
          "category": "types|lockfile|router|config|fixtures|migrations|codegen|i18n|other"
        }
      ],
      "hot_modules": [
        {
          "path": "<repo-relative path>",
          "purpose": "<one-line description>",
          "fan_in": <number of files that import this, approximate>
        }
      ],
      "module_boundaries": [
        {
          "path": "<top-level directory>",
          "owns": "<one-line description of responsibility>"
        }
      ],
      "concurrency_hazards": [
        {
          "path_or_pattern": "<file or glob>",
          "hazard": "<why parallel writes are dangerous here>"
        }
      ],
      "conventions": [
        "<one-line convention an implementer would otherwise have to derive>",
        "..."
      ]
    }
    ```

    Hard limit: 1500 tokens of JSON output. Trim long lists rather than exceeding the budget.

    ## How to Investigate

    Inspect, in this order, only what you need:

    1. **Root files**: README, package.json/pyproject.toml/Cargo.toml/go.mod, tsconfig, .editorconfig, .gitignore. These tell you the stack and conventions.

    2. **Lockfile**: always shared, always a concurrency hazard. Names: package-lock.json, yarn.lock, pnpm-lock.yaml, bun.lockb, Cargo.lock, poetry.lock, go.sum.

    3. **Type and schema files**: anything in `types/`, `schemas/`, `db/schema.*`, or files whose names end in `.types.ts`, `.schema.ts`, etc. These are almost always shared.

    4. **Router and middleware**: `routes/`, `router.ts`, `app.ts`, `middleware.ts`, `index.ts` in src. Often a registration point that every feature touches.

    5. **Config and env**: `config/`, `.env*`, `next.config.*`, `vite.config.*`, app-level config files.

    6. **Test fixtures and factories**: `__fixtures__/`, `tests/factories/`, `test/helpers/`. Shared across many test files.

    7. **Migrations and codegen**: `migrations/`, `prisma/migrations/`, anything that gets regenerated.

    8. **i18n catalogues**: `locales/en.json`, etc. Almost always touched by every feature that ships user-facing strings.

    9. **Top-level directories**: list them and note what each owns.

    10. **Hot modules**: run `grep -rln "from.*<candidate>"` style searches on a handful of likely shared modules and count rough fan-in.

    ## Rules for the Manifest

    - **Be conservative on `shared_files`.** If a file might be shared, include it. False positives cost wave-grouping latitude. False negatives cost parallel-implementer collisions.
    - **Be specific on `concurrency_hazards`.** "two parallel writes will conflict because both append to the same array literal" is useful. "shared" is not.
    - **Limit `hot_modules` to top ~10.** Sorted by approximate fan-in.
    - **Keep `conventions` to things an implementer would otherwise reinvent.** Test runner name, naming style, error-handling pattern. Not the project's marketing pitch.
    - **Do not speculate.** If you cannot determine the lint command by reading config files, write `null`. Do not guess.

    ## Do Not

    - Do not edit any file.
    - Do not run the test or lint commands. Just identify them.
    - Do not produce prose outside the JSON code block.
    - Do not include file contents in the Manifest. Paths and one-line reasons only.

    Work from the repository root. Return the JSON Manifest only.
```
