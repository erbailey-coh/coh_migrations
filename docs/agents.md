# AGENTS.md Documentation

AGENTS.md is an open format specification for providing AI coding agents with project-specific instructions and context. It serves as a "README for agents" - a standardized, predictable location where developers can document build commands, testing procedures, code style guidelines, and other technical details that help AI agents work effectively on a codebase. The format emerged from collaborative efforts across the AI development ecosystem including OpenAI Codex, Amp, Jules from Google, Cursor, and Factory.

The specification is intentionally simple: a Markdown file placed at the repository root (or nested within subprojects for monorepos) containing freeform instructions organized by headings. No required fields or rigid schema exist - teams can structure their AGENTS.md to match their workflow. The format has been adopted by over 20,000 open-source projects and is compatible with a growing ecosystem of AI coding tools including Claude Code, Cursor, GitHub Copilot, Aider, Gemini CLI, and many others.

## Creating a Basic AGENTS.md File

Standard AGENTS.md file with common sections for a TypeScript project.

```markdown
# AGENTS.md

## Setup commands
- Install deps: `pnpm install`
- Start dev server: `pnpm dev`
- Run tests: `pnpm test`

## Code style
- TypeScript strict mode
- Single quotes, no semicolons
- Use functional patterns where possible

## Testing instructions
- Run full test suite: `pnpm test`
- Run specific test: `pnpm vitest run -t "test name"`
- All tests must pass before committing

## PR guidelines
- Title format: [component] Brief description
- Always run linting and tests before pushing
- Update tests for any changed functionality
```

## Creating a Monorepo AGENTS.md with Development Tips

Advanced AGENTS.md for monorepos with workspace-specific guidance.

```markdown
# AGENTS.md

## Dev environment tips
- Use `pnpm dlx turbo run where <project_name>` to jump to a package instead of scanning with `ls`.
- Run `pnpm install --filter <project_name>` to add the package to your workspace so Vite, ESLint, and TypeScript can see it.
- Use `pnpm create vite@latest <project_name> -- --template react-ts` to spin up a new React + Vite package with TypeScript checks ready.
- Check the name field inside each package's package.json to confirm the right name—skip the top-level one.

## Testing instructions
- Find the CI plan in the .github/workflows folder.
- Run `pnpm turbo run test --filter <project_name>` to run every check defined for that package.
- From the package root you can just call `pnpm test`. The commit should pass all tests before you merge.
- To focus on one step, add the Vitest pattern: `pnpm vitest run -t "<test name>"`.
- Fix any test or type errors until the whole suite is green.
- After moving files or changing imports, run `pnpm lint --filter <project_name>` to be sure ESLint and TypeScript rules still pass.
- Add or update tests for the code you change, even if nobody asked.

## PR instructions
- Title format: [<project_name>] <Title>
- Always run `pnpm lint` and `pnpm test` before committing.
```

## Configuring Aider to Use AGENTS.md

Aider configuration file directing the tool to read AGENTS.md for context.

```yaml
# .aider.conf.yml
read: AGENTS.md
```

## Configuring Gemini CLI to Use AGENTS.md

Gemini CLI settings specifying AGENTS.md as the context file.

```json
{
  "contextFileName": "AGENTS.md"
}
```

## Migrating from Legacy Agent Files

Shell commands to migrate from deprecated AGENT.md to AGENTS.md with backward compatibility.

```bash
# Rename existing file and create symbolic link
mv AGENT.md AGENTS.md && ln -s AGENTS.md AGENT.md

# Verify the migration
ls -la AGENT*
# Expected output:
# AGENT.md -> AGENTS.md
# AGENTS.md
```

## Creating Nested AGENTS.md for Subprojects

Directory structure showing nested AGENTS.md files in a monorepo.

```
my-monorepo/
├── AGENTS.md              # Root-level instructions
├── packages/
│   ├── frontend/
│   │   └── AGENTS.md      # Frontend-specific instructions
│   ├── backend/
│   │   └── AGENTS.md      # Backend-specific instructions
│   └── shared/
│       └── AGENTS.md      # Shared library instructions
└── apps/
    ├── web/
    │   └── AGENTS.md      # Web app instructions
    └── mobile/
        └── AGENTS.md      # Mobile app instructions
```

Each nested AGENTS.md takes precedence for files within its directory tree.

## Python Project AGENTS.md Example

AGENTS.md tailored for a Python project with Apache Airflow.

```markdown
# AGENTS.md

## Project overview
Platform to programmatically author, schedule, and monitor workflows using Apache Airflow.

## Setup commands
- Create virtual environment: `python -m venv venv`
- Activate environment: `source venv/bin/activate` (Unix) or `venv\Scripts\activate` (Windows)
- Install dependencies: `pip install -r requirements.txt`
- Run database migrations: `airflow db upgrade`
- Start webserver: `airflow webserver`
- Start scheduler: `airflow scheduler`

## Code style
- Follow PEP 8 guidelines
- Use type hints for function signatures
- Maximum line length: 120 characters
- Format with black: `black .`
- Lint with flake8: `flake8 .`

## Testing instructions
- Run all tests: `pytest`
- Run with coverage: `pytest --cov=airflow`
- Run specific test file: `pytest tests/test_operators.py`
- Minimum coverage requirement: 80%

## Security considerations
- Never commit credentials or API keys
- Use Airflow Connections for external service credentials
- Sanitize all user inputs in custom operators
- Review DAG permissions before deployment
```

## Rust Project AGENTS.md Example

AGENTS.md for a Rust CLI tool project.

```markdown
# AGENTS.md

## Project overview
General-purpose CLI tooling for AI coding agents written in Rust.

## Setup commands
- Install Rust: `curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh`
- Build project: `cargo build`
- Build release: `cargo build --release`
- Run: `cargo run -- <args>`
- Install locally: `cargo install --path .`

## Code style
- Follow Rust naming conventions
- Use `cargo fmt` before committing
- Run `cargo clippy` and fix all warnings
- Document public APIs with doc comments
- Prefer `?` operator over explicit error handling

## Testing instructions
- Run tests: `cargo test`
- Run tests with output: `cargo test -- --nocapture`
- Run specific test: `cargo test test_name`
- Check documentation: `cargo doc --open`
- All tests and clippy checks must pass before PR

## Build considerations
- Minimum supported Rust version: 1.70
- Cross-compile targets: x86_64-unknown-linux-gnu, x86_64-apple-darwin, x86_64-pc-windows-gnu
- Build for all targets: `cargo build --release --target <target>`
```

## Java Project AGENTS.md Example

AGENTS.md for a Java SDK with Gradle build system.

```markdown
# AGENTS.md

## Project overview
Java SDK for Temporal, workflow orchestration defined in code.

## Setup commands
- Install Java 11 or higher: `sdk install java 11.0.20-tem`
- Build project: `./gradlew build`
- Run tests: `./gradlew test`
- Generate docs: `./gradlew javadoc`
- Install to local Maven: `./gradlew publishToMavenLocal`

## Code style
- Follow Google Java Style Guide
- Use 2 spaces for indentation
- Format with: `./gradlew spotlessApply`
- Check formatting: `./gradlew spotlessCheck`
- Maximum line length: 100 characters

## Testing instructions
- Run unit tests: `./gradlew test`
- Run integration tests: `./gradlew integrationTest`
- Run all checks: `./gradlew check`
- Generate coverage report: `./gradlew jacocoTestReport`
- View coverage: Open build/reports/jacoco/test/html/index.html
- Minimum coverage: 85%

## Dependencies
- Use Gradle dependency management
- Update versions in gradle.properties
- Check for updates: `./gradlew dependencyUpdates`
- Avoid SNAPSHOT dependencies in main branch

## PR requirements
- All tests passing
- Code coverage maintained or improved
- Spotless formatting applied
- Changelog entry added
- Documentation updated if API changes
```

## Security-Focused AGENTS.md Section

AGENTS.md section with security guidelines for handling sensitive data.

```markdown
# AGENTS.md

## Security considerations
- Never commit files matching these patterns to git:
  - `.env`, `.env.local`, `.env.*.local`
  - `**/secrets/*.json`
  - `**/config/credentials.yml`
  - Any file containing API keys or passwords

- Use environment variables for all secrets:
  ```bash
  export DATABASE_URL="postgresql://user:pass@localhost/db"
  export API_KEY="your-secret-key"
  ```

- For local development, copy `.env.example` to `.env.local`:
  ```bash
  cp .env.example .env.local
  # Edit .env.local with your local credentials
  ```

- Rotate secrets immediately if accidentally committed:
  1. Revoke the exposed secret in the service dashboard
  2. Generate a new secret
  3. Update all environments with the new secret
  4. Remove the secret from git history using `git filter-branch` or BFG Repo-Cleaner

- Scan for exposed secrets before each commit:
  ```bash
  npm run security:scan
  # Or manually: git diff --cached | grep -E '(password|secret|key|token)='
  ```

## Encryption guidelines
- Use bcrypt for password hashing with cost factor >= 12
- Use AES-256-GCM for data encryption at rest
- Use TLS 1.3 for all network communications
- Never implement custom cryptography
```

## Large Dataset Handling Instructions

AGENTS.md section documenting how to work with large datasets in the project.

```markdown
# AGENTS.md

## Large dataset handling

### Dataset locations
- Production data: `s3://company-data/datasets/production/`
- Staging data: `s3://company-data/datasets/staging/`
- Local dev data: `./data/samples/` (small sample files only)

### Download sample datasets
```bash
# Download 1% sample for local testing
aws s3 cp s3://company-data/datasets/samples/users_1pct.parquet ./data/samples/
aws s3 cp s3://company-data/datasets/samples/transactions_1pct.parquet ./data/samples/

# Verify download
ls -lh ./data/samples/
```

### Processing large files
- Never load entire dataset into memory
- Use streaming/chunking for files > 100MB:
  ```python
  import pandas as pd

  # Bad: loads entire file into memory
  df = pd.read_parquet('large_file.parquet')

  # Good: process in chunks
  for chunk in pd.read_parquet('large_file.parquet', chunksize=10000):
      process_chunk(chunk)
  ```

### Data validation
- Run schema validation before processing:
  ```bash
  python scripts/validate_schema.py --input data/samples/users_1pct.parquet
  ```

- Expected schema versions:
  - Users dataset: v2.3.1
  - Transactions dataset: v1.8.0
  - Events dataset: v3.0.2

### Memory limits
- Local dev environment: 8GB RAM limit
- CI environment: 4GB RAM limit
- Production workers: 32GB RAM limit
- Always profile memory usage: `python -m memory_profiler script.py`
```

## Summary

AGENTS.md provides a standardized approach to documenting project-specific instructions for AI coding agents. The format's flexibility allows teams to include any information relevant to their workflow - from basic setup commands and code style guidelines to advanced topics like security policies, dataset handling procedures, and deployment steps. By maintaining a dedicated AGENTS.md file, teams create a single source of truth that helps AI agents understand project conventions without cluttering human-focused documentation.

The specification's adoption across 20,000+ open-source projects demonstrates its utility in the modern development workflow. Whether working on a simple single-package project or a complex monorepo with multiple subprojects, AGENTS.md scales to meet the need. The ability to nest AGENTS.md files throughout a repository enables precise, context-specific guidance while the lack of rigid schema requirements ensures teams can adapt the format to their unique needs. As AI-assisted development continues to grow, AGENTS.md serves as a bridge between human developers and AI agents, enabling more effective collaboration on codebases of any size or complexity.
