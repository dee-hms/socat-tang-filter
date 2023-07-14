# socat-tang-filter
A simple script that parses request and starts Tang Server to the appropriate database.

Execute it through `socat` tool, so that requests are parsed appropriately:

```bash
$ sudo socat -v tcp-l:80,reuseaddr,fork exec:"$(pwd)/socat-tang-filter.sh"
```

By default, this script will use `/etc/socat-tang-filter.csv` CSV configuration file to identify which Tang directory will be used according to the `workspace` (URL prefix) used.

In case it is required to use the script with a different CSV file, it can be done through `-c` option. In next example, `/usr/local/etc/socat-tang-filter.csv` is used:

```bash
$ sudo socat -v tcp-l:80,reuseaddr,fork exec:"$(pwd)/socat-tang-filter.sh -c /usr/local/etc/socat-tang-filter.csv"
```

Regarding the CSV configuration file, an example of a possible CSV file could be this:

```bash
$ sudo cat /etc/socat-tang-filter.csv
workspace1,/var/db/tang1
workspace2,/var/db/tang2
workspace3,/var/db/tang3
```

For requests to URL of the form "GET /workspace1/adv/..." or "POST /workspace1/rec/..." tangd will be started against directory "/var/db/tang1"
Similarly, for requests to URL of the form "GET /workspace2/adv/..." or "POST /workspace2/rec/..." tangd will be started against directory "/var/db/tang2"
Finally, for requests to URL of the form "GET /workspace3/adv/..." or "POST /workspace3/rec/..." tangd will be started against directory "/var/db/tang3"

This way, a very basic mechanism to maintain multiple directories with different keys, one per workspace (customer, tenant, etc.) can be used.
No parallel processing will be performed. It is considered that socat will enqueue the streams and finish one request / response transaction appropriately.
