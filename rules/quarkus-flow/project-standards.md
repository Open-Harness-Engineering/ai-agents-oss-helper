# Project Standards

This rule file contains build tools, commands, and code style constraints for the project. Commands read this file to determine how to build, test, and format code.

- **Build tool:** `Maven`
- **Build command:** `mvn clean install -DskipTests`
- **Test command:** `mvn verify -DskipITs=false`
- **Format command:** `cd <module> && mvn formatter:format impsort:sort`
- **Module-specific build:** yes (Multi-module Maven project with core, messaging, langchain4j, persistence, and other modules. Build commands should be run from the module directory when working on specific modules.)
- **Parallelized Maven:** no (Integration tests may conflict if run in parallel. Always use sequential builds.)
- **Code style restrictions:**
  - Follow Quarkus extension pattern: never reference deployment code from runtime code
  - No @author tags in Javadoc (use Git history)
  - Limit lambdas/streams in runtime code to minimize footprint
  - Tests are mandatory for all changes (not optional)
  - Integration tests must pass before PR submission
  - Use AssertJ for assertions (preferred)
  - Follow conventional commit message format (fix:, feat:, docs:, etc.)
  - Do NOT change public API signatures without justification
  - Do NOT add new dependencies without justification
  - Maintain backwards compatibility for public APIs

## Version
014fd70863a5e9f962843ccd39338826777ae1e9