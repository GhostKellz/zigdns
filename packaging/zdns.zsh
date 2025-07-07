#compdef zdns

_zdns() {
    local -a commands
    commands=(
        'help:Show comprehensive help information'
        'version:Display version information and build details'
        'start:Start the DNS server (default command)'
        'run:Start the DNS server (alias for start)'
        'query:Query a specific domain name'
        'resolve:Query a specific domain name (alias for query)'
        'flush:Clear the DNS cache'
        'clear-cache:Clear the DNS cache (alias for flush)'
        'stats:Show server statistics and performance metrics'
        'status:Show server statistics (alias for stats)'
        'test-web3:Test Web3 domain resolution functionality'
        'test:Test Web3 domain resolution (alias for test-web3)'
        'config:Show current configuration settings'
        'set:Set configuration value'
    )
    
    local -a protocols
    protocols=(
        'udp:Traditional DNS over UDP (default)'
        'dot:DNS-over-TLS (encrypted)'
        'doh:DNS-over-HTTPS (encrypted)'
        'doq:DNS-over-QUIC (post-quantum ready)'
    )
    
    local -a upstream_servers
    upstream_servers=(
        '1.1.1.1:53:Cloudflare DNS'
        '8.8.8.8:53:Google DNS'
        '9.9.9.9:53:Quad9 DNS'
        '1.1.1.1:853:Cloudflare DNS-over-TLS'
        '8.8.8.8:853:Google DNS-over-TLS'
    )
    
    local -a example_domains
    example_domains=(
        'google.com:Traditional domain'
        'cloudflare.com:Traditional domain'
        'vitalik.eth:ENS domain'
        'brad.crypto:Unstoppable domain'
        'example.ghost:GhostChain domain'
        'fast.cns:CNS QUIC domain'
    )
    
    local -a config_keys
    config_keys=(
        'upstream:Set upstream DNS server'
        'port:Set DNS server port'
        'protocol:Set DNS protocol'
        'mode:Set server mode'
        'cache_size:Set cache size'
    )
    
    _arguments -C \
        '(--verbose -v)'{--verbose,-v}'[Enable verbose output]' \
        '(--quiet -q)'{--quiet,-q}'[Suppress non-error output]' \
        '(--daemon -d)'{--daemon,-d}'[Run as daemon]' \
        '(--help -h)'{--help,-h}'[Show help information]' \
        '--port=[Set DNS server port]:port:(53 853 443 5353 8853)' \
        '--protocol=[Set DNS protocol]:protocol:_describe protocols protocols' \
        '--upstream=[Set upstream DNS server]:server:_describe upstream_servers upstream_servers' \
        '--no-web3[Disable Web3 domain resolution]' \
        '--no-blocklist[Disable ad/malware blocking]' \
        '1: :->commands' \
        '*:: :->args'
    
    case $state in
        commands)
            _describe 'zdns commands' commands
            ;;
        args)
            case $words[1] in
                query|resolve)
                    _describe 'example domains' example_domains
                    ;;
                set)
                    if [[ $#words -eq 2 ]]; then
                        _describe 'configuration keys' config_keys
                    elif [[ $#words -eq 3 ]]; then
                        case $words[2] in
                            protocol)
                                _describe 'protocols' protocols
                                ;;
                            upstream)
                                _describe 'upstream servers' upstream_servers
                                ;;
                            port)
                                _values 'port' 53 853 443 5353 8853
                                ;;
                        esac
                    fi
                    ;;
            esac
            ;;
    esac
}

_zdns "$@"