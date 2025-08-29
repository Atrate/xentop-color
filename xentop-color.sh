#!/bin/bash --posix

# ------------------------------------------------------------------------------
# Copyright (C) 2025 Atrate
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU Affero General Public License as
# published by the Free Software Foundation, either version 3 of the
# License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU Affero General Public License for more details.
#
# You should have received a copy of the GNU Affero General Public License
# along with this program.  If not, see <https://www.gnu.org/licenses/>.
# ------------------------------------------------------------------------------


# ------------------------------------------------------------------------------
# Simple wrapper for xentop that uses AWK to colorize and reformat its output
# --------------------
# Version: 1.0.0
# --------------------
# Exit code listing:
#   0: All good
#   1: Unspecified
#   2: Error in environment configuration or arguments
# ------------------------------------------------------------------------------

## -----------------------------------------------------------------------------
## SECURITY SECTION
## NO EXECUTABLE CODE CAN BE PRESENT BEFORE THIS SECTION
## -----------------------------------------------------------------------------

# Set POSIX-compliant mode for security and unset possible overrides
# NOTE: This does not mean that we are restricted to POSIX-only constructs
# ------------------------------------------------------------------------
POSIXLY_CORRECT=1
set -o posix
readonly POSIXLY_CORRECT
export POSIXLY_CORRECT

# Set IFS explicitly. POSIX does not enforce whether IFS should be inherited
# from the environment, so it's safer to set it expliticly
# --------------------------------------------------------------------------
IFS=$' \t\n'
export IFS

# ------------------------------------------------------------------------------
# For additional security, you may want to specify hard-coded values for:
#   SHELL, PATH, HISTFILE, ENV, BASH_ENV
# They will be made read-only by set -r later in the script.
# ------------------------------------------------------------------------------

# Populate this array with **all** commands used in the script for security.
# The following builtins do not need to be included, POSIX mode handles that:
# break : . continue eval exec exit export readonly return set shift trap unset
# The following keywords are also supposed not to be overridable in bash itself
# ! case  coproc  do done elif else esac fi for function if in
# select then until while { } time [[ ]]
# ------------------------------------------------------------------------------
UTILS=(
    'awk'
    'command'
    'echo'
    'hash'
    'local'
    'read'
    'xentop'
)

# Unset all commands used in the script - prevents exported functions
# from overriding them, leading to unexpected behavior
# -------------------------------------------------------------------
for util in "${UTILS[@]}"
do
    \unset -f -- "$util"
done

# Clear the command hash table
# ----------------------------
hash -r

# Set up fd 3 for discarding output, necessary for set -r
# -------------------------------------------------------
exec 3>/dev/null

# ------------------------------------------------------------------------------
# Options description:
#   -o pipefail: exit on error in any part of pipeline
#   -eE:         exit on any error, go through error handler
#   -u:          exit on accessing uninitialized variable
#   -r:          set bash restricted mode for security
# The restricted mode option necessitates the usage of tee
# instead of simple output redirection when writing to files
# ------------------------------------------------------------------------------
set -o pipefail -eEur

## -----------------------------------------------------------------------------
## END OF SECURITY SECTION
## Make sure to populate the $UTILS array above
## -----------------------------------------------------------------------------

# Speed up script by not using unicode
# ------------------------------------
LC_ALL=C
LANG=C

# Globals
# -------

# Select xentop stats collection delay. Can be specified as the first argument
# ($1). Defaults to 2.
# ----------------------------------------------------------------------------
readonly DELAY=${1:-2}

readonly AWKSCRIPT='
# Colour functions by CodeMedic (written with some greek letters) on Stack

function isnumeric(x)
{
    return ( x == x+0 );
}

function name_to_number(name, predefined)
{
    if (isnumeric(name))
        return name;

    if (name in predefined)
        return predefined[name];

    return name;
}

function colour(v1, v2, v3)
{
    if (v3 == "" && v2 == "" && v1 == "")
        return;

    if (v3 == "" && v2 == "")
        return sprintf("%c[%dm", 27, name_to_number(v1, fgcolours));
    else if (v3 == "")
        return sprintf("%c[%d;%dm", 27, name_to_number(v1, bgcolours), name_to_number(v2, fgcolours));
    else
        return sprintf("%c[%d;%d;%dm", 27, name_to_number(v1, attributes), name_to_number(v2, bgcolours), name_to_number(v3, fgcolours));
}

BEGIN {
    # hack to use attributes for just "None"
    fgcolours["None"] = 0;

    fgcolours["Black"] = 90;
    fgcolours["Red"] = 91;
    fgcolours["Green"] = 92;
    fgcolours["Yellow"] = 93;
    fgcolours["Blue"] = 94;
    fgcolours["Magenta"] = 95;
    fgcolours["Cyan"] = 96;
    fgcolours["White"] = 97;
    fgcolours["Grey"] = 37;

    bgcolours["Black"] = 40;
    bgcolours["Red"] = 41;
    bgcolours["Green"] = 42;
    bgcolours["Yellow"] = 43;
    bgcolours["Blue"] = 44;
    bgcolours["Magenta"] = 45;
    bgcolours["Cyan"] = 46;
    bgcolours["White"] = 47;

    attributes["None"] = 0;
    attributes["Bold"] = 1;
    attributes["Underscore"] = 4;
    attributes["Blink"] = 5;
    attributes["ReverseVideo"] = 7;
    attributes["Concealed"] = 8;
}
{
    $1=$1;

    # NAME
    {printf "%s ", colour("None")$1}

    # STATE
    if ($2 == "STATE")
        {printf "%s ", colour("None")$2}
    else if ($2 == "--b---")
        {printf "%s ", colour("Grey")$2}
    else if ($2 == "--b--r")
        {printf "%s ", colour("None")$2}
    else if ($2 == "-----r")
        {printf "%s ", colour("None")$2}
    else if ($2 == "----p-")
        {printf "%s ", colour("Yellow")$2}
    else
        {printf "%s ", colour("Red")$2}

    # CPU(sec)
    {printf "%s ", colour("None")$3}

    # CPU(%)
    if ($4 ~ /^[0-9\.]+$/)
        if ($4 > 200)
            {printf "%s ", colour("Red")$4}
        else if ($4 > 100)
            {printf "%s ", colour("Yellow")$4}
        else if ($4 > 5)
            {printf "%s ", colour("Green")$4}
        else if ($4 >=1)
            {printf "%s ", colour("White")$4}
        else
            {printf "%s ", colour("Grey")$4}
    else
        {printf "%s ", colour("None")$4}

    # MEM(k)
    if ($5 ~ /^[0-9\.]+$/)
        {printf "%s%.1f=GB ", colour("None"), $5/1024/1024}
    else
        {printf "%s ", colour("None")$5}

    # MEM(%)
    if ($6 ~ /^[0-9\.]+$/)
        if ($6 >= 24)
            {printf "%s ", colour("Red")$6}
        else if ($6 >= 12)
            {printf "%s ", colour("Yellow")$6}
        else if ($6 >= 4)
            {printf "%s ", colour("Green")$6}
        else if ($6 >= 1)
            {printf "%s ", colour("White")$6}
        else
            {printf "%s ", colour("Grey")$6}
    else
        {printf "%s ", colour("None")$6}

    # MAXMEM(k)
    if ($7 ~ /^[0-9\.]+$/)
        {printf "%s%.1f=GB ", colour("None"), $7/1024/1024}
    else
        {printf "%s ", colour("None")$7}

    # # MAXMEM(%)
    # {printf "%s ", colour("None")$8}

    # VCPUS
    if ($9 ~ /^[0-9\.]+$/)
        if ($9 > 16)
            {printf "%s ", colour("Red")$9}
        else if ($9 >= 12)
            {printf "%s ", colour("Yellow")$9}
        else if ($9 >= 4)
            {printf "%s ", colour("Green")$9}
        else if ($9 >= 2)
            {printf "%s ", colour("White")$9}
        else
            {printf "%s ", colour("Grey")$9}
    else
        {printf "%s ", colour("None")$9}

    # # NETS
    # {printf "%s ", colour("None")$10}
    # # NETTX(k)
    # {printf "%s ", colour("None")$11}
    # # NETRX(k)
    # {printf "%s ", colour("None")$12}
    # # VBDS
    # {printf "%s ", colour("None")$13}
    # # VBD_OO
    # {printf "%s ", colour("None")$14}
    # # VBD_RD
    # {printf "%s ", colour("None")$15}
    # # VBD_WR
    # {printf "%s ", colour("None")$16}
    # # VBD_RSECT
    # {printf "%s ", colour("None")$17}
    # # VBD_WSECT
    # {printf "%s ", colour("None")$18}
    # # SSID
    # {printf "%s, colour("None")$19}
    {printf "\n"}

}
'


# Check the environment the script is running in
# ----------------------------------------------
check_environment()
{
    # Check available utilities
    # -------------------------
    for util in "${UTILS[@]}"
    do
        command -v -- "$util" >&3 || { echo "This script requires $util to be installed and in PATH!"; exit 2; }
    done

    return
}


# Main program functionality
# --------------------------
main()
{
    buffer=""

    while read -r line
    do
        # Header line. Detected by the string "NAME". Do not name your VMs "NAME"...
        case "$line" in
            *NAME*)
                clear
                if ! [ -z "$buffer" ]
                then
                    echo -e "$buffer" | awk "$AWKSCRIPT" | column -t -R 0 | tr '=' ' '
                    buffer=""
                fi ;;
        esac
        buffer="$buffer$line\n"
    done < <(xentop -f -b -d "$DELAY")
}

check_environment
main

## END OF FILE #################################################################
# vim: set tabstop=4 softtabstop=4 expandtab shiftwidth=4 smarttab:
# End:
