# Project Standards

This rule file contains build tools, commands, and code style constraints for the project. Commands read this file to determine how to build, test, and format code.

- **Build tool:** Maven
- **Build command:** `./mvnw clean install -B`
- **Test command:** `./mvnw test -B`
- **Format command:** `./mvnw process-sources -B` (auto-formats code and sorts imports via `formatter-maven-plugin` + `impsort-maven-plugin`)
- **Format check command:** `./mvnw -Psourcecheck validate -B` (CI gate — fails on unformatted code)
- **Module-specific build:** yes (run `./mvnw` in the module directory where changes occurred; modules: schema, embedding, indexer, index, mcp)
- **Parallelized Maven:** no (ONNX model downloads and large index operations are resource intensive)
- **Code style restrictions:**
  - Do NOT use Records or Lombok (unless already present in the file)
  - Do not add new dependencies without justification
  - The `index` module uses CI-Friendly Versions (`${revision}`) — do not hardcode versions in its pom.xml
  - Do not modify the embedding model or vector dimensions without updating all dependent modules (schema, indexer, index, mcp)
  - Lucene index schema changes require rebuilding the full index — coordinate with the indexer module
  - MCP server tools must follow the existing naming convention (`camel_knowledge_*`)
  - New document sources require a dedicated `*Indexer` class — keep indexing logic modular
  - All indexed documents must populate the required `KnowledgeDocument` fields (title, content, source, type)
  - Embedding dimension changes are breaking — requires full reindex and MCP server update
  - MCP tool changes must stay in sync with the `/camel-knowledge` skill in the camel-kit repository
  - Code formatting: Eclipse-based formatter (4-space indent, 120-char lines) via `formatter-maven-plugin`
  - Import ordering: `impsort-maven-plugin` — groups: `java, jakarta, javax, org.w3c, org.xml, org.apache.camel, io.github.luigidemasi, *` — static imports after, unused imports removed
  - Error Prone available via `-Perrorprone` profile for compile-time bug detection
  - Forbidden APIs enforcement via `de.thetaphi:forbiddenapis` (runs on every build)

## Version
40402efeb763f9939c9beca0bb3842b48d7ac180
