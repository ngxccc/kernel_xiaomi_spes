#!/bin/sh
# Enforce strict error handling
set -euo pipefail

GKI_ROOT=$(pwd)
OWNER="KernelSU-Next"
REPO="$OWNER"

display_usage() {
    echo "Usage: $0 [--cleanup | <commit-or-tag>]"
    echo "  --cleanup:              Cleans up previous modifications made by the script."
    echo "  <commit-or-tag>:        Sets up or updates the KernelSU-Next to specified tag or commit."
    echo "  -h, --help:             Displays this usage information."
    echo "  (no args):              Sets up or updates the KernelSU-Next environment to the latest tagged version."
}

initialize_variables() {
    if test -d "$GKI_ROOT/common/drivers"; then
         DRIVER_DIR="$GKI_ROOT/common/drivers"
    elif test -d "$GKI_ROOT/drivers"; then
         DRIVER_DIR="$GKI_ROOT/drivers"
    else
         echo '[ERROR] "drivers/" directory not found.'
         exit 127
    fi

    DRIVER_MAKEFILE=$DRIVER_DIR/Makefile
    DRIVER_KCONFIG=$DRIVER_DIR/Kconfig
}

# Reverts modifications made by this script
perform_cleanup() {
    echo "[+] Cleaning up..."
    [ -L "$DRIVER_DIR/kernelsu" ] && rm "$DRIVER_DIR/kernelsu" && echo "[-] Symlink removed."
    grep -q "kernelsu" "$DRIVER_MAKEFILE" && sed -i '/kernelsu/d' "$DRIVER_MAKEFILE" && echo "[-] Makefile reverted."
    grep -q "drivers/kernelsu/Kconfig" "$DRIVER_KCONFIG" && sed -i '/drivers\/kernelsu\/Kconfig/d' "$DRIVER_KCONFIG" && echo "[-] Kconfig reverted."
    if [ -d "$GKI_ROOT/$REPO" ]; then
        rm -rf "$GKI_ROOT/$REPO" && echo "[-] $REPO directory deleted."
    fi
}

# Sets up or update KernelSU-Next environment
setup_kernelsu() {
    echo "[+] Setting up $REPO..."

    # Clone repository if it doesn't exist
    if [ ! -d "$GKI_ROOT/$REPO" ]; then
        git clone "https://github.com/$OWNER/$REPO" "$GKI_ROOT/$REPO"
        echo "[+] Repository cloned."
    fi

    cd "$GKI_ROOT/$REPO" || exit 1
    git stash && echo "[-] Stashed current changes."

    # Fetch all tags from remote to ensure local git registry is up-to-date
    git fetch --tags --quiet

    # Switch to default branch safely
    BRANCH="$(git rev-parse --abbrev-ref origin/HEAD | sed 's@^origin/@@')"
    git checkout "$BRANCH" && echo "[-] Switched to $BRANCH branch."
    git pull --quiet && echo "[+] Repository updated."

    # --- THE MAGIC HAPPENS HERE ---
    if [ -z "${1-}" ]; then
        # 1. git tag --sort=-v:refname: Sort tags descending by Semantic Versioning
        # 2. awk '!/legacy|rc|beta|alpha/: Exclude unwanted pre-release/legacy strings
        # 3. print $1; exit: Print the first match and terminate immediately
        LATEST_TAG=$(git tag --sort=-v:refname | awk '!/legacy|rc|beta|alpha/ {print $1; exit}')

        # Fallback safeguard in case no stable tag is found
        if [ -z "$LATEST_TAG" ]; then
             LATEST_TAG=$(git describe --tags --abbrev=0)
        fi

        git checkout "$LATEST_TAG" && echo "[-] Checked out latest stable tag: $LATEST_TAG 🎯"
    else
        # Allow checking out specific commit or tag from user arguments
        git checkout "$1" && echo "[-] Checked out $1." || echo "[-] Failed to checkout $1"
    fi
    # ------------------------------

    cd "$DRIVER_DIR" || exit 1

    # Create symlink dynamically using modern syntax
    ln -sfn "$(realpath --relative-to="$DRIVER_DIR" "$GKI_ROOT/$REPO/kernel")" "kernelsu"
    echo "[+] Symlink created."

    # Safely inject configurations if they don't exist
    if ! grep -q "kernelsu" "$DRIVER_MAKEFILE"; then
        printf "\nobj-\$(CONFIG_KSU) += kernelsu/\n" >> "$DRIVER_MAKEFILE"
        echo "[+] Modified Makefile."
    fi

    if ! grep -q "source \"drivers/kernelsu/Kconfig\"" "$DRIVER_KCONFIG"; then
        sed -i "/endmenu/i\source \"drivers/kernelsu/Kconfig\"" "$DRIVER_KCONFIG"
        echo "[+] Modified Kconfig."
    fi

    echo '[+] Done.'
}

# Process command-line arguments
if [ "$#" -eq 0 ]; then
    initialize_variables
    setup_kernelsu
elif [ "$1" = "-h" ] || [ "$1" = "--help" ]; then
    display_usage
elif [ "$1" = "--cleanup" ]; then
    initialize_variables
    perform_cleanup
else
    initialize_variables
    setup_kernelsu "$@"
fi
