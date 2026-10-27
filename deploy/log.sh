#!/bin/bash
# Below Hell sunucu loglarını canlı izler.
exec journalctl --user -u belowhell-sunucu -f -o cat
