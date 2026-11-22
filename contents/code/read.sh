#!/bin/sh
# Watt Meter data collector: prints one JSON snapshot of battery, charger and
# platform power state, read straight from sysfs. Called by the widget on a timer.

PS=/sys/class/power_supply

num() { # integer from a sysfs file (unit suffixes stripped), or null
    v=$(cat "$1" 2>/dev/null | tr -dc '0-9-')
    if [ -n "$v" ]; then echo "$v"; else echo null; fi
}
str() { printf '"%s"' "$(head -n1 "$1" 2>/dev/null | tr -d '"\\')"; }

# --- battery -----------------------------------------------------------------
bat=
for d in "$PS"/*; do
    [ "$(cat "$d/type" 2>/dev/null)" = Battery ] || continue
    [ "$(cat "$d/scope" 2>/dev/null)" = Device ] && continue
    bat=$d
    break
done

printf '{"bat":'
if [ -n "$bat" ]; then
    printf '{"status":%s,"capacity":%s' "$(str "$bat/status")" "$(num "$bat/capacity")"
    for k in charge_now charge_full charge_full_design energy_now energy_full \
             energy_full_design current_now power_now voltage_now \
             voltage_min_design cycle_count; do
        printf ',"%s":%s' "$k" "$(num "$bat/$k")"
    done
    printf ',"manufacturer":%s,"model":%s,"technology":%s}' \
        "$(str "$bat/manufacturer")" "$(str "$bat/model_name")" "$(str "$bat/technology")"
else
    printf null
fi

# --- external power ----------------------------------------------------------
ac=0
printf ',"usb":['
sep=
for d in "$PS"/*; do
    t=$(cat "$d/type" 2>/dev/null)
    case $t in
        Mains|USB) [ "$(cat "$d/online" 2>/dev/null)" = 1 ] && ac=1 ;;
    esac
    [ "$t" = USB ] || continue
    printf '%s{"name":"%s","online":%s,"voltage_now":%s,"current_max":%s,"usb_type":%s}' \
        "$sep" "${d##*/}" "$(num "$d/online")" "$(num "$d/voltage_now")" \
        "$(num "$d/current_max")" "$(str "$d/usb_type")"
    sep=,
done
printf '],"ac":%s' "$ac"

# --- USB-PD charger (partner on a port where we are the sink) -----------------
pd=null
for p in /sys/class/typec/port*; do
    case ${p##*/} in *[.-]*) continue ;; esac
    grep -q '\[sink\]' "$p/power_role" 2>/dev/null || continue
    [ -d "$p-partner" ] || continue
    caps=
    sep=
    for c in "$p-partner"/usb_power_delivery/source-capabilities/*:*; do
        [ -d "$c" ] || continue
        n=${c##*/}
        caps="$caps$sep{\"type\":\"${n#*:}\",\"mv\":$(num "$c/voltage"),\"min_mv\":$(num "$c/minimum_voltage"),\"max_mv\":$(num "$c/maximum_voltage"),\"ma\":$(num "$c/maximum_current"),\"mw\":$(num "$c/maximum_power")}"
        sep=,
    done
    loc=
    for k in panel horizontal_position vertical_position; do
        v=$(cat "$p/physical_location/$k" 2>/dev/null)
        [ -n "$v" ] && [ "$v" != unknown ] && loc="$loc${loc:+ }$v"
    done
    pd="{\"port\":\"${p##*/}\",\"revision\":$(str "$p-partner/usb_power_delivery_revision"),\"location\":\"$loc\",\"caps\":[$caps]}"
    break
done
printf ',"pd":%s' "$pd"

# --- battery temperature (any hwmon sensor labelled as battery) ---------------
temp=null
for l in /sys/class/hwmon/hwmon*/temp*_label; do
    case "$(cat "$l" 2>/dev/null)" in
        *[Bb]att*) temp=$(num "${l%_label}_input"); break ;;
    esac
done
printf ',"temp":%s' "$temp"

# --- whole-platform energy counter (Intel RAPL psys) --------------------------
psys=null
pmax=null
for r in /sys/class/powercap/intel-rapl:*; do
    [ "$(cat "$r/name" 2>/dev/null)" = psys ] || continue
    psys=$(num "$r/energy_uj")
    pmax=$(num "$r/max_energy_range_uj")
    break
done
printf ',"psys":%s,"psys_max":%s,"t":%s}\n' "$psys" "$pmax" "$(date +%s%3N)"
