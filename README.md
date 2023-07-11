# socat-tang-filter
A simple script that parses request and starts Tang Server to the appropriate database.

Execute it through `socat` tool, so that requests are parsed appropriately:

```bash
$ sudo socat -v tcp-l:80,reuseaddr,fork exec:"$(pwd)/socat_tang_filter.sh"
```
