# Project Standards

This rule file contains build tools, commands, and code style constraints for the project. Commands read this file to determine how to build, test, and format code.

- **Build tool:** Maven
- **Build command:** `./mvnw clean install -B`
- **Test command:** `./mvnw test -B`
- **Format command:** `./mvnw process-sources -B` (auto-formats code and sorts imports via `formatter-maven-plugin` + `impsort-maven-plugin`)
- **Format check command:** `./mvnw -Psourcecheck validate -B` (CI gate — fails on unformatted code)
- **Module-specific build:** yes (run `./mvnw` in the module directory where changes occurred; modules: camel-kit-main, camel-kit-core, camel-kit-graph, camel-jbang-plugin-kit)
- **Parallelized Maven:** no
- **Code style restrictions:**
  - Do NOT change public API signatures without justification
  - Do NOT add new dependencies without justification
  - Maintain backwards compatibility for public APIs
  - Skill files (`src/main/resources/skills/`) are Markdown instruction files — follow the existing skill authoring conventions in CONTRIBUTING.md
  - Every skill must have a clear entry-point `.md` file named after the skill directory
  - Skills must not embed hardcoded versions — reference `distribution.properties`
  - Sub-skills (internal) must be clearly marked as non-user-invocable
  - Shared guides in `skills/shared/` must not be modified without verifying impact on all skills that reference them
  - New graph parsers must be registered in the parser registry
  - Parser test data goes in `src/test/resources/` with a subdirectory per source platform
  - Code formatting: Eclipse-based formatter (4-space indent, 120-char lines) via `formatter-maven-plugin`
  - Import ordering: `impsort-maven-plugin` — groups: `java, jakarta, javax, org.w3c, org.xml, org.apache.camel, io.github.luigidemasi, *` — static imports after, unused imports removed
  - Error Prone available via `-Perrorprone` profile for compile-time bug detection
  - Forbidden APIs enforcement via `de.thetaphi:forbiddenapis` (runs on every build)

## Version
40402efeb763f9939c9beca0bb3842b48d7ac180
