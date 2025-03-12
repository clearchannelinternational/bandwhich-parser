# bandwidth-monitor
POSIX shell script to parse the output of the `bandwhich` utility and persist it to a log file.

https://github.com/imsnif/bandwhich

The default CLI "raw" output of `bandwhich` looks like this:

```
Refreshing:
connection: <1739773862> <eth0>:2325 => 172.16.9.91:34362 (tcp) up/down Bps: 9/6 process: "chromium"
connection: <1739773861> <wg0>:22 => 10.10.0.1:57038 (tcp) up/down Bps: 204/300 process: "sshd"

Refreshing:
connection: <1739773859> <eth0>:38227 => 3.9.176.156:51820 (udp) up/down Bps: 175/260 process: "<UNKNOWN>"
connection: <1739773844> <eth0>:46952 => 35.157.63.226:443 (tcp) up/down Bps: 4/4 process: "wget"
```

This script formats the output into a table (default) or Influx Line Protocol format and also separates local/remote traffic.
The package also creates a systemd service which streams output to a file.

```
eth1     3.9.176.156        51820      udp      120        69         wireguard        remote       1741792777
eth1     99.81.227.22       443        tcp      10         120        QtWebEngineProc  remote       1741792777
eth1     3.9.176.156        51820      udp      880        1810       wireguard        remote       1741792778
```

NOTE: The headers are not printed but here is a reference example:

```
iface    ip                 port       proto    tx         rx         process          route        timestamp
------   -------------      --------   ------   --------   --------   --------------   ----------   ---------
eth0     55.1.44.190        443        wget     120        2250       wget             remote       1741792790
eth0     55.1.44.190        443        wget     64         2925       wget             remote       1741792791
```

