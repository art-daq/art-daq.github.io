#!/bin/bash

export DEVLINE="develop"

# Store list of packages from repo.sh as packages_with_ci
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
source $SCRIPT_DIR/repo.sh || exit $?

#echo "${packages_with_ci[@]}"

ORG="art-daq"
REPOS=$(gh repo list "$ORG" --limit 100 --json name -q '.[].name')
OUTFILE="ci_summary.json"

echo "[" > "$OUTFILE"
FIRST=true

for REPO in "${packages_with_ci[@]}"; do
  FULL_NAME="$ORG/$REPO"
  echo "This repo: $FULL_NAME"

  OPEN_ISSUES=$(gh issue list -R "$FULL_NAME" --state open --limit 1000 --json number --jq 'length' || echo 0)
  ISSUES_URL=$(echo "https://github.com/art-daq/$REPO/issues")
  OPEN_PRS=$(gh pr list -R "$FULL_NAME" --state open --limit 1000 --json number --jq 'length' || echo 0)
  PRS_URL=$(echo "https://github.com/art-daq/$REPO/pulls")
  BUILD_DEVELOP_STATUS="{}"
  BUILD_SINGLE_STATUS="{}"
  TEST_SINGLE_STATUS="{}"
  FORMAT_STATUS="{}"
  WHITESPACE_STATUS="{}"

  if [[ "$REPO" =~ "artdaq" ]] || [[ "$REPO" =~ "trace" ]]; then
    # Get most recent single-repo CI build status
    BUILD_DEVELOP_STATUS=$(gh run list -R "$FULL_NAME" --limit 1 --json conclusion,createdAt,event,name,status,updatedAt,url --workflow artdaq-develop-cpp-ci.yml -q '.[0]')
    BUILD_SINGLE_STATUS=$(gh run list -R "$FULL_NAME" --limit 1 --json conclusion,createdAt,event,name,status,updatedAt,url --workflow artdaq-build-single-pkg.yml -q '.[0]')
    TEST_SINGLE_STATUS=$(gh run list -R "$FULL_NAME" --limit 1 --json conclusion,createdAt,event,name,status,updatedAt,url --workflow artdaq-test-single-pkg.yml -q '.[0]')
    FORMAT_STATUS=$(gh run list -R "$FULL_NAME" --limit 1 --json conclusion,createdAt,event,name,status,updatedAt,url --workflow artdaq-format-single-pkg.yml -q '.[0]')
    WHITESPACE_STATUS=$(gh run list -R "$FULL_NAME" --limit 1 --json conclusion,createdAt,event,name,status,updatedAt,url --workflow git-whitespace.yml -q '.[0]')
  else
    # Get most recent single-repo CI build status
    BUILD_DEVELOP_STATUS=$(gh run list -R "$FULL_NAME" --limit 1 --json conclusion,createdAt,event,name,status,updatedAt,url --workflow otsdaq-develop-cpp-ci.yml -q '.[0]')
    BUILD_SINGLE_STATUS=$(gh run list -R "$FULL_NAME" --limit 1 --json conclusion,createdAt,event,name,status,updatedAt,url --workflow otsdaq-build-single-pkg.yml -q '.[0]')
    TEST_SINGLE_STATUS=$(gh run list -R "$FULL_NAME" --limit 1 --json conclusion,createdAt,event,name,status,updatedAt,url --workflow otsdaq-test-single-pkg.yml -q '.[0]')
    FORMAT_STATUS=$(gh run list -R "$FULL_NAME" --limit 1 --json conclusion,createdAt,event,name,status,updatedAt,url --workflow otsdaq-format-single-pkg.yml -q '.[0]')
    WHITESPACE_STATUS=$(gh run list -R "$FULL_NAME" --limit 1 --json conclusion,createdAt,event,name,status,updatedAt,url --workflow git-whitespace.yml -q '.[0]')
  fi

  # Prepare JSON fragment
  JSON_ENTRY=$(jq -n \
    --arg repo "$REPO" \
    --argjson issues "$OPEN_ISSUES" \
    --arg issues_url "$ISSUES_URL" \
    --argjson prs "$OPEN_PRS" \
    --arg prs_url "$PRS_URL" \
    --argjson build_develop "$BUILD_DEVELOP_STATUS" \
    --argjson build_single "$BUILD_SINGLE_STATUS" \
    --argjson test_single "$TEST_SINGLE_STATUS" \
    --argjson format "$FORMAT_STATUS" \
    --argjson whitespace "$WHITESPACE_STATUS" \
    '{
      repo: $repo,
      open_issues: $issues,
      issues_url: $issues_url,
      open_prs: $prs,
      prs_url: $prs_url,
      build_develop: $build_develop,
      build_single: $build_single,
      test_single: $test_single,
      format: $format,
      whitespace: $whitespace,
    }')
  retval=$?

  if [[ $retval == 0 ]]; then
    if [[ "$FIRST" = true ]]; then
      FIRST=false
    else 
      echo "," >> "$OUTFILE"
    fi
  else
    echo "Non-zero return value in $REPO. Skipping..."
    continue
  fi

  echo "$JSON_ENTRY" >> "$OUTFILE"
done

echo "]" >> "$OUTFILE"

echo "Results saved to $OUTFILE"
