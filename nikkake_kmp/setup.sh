#!/bin/bash
# Modify root build.gradle.kts to add serialization plugin
cat << 'INNER_EOF' >> build.gradle.kts
plugins {
    kotlin("plugin.serialization").version("1.9.21").apply(false)
}
INNER_EOF

# Modify shared/build.gradle.kts
# We'll use sed or awk, but easier to just rewrite shared/build.gradle.kts completely or use multi_replace.
