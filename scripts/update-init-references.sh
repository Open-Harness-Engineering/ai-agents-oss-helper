#!/bin/bash
# Script to update all commands to reference the _common-init.md fragment

set -e

COMMANDS_DIR="$(cd "$(dirname "$0")/../commands" && pwd)"
UPDATED=0
SKIPPED=0

echo "🔄 Updating command initialization sections to reference fragment..."
echo ""

# Find all command files (excluding fragments and hidden files)
COMMAND_FILES=$(find "$COMMANDS_DIR" -maxdepth 1 -name "oss-*.md" -type f)

for cmd_file in $COMMAND_FILES; do
    cmd_name=$(basename "$cmd_file")
    
    # Check if already using fragment reference
    if grep -q "_fragments/_common-init.md" "$cmd_file"; then
        echo "⏭️  $cmd_name - Already using fragment reference"
        SKIPPED=$((SKIPPED + 1))
        continue
    fi
    
    # Check if has initialization section to replace
    if ! grep -q "### 1. Initialize Project Context" "$cmd_file" && \
       ! grep -q "### 1\. Initialize Project Context" "$cmd_file"; then
        echo "⚠️  $cmd_name - No initialization section found, skipping"
        SKIPPED=$((SKIPPED + 1))
        continue
    fi
    
    # Create backup
    cp "$cmd_file" "$cmd_file.bak"
    
    # Replace the verbose initialization section with fragment reference
    # This handles the multi-line initialization text
    sed -i '' '/### 1\. Initialize Project Context/,/All subsequent steps assume the project context.*is loaded\./c\
### 1. Initialize Project Context\
\
**MANDATORY:** Process `.oss-init.md` to load project rules. See `_fragments/_common-init.md` for details.
' "$cmd_file"
    
    # Check if the replacement was successful
    if grep -q "_fragments/_common-init.md" "$cmd_file"; then
        echo "✅ $cmd_name - Updated successfully"
        rm "$cmd_file.bak"
        UPDATED=$((UPDATED + 1))
    else
        echo "❌ $cmd_name - Update failed, restoring backup"
        mv "$cmd_file.bak" "$cmd_file"
    fi
done

echo ""
echo "📊 Summary:"
echo "  Commands updated: $UPDATED"
echo "  Commands skipped: $SKIPPED"
echo ""

if [ $UPDATED -gt 0 ]; then
    echo "✅ Successfully updated $UPDATED command(s)!"
    echo ""
    echo "Next steps:"
    echo "  1. Review the changes: git diff commands/"
    echo "  2. Run validation: ./scripts/validate-fragments.sh"
    echo "  3. Test with an agent to ensure fragment references work"
else
    echo "ℹ️  No commands needed updating"
fi
