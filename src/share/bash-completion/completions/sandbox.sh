_sandbox_sh_names()
{
    local config_dir="${XDG_CONFIG_HOME:-${HOME}/.config}/sandbox.sh.d"
    local path name

    for path in "${config_dir}"/sbox.*.rc; do
        name="${path##*/}"
        name="${name#sbox.}" && name="${name%.rc}"
        printf '%s\n' "${name}"
    done

    for path in "${HOME}"/Sandbox/*; do
        name="${path##*/}"
        printf '%s\n' "${name}"
    done
}

_sandbox_sh_completion()
{
    local cur prev word
    local -a options
    COMPREPLY=()
    cur="${COMP_WORDS[COMP_CWORD]}"
    prev="${COMP_WORDS[COMP_CWORD - 1]}"

    case "${prev}" in
    -n|--name)
        mapfile -t COMPREPLY < <(compgen -W "$(_sandbox_sh_names)" -- "${cur}")
        return
        ;;
    -s|--share|--ro-share|--sandbox-dir)
        compopt -o filenames
        mapfile -t COMPREPLY < <(compgen -f -- "${cur}")
        return
        ;;
    --hostname)
        return
        ;;
    --pki)
        mapfile -t COMPREPLY < <(compgen -W 'ro rw isolate' -- "${cur}")
        return
        ;;
    --)
        compopt -o filenames
        mapfile -t COMPREPLY < <(compgen -c -- "${cur}")
        return
        ;;
    esac


    for ((word = 1; word < COMP_CWORD; word++)); do
        if [[ "${COMP_WORDS[word]}" == -- ]]; then
            compopt -o bashdefault -o default
            return
        fi
    done

    options=(
        -n --name -s --share --ro-share
        -D --share-raw-dbus --share-at-spi --sandbox-dir
        --no-bind-resolv-conf -x --no-x11 --no-dri --no-audio --no-wayland
        -b --dbus-session-rules -B --dbus-system-rules -e --dbus-rules-end
        --talk= --own= --see= --call= --no-default-dbus-rules --debug-dbus
        -H --real-hostname --hostname --pki --no-gui-workarounds
        --no-gtk-config --no-icons --no-fonts --no-fontconfig --no-ibus
        --no-fcitx --fakeroot -N --nested -S --no-new-session
        --interactive-shell -v --verbose -V --version -h --help --
    )

    mapfile -t COMPREPLY < <(compgen -W "$(_sandbox_sh_names) ${options[*]}" -- "${cur}")
}

complete -F _sandbox_sh_completion sandbox.sh
