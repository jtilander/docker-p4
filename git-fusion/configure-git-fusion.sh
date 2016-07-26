#!/bin/bash
# vim:sw=4
#-------------------------------------------------------------------------------
# Configuration script for Helix Git Fusion.
# Copyright 2014-2016, Perforce Software Inc. All rights reserved.
#
# Environment
#
#-------------------------------------------------------------------------------

#-------------------------------------------------------------------------------
# Global variables
#-------------------------------------------------------------------------------
MONOCHROME=false
DEBUG=false
PATH="/opt/perforce/git-fusion/bin:/opt/perforce/usr/bin:/opt/perforce/bin:/usr/local/bin:$PATH"
PLATFORM=unknown

#-------------------------------------------------------------------------------
# Dependency versions
#-------------------------------------------------------------------------------

# P4D versions
# >= 2012.2.684894 < 2013.1
# >= 2013.1.685046 < 2013.2
# >= 2013.2.671876 < 2013.3
# >= 2013.3
declare -A P4D_MIN_VERSION_ARRAY
P4D_MIN_VERSION_ARRAY[2015.1]="1171507"
P4D_MIN_VERSION_ARRAY[2015.2]="1171507"
P4D_MIN_VERSION="2015.1"

# P4Python >= 2014.1/925900
P4PYTHON_MIN_VERSION="2014.1/925900"

# Git >= 1.7.9.5
GIT_MIN_VERSION="1.7.9.5"

# Python == 3.3.2
PYTHON_VERSION="3.3.2"

# pygit2 == 0.22.0
PYGIT2_VERSION="0.22.0"

# libgit2 == 0.22.0
LIBGIT2_VERSION="0.22.0"

# pytz == 2013b
PYTZ_VERSION="2013b"
MAX_TEMP_CLIENTS_EDGE="500"

#-------------------------------------------------------------------------------
# Functions
#-------------------------------------------------------------------------------
die()
{
    error "FATAL: $*" >&2
    exit 1
}

highlightOn()
{
    # ANSI blue
    if ! $MONOCHROME; then
        echo -n -e "\033[34m"
    else
        echo ""
    fi
}

highlightOff()
{
    if ! $MONOCHROME; then
        echo -n -e "\033[0m"
    else
        echo ""
    fi
}

highlight()
{
    # ANSI blue
    if ! $MONOCHROME; then
        echo -e "\033[34m$1\033[0m"
    else
        echo "$1"
    fi
}

errorOn()
{
    # ANSI red
    if ! $MONOCHROME; then
        echo -e "\033[31m"
    else
        echo ""
    fi
}

error()
{
    # ANSI red
    if ! $MONOCHROME; then
        echo -e "\033[31m$1\033[0m" >&2
    else
        echo "$1" >&2
    fi
}

debug()
{
    # ANSI cyan
    $DEBUG && echo -e "\033[36m$1\033[0m" >&2
    return 0
}

usage()
{
    cat <<EOS
Configuration script for Helix Git Fusion.

Usage:

    configure-git-fusion.sh [-n] [-m] [--server local|remote]
        [--readonly] [--super <username>] [--superpassword <password>]
        [--gfp4password <password>] [--gfsysuser <username>]
        [--id <server-id>] [--p4port <[ssl:][host:]port>] [--timezone <tz>]
        [--unknownuser <method>]

    configure-git-fusion.sh

Description:

    For configuring a new Git Fusion instance, provide the required data via
    arguments or prompts. If no arguments are given and system user 'git'
    exists with the default home directory containing
    '/opt/perforce/git-fusion/home/perforce-git-fusion/p4gf_environment.cfg',
    then an upgrade will be performed using parameters read from
    p4gf_envonment.cfg.

    -n
            Non-interactive mode; exits immediately if prompting is required.

    -m
            Monochrome; no colored text.

    --super <username>
            Perforce super-user's username.

    --superpassword <password>
            Perforce super-user's password.

    --gfp4password <password>
            Password set on new Git Fusion Perforce users.

    --gfsysuser <username>
            The system user to run Git Fusion as. If the user does not exist,
            it will be created. Defaults to "git".

    --gfdir
            The path to the Git Fusion executable files.

    --server local|remote
            Choose the server type to be used with this Git Fusion instance

            local  = use an existing Perforce service on this machine
            remote = use an existing Perforce service on another machine

    --readonly
            Configure this Git Fusion instance to be read only - no pushes
            allowed.

    --id <server-id>
            Server-id used to identify the Git Fusion server. Defaults to
            the current hostname.

    --p4port <p4port>
            The P4PORT for the Perforce service.

    --timezone <tz>
            The Perforce service's timezone in Olson format.

    --unknownuser reject|pusher|unknown
            Choose how to handle the Perforce change owner for git commits
            authored by non-Perforce users.

            reject  = reject push which contains commits authored by
                      non-Perforce users (default)
            pusher  = accept commits authored by non-Perforce users and
                      set the change owner to the pusher
            unknown = accept commits authored by non-Perforce users and
                      set the change owner to 'unknown_git'

    --https
            Configure HTTPS authentication using Apache.

    --debug
            Enable debugging reporting.

    --help
            Display this help message.
EOS
}
unknownuser_usage()
{
    cat <<EOS

You must choose how to handle the Perforce change owner for git commits
authored by non-Perforce users.

  reject  = reject push which contains commits authored by non-Perforce
            users (default)
  pusher  = accept commits authored by non-Perforce users and set the change
            owner to the pusher
  unknown = accept commits authored by non-Perforce users and set the change
            owner to 'unknown_git'
            .. Note: The actual pusher, author, and committer are recorded
                     in the change description.

EOS
}

# Prompt the user for information by showing a prompt string, and if the
# prompt is for a password also disabling echo on the terminal. Optionally
# calls a validation function to check if the response is OK.
#
# promptfor <VAR> <prompt> <default> [<ispassword>] [<validationfunc>]
promptfor()
{
    local var="$1"
    local prompt="$2"
    local default="$3"
    local secure=false
    local check_func=true
    local non_default_check_func=false

    [ -n "$4" ] && secure=$4
    [ -n "$5" ] && check_func=$5 && non_default_check_func=true

    if [ "$default" = " " ]; then
        default=""
    fi

    while true; do
        local pw=""
        local pw2=""
        if $secure; then
            stty -echo echonl
        fi

        if [ -n "$default" ]; then
            showDefault=$default
            if [ "$secure" = "true" ]; then
                showDefault=$(echo "$default" | sed 's/./*/g')
            fi
            read -e -p "$prompt [$showDefault]: " pw
            if [ ! -n "$pw" ]; then
                pw=$default
            fi
        else
            read -e -p "$prompt: " pw
        fi
        stty echo -echonl || true
        if $secure; then
            echo ""
        fi
        if $check_func "$pw"; then
            if $secure && $non_default_check_func; then
                stty -echo echonl
                read -e -p "Re-enter new password: " pw2
                stty echo -echonl || true
                echo ""
                if [ "$pw" == "$pw2" ]; then
                    eval "$var=\"$pw\""
                    break;
                else
                    echo "Passwords do not match. Please try again."
                fi
            else
                eval "$var=\"$pw\""
                break;
            fi
        fi
    done
    true
}

# Ensure password is Strong by Perforce definition
# Usage: strong_password <password>
strong_password()
{
    local pw=$1
    local secure=false

    if [ ${#pw} -ge 8 ]; then
        # Test for two character classes
        if echo "$pw" | egrep '[[:upper:]]' | egrep '[[:lower:]]' >/dev/null; then
            secure=true
        elif echo "$pw" | egrep '[[:upper:]]' | egrep '[^[:alpha:]]' > /dev/null; then
            secure=true
        elif echo "$pw" | egrep '[[:lower:]]' | egrep '[^[:alpha:]]' > /dev/null; then
            secure=true
        else
            error "Password too simple"
        fi
    else
        [ -n "$pw" ] && error "Password too short."
    fi
    $secure
}

# Work out which flavour *nix we're on
get_distro()
{
    if [ -e "/etc/redhat-release" ]; then
        PLATFORM=redhat
    elif [ -e "/etc/debian_version" ]; then
        PLATFORM=debian
    else
        if [ "$(uname -o)" != "GNU/Linux" ]; then
            PLATFORM=notlinux
        fi
        # Exit now if this is not a supported Linux distribution
        die "Could not determine OS distribution"
    fi
}

# Root user check
# If not root, escalate with sudo
ensure_root()
{
    if [ $EUID != 0 ]; then
        error "This script must run with root privileges. Attempting to sudo!"
        sudo -H "$SCRIPTPATH/$SCRIPT" "$@"
        exit $?
    else
        # If we are root from a previous sudo, we need to ensure that the home
        # direectory in the environment is correct for the effective user
        if [ "$HOME" != "$(getent passwd "$EUID" | cut -d ":" -f 6 )" ]; then
            export HOME="$(getent passwd "$EUID" | cut -d ":" -f 6 )"
        fi
    fi
}

# Architecture check
# Git Fusion only runs on 64-bit systems (amd64 or x86_64)
# uname -p is more specific, but Debian returns 'unknown'
ensure_64bit()
{
    if ! uname -a | grep -q -E "x86_64|amd64"; then
        error "Git Fusion only supports x86_64 based architectures."
        exit 1
    fi
}

# Dependency check
# Git Fusion requires specific versions of Python, Python modules, P4 and Git
ensure_dependencies()
{
    # Start with the easy stuff
    # Python
    if which python3.3 >/dev/null 2>&1; then
        local PYTHON_VER="$(python3.3 -c "import sys; print('{0}.{1}.{2}'.format(sys.version_info.major, sys.version_info.minor, sys.version_info.micro))")"
        if [ "$PYTHON_VER" != "$PYTHON_VERSION" ]; then
            die "Found Python $PYTHON_VER but Git Fusion requires version $PYTHON_VERSION"
        fi
    else
        die "Can't find python3.3!"
    fi

    # PyTz
    local PYTZ_VER=""
    if PYTZ_VER="$(python3.3 -c 'import pytz; print(pytz.__version__)')" >/dev/null 2>&1; then
        if [ "$PYTZ_VER" != "$PYTZ_VERSION" ]; then
            die "Found pytz $PYTZ_VER but Git Fusion requires version $PYTZ_VERSION"
        fi
    else
        die "Couldn't import pytz!"
    fi

    # PyGit2 and libgit2
    local PYGIT2_VER=""
    if PYGIT2_VER="$(python3.3 -c 'import pygit2; print(pygit2.__version__)')" >/dev/null 2>&1; then
        if [ "$PYGIT2_VER" != "$PYGIT2_VERSION" ] ; then
            die "Found pygit2 $PYGIT2_VER but Git Fusion requires version $PYGIT2_VERSION"
        fi
        local LIBGIT2_VER=""
        if LIBGIT2_VER="$(python3.3 -c 'import pygit2; print(pygit2.LIBGIT2_VERSION)')" >/dev/null 2>&1; then
            if [ "$LIBGIT2_VER" != "$LIBGIT2_VERSION" ]; then
                die "Found libgit2 $LIBGIT2_VER but Git Fusion requires version $LIBGIT2_VERSION"
            fi
        else
            die "Could not identify underlying libgit2 library version."
        fi
    else
        die "Couldn't import pygit2!"
    fi
    if [ "$PYGIT2_VER" != "$LIBGIT2_VER" ] ; then
        die "pygit2 version $PYGIT2_VER must equal libgit2 version $LIBGIT2_VER"
    fi
    debug "pygit2 version $PYGIT2_VER equals libgit2 version $LIBGIT2_VER"

    # Move onto the dependencies with >= versions we need to check
    # Git
    if which git >/dev/null 2>&1; then
        local GIT_VER="$(git --version | grep -o '[0-9.]*')"
        local GIT_VER_ARR=(${GIT_VER//./ })
        local GIT_MIN_ARR=(${GIT_MIN_VERSION//./ })
        for (( i=0 ; i < ${#GIT_MIN_ARR[@]} ; i++ )); do
            local m=${GIT_MIN_ARR[i]}
            local c=${GIT_VER_ARR[i]}

            if [ -z "$c" ] || [ "$c" -lt "$m" ]; then
                die "Found $GIT_VER but Git Fusion requires version $GIT_MIN_VERSION"
            elif [ "$c" -gt "$m" ]; then
                break
            fi
        done
    else
        die "Can't find git!"
    fi

    # P4Python
    local P4PY_VER=""
    if P4PY_VER="$(python3.3 -c 'import P4; print(P4.P4.identify())' | grep -o 'P4PYTHON/[^ ]*/[^ ]*/[^ ]*')" >/dev/null 2>&1; then
        P4PY_VER="$(echo "$P4PY_VER" | sed -e "s;^.*P4PYTHON/[^/]*/;;" -e "s;[^0-9.]*/;/;" -e "s;[.]/;/;" -e "s; .*$;;" -e "s;/; ;")"
        local P4PY_REL="$(echo "$P4PY_VER" | awk '{ print $1; }')"
        local P4PY_CHANGE="$(echo "$P4PY_VER" | awk '{ print $2; }')"
        local P4PYTHON_MIN_VERSION_MAJOR="$(echo "$P4PYTHON_MIN_VERSION" | cut -d "/" -f1)"
        if [ "$(awk 'BEGIN{ if ("'$P4PY_REL'" > "'$P4PYTHON_MIN_VERSION_MAJOR'") print(0); else print(1) }')" -eq 1 ] && \
            [ "$P4PY_REL" != "$P4PYTHON_MIN_VERSION_MAJOR" -o "$P4PY_CHANGE" -lt "$(echo "$P4PYTHON_MIN_VERSION" | cut -d "/" -f2)" ]; then
            die "Found P4Python $P4PY_REL/$P4PY_CHANGE but Git Fusion requires at least version $P4PYTHON_MIN_VERSION"
        fi
    else
        die "Couldn't import P4Python!"
    fi
}

# Got P4?
find_p4()
{
    if ! which p4 >/dev/null 2>&1; then
        return 1
    fi
    local P4_VER=""
    if P4_VER="$(p4 -V | grep -o 'P4/[^ ]*/[^ ]*/[^ ]*')" >/dev/null 2>&1; then
        P4_VER="$(echo "$P4_VER" | sed -e "s;^.*P4/[^/]*/;;" -e "s;[^0-9.]*/;/;" -e "s;[.]/;/;" -e "s; .*$;;" -e "s;/; ;")"
        local P4_REL="$(echo "$P4_VER" | awk '{ print $1; }')"
        if [ "$(awk 'BEGIN{ if ("'$P4_REL'" >= "'$P4_MIN_VERSION'") print(0); else print(1) }')" -eq 1 ]; then
            error "Found p4 $P4_REL but Git Fusion requires at least version $P4_MIN_VERSION"
            return 1
        fi
    fi
    return $?
}

# Checks to see where Git Fusion is installed.
# Should always set GFINSTALLPATH to /opt/perforce/git-fusion/libexec if using
# packages. If this is a manual install, the --gfdir option allows
# non-interactive override of the path.
get_p4gf()
{
    if [ -n "$GFINSTALLPATH" -a -s "$GFINSTALLPATH/Version" ]; then
        # Path provided and validated
        return 0
    elif [ -s "/opt/perforce/git-fusion/libexec/Version" ]; then
        # Git Fusion was installed as expected
        GFINSTALLPATH=/opt/perforce/git-fusion/libexec
        return 0
    elif [ -s "/usr/local/git-fusion/bin/Version" ]; then
        # Git Fusion was installed as expected
        GFINSTALLPATH=/usr/local/git-fusion/bin
        return 0
    elif $INTERACTIVE; then
        # Git Fusion wasn't found: prompt for path
        while [ ! -s "$GFINSTALLPATH/Version" ]; do
            promptfor GFINSTALLPATH "Where is Git Fusion installed?"
        done
    else
        die "Couldn't find Git Fusion install directory!"
    fi
}

# Validate P4USER
# User must be set and must not start with a number
# Usage: validate_p4user <p4user>
validate_p4user()
{
    local USERRE="^[a-zA-Z]+"
    if [ ! -n "$1" ] || [[ ! "$1" =~ $USERRE ]]; then
        $hideErrors || error "Username must start with a letter."
        return 1
    fi
    return 0
}

# Validates a yes/no prompt
# Usage: validate_yesno [yes/no>
validate_yesno()
{
    local CHOICE="$1"
    if [ -z "$CHOICE" ] || [ "$CHOICE" != "yes" -a "$CHOICE" != "no" ]; then
        $hideErrors || error "Please specify either yes or no"
        return 1
    fi
    return 0
}

# Validates that P4PORT looks reasonable
# If this is for binding, do some extra checks
# Usage: validate_p4port <p4port>
validate_p4port()
{
    local PORT=$1
    local BIND=false

    local PROTOS="tcp tcp4 tcp6 tcp46 tcp64 ssl ssl4 ssl6 ssl46 ssl64"
    local PROTO=""
    local HOST=""
    local PNUM=""

    local BITS=(${PORT//:/ })
    local COUNT=${#BITS[@]}
    if [ $COUNT -eq 1 ]; then
        PNUM=${BITS[0]}
    elif [ $COUNT -eq 2 ]; then
        [[ $PROTOS =~ ${BITS[0]} ]] && PROTO=${BITS[0]} || HOST=${BITS[0]}
        PNUM=${BITS[1]}
    elif [ $COUNT -eq 3 ]; then
        PROTO=${BITS[0]}
        HOST=${BITS[1]}
        PNUM=${BITS[2]}
    elif [ $COUNT -gt 3 ]; then
        $hideErrors || error "Too many parts in P4PORT: $PORT"
    fi

    #check for protocol (does it match our list of valid protocols?)
    if [ -n "$PROTO" ] && [[ ! $PROTOS =~ $PROTO ]]; then
        $hideErrors || error "Invalid Perforce protocol: $PROTO"
        return 1
    fi

    # check port range (port >= 1024 && port =< 65535)
    # see http://www.iana.org/assignments/port-numbers for details
    local NUMRE="^[0-9]+$"
    if [[ ! $PNUM =~ $NUMRE ]] || [ $PNUM -lt 1024 -o $PNUM -gt 65535 ]; then
        $hideErrors || error "Port number out of range (1024-65535): $PNUM"
        return 1
    fi

    #check port not in use
    if $BIND && ! p4 -p $PNUM info 2>&1 | grep -q "Connect to server failed"; then
        $hideErrors || error "Port appears to be in use"
        return 1
    fi

    return 0
}

# Checks to see if a user exists and that they have a valid home directory
validate_system_user()
{
    local USER="$1"
    if [ -z "$USER" ]; then
        error "User not specified!"
        return 1
    fi

    local GFUSERHOME="$(getent passwd "$USER" | cut -d ":" -f 6 )"
    debug "User $USER has home directory: $GFUSERHOME"

    if [ -z "$GFUSERHOME" ]; then
        return 1
    fi
    if [ ! -d "$GFUSERHOME" ]; then
        return 1
    fi

    return 0
}

set_lc_all_lang()
{
    local BASHRC="$1"
    # is valid LANG already in the environment of GFUSER?
    local UTF8LOCALE=$(su - "$GFUSER" -c 'echo $LANG | egrep -i '"'[.](utf-8|utf8)$'"'')
    if [ -z "$UTF8LOCALE" ]; then
        # if en_US.utf-8 locale available use that
        UTF8LOCALE=$(locale -a | egrep -i 'en_US[.](utf-8|utf8)$')
    fi
    if [ -z "$UTF8LOCALE" ]; then
        # if all fails, use the first utf-8 locale installed on the system
        UTF8LOCALE=$(locale -a | egrep -i '[.](utf-8|utf8)$' | head -1)
    fi
    if [ -z "$UTF8LOCALE" ]; then
        highlight 'Unable to determine valid UTF-8 locale on this system.'
        exit 1
    fi
    highlight "Setting LC_ALL=$UTF8LOCALE and LANG=$UTF8LOCALE in $BASHRC"
    # comment the current export LC_ALL and LANG statements
    sed -i "s/^\s*export\s\+LC_ALL/# export LC_ALL/" "$BASHRC"
    sed -i "s/^\s*export\s\+LANG/# export LANG/" "$BASHRC"
    echo "export LC_ALL=$UTF8LOCALE" >> "$BASHRC"
    echo "export LANG=$UTF8LOCALE" >> "$BASHRC"
}

# Creates a new Git Fusion system user.
# Usage: create_update_p4gf_user <username> ['update']
# if 'update' then only update the .bashrc script and do not create user
create_update_p4gf_user()
{
    local USER="$1"
    local update="$2"

    if [ ! "$update" ]; then
        highlight "Creating user"
        # Create the new user (with an empty home directory)
        local NOSKEL=$(mktemp -d)
        useradd --system --create-home --shell /bin/bash \
                --skel "$NOSKEL" -c "Helix Git Fusion" "$USER"
        rmdir "$NOSKEL"

   fi
    # Stash the home directory
    local GFUSERHOME="$(getent passwd "$USER" | cut -d ":" -f 6 )"
    P4GF_ENV_PATH="$GFUSERHOME/p4gf_environment.cfg"
     # If .bashrc exists we need to replace some values
    local have_p4gf_env=''
    local CURRENTPATH=''
    if [ -n "$update" -a -f "$GFUSERHOME/.bashrc"  ]; then
        highlight "Updating .bashrc for user $USER, $GFUSERHOME/.bashrc"
        # get the current export PATH statement and remove the "export PATH=" and ":$PATH" strings.
        # This retains the locally added PATH elements
        local CURRENTPATH="$(grep "^export\s\+PATH" "$GFUSERHOME/.bashrc" | sed 's;:\$PATH;;' | sed 's;^export PATH=;;')"
        if [ -n "$CURRENTPATH" ]; then
            CURRENTPATH=":${CURRENTPATH}"
        fi

        local NEWPATH="$GFINSTALLPATH:${PATH}${CURRENTPATH}:\$PATH"
        # removed duplicated paths
        NEWPATH=$(echo "$NEWPATH" | sed ':b;s/:\([^:]*\)\(:.*\):\1/:\1\2/;tb;s/^\([^:]*\)\(:.*\):\1/:\1\2/')
        NEWPATH=$(echo "$NEWPATH" | sed 's;^:;;')    # remove leading ':' left by above reduction
        NEWPATH=$(echo "$NEWPATH" | sed 's;:\+;:;g')    # reduce consecutive '::' to ':'
        # comment the current export PATH statement
        sed -i "s/^export\s\+PATH/# export PATH/" "$GFUSERHOME/.bashrc"
        echo "export PATH=$NEWPATH" >> "$GFUSERHOME/.bashrc"
        # Do not update P4GF_ENV is it already exists
        have_p4gf_env="$(grep "^export\s\+P4GF_ENV" "$GFUSERHOME/.bashrc")"
        if [ -z "$have_p4gf_env" ]; then
            #echo "export P4GF_ENV=~$USER/p4gf_environment.cfg" >> $GFUSERHOME/.bashrc
            echo "export P4GF_ENV=\"$P4GF_ENV_PATH\"" >> "$GFUSERHOME/.bashrc"
        else
            P4GF_ENV_PATH=$(echo "$have_p4gf_env" | sed 's/export\s\+P4GF_ENV=//')
            P4GF_ENV_PATH=$(eval "echo $P4GF_ENV_PATH")    # force tilde interpolation
        fi

        have_config_nosystem="$(grep "^export\s\+GIT_CONFIG_NOSYSTEM" "$GFUSERHOME/.bashrc")"
        # reset GIT_CONFIG_NOSYSTEM
        if [ -z "$have_config_nosystem" ]; then
            echo "export GIT_CONFIG_NOSYSTEM=1" >> "$GFUSERHOME/.bashrc"
        else
            sed -i "s;^export\s\+GIT_CONFIG_NOSYSTEM=.*$;export GIT_CONFIG_NOSYSTEM=1;" "$GFUSERHOME/.bashrc"
        fi
        set_lc_all_lang "$GFUSERHOME/.bashrc"
    else
        # Create the bash environment config
        {
            echo "export PATH=$GFINSTALLPATH:$PATH:\$PATH"
            echo "export P4GF_ENV=~$USER/p4gf_environment.cfg"
            echo "export GIT_CONFIG_NOSYSTEM=1"
        } >> "$GFUSERHOME/.bashrc"
        echo ". ~/.bashrc" > "$GFUSERHOME/.bash_profile"
        set_lc_all_lang "$GFUSERHOME/.bashrc"
    fi
    if [ ! -d "$GFUSERHOME/.git-fusion" ]; then
        mkdir -p "$GFUSERHOME/.git-fusion"
    fi
    # Set the correct permissions on the new files in the home directory
    # There could be many files, stored on a network file system, so let
    # the user know what is happening right now (GF-2159).
    highlight "Setting file ownership and permissions for $GFUSERHOME..."
    chown -R "$USER" "$GFUSERHOME"
    USER_GROUP="$(groups "$USER" | cut -d ":" -f 2 | awk '{ print $1 }')"
    chgrp -R "$USER_GROUP" "$GFUSERHOME"
    chmod ug+r "$GFUSERHOME/.bashrc"
    chmod ug+r "$GFUSERHOME/.bash_profile"
    if [ -f "$GFUSERHOME/.bash_history" ]; then
        chmod ug+r "$GFUSERHOME/.bash_history"
    fi
    if [ -f "$GFUSERHOME/.p4enviro" ]; then
        chmod ug+r "$GFUSERHOME/.p4enviro"
    fi
    if [ -f "$GFUSERHOME/.gitconfig" ]; then
        chmod ug+r "$GFUSERHOME/.gitconfig"
    fi
    chmod ug+rwx "$GFUSERHOME/.git-fusion"

    if [ "$update" ]; then
        highlight "User $USER updated!"
    else
        highlight "User $USER created!"
    fi
}

verify_triggers_io()
{
    # Verify the triggers.io == 0
    if ! triggers_io=$(p4 -ztag -c "$P4CLIENT" -p "$P4PORT" -u "$P4USER" -C "$P4CHARSET"  configure show triggers.io | grep Value | awk '{print $3}' ); then
        $hideErrors || error "Unable to connect to Perforce service $P4PORT"
        return 1
    fi
    if [ "$triggers_io" != "0" ]; then
        $hideErrors || error "Git Fusion only supports Perforce service configurable 'triggers.io=0'."
        $hideErrors || error "This Perforce service at P4PORT=$P4PORT is set with 'triggers.io=$triggers_io'".
        return 1
    fi
}

# Checks that Perforce service is running.
# If SSL, runs p4 trust
# If unicode, sets P4CHARSET to UTF8
# If case sensitive, sets P4CASEHANDLING to sensitive
check_perforce_server()
{
    # Exit fast if we don't have the details we need
    if [ -z "$P4PORT" ]; then
        $hideErrors || error "No P4PORT specified"
        return 1
    fi

    local SSLRE="^ssl"
    local BITS=(${P4PORT//:/ })
    if [[ ${BITS[0]} =~ $SSLRE ]]; then
        debug "Trusting P4 server"
        p4 -c "$P4CLIENT"  -p "$P4PORT" trust -f -y >/dev/null 2>&1
        if [ $? -ne 0 ]; then
            error "Unable to trust the server $P4PORT"
            return 1
        fi
    fi

    local P4INFO=""
    if ! P4INFO=$(p4 -p "$P4PORT" -ztag info 2>/dev/null); then
        $hideErrors || error "Unable to connect to Perforce service $P4PORT"
        return 1
    fi

    local P4D_VERSION="$(echo "$P4INFO" | grep -F "... serverVersion" | \
        sed -e "s;^.*P4D/[^/]*/;;" -e "s;[^0-9.]*/;/;" -e "s;[.]/;/;" -e "s; .*$;;" -e "s;/; ;" )"
    local P4D_REL="$(echo "$P4D_VERSION" | awk '{ print $1; }')"
    local P4D_CHANGE="$(echo "$P4D_VERSION" | awk '{ print $2; }')"
    local MIN_CHANGE="${P4D_MIN_VERSION_ARRAY[$P4D_REL]}"
    debug "P4D version: $P4D_REL/$P4D_CHANGE"
    debug "For P4D version '$P4D_REL' the required minimum patch='$MIN_CHANGE'"
    if [ "$(awk 'BEGIN{ if ("'$P4D_REL'" < "'$P4D_MIN_VERSION'") print(1); else print(0) }')" -eq 1 ] || \
       [ -n "$MIN_CHANGE" -a "$P4D_CHANGE" -lt "${MIN_CHANGE:-0}" ]; then
        $hideErrors || error "This Perforce service $P4D_REL/$P4D_CHANGE is not supported by Git Fusion."
        if [ -n "$MIN_CHANGE" -a "$P4D_CHANGE" -lt "${MIN_CHANGE:-0}" ]; then
            $hideErrors || error "Git Fusion supports Perforce service version '$P4D_REL' starting with patch='$MIN_CHANGE'"
        else
            $hideErrors || error "Git Fusion supports Perforce services starting with $P4D_MIN_VERSION/${P4D_MIN_VERSION_ARRAY[$P4D_MIN_VERSION]}"
        fi
        return 1
    fi


    if echo "$P4INFO" | grep -q -F "unicode enabled"; then
        P4CHARSET="utf8"
    fi

    if echo "$P4INFO" | grep -q -F "caseHandling sensitive"; then
        P4CASEHANDLING="sensitive"
    fi
    P4_SERVICETYPE="$(echo "$P4INFO" | grep serverServices | awk '{print $3}' | xargs)"
    # check if service type is a forwarding replica
    for st in edge-server forwarding-replica forwarding-standby; do
        if [[ "$st" == "$P4_SERVICETYPE" ]]; then
            IS_FORWARDING_REPLICA=true
            # does this forwarding replica need a limit on clients? client
            # creation on the edge is very expensive, thus we use a larger
            # temp pool
            for maxc in edge-server; do
                if [[ "$maxc" == "$P4_SERVICETYPE" ]]; then
                    P4_SET_MAXCLIENTS=true
                fi
            done
            echo "The 'serverServices' for the Perforce service on P4PORT=$P4PORT is '$P4_SERVICETYPE'."
            echo "Git Fusion must be configured as READ ONLY on a Perforce service with services of this type."
            if ! $READ_ONLY_INSTANCE; then
                if ! $INTERACTIVE; then
                    return 1
                fi
                rmsg="Do you wish to proceed and configure this Git Fusion instance as READ ONLY? [yes/no]"
                promptfor CONFIGURE_READONLY_SERVER "$rmsg" "yes" false validate_yesno
                if [ "$CONFIGURE_READONLY_SERVER" != 'yes' ]; then
                    echo "Stopping."
                    return 1
                fi
            fi
            return 0
        fi
    done
    # check if service tpe is a non-forwarding replica
    for st in replica build-server standby; do
        if [[ "$st" == "$P4_SERVICETYPE" ]]; then
            error "The 'serverServices' for the Perforce service on P4PORT=$P4PORT is '$P4_SERVICETYPE'."
            error "Git Fusion may not be configured on a Perforce service with services of this type."
            error "Stopping."
            return 1
        fi
    done
}

# Checks that the user credentials provided are valid and that the user is
# as super-user.
check_perforce_super_user()
{
    # Exit fast if we don't have the details we need
    if [ -z "$P4PORT" -o -z "$P4USER" ]; then
        $hideErrors || error "No P4PORT or P4USER specified"
        return 1
    fi

    debug "Check $P4USER/$P4PASSWD against $P4PORT"

    if [[ -z "$P4PASSWD" ||  "$P4PASSWD" =~ ^[[:blank:]]+$ ]]; then
        echo "P4PASSWD='$P4PASSWD' is empty or is whitespace. Skipping Perforce service login."
    else
        if ! echo "$P4PASSWD" | p4 -c "$P4CLIENT" -p "$P4PORT" -u "$P4USER" -C "$P4CHARSET" login >/dev/null 2>&1; then
            $hideErrors || error "Unable to login to the Perforce service '$P4PORT' as '$P4USER' with supplied password"
            return 1
        fi
    fi

    # Check the output of p4 protects -m
    local protects_out=$(mktemp)
    if ! p4 -c "$P4CLIENT" -p "$P4PORT" -u "$P4USER" -C "$P4CHARSET" protects -m 2> "$protects_out" | grep -q "super"; then
        $hideErrors || error "User '$P4USER' must have super privileges"
        $hideErrors || cat "$protects_out"
        return 1
    fi
    rm "$protects_out"

    if ! verify_triggers_io; then
        return 1
    fi

    return 0
}

# Gathers Perforce related variables for configuring Git Fusion against an
# existing Perforce service
gather_existing_p4d_configuration()
{
    # Get and validate the admin credentials
    if $INTERACTIVE && [ -z "$P4PORT" -o -z "$P4USER" ]; then
        hideErrors=true
    fi
    while ! check_perforce_server  || ! check_perforce_super_user; do
        if $INTERACTIVE; then
            hideErrors=false
            if ! $UPGRADE; then
                promptfor P4PORT "Enter the Perforce service's P4PORT" "$P4PORT" false validate_p4port
            fi
            promptfor P4USER "Enter the Perforce super-user's username" "$P4USER" false validate_p4user
            promptfor P4PASSWD "Enter the Perforce super-user's password" "$P4PASSWD" true
        else
            # Detailed errors reported by check functions
            exit 1
        fi
    done
}

# Gather if Perforce service is case-sensitive
gather_case_p4d_configuration()
{
    # Git Fusion only supports case-sensitive Perforce services
    if [ "$P4CASEHANDLING" != "sensitive" ]; then
        errorOn
        cat <<EOT
The Perforce service's case-handling policy is not set to 'sensitive', which
means any files introduced via Git whose names differ only by case may result
in data loss or errors during push. It is strongly advised to set the
case-handling policy to 'sensitive'.

EOT
        #promptfor INSTALL_CASE_INSENSITIVE "Do you wish to continue the GF installation? [yes/no]" "no" false validate_yesno
        INSTALL_CASE_INSENSITIVE=yes
        if [ "$INSTALL_CASE_INSENSITIVE" != 'yes' -a  "$INSTALL_CASE_INSENSITIVE" != 'Yes' ]; then
            echo "p4d on $P4PORT is not set to 'sensitive'."
            echo "Stopping Git Fusion installation."
            highlightOff
            exit 1
        fi
        # echo "Bypassing p4gf_super_init.py case check with '--ignore-case'."
        # echo "Continuing Git Fusion installation."
        highlightOff
    fi
}

# Use the package manager to install the Perforce service package
# This calls configure-helix-p4d.sh with the apropriate arguments
do_not_install_p4d()
{
    errorOn
    cat <<EOT
Sorry! configure-git-fusion.sh does not support installing new server.
Please install and configure Helix Versioning Engine and re-run this script.
You can install Helix Versioning Engine package by running:
EOT

    if [ $PLATFORM == "debian" ]; then
        echo "sudo apt-get install helix-p4d"
        highlightOff
        exit 1
    elif [ $PLATFORM == "redhat" ]; then
        echo "sudo yum install helix-p4d"
        highlightOff
        exit 1
    else
        die "Sorry! This script doesn't know how to install the Perforce service on this platform!"
    fi
    highlightOff

}

# Ensure the timezone is valid by checking to see if the timezone file exists.
validate_timezone()
{
    if [ -z "$1" ]; then
        $hideErrors || error "Timezone must be specified!"
        return 1
    fi

    local ZONE="${1// /_}"
    debug "Looking for /usr/share/zoneinfo/$ZONE"
    if [ -z "$ZONE" -o ! -e "/usr/share/zoneinfo/$ZONE" ]; then
        $hideErrors || error "Unknown timezone! Must be in Olson format."
        return 1
    fi
    return 0
}

# This retrieves and validates the timezone. If no timezone was provided,
# we try to suggest the system's current timezone or fall back to UTC.
#
# If interactive, we prompt if the timezone is invalid.
get_timezone()
{
    # No need to get timezone for upgrades or local p4d installs.
    if $UPGRADE; then
        return
    fi
    if [[ $SERVER == 'local' ]]; then
        return
    fi

    # Get the current timezone by one means or another, or default to UTC
    # if we cannot discover the system setting.
    local ZONE="Etc/UTC"
    if [ -n "$TIMEZONE" ]; then
        ZONE=$TIMEZONE
    elif [ -e "/etc/timezone" ]; then
        # This works on Ubuntu systems.
        ZONE=$(cat /etc/timezone)
    elif [ -e "/etc/sysconfig/clock" ]; then
        # This works on CentOS 6.
        eval "$(grep ZONE /etc/sysconfig/clock)"
    else
        # And then there is CentOS 7. Not much else we can do, without
        # relying on systemd being installed and invoking timedatectl. This
        # method will produce an abbreviated value (e.g. "UTC"), but that
        # still has a good chance of working.
        ZONE=$(date +'%Z')
    fi

    # Validate the timezone.
    if $INTERACTIVE && [ -z "$TIMEZONE" ]; then
        hideErrors=true
    fi
    if ! validate_timezone "$TIMEZONE"; then
        if $INTERACTIVE; then
            hideErrors=false
            promptfor ZONE "Which timezone is your Perforce service in?" "$ZONE" false validate_timezone
        else
            exit 1;
        fi
    fi
    TIMEZONE=$ZONE
    debug "Timezone set to $TIMEZONE"
}

# Configure SYSLOG fo Git Fusion
configure_syslog()
{
    highlight "Configuring logging"

    # Detect if this is an OVA, in which case, logs go on an extendable volume
    local LOGPATH="/var/log"
    if [ -d "/fs/git-fusion/log" ]; then
        LOGPATH="/fs/git-fusion/log"
        # For the OVA - set P4GF_LOGS_DIR in p4gf_environment.cfg, if not already set
        if ! grep -q ^P4GF_LOGS_DIR "$P4GF_ENV_PATH"; then
            echo "P4GF_LOGS_DIR=$LOGPATH" >> "$P4GF_ENV_PATH"
        fi
    fi

    # Detect where the syslog logrotate configuration is
    local LOGROTATE_CFG=""
    if [ -e "/etc/logrotate.d/rsyslog" ]; then
        LOGROTATE_CFG="/etc/logrotate.d/rsyslog"
    elif [ -e "/etc/logrotate.d/syslog" ]; then
        LOGROTATE_CFG="/etc/logrotate.d/syslog"
    else
        error "Failed to find logrotate configuration! Skipping syslog configuration!"
        return
    fi

    # Ensure the logging config is in place.
    if [ ! -e "/etc/git-fusion.log.conf" ]; then
        cp "$GFINSTALLPATH/git-fusion.log.conf" /etc/git-fusion.log.conf
    fi

    # Add the extra syslog filter rules for Git Fusion
    mkdir -p /etc/rsyslog.d
    {
        echo ":syslogtag,contains,\"git-fusion[\" -$LOGPATH/git-fusion.log"
        echo ":syslogtag,contains,\"git-fusion-auth[\" -$LOGPATH/git-fusion-auth.log"
        echo ":syslogtag,contains,\"git-fusion-auth-keys[\" -$LOGPATH/git-fusion-auth-keys.log"
    } > /etc/rsyslog.d/30-git-fusion.conf

    # Replace previous Git Fusion log rotation configuration
    sed "\|$LOGPATH/git-fusion|d" -i "$LOGROTATE_CFG"
    {
        echo "$LOGPATH/git-fusion-auth.log"
        echo "$LOGPATH/git-fusion.log"
        cat "$LOGROTATE_CFG"
    } > /tmp/syslog.tmp
    cat /tmp/syslog.tmp > "$LOGROTATE_CFG"
    rm -f /tmp/syslog.tmp

    # We'll try the standard way to restart the daemon first
    if ! /etc/init.d/rsyslog restart >/dev/null 2>&1; then
        # If that failed (or at least said it failed) try the service command
        service rsyslog restart >/dev/null 2>&1
    fi
}

# Configure CRONTAB for Git Fusion
configure_crontab()
{
    highlight "Configuring crontab"

    if [ ! -d /etc/cron.d/ ]; then
        mkdir /etc/cron.d
    fi

    if [ -e /etc/cron.d/perforce-git-fusion ]; then
        sed -i -e "s;^PATH.*$;PATH = $GFINSTALLPATH:$PATH;g" /etc/cron.d/perforce-git-fusion
        sed -i -e "/^$/ d" -e "/.* .* .* .* .* $GFUSER / d" /etc/cron.d/perforce-git-fusion
        {
            echo "* * * * * $GFUSER bash -l -c p4gf_auth_update_authorized_keys.py"
            echo ""
        } >> /etc/cron.d/perforce-git-fusion
    else
        {
            echo "PATH = $GFINSTALLPATH:$PATH"
            echo "# CAUTION: This file is updated by configure-git-fusion.sh"
            echo "# update auth keys EVERY MINUTE"
            echo "* * * * * $GFUSER bash -l -c p4gf_auth_update_authorized_keys.py"
            echo ""
        } > /etc/cron.d/perforce-git-fusion
    fi
}

# This sets the required values in the Git Fusion environment file
# We need to do this before we query the server-ids, or else we get an error.
set_p4gf_env()
{
    if $UPGRADE; then
        return
    fi
    highlight "Configuring Git Fusion p4gf_environment.cfg"

    local GFUSERHOME=$(getent passwd "$GFUSER" | cut -d ":" -f 6 )
    debug "Found $GFUSER's home dir: $GFUSERHOME"

    if [ -e "$P4GF_ENV_PATH" ]; then
        # Ensure that if P4PORT/P4CHARSET are already set, they are replaced
        debug "Updating existing environment configuration: $P4GF_ENV_PATH"
        # remove these two and force reset below
        sed '/^P4PORT/d' -i "$P4GF_ENV_PATH"
        sed '/^P4CHARSET/d' -i "$P4GF_ENV_PATH"
    else
        highlight "$P4GF_ENV_PATH"
         {
             cat "$GFINSTALLPATH/p4gf_env_config.txt"
             echo "[environment]"
             echo "GIT_BIN=git"
         } > "$P4GF_ENV_PATH"
    fi
    # Ensure that all the settings we need are set
    # Set values which do not exist in the config
    # For a new p4gf_environment.cfg this will be all that are appropriate
    if ! grep -q ^P4GF_HOME "$P4GF_ENV_PATH"; then
        echo "P4GF_HOME=$GFUSERHOME/.git-fusion" >> "$P4GF_ENV_PATH"
    fi
    echo "P4PORT=$P4PORT" >> "$P4GF_ENV_PATH"
    if [ "$P4CHARSET" != "none" ]; then
        echo "P4CHARSET=$P4CHARSET" >> "$P4GF_ENV_PATH"
    fi
    if $IS_FORWARDING_REPLICA; then   # auto detected so do not reset values which already exist
        if ! grep -q ^READ_ONLY "$P4GF_ENV_PATH"; then
            echo "READ_ONLY=true" >> "$P4GF_ENV_PATH"
        fi
        if $P4_SET_MAXCLIENTS; then
            if ! grep -q ^MAX_TEMP_CLIENTS "$P4GF_ENV_PATH"; then
                echo "MAX_TEMP_CLIENTS=$MAX_TEMP_CLIENTS_EDGE" >> "$P4GF_ENV_PATH"
            fi
        fi
    fi
    if $READ_ONLY_INSTANCE; then  # user argument so set if requested
        sed '/^READ_ONLY/d' -i "$P4GF_ENV_PATH"
        echo "READ_ONLY=true" >> "$P4GF_ENV_PATH"
    fi
    if ! grep -q ^P4D_ON_LOCALHOST "$P4GF_ENV_PATH"; then
        if [[ $SERVER == 'local' ]]; then
            islocal='true'
        else
            islocal='false'
        fi
        echo "P4D_ON_LOCALHOST=$islocal" >> "$P4GF_ENV_PATH"
    fi
    # Set a bogus client name so that 'hostname' will not be the default client
    if ! grep -q ^P4CLIENT "$P4GF_ENV_PATH"; then
        echo "P4CLIENT=$P4CLIENT" >> "$P4GF_ENV_PATH"
    fi
    chown "$GFUSER" "$P4GF_ENV_PATH"
    if  $DEBUG; then
        debug "IS_FORWARDING_REPLICA = $IS_FORWARDING_REPLICA"
        debug "$P4GF_ENV_PATH"
        cat "$P4GF_ENV_PATH" | grep -v '^#'
    fi


    local P4GFHOME="$(grep ^P4GF_HOME "$P4GF_ENV_PATH" | cut -f 2 -d "=" | xargs)"
    if [ -z "$P4GFHOME" ]; then
        P4GFHOME="$GFUSERHOME/.git-fusion"
    fi
    if [ ! -d "$P4GFHOME" ]; then
        mkdir -p "$P4GFHOME"
    fi
    chown -R "$GFUSER" "$P4GFHOME"
    chgrp "$(groups "$GFUSER" | cut -d ":" -f 2 | awk '{ print $1 }')" -R "$P4GFHOME"
    chmod ug+rwx -R "$P4GFHOME"
}

# This calls the Git Fusion initialization script to request the list of in-use
# Git Fusion server IDs.
# If the one we want to use is already in use, we either prompt for a different
# one, or we fail.
check_uniq_p4gf_key()
{
    debug "Checking for unique server-id."

    local GFUSERHOME="$(getent passwd "$GFUSER" | cut -d ":" -f 6 )"
    local P4GFHOME="$(grep ^P4GF_HOME "$GFUSERHOME/p4gf_environment.cfg" | cut -f 2 -d "=" | xargs)"
    if [ -z "$P4GFHOME" ]; then
        P4GFHOME="$GFUSERHOME/.git-fusion"
    fi

    # Quick check to see if the server-id is already set and is not changing
    if [ -e "$P4GFHOME/server-id" ]; then
        OLDSERVERID="$(cat "$P4GFHOME/server-id")"
        debug "Found an existing server-id: $OLDSERVERID"
    fi
    if [ -n "$OLDSERVERID" -a -n "$SERVERID" -a "$OLDSERVERID" == "$SERVERID"  -a  "$P4PORT_CHANGED" = false ]; then
        return 0
    fi
    local SSLRE="^ssl"
    local BITS=(${P4PORT//:/ })
    if [[ ${BITS[0]} =~ $SSLRE ]]; then
        debug "Trusting P4 server as $GFUSER"
        su - "$GFUSER" -c "p4 -c "$P4CLIENT" -p $P4PORT trust -f -y >/dev/null 2>&1"
        if [ $? -ne 0 ]; then
            error "Unable to trust the server $P4PORT"
            return 1
        fi
    fi

    if  ! su - "$GFUSER" -c "echo \"$P4PASSWD\"| p4 -c \"$P4CLIENT\" -p \"$P4PORT\" -u \"$P4USER\" -C \"$P4CHARSET\" login >/dev/null 2>&1"; then
        error "Couldn't log into Perforce as $P4USER from the system account $GFUSER!"
        return 1
    fi

    debug "Getting a list of server-ids in use on $P4PORT.  SERVERID=[$SERVERID]"
    has_serverid=''
    if [ -n "$SERVERID" ]; then
        if ! su - "$GFUSER" -c "echo \"$P4PASSWD\" | p4 -c "$P4CLIENT" -p \"$P4PORT\" -u \"$P4USER\" -C \"$P4CHARSET\" login >/dev/null"; then
            die "Cannot login to $P4PORT with ${P4USER}/{$P4PASSWD}."
        fi
        debug "Calling super_init --showids"
        has_serverid="$(su - "$GFUSER" -c "export P4CHARSET=$P4CHARSET && $GFINSTALLPATH/p4gf_super_init.py --port $P4PORT --user $P4USER --showids" | sed -r -e '/^\s+([^ ]+).*/ s//\1/g' -e 's/.*(IDs:|Proceeding.).*//' | egrep  "^${SERVERID}$" | awk '{print $1}')"
   fi
   debug "has_serverid=$has_serverid"
    if [ -z "$SERVERID" -o -n "$has_serverid" ]; then
        if [ -z "$SERVERID" ]; then
            if [ -n "$OLDSERVERID" ]; then
                SERVERID="$OLDSERVERID"
            else
                SERVERID="$(hostname)"
                if [ -z "$SERVERID" -o "$SERVERID" == "localhost" ]; then
                    SERVERID="git-fusion"
                fi
            fi
            check_uniq_p4gf_key
        else
            error "The Git Fusion server-id '$SERVERID' is taken!"
            if $INTERACTIVE; then
                promptfor SERVERID "Please enter a new server-id"
                check_uniq_p4gf_key
            else
                return 1
            fi
        fi
    fi
}

# Calls the Git Fusion initialization script with the required arguments.
# Sets some values in the p4gf_environment.cfg first.
p4gf_super_init()
{
    highlight "Initializing Git Fusion with p4gf_super_init.py"

    local SSLRE="^ssl"
    local BITS=(${P4PORT//:/ })
    if [[ ${BITS[0]} =~ $SSLRE ]]; then
        debug "Trusting P4 server as $GFUSER"
        su - "$GFUSER" -c "p4 -c "$P4CLIENT" -p $P4PORT trust -f -y >/dev/null 2>&1"
        if [ $? -ne 0 ]; then
            error "Unable to trust the server $P4PORT"
            return 1
        fi
    fi

    local GFUSERHOME="$(getent passwd "$GFUSER" | cut -d ":" -f 6 )"
    debug "Found $GFUSER's home dir: $GFUSERHOME"

    local P4GFHOME="$(grep ^P4GF_HOME "$GFUSERHOME/p4gf_environment.cfg" | cut -f 2 -d "=")"
    if [ -z "$P4GFHOME" ]; then
        P4GFHOME="$GFUSERHOME/.git-fusion"
    fi

    # Ensure we can set the server-id
    if [ -e "$P4GFHOME/server-id" ]; then
        chown "$GFUSER" "$P4GFHOME/server-id"
    fi

    local FORCE=""
    if [ "$OLDSERVERID" != "$SERVERID" ]; then
        FORCE="--force"
    fi

    # Case insensitive Perforce services require an extra flag
    local CASEIGNORE=""
    # if [ "$P4CASEHANDLING" != "sensitive" ]; then
    #     CASEIGNORE="--ignore-case"
    # fi

    # Set arg to create unknown_git user
    if [ "$UNKNOWN_USER" == "unknown" ]; then
        UNKNOWN_USER_ARG="--unknown-git"
    else
        UNKNOWN_USER_ARG=""
    fi
    # Login as super and init Git Fusion
    local super_init_out=$(mktemp)
    chmod 666 "$super_init_out"
    if ! su - "$GFUSER" -c "export P4CLIENT=$P4CLIENT; echo \"$P4PASSWD\" | p4 -p \"$P4PORT\" -u \"$P4USER\" -C \"$P4CHARSET\" login >/dev/null" || \
       ! su - "$GFUSER" -c "\"$GFINSTALLPATH/p4gf_super_init.py\" --port \"$P4PORT\" --user \"$P4USER\" --id \"$SERVERID\" $P4GFPASSWD_ARG $UNKNOWN_USER_ARG $FORCE $CASEIGNORE > $super_init_out 2>&1"; then
        echo "There was an error in p4gf_super_init."
        sed -n "/Error/p" "$super_init_out"
        # Print the error messages concerning disallowed passwd command
        sed -n "/Unable to run 'p4 passwd/,+4p" "$super_init_out"
        # Print the error messages concerning protections
        sed -n "/You don't have permission/,+2p" "$super_init_out"
        echo "p4gf_super_init.py log"
        cat "$super_init_out"
        die "Initialization of Git Fusion failed! p4gf_super_init.py log = $super_init_out"
    fi
    # If an auth-check trigger is present, super init will report password/logins are required.
    if grep -q '!!' "$super_init_out"; then
        grep '!!' "$super_init_out" | sed 's/\(.*\)The Perforce service has an auth_check/\n\1The Perforce service has an auth_check/'
        echo ''
    fi
    if  $DEBUG; then
        debug "\np4gf_super_init.py succeeded: Log:"
        cat "$super_init_out"
        debug "\n"
    fi
    rm -f "$super_init_out"


    # Set the timezone
    if [ -n "$TIMEZONE" -a "$UPGRADE" = false  ]; then
        highlight "Setting Git Fusion timezone to '$TIMEZONE'."
        if ! echo "$P4PASSWD" | p4 -c "$P4CLIENT" -p "$P4PORT" -u "$P4USER" -C "$P4CHARSET" login >/dev/null || \
           ! p4 -c "$P4CLIENT" -p "$P4PORT" -u "$P4USER" -C "$P4CHARSET" key git-fusion-perforce-time-zone-name "$TIMEZONE" >/dev/null ;  then
            echo "error setting TIMEZONE $TIMEZONE"
        fi
    fi


}

# Complete the inialization with p4gf_init.py
# after triggers have been installed.
p4gf_init()
{
    highlight "Initializing Git Fusion with p4gf_init.py"
    local init_out=$(mktemp)
    chmod 666 "$init_out"
    if ! su - "$GFUSER" -c "export P4CLIENT=$P4CLIENT; \"$GFINSTALLPATH/p4gf_init.py\" -v > \"$init_out\" 2>&1"; then
        echo "There was an error in p4gf_init."
        cat "$init_out"
        die "Initialization of Git Fusion failed! p4gf_init.py log = $init_out"
    fi
    if  $DEBUG; then
        debug "\npgf_init.py succeeded: Log:"
        cat "$init_out"
        debug "\n"
    fi
    rm -f "$init_out"
}

# Configure Git Fusion for handling unknown git authors.
configure_for_unknown_users()
{
    if $UPGRADE; then
        return
    fi

    case "$UNKNOWN_USER" in
        reject)
            # do nothing - default action rejects unknown users
            highlight "Git Fusion will reject pushes with authors without Perforce user accounts."
            ;;

        pusher)
            # set global config: change-owner='pusher'
            highlight "Configuring Git Fusion for change-owner=pusher"
            local config_out=$(mktemp)
            chmod 666 "$config_out"
            if ! su - "$GFUSER" -c " export P4CLIENT=$P4CLIENT;  \"$GFINSTALLPATH/p4gf_config.py\" -s git-to-perforce/change-owner=pusher  > \"$config_out\" 2>&1"; then
                echo "There was an error in p4gf_config."
                cat "$config_out"
                die "Editing global config file of Git Fusion failed! p4gf_config.py log = $config_out"
            fi
            ;;

        unknown)
            # created unknown user
            highlight "Created 'unknown_git' user."
            ;;
        *)
            die " --unknownuser must be 'reject', 'pusher', or ;unknown'"
            exit 1
            ;;
    esac
}

# Call the p4gf_submit_trigger.py --install command
install_triggers_local()
{
    highlight "Installing Git Fusion triggers locally on Perforce service on P4PORT $P4PORT."

    local TRIGGER=""
    if ! TRIGGER=$(which p4gf_submit_trigger.py 2>/dev/null); then
        debug "Checking: $GFINSTALLPATH/p4gf_submit_trigger.py"
        if [ -e "$GFINSTALLPATH/p4gf_submit_trigger.py" ]; then
            TRIGGER="$GFINSTALLPATH/p4gf_submit_trigger.py"
        fi
    fi
    if [ -z "$TRIGGER" ]; then
        die "Couldn't find trigger script: p4gf_submit_trigger.py"
    else
        debug "Trigger script found at: $TRIGGER"
    fi

    # Use the --config-path arg to ensure that multiple GF instance with different LOCAL p4d
    # will have unigue configurations.
    if $NO_CONFIG; then
        config_arg="--no-config"
    else
        config_arg="--config-path=${TRIGGER%.py}.cfg.${P4PORT#*:}"
    fi
    local triggers_out=$(mktemp)
    chmod 666 "$triggers_out"
    if ! P4CHARSET=$P4CHARSET python3.3 "$TRIGGER" --install "$config_arg"  "$P4PORT" "$P4USER" "$P4PASSWD" > "$triggers_out"; then
        cat "$triggers_out";
        die "Failed to install triggers into Perforce service!"
    fi
    if  $DEBUG; then
        debug "\np4gf_submit_trigger.py trigger installation succeeded: Log"
        cat "$triggers_out"
        debug "\n"
    else
        trigger_version=$(sed -n  '/git-fusion-submit-trigger-version/p' "$triggers_out")
        highlight "$trigger_version"
    fi
    rm -f "$triggers_out"
}

done_all_msgs()
{
    highlightOn
    cat <<EOT

:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
::
::  Git Fusion configuration has completed successfully.
::
::  Here is what had been done so far:
::
::  $TRIGGER_MSG
::  - Git Fusion is configured with system user [$GFUSER]
::  - Git Fusion configuration file is
::    [$P4GF_ENV_PATH]
::
::  Here is what still needs to be done:
::
::  - Set up users and repositories, as covered in the Git Fusion Guide:
::
::  https://www.perforce.com/perforce/doc.current/manuals/git-fusion
::
:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::

EOT
    highlightOff
}

done_notriggers_msgs()
{
    highlightOn
    cat <<EOT

:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
::
::  Git Fusion configuration has completed successfully.
::
::  Here is what had been done so far:
::
::  - Git Fusion is configured with system user [$GFUSER]
::  - Git Fusion configuration file is
::    [$P4GF_ENV_PATH]
::
::  Here is what still needs to be done:
::
::  - Install Git Fusion triggers on your Perforce Service host,
::  as covered in the Git Fusion Guide
::  - Set up users and repositories, as covered in the Git Fusion Guide:
::
::  https://www.perforce.com/perforce/doc.current/manuals/git-fusion
::
:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
EOT
    highlightOff
}

prompt_for_GF_updates()
{
    if ! $INTERACTIVE; then
        return
    fi

    # update program not present - do not prompt
    if [ ! -x "$GFINSTALLPATH/p4gf_get_product_updates.py" ]; then
        return
    fi
    promptfor CHECKFORUPDATES "Do you want to check for Git Fusion updates? [yes/no]" "no" false validate_yesno
    highlightOn
    if [ "$CHECKFORUPDATES" == 'yes' -o  "$CHECKFORUPDATES" == 'Yes' ]; then
        if ! UPDATES=$("$GFINSTALLPATH/p4gf_get_product_updates.py" -p "$P4PORT"); then
            echo "Unable to check for Git Fusion updates at the moment."
            return
        fi
        echo
        echo "$UPDATES"
        echo
        if echo "$UPDATES" | grep "There are updates available" > /dev/null ; then
            promptfor STOPFORUPDATES "Do you want to stop now and update Git Fusion? [yes/no]" "no" false validate_yesno
            if [ "$STOPFORUPDATES" == 'yes' -o  "$STOPUPDATES" == 'Yes' ]; then
                cat <<EOT

Stopping this configuration.
You may run this script again after you have updated Git Fusion.

EOT
            highlightOff
            exit
            fi

        fi
    fi
    highlightOff

}
# Do the git-fusion-* users exist and have passwd?
need_to_create_gf_users()
{
    users_with_passwds=0
    missing_users=0
    for user in git-fusion-user git-fusion-reviews-${SERVERID} git-fusion-reviews--all-gf git-fusion-reviews--non-gf
    do
       if ! p4 -c "$P4CLIENT" -p "$P4PORT" -u "$P4USER" -C "$P4CHARSET" users -a "$user"  2>&1 | grep 'no such user' > /dev/null; then
           has_no_passwd="$(p4 -c "$P4CLIENT" -p "$P4PORT" -u "$user" -C "$P4CHARSET" login -s 2>/dev/null  | grep -e 'no password set for this user')"
           if [ -z "$has_no_passwd" ]; then
               ((users_with_passwds=users_with_passwds+1))
           fi
       else
               ((missing_users=missing_users+1))
       fi
    done
    # We need the password if some user needs creation
    # Or if all the passwords are not set
    # super_init sets passwords only for user that it creates
    if [[ $missing_users -ne 0 ]]; then
        echo 1
    elif [[ "$users_with_passwds" -ne 0 ]]; then
        echo 0
    else
        echo 1
    fi
}

# Should we configure HTTPS?
prompt_for_HTTPS_config()
{
    # Do not prompt in non-interactive mode
    if ! $INTERACTIVE; then
        return
    fi

    # Do not prompt during upgrade
    if $UPGRADE; then
        return
    fi

    # If users supply --https flag from the command line, do not prompt again
    if $HTTPS; then
        return
    fi

    cat <<EOT
Git and Git Fusion support the SSH and HTTPS protocols for accessing remote
Git servers. SSH support is available by default. HTTPS support is optional,
and enables use of web style remote URLs:

  $ git clone www.myco.com/myrepo

When Git Fusion is configured with HTTPS support, users authenticate using
their Helix user name and password, no pre-shared keys are required. This
script can take care of the additional packages (Apache2 web server) and
configuration needed to configure Git Fusion with HTTPS support.
EOT
    promptfor HTTPS_PROMPT "Do you wish to configure Git Fusion with https support? [yes/no]" "yes" false validate_yesno
    if [ "$HTTPS_PROMPT" == "yes" ]; then
        HTTPS=true
    fi
}

# Attempt to ascertain if there is a local running Perforce service using p4dctl
detect_local_p4d()
{
    # Don't attempt to use p4dctl if it is not available
    if ! $UPGRADE && $INTERACTIVE && which p4dctl >/dev/null 2>&1; then
        hideErrors=false
        debug "Using p4dctl to detect if there is a running Perforce service."
        local DEFAULT_SERVICE="$(p4dctl list -t p4d 2>&1 | sed -n '2p' | awk '{ print $3; }')"
        if [ -n "$DEFAULT_SERVICE" ]; then
            eval "$(p4dctl env $DEFAULT_SERVICE -t p4d P4PORT)"
            eval "$(p4dctl env $DEFAULT_SERVICE -t p4d P4USER)"
            if validate_p4port "$P4PORT"; then
                highlight "There appears to be a running Perforce service \"$DEFAULT_SERVICE\" on P4PORT \"$P4PORT\"."
                promptfor USE_DETECTED_HELIX "Would you like to use this configuration for Git Fusion? [yes/no]" "yes" false validate_yesno
                if [ "$USE_DETECTED_HELIX" == 'yes' ]; then
                    if [ -z "$P4USER" ]; then
                        promptfor P4USER "Enter the Perforce super-user's username" "$P4USER" false validate_p4user
                        promptfor P4PASSWD "Enter the Perforce super-user's password" "$P4PASSWD" true
                    elif validate_p4user "$P4USER"; then
                        highlight "The super-user for the running Perforce service appears to be \"$P4USER\"."
                        promptfor USE_DETECTED_P4USER "Would you like to use this P4USER as super-user for Git Fusion? [yes/no]" "yes" false validate_yesno
                        if [ "$USE_DETECTED_P4USER" == 'yes' ]; then
                            promptfor P4PASSWD "Enter the Perforce super-user's password" "$P4PASSWD" true
                        fi
                    fi
                fi
            fi
        else
            highlight "No running local Perforce service detected, continuing with configuration."
            return
        fi
        # Just one chance to pass right values since users will be prompted for them later in case of a mistake
        if ! check_perforce_server  || ! check_perforce_super_user ; then
            highlight "Detected running Perforce service will not be used. You will be prompted for P4PORT and P4USER later."
            unset P4PORT
            unset P4USER
            unset P4PASSWD
        else
            # Success! Running Helix service is detected, use supplied P4PORT, P4USER and P4PASSWD
            SERVER='local'
            DETECTED_HELIX='true'
        fi
    fi
}

#-------------------------------------------------------------------------------
# Begin functionallity
#-------------------------------------------------------------------------------

# Prevent warnings from sudo if we are in a directory the target user
# does not have permission to be in. But store the original directory first.
SCRIPT="$(basename "$0")"
SCRIPTPATH="$( cd "$(dirname "$0")" ; pwd -P )"
cd /

# Do not require sudo for --help.
if [ "$1" == "--help" ]; then
    usage
    exit 0
fi

# Compatibility checks
ensure_64bit
ensure_root "$@"

# Clean the environment
ENVREG="^P4"
for c in $(env | cut -d '=' -f 1); do
    if [[ "$c" =~ $ENVREG ]]; then
        unset "$c";
    fi;
done

# Evaluate arguments.

P4USER=""
P4PASSWD=""
P4GFPASSWD=""
P4PORT=""
P4ROOT=""
SERVERID=""
SERVER=""
UNICODE=""

GFUSER="git"
GFINSTALLPATH=""
TIMEZONE=""
P4CHARSET="none"
P4CASEHANDLING="unknown"
P4_SERVICETYPE=""
P4_SET_MAXCLIENTS=false
IS_FORWARDING_REPLICA=false
READ_ONLY_INSTANCE=false
NO_CONFIG=false
OLDSERVERID=""
UPGRADE=false
UNKNOWN_USER=""
DONE=false
DONE_NO_TRIGGERS=false
HTTPS=false
VERIFY=false
ARG_GFUSER=false

INTERACTIVE=true

if [[ "$*" =~ '--debug' ]]; then
    echo "called with: configure-git-fusion.sh $*"
fi

TEMP=$(getopt -n "configure-git-fusion.sh" \
        -o "nm" \
        -l "super:,superpassword:,gfp4password:,gfsysuser:,gfdir:,server:,id:,p4root:,p4port:,timezone:,unknownuser:,unicode,readonly,https,no-config,verify,debug,help" -- "$@")
if [ $? -ne 0 ]; then
    usage
    exit 1
fi

# Save the arg count to determine later whether this script was called with no arguments.
NUM_ARGS=$#

# Re-inject args from getopt, so now we know they're valid and in the
# right order.
eval set -- "$TEMP"
while true; do
    case "$1" in
    -n)                 INTERACTIVE=false;  shift;;
    -m)                 MONOCHROME=true;    shift;;
    --super)            P4USER=$2;          shift 2;;
    --superpassword)    P4PASSWD=$2;        shift 2;;
    --gfp4password)     P4GFPASSWD=$2;      shift 2;;
    --gfsysuser)        GFUSER=$2; ARG_GFUSER=true;         shift 2;;
    --gfdir)            GFINSTALLPATH=$2;   shift 2;;
    --server)           SERVER=$2;          shift 2;;
    --id)               SERVERID=$2;        shift 2;;
    --p4root)           highlight "You used depreciated option --p4root, it will be ignored";          shift 2;;
    --p4port)           P4PORT=$2;          shift 2;;
    --timezone)         TIMEZONE=$2;        shift 2;;
    --unknownuser)      UNKNOWN_USER=$2;    shift 2;;
    --https)            HTTPS=true;         shift ;;
    --unicode)          highlight "You used depreciated option --unicode, it will be ignored"; shift;;
    --readonly)         READ_ONLY_INSTANCE=true; shift;;
    --no-config)        NO_CONFIG=true;     shift;;
    --verify)           VERIFY=true;        shift;;
    --debug)            DEBUG=true;         shift;;
    --help)             usage ;             exit 0;;
    --) shift ; break ;;
    *) die "Command-line syntax error! Unknown option: $1" ; exit 1 ;;
    esac
done

if $INTERACTIVE || $DEBUG; then
    highlightOn
    cat <<INTERACTIVE
Summary of arguments passed:

Perforce super-user            [${P4USER:-(not specified)}]
Perforce super-user password   [${P4PASSWD:-(not specified)}]
Git Fusion users passwords     [${P4GFPASSWD:-(not specified)}]
Git Fusion system user         [${GFUSER:-(not specified)}]
Git Fusion install path        [${GFINSTALLPATH:-(not specified)}]
Server type                    [${SERVER:-(not specified)}]
Read only?                     [${READ_ONLY_INSTANCE:-(not specified)}]
Git Fusion server id           [${SERVERID:-(not specified)}]
Perforce service P4PORT        [${P4PORT:-(not specified)}]
Perforce service timezone      [${TIMEZONE:-(not specified)}]
Change owner for unknown users [${UNKNOWN_USER:-(not specified)}]
Configure HTTPS?               [${HTTPS:-(not specified)}]

For a list of other options, type Ctrl-C to exit, and then run:
\$ sudo $SCRIPTPATH/$SCRIPT --help

You have entered interactive configuration for Git Fusion. This script will
ask a series of questions, and use your answers to configure Git Fusion for
first time use. Options passed in from the command line or automatically
discovered in the environment are presented as defaults. You may press enter
to accept them, or enter an alternative.

INTERACTIVE
    highlightOff
    hideErrors=false
else
    hideErrors=false
fi

# Create a bogus client name
export P4CLIENT="GF_0xS_Sx0_FG"
#
# Begin data collection and validation
#

#
# Begin data collection and validation
#

#
# Determine if we are upgrading an exising installation
# Exists user 'git' ?
# ... is the home dir of 'git'  /opt/perforce/git-fusion/home/perforce-git-fusion
# ... and does it exist
# ... does it contain p4gf_environment.cfg ?
# Extract the P4PORT and P4GF_HOME.
# Extract the server-id from P4GF_HOME/server-id.
# server_type=remote ( unless we find P4D_ON_LOCALHOST=true in p4gf_environment.cfg)
# This script will still require the Perforce super-user and password to function.

check_if_upgrade_and_set_parameters()
{
# This optimized configure check is expects no arguments or
# exactly four arguments: '--super <user> --superpassword <pw>'
# Otherwise, it is a noop and normal argument processing is performed.
# But we do not count the meta arguments: --debug, -n -m
if $DEBUG ; then
    NUM_ARGS=$((NUM_ARGS-1))
fi
if  ! $INTERACTIVE ; then
    NUM_ARGS=$((NUM_ARGS-1))
fi
if  $MONOCHROME ; then
    NUM_ARGS=$((NUM_ARGS-1))
fi
if  $VERIFY ; then
    NUM_ARGS=$((NUM_ARGS-1))
fi

min_expected_arg_count=0
max_expected_arg_count=4
# Allow the update to succeed on a non-default('git') GFUSER
# This would have been passed in with '--gfsysuser <user>'
if $ARG_GFUSER; then
	min_expected_arg_count=2
	max_expected_arg_count=6
fi

if [ "$NUM_ARGS" -ne $min_expected_arg_count ]; then
    if [ "$NUM_ARGS" -ne $max_expected_arg_count ]; then
        return
    else
        if [[ ! "$P4USER" ||  ! "$P4PASSWD" ]]; then
            return
        fi
    fi
fi
debug "Appears to be an upgrade/verify of user '$GFUSER' . Check other conditions"
# Either no arguments or the four expected p4 super/password arguments
# Forward ...

    user=$GFUSER
    if validate_system_user "$user"; then
        local GFUSERHOME="$(getent passwd "$user" | cut -d ":" -f 6 )"
        P4GF_ENV_PATH="$GFUSERHOME/p4gf_environment.cfg"
        if [ -f "$P4GF_ENV_PATH" ]; then
            port="$(grep "^P4PORT" "$P4GF_ENV_PATH" | sed 's;^P4PORT=;;' | xargs )"
            gfhome="$(grep "^P4GF_HOME" "$P4GF_ENV_PATH" | sed 's;^P4GF_HOME=;;' | xargs )"
            if [ -e "$gfhome/server-id" ]; then
                serverid="$(cat "$gfhome/server-id")"
            fi
            value="$(grep "^P4D_ON_LOCALHOST" "$P4GF_ENV_PATH" | sed 's;^P4D_ON_LOCALHOST=;;' | xargs )"
            value="$(echo "$value" | tr '[:upper:]' '[:lower:]')"
            if [[ "$value" == "" ]]; then
                server_type=''
            elif [[ "$value" == 'false' || "$value" == 'no' ]]; then
                server_type='remote'
            elif [[ "$value" == 'true' || "$value" == 'yes' ]]; then
                server_type='local'
            else
                value="$(grep "^P4D_ON_LOCALHOST" "$P4GF_ENV_PATH")"
                die "In $P4GF_ENV_PATH $value has must be 'true' or 'false'"
            fi
       fi
    fi
    if [[ "$port" && "$gfhome"  && "$serverid"  ]] ;  then
        highlight ""
        highlight "An existing Git Fusion installation is detected using '$P4GF_ENV_PATH' with settings:"
        highlight "    user='$GFUSER'  P4PORT=$port P4GF_HOME=$gfhome server-id=$serverid"
        DO_UPDATE='y'
        if ! $VERIFY ; then
            promptfor DO_UPDATE "Do you want to upgrade the configuration of this Git Fusion instance using these settings? [yes/no]" "yes" false validate_yesno
        fi
        if [ "$DO_UPDATE" == 'yes' -o  "$DO_UPDATE" == 'Yes' ]; then
            P4PORT=$port
            GFUSER=$user
            SERVERID=$serverid
            # prompt for server location and write results to P4GF_ENV_PATH
            if [[ "$server_type" == "" ]]; then
                while [ "$SERVER" != "local" -a "$SERVER" != "remote"  ]; do
                    promptfor SERVER "Is the p4d server with P4PORT=$P4PORT a [local] existing Perforce service on this machine or use a [remote] Server exising on another machine ? [local/remote]"
                done
                if [[ $SERVER == 'local' ]]; then
                    islocal='true'
                else
                    islocal='false'
                fi
                echo "P4D_ON_LOCALHOST=$islocal" >> "$P4GF_ENV_PATH"
            else
                SERVER=$server_type
            fi
            # check that all the expected Git Fusion users exist
            UPGRADE=true
            msg="Git Fusion configuration will continue using existing settings."
            reviewsuser=git-fusion-reviews-${SERVERID}
            for u in git-fusion-user git-fusion-reviews--all-gf git-fusion-reviews--non-gf $reviewsuser; do
                if p4 -c "$P4CLIENT" -p "$P4PORT" -u "$P4USER" -C "$P4CHARSET" users -a "$u" 2>&1 | grep -q "no such user"; then
                    highlight "Expecting user to exist: $u."
                    UPGRADE=false
                fi
            done
            if ! $UPGRADE; then
                highlight "Some users are missing. You will need to re-run this script and provide arguments."
                exit 1
            fi
       else
           highlight "Git Fusion configuration will continue ignoring existing settings."
       fi
       highlight ""
    fi
}
get_port_gfhome_serverid_from_env_cfg()
{
    local GFUSERHOME="$(getent passwd "$GFUSER" | cut -d ":" -f 6 )"
    P4GF_ENV_PATH="$GFUSERHOME/p4gf_environment.cfg"
    if [ -f $P4GF_ENV_PATH ]; then
        OLD_P4PORT="$(grep "^P4PORT" "$P4GF_ENV_PATH" | sed 's;^P4PORT=;;' | xargs )"
        OLD_GFHOME="$(grep "^P4GF_HOME" "$P4GF_ENV_PATH" | sed 's;^ *P4GF_HOME *=;;' | xargs )"
        if [ -e "$OLD_GFHOME/server-id" ]; then
            OLD_SERVERID="$(cat "$OLD_GFHOME/server-id")"
        fi
    fi
    if [ -z "$OLD_P4PORT" ]; then
        OLD_P4PORT="none"
    fi
    if [ -z "$OLD_GFHOME" ]; then
        OLD_GFHOME="none"
    fi
    if [ -z "$OLD_SERVERID" ]; then
        OLD_SERVERID="none"
    fi
}

views_are_empty()
# return 0 (true) if the immediate subdir 'views' are empty
{
    views=${1}/views
    if [ ! -d $views ]; then
        return 0
    elif ls -d $views/*  > /dev/null 2>&1; then
        return 1
    else
        return 0
    fi
}

check_if_upgrade_and_set_parameters
if [ "$VERIFY" = true -a "$UPGRADE" = false ] ; then
    die "This Git Fusion installation is not fully installed with the expected defaults. Re-run configure-git-fusion.sh without the --verify option."
fi

# We need P4 to validate Perforce credentials
get_distro
ensure_dependencies
if ! find_p4; then
    die "No Perforce Command-line Client found!"
fi

# Make sure we know where P4GF is installed
get_p4gf

# Try to figure out if there is a running p4d we can use
detect_local_p4d

if [ -z "$DETECTED_HELIX" ]; then
    # Prompt if we don't already know which path to take
    while $INTERACTIVE && [ "$SERVER" != "local" -a "$SERVER" != "remote"  ]; do
        promptfor SERVER "Use a [local] existing Perforce service on this machine or use a [remote] service on another machine? [local/remote]"
    done
fi

# Prompt if we don't already know the setting to handle unknown Perforce users
if ! $UPGRADE; then
    display_help=true
    while $INTERACTIVE && [ "$UNKNOWN_USER" != "reject" -a "$UNKNOWN_USER" != "pusher" -a "$UNKNOWN_USER" != "unknown"  ]; do
        if $display_help; then
            display_help=false
            unknownuser_usage
        fi
        promptfor UNKNOWN_USER "How do you want Git Fusion to set the change owner for git commits authored by non-Perforce users? [reject/pusher/unknown]" "reject"
    done
    if [ "$UNKNOWN_USER" != "reject" -a "$UNKNOWN_USER" != "pusher" -a "$UNKNOWN_USER" != "unknown"  ]; then
        die "unknownuser must be 'reject', 'pusher', or 'unknown'"
    fi
fi

# Choose server setup path based on $SERVER
case "$SERVER" in
new)
    hideErrors=false
    do_not_install_p4d
    ;;

local|remote)
    debug "Using existing Perforce service."
    gather_existing_p4d_configuration
    gather_case_p4d_configuration
    ;;

*)
    die "server must be either new or local or remote!"
    exit 1
    ;;
esac


# P4GF Data collection
get_timezone

get_p4gf_password()
{
    # Ensure the Git Fusion users' password is valid
    if $INTERACTIVE && [ -z "$P4GFPASSWD" ]; then
        hideErrors=true
    fi

    SET_PASSWD=true
    if [ "$(need_to_create_gf_users)" = "0" ]; then
            highlight "Some or all Git Fusion users already exist with passwords."
            highlight "Not setting Git Fusion user passwords."

            SET_PASSWD=false
    fi


    if $SET_PASSWD; then
        if ! strong_password "$P4GFPASSWD"; then
            if $INTERACTIVE; then
                hideErrors=false
                echo "This installation creates Helix users needed by this new instance of Git Fusion."
                promptfor P4GFPASSWD "Please provide a strong password to be set for Git Fusion users that will be created" " " true strong_password
            else
                die "Password provided for the Git Fusion users is not strong enough!"
            fi
        fi
    fi
    # P4GFPASSWD_ARG passed to super_init
    if $SET_PASSWD; then
        P4GFPASSWD_ARG="--passwd \"$P4GFPASSWD\""
    else
        P4GFPASSWD_ARG=""
    fi
    hideErrors=false
}

# Report a message if /etc/ssh/ssh_config has disasbled PubkeyAuthentication
report_pubkeyauthentication()
{
    ssh_config=/etc/ssh/sshd_config
    kname=PubkeyAuthentication
    if [ -e $ssh_config ] ; then
        kvalue="$(grep $kname $ssh_config | grep -v '#' | awk '{print $2;}' )"
        if [ "$kvalue" == 'no' ]; then
            highlight "Public key authentication is disabled on this system."
            highlight "'$ssh_config' is configured with '$kname $kvalue'."
            highlight "This setting prevents PublicKey authentication for the git ssh protocol."
            highlight "Contact your system administrator in order to enable this feature."
        fi
    fi
}

# Use a white list of protocols prefixes to match and strip from a P4PORT
strip_protocol_from_p4port()
{
    p4port="$1"
    for pro in tcp: tcp4: tcp6: tcp46: tcp64: ssl: ssl4: ssl6: ssl46: ssl64:
    do
        if [[ $p4port = $pro* ]]; then
            p4port=${p4port#$pro}
            break
        fi
    done
    echo "$p4port"

}

# Ensure we have a user to install Git Fusion into
if $INTERACTIVE; then
    hideErrors=true
fi
P4GF_ENV_PATH=''
new_user=true
# If the user exists update .bashrc only
if [ -n "$GFUSER" ] &&  validate_system_user "$GFUSER"; then
    create_update_p4gf_user "$GFUSER" "update-bash"
    new_user=false
fi

CREATEUSER="yes"
while [ -z "$GFUSER" ] || ! validate_system_user "$GFUSER"; do
    hideErrors=false
    if $INTERACTIVE; then
        if [ -z "$GFUSER" ]; then
            promptfor GFUSER "Which system user should be used to run Git Fusion" "$GFUSER"
        fi
        # If the user doesn't exist, ask whether we should create them.
        if [ -n "$GFUSER" ] && ! validate_system_user "$GFUSER"; then
            promptfor CREATEUSER "Create new user '$GFUSER'? [yes/no]" "yes" false validate_yesno
            if [ "$CREATEUSER" == "yes" ]; then
                create_update_p4gf_user "$GFUSER"
            else
                GFUSER=""
            fi
        fi
    else
        if [ "$CREATEUSER" == "yes" -a -n "$GFUSER" ]; then
            # Just in case something goes wrong: we don't want an infinate loop
            CREATEUSER="no"
            create_update_p4gf_user "$GFUSER"
        else
            die "No Git Fusion system user specified!"
        fi
    fi
done

OLD_P4PORT=''
OLD_GFHOME=''
OLD_SERVERID=''
P4PORT_CHANGED=false
prevent_port_id_change=false
if [ "$UPGRADE"  = false -a "$new_user" = false ]; then
    get_port_gfhome_serverid_from_env_cfg
    OLD_P4PORT_no_protocol=$(strip_protocol_from_p4port "$OLD_P4PORT" | xargs)
    P4PORT_no_protocol=$(strip_protocol_from_p4port "$P4PORT" | xargs)
    # disregard protocal when comparing P4PORT connections
    if [ "$OLD_P4PORT_no_protocol" != "$P4PORT_no_protocol" ]; then
       P4PORT_CHANGED=true
    fi
    if ! views_are_empty "$OLD_GFHOME"; then
        prevent_port_id_change=true
    fi
    non_empty_msg_prefix="This Git Fusion is already populated with repo data. "
    debug "old p4port=$OLD_P4PORT new p4port=$P4PORT"
    debug "old serverid=$OLD_SERVERID new serverid=$SERVERID"
fi

# First check whether a request is to change the port against a non-empty views dir
if [ "$prevent_port_id_change" = true -a  "$P4PORT_CHANGED" = true ]; then
       error ""
       error "$non_empty_msg_prefix"
       die "You may not change the current 'P4PORT=$old_port' to '$P4PORT' using this program."
fi

# Now create or update P4GF_ENV
if ! $UPGRADE; then
    set_p4gf_env
fi
# Now that we have a P4PORT we can use super_init to --showids and verify our server_id is unique
if ! check_uniq_p4gf_key; then
   if [ "$P4PORT_CHANGED" = true ]; then
      # After this error against the new P4PORT with the serverid
      # restore the original P4PORT to the P4GF_ENV
      P4PORT=$OLD_P4PORT
      set_p4gf_env
   fi
   exit 1
fi


# Now check whether a request is to change the server_id against a non-empty views dir
if [ "$prevent_port_id_change" = true -a  "$OLD_SERVERID" != "$SERVERID" ]; then
       error ""
       error "$non_empty_msg_prefix"
       die "You may not change current 'SERVERID=$OLD_SERVERID' to '$SERVERID' using this program."
fi

if ! $UPGRADE; then
    prompt_for_GF_updates
    prompt_for_HTTPS_config
fi


if ! $UPGRADE; then
    configure_syslog
    get_p4gf_password
fi

p4gf_super_init
p4gf_init
configure_for_unknown_users
configure_crontab

# Attempt remote trigger install
# Or at least tell the user how
if [ "$SERVER" == "local" ]; then
    install_triggers_local
    DONE=true
    TRIGGER_MSG="- Git Fusion triggers installed into local p4d service [$P4PORT]"
else
    # (assume new trigger has been installed)
    if su - "$GFUSER" -c "P4CHARSET=$P4CHARSET python3.3 $GFINSTALLPATH/p4gf_submit_trigger.py --no-config  --verify-version-p4key $P4PORT"; then
        highlight "Your Git Fusion triggers are up to date."
        TRIGGER_MSG="- Git Fusion triggers are verified as installed into remote p4d service [$P4PORT]"
        DONE=true

    else
    # Tell the user that they need to install the Git Fusion triggers
        DONE_NO_TRIGGERS=true
    fi
fi

# Invoke HTTP configuration script
if [ "$HTTPS" = true ]; then
    if [ "$PLATFORM" == "debian" ]; then
        export INTERACTIVE export P4PORT && export P4USER && export P4PASSWD && export P4CHARSET && export GFUSER && /opt/perforce/git-fusion/libexec/configure_https_auth_ubuntu.sh
    elif [ "$PLATFORM" == "redhat" ]; then
        export INTERACTIVE export P4PORT && export P4USER && export P4PASSWD && export P4CHARSET && export GFUSER && /opt/perforce/git-fusion/libexec/configure_https_auth_centos.sh
    else
        highlight "Git Fusion cannot configure HTTPS authentication on this platform"
    fi
    if [ $? -ne 0 ]; then
        echo 'Failed to set up HTTPS authentication!'
        echo 'Please refer to the Git Fusion release notes for Apache install requirements'
        echo '* http://www.perforce.com/perforce/doc.current/user/git-fusion-notes.txt'
        exit 1
    fi
fi

if [ "$DONE_NO_TRIGGERS" = true ]; then
    done_notriggers_msgs
else
    done_all_msgs
fi

report_pubkeyauthentication
