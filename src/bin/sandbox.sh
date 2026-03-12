#!/usr/bin/env bash

function fail {
    echo "error: " "$@"
    exit 1
}

SANDBOX_NAME=""

SHELL="${SHELL:-/bin/bash}"
COMMAND=("${SHELL}" -l)
BIN_STAGING=""
declare -i NO_NEW_SESSION=0
HOSTNAME=""
SANDBOX_DIR=""

declare -i SHARE_X11=1
declare -i SHARE_DRI=1
declare -i SHARE_AUDIO=1
declare -i SHARE_WAYLAND=1
declare -i SHARE_RAW_DBUS=0
declare -i NESTED=0
declare -i FAKEROOT=0
declare -i VERBOSE=0

SHARE_PKI=ro
declare -i GUI_GTK_CONFIG=1
declare -i GUI_ICONS=1
declare -i GUI_FONTS=1
declare -i GUI_FONTCONFIG=1
declare -i GUI_IBUS_ENV=1

EXTRA_SHARES=()
EXTRA_SHARES_RO=()
EXTRA_BWRAP_OPTIONS=()
DBUS_PROXY_SESSION_OPTIONS=()
DBUS_PROXY_SYSTEM_OPTIONS=()
declare -i DEBUG_DBUS=0

XDG_RUNTIME_DIR="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"

XDG_CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"
XDG_DATA_HOME="${XDG_DATA_HOME:-$HOME/.local/share}"

FONTCONFIG_HOME="${XDG_CONFIG_HOME%/}/fontconfig"

XAUTHORITY="${XAUTHORITY:-$HOME/.Xauthority}"
WAYLAND_DISPLAY="${WAYLAND_DISPLAY:-wayland-0}"
PIPEWIRE_REMOTE="${PIPEWIRE_REMOTE:-pipewire-0}"
PIPEWIRE_RUNTIME_DIR="${PIPEWIRE_RUNTIME_DIR:-"${XDG_RUNTIME_DIR}"}"

# shellcheck disable=SC1091
[[ -f "${XDG_CONFIG_HOME}/sandbox.sh.rc" ]] && source "${XDG_CONFIG_HOME}/sandbox.sh.rc"

VERSION=0.5.3
function print_help {
    cat <<EOF
sandbox.sh - An easy-to-use unprivileged sandbox bootstrapper powered by 
                bubblewarp and xdg-dbus-proxy
version ${VERSION}

Copyright © 2023, 2025-2026 Eric Tian <thxdaemon@gmail.com>.
All rights reserved.
This program is free software: you can redistribute it and/or modify it under 
the terms of the GNU Affero General Public License as published by the 
Free Software Foundation, either version 3 of the License, or (at your option) 
any later version.
This program is distributed in the hope that it will be useful, but 
WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or 
FITNESS FOR A PARTICULAR PURPOSE. See the GNU Affero General Public License 
for more details.
You should have received a copy of the GNU Affero General Public License along 
with this program. If not, see <https://www.gnu.org/licenses/>.

usage:
    $0 [OPTIONS] [-n] <sandbox name> [--] [command...]

OPTIONS:
    [-n, --name] <sandbox name>    Sandbox name (If the leading '-n' is omitted,
                                    it must be placed last among all OPTIONS)
    -s, --share <dir>              Share specific directory <dir>
    --ro-share <dir>               Share specific directory <dir> read-only
    -D, --share-raw-dbus           Share un-filtered dbus sockets (Dangerous)
    --share-at-spi                 Share at-spi bus sockets (Dangerous)
                                    (not impl)
    --sandbox-dir <dir>            Use specificed dir as in-sandbox new HOME
                                    insteads of ~/Sandbox/<sandbox name>
    -x, --no-x11                   Do not share X11 sockets and credentials
    --no-dri                       Do not share DRI nodes
    --no-audio                     Do not share PipeWire/PulseAudio sockets
    --no-wayland                   Do not share Wayland sockets
    -b, --dbus-session-rules       Following --{talk,own,see,call}= opt will be 
                                    passed to xdg-dbus-proxy for session bus
    -B, --dbus-system-rules        Following --{talk,own,see,call}= opt will be
                                    passed to xdg-dbus-proxy for system bus
    -e, --dbus-rules-end           Following --{talk,own,see,call}= will be
                                    treated as error
    --talk=<RULE>, --own=<RULE>, --see=<RULE>, --call=<RULE>
                                   Rules which will be passed to xdg-dbus-proxy.
                                    Must be specified after -b or -B and before
                                    -e. See xdg-dbus-proxy(1)
    --no-default-dbus-rules        Remove all builtin dbus proxy rules add by
                                    sandbox.sh (not impl)
    --debug-dbus                   Show dbus proxy logs (pass --log to 
                                    xdg-dbus-proxy) (conflict with -D)
    -H, --real-hostname            Do not mangle hostname in sandbox
    --hostname <hostname>          Use specified hostname in sandbox
    --pki <ro|rw|isolate>          Ro/rw/not-sharing your PKI database, default
                                    is ro.
    --no-gui-workarounds           Do not apply any GUI workarounds
    --no-gtk-config                Do not ro-share user GTK configs
    --no-icons                     Do not ro-share user icons
    --no-fonts                     Do not ro-share user fonts
    --no-fontconfig                Do not ro-share user fontconfig configs
    --no-ibus                      Do not set env-var IBUS_USE_PORTAL=1 (note:
                                    use --no-default-dbus-rules to hide ibus'
                                    portal)
    --no-fcitx                     (not impl) (currently fcitx is not supported)
    --fakeroot                     Mock uid/gid to 0 in sandbox
    -N, --nested                   Allow to create nested user-namespace in
                                    sandbox
    -S, --no-new-session, --interactive-shell
                                   Do not pass --new-session and do pass
                                    --die-with-parent to bubblewrap.
                                    Default on for default command, default
                                    off for user-specified command.
    -v, --verbose                  Enable verbose mode
    -V, --version                  Print version
    -h, --help                     Show this text

    [--] command...                Command, default: ${SHELL} -l

CONFIG FILES:
    ${XDG_CONFIG_HOME%/}/sandbox.sh.rc
    ${XDG_CONFIG_HOME%/}/sandbox.sh.d/sbox.<sandbox name>.rc

EOF
}

dbus_proxy_opt_status=""
while [[ -n "$1" ]]; do
    opt="$1"
    shift
    case "$opt" in
    -n|--name)
        SANDBOX_NAME="$1"
        shift
        ;;
    -s|--share)
        EXTRA_SHARES+=("$1")
        shift
        ;;
    --ro-share)
        EXTRA_SHARES_RO+=("$1")
        shift
        ;;
    -D|--share-raw-dbus)
        SHARE_RAW_DBUS=1
        ;;
    --sandbox-dir)
        SANDBOX_DIR="$1"
        shift
        ;;
    -x|--no-x11)
        SHARE_X11=0
        ;;
    --no-dri)
        SHARE_DRI=0
        ;;
    --no-audio)
        SHARE_AUDIO=0
        ;;
    --no-wayland)
        SHARE_WAYLAND=0
        ;;
    -b|--dbus-session-rules)
        dbus_proxy_opt_status=DBUS_PROXY_SESSION_OPTIONS
        ;;
    -B|--dbus-system-rules)
        dbus_proxy_opt_status=DBUS_PROXY_SYSTEM_OPTIONS
        ;;
    -e|--dbus-rules-end)
        dbus_proxy_opt_status=""
        ;;
    --talk=*|--own=*|--see=*|--call=*)
        [[ "${dbus_proxy_opt_status}" == "" ]] && fail "'${opt}' shoule be passed after -b or -B, and before -e"
        declare -n arr="${dbus_proxy_opt_status}"
        arr+=("${opt}")
        ;;
    --debug-dbus)
        DEBUG_DBUS=1
        ;;
    -H|--real-hostname)
        HOSTNAME="$(uname -n)"
        ;;
    --hostname)
        HOSTNAME="$1"
        shift
        ;;
    --pki)
        SHARE_PKI="$1"
        shift
        ;;
    --no-gui-workarounds)
        GUI_GTK_CONFIG=0
        GUI_ICONS=0
        GUI_FONTS=0
        GUI_FONTCONFIG=0
        GUI_IBUS_ENV=0
        ;;
    --no-gtk-config)
        GUI_GTK_CONFIG=0
        ;;
    --no-icons)
        GUI_ICONS=0
        ;;
    --no-fonts)
        GUI_FONTS=0
        ;;
    --no-fontconfig)
        GUI_FONTCONFIG=0
        ;;
    --no-ibus)
        GUI_IBUS_ENV=0
        ;;
    -N|--nested)
        NESTED=1
        ;;
    --fakeroot)
        FAKEROOT=1
        ;;
    -S|--no-new-session|--interactive-shell)
        NO_NEW_SESSION=1
        ;;
    -v|--verbose)
        VERBOSE=1
        ;;
    -h|--help)
        print_help
        exit 0
        ;;
    -V|--version)
        echo "${VERSION}"
        exit 0
        ;;
    --)
        BIN_STAGING="$1"
        shift
        break
        ;;
    -*)
        fail "unknown option: ${opt}"
        ;;
    *)
        if [[ -z "${SANDBOX_NAME}" ]]; then
            SANDBOX_NAME="$opt"
            if [[ "$1" == "--" ]]; then
                shift
            elif [[ "$1" == -* ]]; then
                fail "sandbox name without the leading '-n' must br placed last among all OPTIONS"
            fi
            BIN_STAGING="$1"
            shift
        else
            BIN_STAGING="${opt}"
        fi
        break
        ;;
    esac
done

(( SHARE_RAW_DBUS && DEBUG_DBUS )) && fail "-D conflict with --debug-dbus"

if [[ -n "${BIN_STAGING}" ]]; then
    COMMAND=("${BIN_STAGING}" "$@")
else
    NO_NEW_SESSION=1
fi

if [[ -z "$SANDBOX_NAME" ]]; then
    print_help >&2
    exit 1
fi

[[ "${SANDBOX_NAME}" =~ ^[a-zA-Z0-9_.-]+$ ]] || fail "invalid sandbox name: '${SANDBOX_NAME}'"

[[ -z "${SANDBOX_DIR}" ]] && SANDBOX_DIR="${HOME%/}/Sandbox/${SANDBOX_NAME}"
[[ -z "${HOSTNAME}" ]] && HOSTNAME="$(uname -n)-sbox-${SANDBOX_NAME}"

RCFILE="${XDG_CONFIG_HOME%/}/sandbox.sh.d/sbox.${SANDBOX_NAME}.rc"
# shellcheck disable=SC1090
[[ -f "${RCFILE}" ]] && source "${RCFILE}"

set -e

[[ "$(id -u)" == "0" ]] && fail "must be executed as non-root"

mkdir -p "${SANDBOX_DIR}"

legacy_tiocsti="$(sysctl -n dev.tty.legacy_tiocsti 2>/dev/null)"
if [[ "$legacy_tiocsti" != "0" ]] && (( NO_NEW_SESSION )); then
    echo "WARNNING: LEGACY_TIOCSTI is not supported by your kernel, or it has not been disabled." >&2
    echo "If you are using kernel version >= 6.2, consider set \`dev.tty.legacy_tiocsti' to 0." >&2
    echo "If you are using old kernel, please consider use \`$0 $SANDBOX_NAME luit' to alloc a pty." >&2
    echo "This shell may be exploited by CVE-2017-5226 to cause sandbox escape." >&2
    echo "" >&2
fi

BWRAP_OPTIONS=()
function add_bubblewrap_bind {
    # $1: bind type
    # $2: source path
    # $3: dest path (optional)

    local dest="${3:-"${2}"}"
    BWRAP_OPTIONS+=("$1" "$2" "$dest")
}

if (( NO_NEW_SESSION )); then
    BWRAP_OPTIONS+=(--die-with-parent)
else
    BWRAP_OPTIONS+=(--new-session)
fi

BWRAP_OPTIONS+=(
    --unshare-uts --hostname "$HOSTNAME"
    --cap-drop ALL --unshare-user --unshare-pid
    --unsetenv VTE_VERSION
)

(( NESTED )) || BWRAP_OPTIONS+=(--disable-userns)

(( FAKEROOT )) && BWRAP_OPTIONS+=(--uid 0 --gid 0)

(( GUI_IBUS_ENV )) && BWRAP_OPTIONS+=(--setenv IBUS_USE_PORTAL 1)

BWRAP_OPTIONS+=(
    --proc /proc
    --dev /dev
    --ro-bind /sys /sys
    --tmpfs "${XDG_RUNTIME_DIR}"
    --tmpfs /tmp
)

(( SHARE_DRI )) && add_bubblewrap_bind --dev-bind /dev/dri /dev/dri

add_bubblewrap_bind --ro-bind /usr
add_bubblewrap_bind --ro-bind /opt
add_bubblewrap_bind --ro-bind /etc
add_bubblewrap_bind --ro-bind /var/cache
BWRAP_OPTIONS+=(--dir /var/tmp)

for i in /lib /lib64 /bin /sbin; do
    [[ -e "$i" ]] || continue
    real_path="$(realpath "$i")"
    if [[ "${real_path}" == "${i}" ]]; then
        add_bubblewrap_bind --ro-bind "${i}"
    else
        if [[ "$real_path" =~ ^(/usr|/opt)/.* ]]; then
            BWRAP_OPTIONS+=(--symlink "${real_path}" "${i}")
        else    
            add_bubblewrap_bind --ro-bind "${real_path}" "${i}"
        fi
    fi
done


if (( SHARE_X11 )) && [[ -n "$DISPLAY" ]]; then
    DISPLAY="${DISPLAY#localhost:}"
    # tcp sockets is no need to bind
    if [[ "$DISPLAY" =~ ^(unix/)?:[0-9]+(.[0-9]*)?$ ]]; then
        X11_SOCKET_NO="${DISPLAY#unix/}"
        X11_SOCKET_NO="${X11_SOCKET_NO#:}"
        X11_SOCKET_NO="${X11_SOCKET_NO%.*}"
        add_bubblewrap_bind --dev-bind-try /tmp/.ICE-unix/
        add_bubblewrap_bind --dev-bind-try "/tmp/.X11-unix/X${X11_SOCKET_NO}"
        add_bubblewrap_bind --dev-bind-try "/tmp/.X${X11_SOCKET_NO}-lock"
    fi
    [[ -n "${XAUTHORITY}" && -f "${XAUTHORITY}" ]] && add_bubblewrap_bind --ro-bind-try "${XAUTHORITY}"
    add_bubblewrap_bind --ro-bind-try "${HOME%/}/.ICEauthority"
else
    BWRAP_OPTIONS+=(--unsetenv DISPLAY)
fi

if (( SHARE_WAYLAND )); then
    add_bubblewrap_bind --dev-bind-try "${XDG_RUNTIME_DIR%/}/${WAYLAND_DISPLAY}"
    add_bubblewrap_bind --dev-bind-try "${XDG_RUNTIME_DIR%/}/${WAYLAND_DISPLAY}.lock"
fi


if (( SHARE_AUDIO )); then
    add_bubblewrap_bind --dev-bind-try "${PIPEWIRE_RUNTIME_DIR%/}/${PIPEWIRE_REMOTE}"
    add_bubblewrap_bind --dev-bind-try "${PIPEWIRE_RUNTIME_DIR%/}/${PIPEWIRE_REMOTE}.lock"
    # TODO: use PULSE_SERVER env-var
    add_bubblewrap_bind --dev-bind-try "${XDG_RUNTIME_DIR%/}/pulse/native"
fi

if (( SHARE_RAW_DBUS )); then
    add_bubblewrap_bind --dev-bind-try /run/dbus/system_bus_socket
    # abstract socket is no need to bind
    if [[ "${DBUS_SESSION_BUS_ADDRESS}" == unix:path=* ]]; then
        add_bubblewrap_bind --dev-bind-try "${DBUS_SESSION_BUS_ADDRESS#unix:path=}"
    fi
else
    dbus_proxy_session_bus="$(mktemp -p "$XDG_RUNTIME_DIR" sandbox-dbus-session-XXXXXX)"
    dbus_proxy_system_bus="$(mktemp -p "$XDG_RUNTIME_DIR" sandbox-dbus-system-XXXXXX)"
    sync_fifo="$(mktemp -u -p "$XDG_RUNTIME_DIR" sandbox-sync-XXXXXX)"
    mkfifo "$sync_fifo"

    if (( DEBUG_DBUS )); then
        DBUS_PROXY_SESSION_OPTIONS+=(--log)
        DBUS_PROXY_SYSTEM_OPTIONS+=(--log)
    fi

    (
        exec {sync_fd_w}>"$sync_fifo"
        (( VERBOSE )) && set -x
        exec xdg-dbus-proxy \
            "${DBUS_SESSION_BUS_ADDRESS}" \
            "${dbus_proxy_session_bus}" \
            --filter \
            --talk=org.freedesktop.DBus \
            --talk='org.freedesktop.portal.*' \
            --talk=org.gnome.SettingsDaemon.MediaKeys \
            --talk=org.kde.StatusNotifierWatcher \
            --talk=org.freedesktop.Notifications \
            "${DBUS_PROXY_SESSION_OPTIONS[@]}" \
            "unix:path=/run/dbus/system_bus_socket" \
            "${dbus_proxy_system_bus}" \
            --filter \
            --talk=org.freedesktop.DBus \
            "${DBUS_PROXY_SYSTEM_OPTIONS[@]}" \
            --fd="${sync_fd_w}"
    ) &

    exec {sync_fd_r}<"$sync_fifo"
    #exec {sync_fd_r2}<"$sync_fifo"
    dd if=/proc/$$/fd/"$sync_fd_r" of=/dev/null bs=1 count=1 2>/dev/null
    BWRAP_OPTIONS+=(
        --sync-fd "${sync_fd_r}"
    #    --block-fd "${sync_fd_r2}"
    )

    add_bubblewrap_bind --dev-bind "${dbus_proxy_system_bus}" /run/dbus/system_bus_socket
    add_bubblewrap_bind --dev-bind "${dbus_proxy_session_bus}" "${XDG_RUNTIME_DIR%/}/bus"
    BWRAP_OPTIONS+=(--setenv DBUS_SESSION_BUS_ADDRESS "unix:path=${XDG_RUNTIME_DIR%/}/bus")

    rm -f "$sync_fifo"
fi

add_bubblewrap_bind --bind "${SANDBOX_DIR}" "${HOME}"

case "${SHARE_PKI}" in
ro) add_bubblewrap_bind --ro-bind-try "${HOME%/}/.pki" ;;
rw) add_bubblewrap_bind --bind-try "${HOME%/}/.pki" ;;
isolate) ;;
*) fail "unknown --pki option: '${SHARE_PKI}'"
esac

(( GUI_GTK_CONFIG )) && add_bubblewrap_bind --ro-bind-try "${XDG_CONFIG_HOME%/}/gtk-3.0"
(( GUI_GTK_CONFIG )) && add_bubblewrap_bind --ro-bind-try "${XDG_CONFIG_HOME%/}/gtk-4.0"
(( GUI_ICONS )) && add_bubblewrap_bind --ro-bind-try "${HOME%/}/.icons"
(( GUI_ICONS )) && add_bubblewrap_bind --ro-bind-try "${XDG_DATA_HOME%/}/icons"
(( GUI_FONTCONFIG )) && add_bubblewrap_bind --ro-bind-try "${FONTCONFIG_HOME}"
(( GUI_FONTS )) && add_bubblewrap_bind --ro-bind-try "${XDG_DATA_HOME%/}/fonts"

for i in "${EXTRA_SHARES[@]}"; do
    add_bubblewrap_bind --bind "$i"
done
for i in "${EXTRA_SHARES_RO[@]}"; do
    add_bubblewrap_bind --ro-bind "$i"
done

(( VERBOSE )) && set -x
exec bwrap "${BWRAP_OPTIONS[@]}" "${EXTRA_BWRAP_OPTIONS[@]}" -- "${COMMAND[@]}"
