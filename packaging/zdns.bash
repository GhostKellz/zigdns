# Bash completion for zdns
_zdns() {
    local cur prev opts base
    COMPREPLY=()
    cur="${COMP_WORDS[COMP_CWORD]}"
    prev="${COMP_WORDS[COMP_CWORD-1]}"
    
    # Commands
    local commands="help version start run query resolve flush clear-cache stats status test-web3 test config set"
    
    # Options
    local options="--verbose --quiet --daemon --port --protocol --upstream --no-web3 --no-blocklist -v -q -d -h --help"
    
    # Protocol options
    local protocols="udp dot doh doq"
    
    case ${COMP_CWORD} in
        1)
            COMPREPLY=( $(compgen -W "${commands}" -- ${cur}) )
            return 0
            ;;
        *)
            case "${prev}" in
                --protocol)
                    COMPREPLY=( $(compgen -W "${protocols}" -- ${cur}) )
                    return 0
                    ;;
                --port)
                    COMPREPLY=( $(compgen -W "53 853 443 5353 8853" -- ${cur}) )
                    return 0
                    ;;
                --upstream)
                    COMPREPLY=( $(compgen -W "1.1.1.1:53 8.8.8.8:53 9.9.9.9:53 1.1.1.1:853" -- ${cur}) )
                    return 0
                    ;;
                query|resolve)
                    # Suggest some common domains
                    COMPREPLY=( $(compgen -W "google.com cloudflare.com vitalik.eth brad.crypto example.ghost" -- ${cur}) )
                    return 0
                    ;;
                set)
                    COMPREPLY=( $(compgen -W "upstream port protocol mode cache_size" -- ${cur}) )
                    return 0
                    ;;
                *)
                    # Check if current word starts with --
                    if [[ ${cur} == --* ]]; then
                        COMPREPLY=( $(compgen -W "${options}" -- ${cur}) )
                        return 0
                    elif [[ ${cur} == -* ]]; then
                        COMPREPLY=( $(compgen -W "-v -q -d -h" -- ${cur}) )
                        return 0
                    fi
                    ;;
            esac
            ;;
    esac
}

complete -F _zdns zdns