#!/bin/bash

# Load the base test matrix
BASE_MATRIX=$(cat "$GITHUB_ACTION_PATH/test-matrix.json")

if [[ -n "${RUNS_ON_ENV}" && "${RUNS_ON_ENV}" == "s390x" ]]; then
    BASE_MATRIX=$(cat "$GITHUB_ACTION_PATH/test-matrix-s390x.json")
fi

# Check if ADDITIONAL_MATRIX is provided and not empty
if [ -n "${ADDITIONAL_MATRIX}" ]; then
    # Combine the matrices by merging the include arrays
    # BASE_MATRIX has format: {"include": [...]}
    # ADDITIONAL_MATRIX should be an array: [...]
    FINAL_MATRIX=$(echo "$BASE_MATRIX" "$ADDITIONAL_MATRIX" | jq -s '{include: (.[0].include + .[1])}')
else
    # Use the base matrix as-is
    FINAL_MATRIX="$BASE_MATRIX"
fi

# Filter the matrix based on GitHub event type and repository
if [ "$GITHUB_EVENT_NAME" = "pull_request" ] || [[ ! "$GITHUB_REPOSITORY" =~ ^mariadb-corporation/ ]]; then
    # Filter out enterprise db-type entries for pull requests or non-mariadb-corporation repositories
    FILTERED_MATRIX=$(echo "$FINAL_MATRIX" | jq '{
        include: [.include[] | select(.["db-type"] != "enterprise")]
    }')
else
    # Use the full matrix for other events in mariadb-corporation repositories
    FILTERED_MATRIX="$FINAL_MATRIX"
fi

echo "final-matrix=$(echo "$FILTERED_MATRIX" | jq -c '.include |= sort_by(
  if (.name | test("^\\\\S+\\\\s+\\\\d+\\\\.\\\\d+")) then
    (.name | capture("^(?<product>\\\\S+)\\\\s+(?<major>\\\\d+)\\\\.(?<minor>\\\\d+)") |
     [(.major | tonumber), (.minor | tonumber), .name])
  else
    [999, 999, .name]
  end
)')" >> "$GITHUB_OUTPUT"
