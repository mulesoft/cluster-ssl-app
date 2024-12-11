#!/usr/bin/env bash
set -o errexit
set -o nounset
set -o pipefail

# this versioning algorithm:
#  - if on a tagged commit, use the tag
#    e.g. 6.2.18 (for the commit tagged 6.2.18)
#  - if last tag was a regular release, bump the minor version, make a it a 'alpha.0' pre-release, and append # of commits since tag
#    e.g. 5.5.38-alpha.0.5 (for 5 commits after 5.5.37)
#  - if last tag was a pre-release tag (e.g. alpha, beta, rc), append number of commits since the tag
#    e.g. 7.0.0-alpha.1.5 (for 5 commits after 7.0.0-alpha.1)

# Comparison algorithm:
#   '7.0.33' < '7.0.34-pre' < '7.0.34-pre.1.<hash>' < '7.0.34-pre.11.<hash>' < '7.0.34'

increment_patch() {
    # increment_patch returns x.y.(z+1) given valid x.y.z semver.
    # If we need to robustly handle this, it is probably worth
    # looking at https://github.com/davidaurelio/shell-semver/
    # or moving this logic to a 'real' programming language -- 2020-03 walt
    local major minor patch
    major=$(echo "$1" | cut -d'.' -f1)
    minor=$(echo "$1" | cut -d'.' -f2)
    patch=$(echo "$1" | cut -d'.' -f3)
    patch=$((patch + 1))
    echo "${major}.${minor}.${patch}"
}

version::get_version_vars() {
    local git_tree_state
    if git_status=$(git status --porcelain 2>/dev/null) && [[ -z ${git_status} ]]; then
        git_tree_state="clean"
    else
        git_tree_state="dirty"
    fi

    local short_tag commit long_tag commit_with_last_tag commits_since_last_tag
    short_tag=$(git describe --abbrev=0 --tags)
    commit="g$(git rev-parse HEAD | cut -c-7)"
    long_tag=$(git describe --tags)
    commit_with_last_tag=$(git rev-list -n1 "${short_tag}")
    commits_since_last_tag=$(git rev-list  "${commit_with_last_tag}..HEAD" --count)

    if [[ "${long_tag}" == "${short_tag}" ]] ; then  # the current commit is tagged as a release
        GIT_VERSION="${short_tag}"
    elif [[ "${short_tag}" != *-* ]] ; then  # the current ref is not a descendent of a pre-release version
        short_tag=$(increment_patch "${short_tag}")
        GIT_VERSION="${short_tag}-alpha.0.${commits_since_last_tag}.${commit}"
    else  # the current ref is a descendent of a pre-release version (e.g. already an rc, alpha, or beta)
        GIT_VERSION="${short_tag}.${commits_since_last_tag}.${commit}"
    fi
    if [[ "${git_tree_state-}" == "dirty" ]]; then
        # git describe --dirty only considers changes to existing files, but
        # that is problematic since new untracked .go files affect the build,
        # so use our idea of "dirty" from git status instead.
        GIT_VERSION+="-dirty"
    fi

    # If GIT_VERSION is not a valid Semantic Version, then refuse to build.
    if ! [[ "${GIT_VERSION}" =~ ^([0-9]+)\.([0-9]+)(\.[0-9]+)?(-[0-9A-Za-z.-]+)?(\+[0-9A-Za-z.-]+)?$ ]]; then
        echo "GIT_VERSION should be a valid Semantic Version. Current value: ${GIT_VERSION}"
        echo "Please see more details here: https://semver.org"
        exit 1
    fi
}

version::get_version_vars
echo ${GIT_VERSION}
