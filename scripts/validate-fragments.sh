#!/bin/bash
# Validation script to ensure all commands properly reference initialization fragment

set -e

COMMANDS_DIR="$(cd "$(dirname "$0")/../commands" && pwd)"
FRAGMENTS_DIR="$COMMANDS_DIR/_fragments"
ERRORS=0

echo "🔍 Validating OSS Helper command fragments..."
echo ""

# Check that fragments directory exists
if [ ! -d "$FRAGMENTS_DIR" ]; then
    echo "❌ ERROR: Fragments directory not found: $FRAGMENTS_DIR"
    exit 1
fi

# Check that _common-init.md exists
if [ ! -f "$FRAGMENTS_DIR/_common-init.md" ]; then
    echo "❌ ERROR: Common init fragment not found: $FRAGMENTS_DIR/_common-init.md"
    exit 1
fi

echo "✅ Fragments directory exists"
echo "✅ Common init fragment exists"
echo ""

# Find all command files (excluding fragments and hidden files)
COMMAND_FILES=$(find "$COMMANDS_DIR" -maxdepth 1 -name "*.md" ! -name ".*" -type f)
TOTAL_COMMANDS=$(echo "$COMMAND_FILES" | wc -l | tr -d ' ')

echo "📋 Found $TOTAL_COMMANDS command files to validate"
echo ""

COMMANDS_WITH_INIT=0
COMMANDS_WITHOUT_INIT=0
COMMANDS_WITH_FRAGMENT_REF=0

# Check each command file
for cmd_file in $COMMAND_FILES; do
    cmd_name=$(basename "$cmd_file")
    
    # Check if command has initialization section
    if grep -q "### 1. Initialize Project Context" "$cmd_file" || \
       grep -q "### 1\. Initialize Project Context" "$cmd_file"; then
        COMMANDS_WITH_INIT=$((COMMANDS_WITH_INIT + 1))
        
        # Check if it references the fragment
        if grep -q "_fragments/_common-init.md" "$cmd_file"; then
            COMMANDS_WITH_FRAGMENT_REF=$((COMMANDS_WITH_FRAGMENT_REF + 1))
            echo "✅ $cmd_name - Uses fragment reference"
        else
            echo "⚠️  $cmd_name - Has init section but doesn't reference fragment"
            ERRORS=$((ERRORS + 1))
        fi
    else
        COMMANDS_WITHOUT_INIT=$((COMMANDS_WITHOUT_INIT + 1))
        echo "❌ $cmd_name - Missing initialization section"
        ERRORS=$((ERRORS + 1))
    fi
done

echo ""
echo "📊 Summary:"
echo "  Total commands: $TOTAL_COMMANDS"
echo "  Commands with init section: $COMMANDS_WITH_INIT"
echo "  Commands using fragment reference: $COMMANDS_WITH_FRAGMENT_REF"
echo "  Commands without init section: $COMMANDS_WITHOUT_INIT"
echo ""

if [ $ERRORS -eq 0 ]; then
    echo "✅ All commands properly reference initialization fragment!"
    exit 0
else
    echo "❌ Found $ERRORS issue(s) that need to be fixed"
    echo ""
    echo "To fix commands that don't reference the fragment:"
    echo "  Replace the verbose initialization section with:"
    echo "  **MANDATORY:** Process \`.oss-init.md\` to load project rules. See \`_fragments/_common-init.md\` for details."
    exit 1
fi
