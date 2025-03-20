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

rm -f /tmp/bandwidth_monitor-*
temp_file=$(mktemp -t bandwidth_monitor-XXXXXX)
consolidated_file=$(mktemp -t bandwidth_monitor-XXXXXX)

# Process the input stream from bandwhich
while IFS= read -r line; do
    case "$line" in
        Refreshing:*)
            [ -s "$temp_file" ] || continue
            # Consolidate data by IP:port
            awk -F'\t' '
            {
                # Create a key using IP and port
                key = $2 ":" $3
                
                # Sum tx and rx values
                tx[key] += $5
                rx[key] += $6
                
                # Store other fields (last one wins)
                iface[key] = $1
                proto[key] = $4
                proc[key] = $7
                tag[key] = $8
                ts[key] = $9
            }
            
            END {
                for (key in tx) {
                    split(key, parts, ":")
                    ip = parts[1]
                    port = parts[2]
                    printf "%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n", \
                        iface[key], ip, port, proto[key], tx[key], rx[key], proc[key], tag[key], ts[key]
                }
            }
            ' < "$temp_file" > "$consolidated_file"
            
            awk -F'\t' '{
                printf "%-8s %-18s %-10s %-8s %-10s %-10s %-16s %-12s %s\n", $1, $2, $3, $4, $5, $6, $7, $8, $9
            }' "$consolidated_file"
            # Clear the temp file for next batch
            true > "$temp_file"
            ;;
        
        connection:*)
            # Extract timestamp between first <...>
            ts=${line#*<}
            ts=${ts%%>*}

            # only process the lines every 10 seconds (this would be better as a script arg)
            case "$ts" in
                *0)  ;;
                *5)  ;;
                *)  continue
            esac
            
            # Process connection line
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
                5665)   [ "$proto" = tcp ] && proc="icinga2"   ;;
                53)     [ "$proto" = udp ] && proc="DNS"       ;;
            esac
            
            if [ "$remote_only" -eq 1 ] && [ "$tag" != "remote" ]; then
                continue
            fi
            
            # Add to temp file for this batch
            printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' \
                   "$iface" "$dest" "$port" "$proto" "$up" "$down" "$proc" "$tag" "$ts" >> "$temp_file"
            ;;
    esac
done

