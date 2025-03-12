#!/bin/sh

remote_only=0
output_format="table"

# Parse options (very basic for now - use getoptions to make this a proper program)
while [ $# -gt 0 ]; do
    case "$1" in
        --remote)
            remote_only=1
            ;;
        --output)
            shift
            output_format="$1"
            ;;
        *)
            echo "Unknown option: $1"
            exit 1
            ;;
    esac
    shift
done

while IFS= read -r line; do
    case "$line" in
        connection:*) ;;
        *) continue ;;
    esac
    # Extract timestamp between first <...>
    ts=${line#*<}
    ts=${ts%%>*}
    
    # Extract interface
    iface=${line#*<*<}
    iface=${iface%%>*}
    # ignore loopback interface
    [ "$iface" = lo ] && continue

    # Extract destination IP
    dest=${line#*=> }
    dest=${dest%% \(*}

    # Extract port
    port=${dest#*:}

    # remove port from IP
    dest=${dest%%:*}

    case "$dest" in
        # Ignore IPv6 traffic
        *:*|*[a-z]*)  continue  ;;
        # Determine if the traffic is local or remote
        172.1[6-9].*|172.2[0-9].*|172.3[0-1].*|192.168.*|10.*|169.254.*)  tag="local" ;;
        *)  tag="remote"
    esac

    # Extract protocol (tcp or udp)
    proto=${line#*\(}
    proto=${proto%%\)*}

    # Extract bandwidth
    bw=${line#*Bps: }
    up=${bw%%/*}
    
    down=${bw%% process*}
    down=${down#*/}
    
    # Extract process
    proc=${line#*process: \"}
    proc=${proc%\"*}
    # remove < and > from around process name
    proc=${proc#*<}
    proc=${proc%%>*}

    # this should be moved to a TOML config file
    case "$port" in
        51820)  [ "$proto" = udp ] && proc="wireguard" ;;
    esac

    if [ "$remote_only" -eq 1 ] && [ "$tag" != "remote" ]; then
        continue
    fi

    # Output formatting based on the selected format
    case "$output_format" in
        table)
            printf '%-8s %-18s %-10s %-8s %-10s %-10s %-16s %-12s %s\n' \
                "$iface" "$dest" "$port" "$proto" "$up" "$down" "$proc" "$tag" "$ts"
            ;;
        ilp)
            printf 'network,host=%s,iface=%s,process=%s ip="%s",port=%si,protocol="%s",up=%si,down=%si %s\n' \
                  "$(hostname -s)" "$iface" "$proc" "$dest" "$port" "$proto" "$up" "$down" "$ts"
            ;;
        *)
            echo "Unknown output format: $output_format"
            exit 1
    esac
done
