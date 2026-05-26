#!/bin/bash

export DEVLINE="develop"

# Store list of packages from repo.sh as packages_with_ci
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
source $SCRIPT_DIR/repo.sh || exit $?

#echo "${packages_with_ci[@]}"

ORG="art-daq"
REPOS=$(gh repo list "$ORG" --limit 100 --json name -q '.[].name')
OUTFILE="ci_summary.json"

echo "{" > "$OUTFILE"
FIRST=true

echo "Reset inactivity timers for special workflows"
gh api -X PUT "repos/art-daq/art-daq.github.io/actions/workflows/nightly-ci-dashboard.yml/enable"
gh api -X PUT "repos/art-daq/daq-docker/actions/workflows/alma9-spack-base.yaml/enable"
gh api -X PUT "repos/art-daq/daq-docker/actions/workflows/alma10-spack-base.yaml/enable"
gh api -X PUT "repos/art-daq/daq-docker/actions/workflows/artdaq-spack-selfhosted.yaml/enable"
gh api -X PUT "repos/art-daq/daq-docker/actions/workflows/otsdaq-spack-selfhosted.yaml/enable"
gh api -X PUT "repos/art-daq/.github/actions/workflows/artdaq-lcov.yml/enable"
gh api -X PUT "repos/art-daq/.github/actions/workflows/otsdaq-lcov.yml/enable"

# collect special job statuses
NIGHTLY_STATUS=$(gh run list -R "art-daq/art-daq.github.io" --limit 2 --json conclusion,createdAt,event,name,status,updatedAt,url --workflow nightly-ci-dashboard.yml -q '.[1]')
ALMA9_STATUS=$(gh run list -R "art-daq/daq-docker" --limit 1 --json conclusion,createdAt,event,name,status,updatedAt,url --workflow alma9-spack-base.yaml -q '.[0]')
ALMA10_STATUS=$(gh run list -R "art-daq/daq-docker" --limit 1 --json conclusion,createdAt,event,name,status,updatedAt,url --workflow alma10-spack-base.yaml -q '.[0]')
ARTDAQ_STATUS=$(gh run list -R "art-daq/daq-docker" --limit 1 --json conclusion,createdAt,event,name,status,updatedAt,url --workflow artdaq-spack-selfhosted.yaml -q '.[0]')
OTSDAQ_STATUS=$(gh run list -R "art-daq/daq-docker" --limit 1 --json conclusion,createdAt,event,name,status,updatedAt,url --workflow otsdaq-spack-selfhosted.yaml -q '.[0]')
ARTDAQ_LCOV_STATUS=$(gh run list -R "art-daq/.github" --limit 1 --json conclusion,createdAt,event,name,status,updatedAt,url --workflow artdaq-lcov.yml -q '.[0]')
OTSDAQ_LCOV_STATUS=$(gh run list -R "art-daq/.github" --limit 1 --json conclusion,createdAt,event,name,status,updatedAt,url --workflow otsdaq-lcov.yml -q '.[0]')
echo '"jobs": ' >> "$OUTFILE"

#echo "Prepare JSON fragment"
JSON_ENTRY=$(jq -n \
  --argjson nightly "$NIGHTLY_STATUS" \
  --argjson alma9 "$ALMA9_STATUS" \
  --argjson alma10 "$ALMA10_STATUS" \
  --argjson artdaq "$ARTDAQ_STATUS" \
  --argjson otsdaq "$OTSDAQ_STATUS" \
  --argjson artdaq_lcov "$ARTDAQ_LCOV_STATUS" \
  --argjson otsdaq_lcov "$OTSDAQ_LCOV_STATUS" \
  '[
    nightly: $nightly,
    alma9: $alma9,
    alma10: $alma10,
    artdaq: $artdaq,
    otsdaq: $otsdaq,
    artdaq_lcov: $artdaq_lcov,
    otsdaq_lcov: $otsdaq_lcov,
  ]')
retval=$?

if [[ $retval == 0 ]]; then
  echo "$JSON_ENTRY" >> "$OUTFILE"
else
  echo "Non-zero return value for central CI jobs. Skipping..."
fi

echo "," >> "$OUTFILE"
PROJECT_NUMBER=1

echo "Collecting statistics for CI-enabled repos"
echo '"repos": [' >> "$OUTFILE"

for REPO in "${packages_with_ci[@]}"; do
  FULL_NAME="$ORG/$REPO"
  echo "This repo: $FULL_NAME"

  BRANCHES=-1
  BRANCH_URL=$(echo "https://github.com/$ORG/$REPO/branches/all")
  gh repo clone $FULL_NAME $REPO -- --no-checkout --filter=blob:none &>/dev/null
  if [ -d $REPO ];then
    cd $REPO
    BRANCHES=`git branch -r |grep -vE 'origin/(HEAD|main|stable|develop|artdaq/Spack0\.28|artdaq/Spack1\.1)$'|wc -l`
    cd ..
  fi
  branch=`git branch -a|grep origin/HEAD|cut -d'>' -f'2'|sed 's|\s*origin/||'`

  OPEN_ISSUES=$(gh issue list -R "$FULL_NAME" --state open --limit 1000 --json number --jq 'length' || echo 0)
  ISSUES_URL=$(echo "https://github.com/$ORG/$REPO/issues")
  OPEN_PRS=$(gh pr list -R "$FULL_NAME" --state open --limit 1000 --json number --jq 'length' || echo 0)
  PRS_URL=$(echo "https://github.com/$ORG/$REPO/pulls")
  REPO_INFO=$(gh repo view "$FULL_NAME" --json isPrivate,updatedAt)

  #echo "Add missing Issues and PRs to Project"
  gh issue list -R "$FULL_NAME" --search "no:project" --state all --limit 1000 --json url \
  | jq -r '.[].url' \
  | while read -r URL; do
    echo "Adding $URL to project $PROJECT_NUMBER"
    gh project item-add "$PROJECT_NUMBER" --owner "$ORG" --url "$URL" >/dev/null || true
  done
  gh pr list -R "$FULL_NAME" --search "no:project" --state all --limit 1000 --json url \
  | jq -r '.[].url' \
  | while read -r URL; do
    echo "Adding $URL to project $PROJECT_NUMBER"
    gh project item-add "$PROJECT_NUMBER" --owner "$ORG" --url "$URL" >/dev/null || true
  done

  if [[ "$REPO" =~ "artdaq" ]] || [[ "$REPO" =~ "trace" ]]; then
    #echo "Get most recent single-repo CI build status"
    BUILD_DEVELOP_STATUS=$(gh run list -R "$FULL_NAME" -b "$branch" --limit 1 --json conclusion,createdAt,event,name,status,updatedAt,url --workflow artdaq-develop-cpp-ci.yml -q '.[0]')
    BUILD_SINGLE_STATUS=$(gh run list -R "$FULL_NAME" -b "$branch" --limit 1 --json conclusion,createdAt,event,name,status,updatedAt,url --workflow artdaq-build-single-pkg.yml -q '.[0]')
    TEST_SINGLE_STATUS=$(gh run list -R "$FULL_NAME" -b "$branch" --limit 1 --json conclusion,createdAt,event,name,status,updatedAt,url --workflow artdaq-test-single-pkg.yml -q '.[0]')
    FORMAT_STATUS=$(gh run list -R "$FULL_NAME" -b "$branch" --limit 1 --json conclusion,createdAt,event,name,status,updatedAt,url --workflow artdaq-format-single-pkg.yml -q '.[0]')
    WHITESPACE_STATUS=$(gh run list -R "$FULL_NAME" -b "$branch" --limit 1 --json conclusion,createdAt,event,name,status,updatedAt,url --workflow git-whitespace.yml -q '.[0]')

    #echo "Reset inactivity timers"
    gh api -X PUT "repos/$FULL_NAME/actions/workflows/artdaq-develop-cpp-ci.yml/enable"
    gh api -X PUT "repos/$FULL_NAME/actions/workflows/artdaq-build-single-pkg.yml/enable"
    gh api -X PUT "repos/$FULL_NAME/actions/workflows/artdaq-test-single-pkg.yml/enable"
    gh api -X PUT "repos/$FULL_NAME/actions/workflows/artdaq-format-single-pkg.yml/enable"
    gh api -X PUT "repos/$FULL_NAME/actions/workflows/git-whitespace.yml/enable"
  else
    #echo "Get most recent single-repo CI build status"
    BUILD_DEVELOP_STATUS=$(gh run list -R "$FULL_NAME" -b "$branch" --limit 1 --json conclusion,createdAt,event,name,status,updatedAt,url --workflow otsdaq-develop-cpp-ci.yml -q '.[0]')
    BUILD_SINGLE_STATUS=$(gh run list -R "$FULL_NAME" -b "$branch" --limit 1 --json conclusion,createdAt,event,name,status,updatedAt,url --workflow otsdaq-build-single-pkg.yml -q '.[0]')
    TEST_SINGLE_STATUS=$(gh run list -R "$FULL_NAME" -b "$branch" --limit 1 --json conclusion,createdAt,event,name,status,updatedAt,url --workflow otsdaq-test-single-pkg.yml -q '.[0]')
    FORMAT_STATUS=$(gh run list -R "$FULL_NAME" -b "$branch" --limit 1 --json conclusion,createdAt,event,name,status,updatedAt,url --workflow otsdaq-format-single-pkg.yml -q '.[0]')
    WHITESPACE_STATUS=$(gh run list -R "$FULL_NAME" -b "$branch" --limit 1 --json conclusion,createdAt,event,name,status,updatedAt,url --workflow git-whitespace.yml -q '.[0]')

    #echo "Reset inactivity timers"
    gh api -X PUT "repos/$FULL_NAME/actions/workflows/otsdaq-develop-cpp-ci.yml/enable"
    gh api -X PUT "repos/$FULL_NAME/actions/workflows/otsdaq-build-single-pkg.yml/enable"
    gh api -X PUT "repos/$FULL_NAME/actions/workflows/otsdaq-test-single-pkg.yml/enable"
    gh api -X PUT "repos/$FULL_NAME/actions/workflows/otsdaq-format-single-pkg.yml/enable"
    gh api -X PUT "repos/$FULL_NAME/actions/workflows/git-whitespace.yml/enable"
  fi

  BUILD_DEVELOP_STATUS=${BUILD_DEVELOP_STATUS:-null}
  BUILD_SINGLE_STATUS=${BUILD_SINGLE_STATUS:-null}
  TEST_SINGLE_STATUS=${TEST_SINGLE_STATUS:-null}
  FORMAT_STATUS=${FORMAT_STATUS:-null}
  WHITESPACE_STATUS=${WHITESPACE_STATUS:-null}

  #echo "Prepare JSON fragment"
  JSON_ENTRY=$(jq -n \
    --arg repo "$REPO" \
    --argjson repo_info "$REPO_INFO" \
    --argjson issues "$OPEN_ISSUES" \
    --arg issues_url "$ISSUES_URL" \
    --argjson prs "$OPEN_PRS" \
    --arg prs_url "$PRS_URL" \
    --argjson branches "$BRANCHES" \
    --arg branches_url "$BRANCH_URL" \
    --argjson build_develop "$BUILD_DEVELOP_STATUS" \
    --argjson build_single "$BUILD_SINGLE_STATUS" \
    --argjson test_single "$TEST_SINGLE_STATUS" \
    --argjson format "$FORMAT_STATUS" \
    --argjson whitespace "$WHITESPACE_STATUS" \
    '{
      repo: $repo,
      repo_info: $repo_info,
      open_issues: $issues,
      issues_url: $issues_url,
      open_prs: $prs,
      prs_url: $prs_url,
      branches: $branches,
      branches_url: $branches_url,
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

echo "Collecting statistics for non-CI-enabled repos"
for REPO in "${packages_without_ci[@]}"; do
  FULL_NAME="$ORG/$REPO"
  echo "This repo: $FULL_NAME"

  BRANCHES=-1
  BRANCH_URL=$(echo "https://github.com/$ORG/$REPO/branches/all")
  gh repo clone $FULL_NAME $REPO -- --no-checkout --filter=blob:none &>/dev/null
  if [ -d $REPO ];then
    cd $REPO
    BRANCHES=`git branch -r |grep -vE 'origin/(HEAD|main|stable|develop|artdaq/Spack0\.28|artdaq/Spack1\.1)$'|wc -l`
    cd ..
  fi

  OPEN_ISSUES=$(gh issue list -R "$FULL_NAME" --state open --limit 1000 --json number --jq 'length' || echo 0)
  ISSUES_URL=$(echo "https://github.com/$ORG/$REPO/issues")
  OPEN_PRS=$(gh pr list -R "$FULL_NAME" --state open --limit 1000 --json number --jq 'length' || echo 0)
  PRS_URL=$(echo "https://github.com/$ORG/$REPO/pulls")
  REPO_INFO=$(gh repo view "$FULL_NAME" --json isPrivate,updatedAt)

  FORMAT_STATUS=
  if [[ "$REPO" =~ "artdaq" ]]; then
    FORMAT_STATUS=$(gh run list -R "$FULL_NAME" --limit 1 --json conclusion,createdAt,event,name,status,updatedAt,url --workflow artdaq-format-single-pkg.yml -q '.[0]')
  elif [[ "$REPO" =~ "otsdaq" ]]; then
    FORMAT_STATUS=$(gh run list -R "$FULL_NAME" --limit 1 --json conclusion,createdAt,event,name,status,updatedAt,url --workflow otsdaq-format-single-pkg.yml -q '.[0]')
  fi
  WHITESPACE_STATUS=$(gh run list -R "$FULL_NAME" --limit 1 --json conclusion,createdAt,event,name,status,updatedAt,url --workflow git-whitespace.yml -q '.[0]')

  FORMAT_STATUS=${FORMAT_STATUS:-null}
  WHITESPACE_STATUS=${WHITESPACE_STATUS:-null}

  #echo "Add missing Issues and PRs to Project"
  gh issue list -R "$FULL_NAME" --search "no:project" --state all --limit 1000 --json url \
  | jq -r '.[].url' \
  | while read -r URL; do
    echo "Adding $URL to project $PROJECT_NUMBER"
    gh project item-add "$PROJECT_NUMBER" --owner "$ORG" --url "$URL" >/dev/null || true
  done
  gh pr list -R "$FULL_NAME" --search "no:project" --state all --limit 1000 --json url \
  | jq -r '.[].url' \
  | while read -r URL; do
    echo "Adding $URL to project $PROJECT_NUMBER"
    gh project item-add "$PROJECT_NUMBER" --owner "$ORG" --url "$URL" >/dev/null || true
  done

  #echo "Reset inactivity timers"
  gh api -X PUT "repos/$FULL_NAME/actions/workflows/artdaq-format-single-pkg.yml/enable"
  gh api -X PUT "repos/$FULL_NAME/actions/workflows/git-whitespace.yml/enable"

  #echo "Prepare JSON fragment"
  JSON_ENTRY=$(jq -n \
    --arg repo "$REPO" \
    --argjson repo_info "$REPO_INFO" \
    --argjson issues "$OPEN_ISSUES" \
    --arg issues_url "$ISSUES_URL" \
    --argjson prs "$OPEN_PRS" \
    --arg prs_url "$PRS_URL" \
    --argjson branches "$BRANCHES" \
    --arg branches_url "$BRANCH_URL" \
    --argjson format "$FORMAT_STATUS" \
    --argjson whitespace "$WHITESPACE_STATUS" \
    '{
      repo: $repo,
      repo_info: $repo_info,
      open_issues: $issues,
      issues_url: $issues_url,
      open_prs: $prs,
      prs_url: $prs_url,
      branches: $branches,
      branches_url: $branches_url,
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
echo "}" >> "$OUTFILE"

echo "Results saved to $OUTFILE"
