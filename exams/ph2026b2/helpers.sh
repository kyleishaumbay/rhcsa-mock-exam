# PH2026B2 mocks — shared read-only check helpers, prepended to each paper's checks by build.sh
# ------------------------------------------------------------
root_pw_is() {   # <password> — compares against root's hash in /etc/shadow
  local h; h=$(awk -F: '$1=="root"{print $2}' /etc/shadow)
  python3 -c 'import crypt,sys; sys.exit(0 if crypt.crypt(sys.argv[1], sys.argv[2]) == sys.argv[2] else 1)' "$1" "$h" 2>/dev/null && return 0
  _rec "compare root's hash in /etc/shadow with '$1'" "root's password is not '$1'"; return 1
}
on_gpt_disk() {  # <mountpoint> <disk> <min MiB> <max MiB>
  local src disk pt size
  src=$(findmnt -no SOURCE "$1" 2>/dev/null); disk=$(lsblk -no PKNAME "$src" 2>/dev/null | head -1)
  pt=$(lsblk -dno PTTYPE "/dev/$disk" 2>/dev/null); size=$(( $(lsblk -bdno SIZE "$src" 2>/dev/null || echo 0) / 1048576 ))
  [[ $disk == "$2" ]] || { _rec "lsblk -no PKNAME $src" "$1 is not on a partition of /dev/$2 (got: '${disk:-none}')"; return 1; }
  [[ $pt == gpt ]] || { _rec "lsblk -dno PTTYPE /dev/$disk" "/dev/$disk has no GPT label (got: '${pt:-none}')"; return 1; }
  (( size >= $3 && size <= $4 )) || { _rec "lsblk -bdno SIZE $src" "$src is ${size} MiB, expected $3-$4 MiB"; return 1; }
}
swap_dev_on_disk() {  # <disk> — prints the active swap device(s) on that disk
  local d r
  awk 'NR>1{print $1}' /proc/swaps | while read -r d; do
    r=$(readlink -f "$d"); [[ $(lsblk -no PKNAME "$r" 2>/dev/null) == "$1" || ${r##*/} == "$1" ]] && echo "$r"
  done
}
swap_persisted() {    # <device> — active now AND an fstab swap entry resolving to it
  local want src r; want=$(readlink -f "$1")
  awk 'NR>1{print $1}' /proc/swaps | xargs -r -n1 readlink -f | grep -qx "$want" \
    || { _rec "cat /proc/swaps" "$1 is not active swap"; return 1; }
  while read -r src; do
    r=$(findfs "$src" 2>/dev/null || readlink -f "$src"); [[ $(readlink -f "$r") == "$want" ]] && return 0
  done < <(findmnt --fstab -n -t swap -o SOURCE)
  _rec "findmnt --fstab -t swap" "no /etc/fstab swap entry for $1 (by UUID, LABEL or path)"; return 1
}
cron_has() {          # <regex> — root's crontab, /etc/crontab or /etc/cron.d
  { crontab -l -u root 2>/dev/null; cat /etc/crontab /etc/cron.d/* 2>/dev/null; } | grep -v '^\s*#' | grep -Eq -- "$1" && return 0
  _rec "crontab -l -u root; cat /etc/crontab /etc/cron.d/*" "no cron entry matching /$1/"; return 1
}
fw_has() {            # <service> <port/proto> — in the default zone, permanent AND runtime
  local z; z=$(firewall-cmd --get-default-zone 2>/dev/null)
  local rx="services:(.* )?$1( |\$)|ports:(.* )?$2( |\$)"
  expect_match "firewall-cmd --permanent --zone=$z --list-all" "$rx" || return 1
  expect_match "firewall-cmd --zone=$z --list-all" "$rx"
}
autofs_maps_to() {    # <path> <source regex> — indirect (parent dir) or direct (/-) map
  local mp=${1%/*} key=${1##*/}
  { autofs_entry "$mp" | awk -F'|' -v k="$key" '{gsub(/ /,"",$1)} $1==k{print $2}'
    autofs_entry /-    | awk -F'|' -v k="$1"   '{gsub(/ /,"",$1)} $1==k{print $2}'; } \
    | grep -Eq "(^|[[:space:]])$2/?([[:space:]]|\$)" && return 0
  _rec "automount -m" "no autofs entry mapping $1 to $2"; return 1
}
same_dev() {          # <mountpoint> <device> — the mount's source is that device
  [[ $(readlink -f "$(findmnt -no SOURCE "$1" 2>/dev/null)") == "$(readlink -f "$2")" ]] && return 0
  _rec "findmnt -no SOURCE $1" "$1 is not mounted from $2"; return 1
}
key_login_ok() {      # <user> <host> — that user logs in to the host by key, with no prompt
  runuser -u "$1" -- ssh -o BatchMode=yes -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
    -o ConnectTimeout=5 "$1@$2" true </dev/null >/dev/null 2>&1 && return 0
  _rec "runuser -u $1 -- ssh -o BatchMode=yes $1@$2 true" "key login as $1 to $2 failed (if the other node's SSH task failed, fix that first)"; return 1
}
CUSER=""
find_cuser() {        # <container> — the lingering rootless user running it
  local f u
  for f in /var/lib/systemd/linger/*; do
    [[ -e $f ]] || continue; u=${f##*/}
    runuser -l "$u" -c 'XDG_RUNTIME_DIR=/run/user/$(id -u) podman ps --format "{{.Names}}"' 2>/dev/null | grep -qx "$1" \
      && { CUSER=$u; return 0; }
  done
  _rec "podman ps, as each user in /var/lib/systemd/linger/" "no lingering user has a running container named $1"; return 1
}
asu() { echo "runuser -l $CUSER -c 'XDG_RUNTIME_DIR=/run/user/\$(id -u) $1'"; }
user_unit_for() {     # <container> — its systemd --user service is active and enabled/generated
  local u; u=$(bash -c "$(asu 'systemctl --user list-units --all --type=service --no-legend --plain')" 2>/dev/null | awk '{print $1}' | grep -m1 "$1")
  [[ -n $u ]] || { _rec "$(asu 'systemctl --user list-units --all --type=service')" "no systemd user service for $1"; return 1; }
  expect "$(asu "systemctl --user is-active $u")" active || return 1
  expect_match "$(asu "systemctl --user is-enabled $u")" '^(enabled|generated)$'
}
autofs_opts() {       # <path> — options+source autofs loaded for that path (indirect or direct)
  local mp=${1%/*} key=${1##*/}
  autofs_entry "$mp" | awk -F'|' -v k="$key" '{gsub(/ /,"",$1)} $1==k{print $2}'
  autofs_entry /-    | awk -F'|' -v k="$1"   '{gsub(/ /,"",$1)} $1==k{print $2}'
}
fstab_source() {      # <mountpoint> — the fstab SOURCE field as written (UUID=…, LABEL=…, /dev/…)
  awk -v m="$1" '$0!~/^[[:space:]]*#/ && $2==m{print $1}' /etc/fstab
}
autofs_has_opt() {    # <path> <option> — the loaded autofs entry for path carries that mount option
  autofs_opts "$1" | grep -Eq "(^|[-, ])$2(,|[[:space:]]|\$)" && return 0
  _rec "automount -m" "autofs entry for $1 lacks the '$2' option (got: '$(autofs_opts "$1" | head -1)')"; return 1
}
iso_repos() {         # <mountpoint> — ISO mounted there at boot; BaseOS + AppStream repos from it
  need mount_persisted "$1"
  need expect_ok "test -d $1/AppStream/repodata"
  need expect_match "grep -rhE '^\s*baseurl\s*=' /etc/yum.repos.d/" "file://$1/BaseOS/?\$"
  need expect_match "grep -rhE '^\s*baseurl\s*=' /etc/yum.repos.d/" "file://$1/AppStream/?\$"
}
nfs_export_is() {     # <path> <rw|ro> [any] — exported now and in /etc/exports(.d) with that mode; only to NODE1_IP unless "any"
  local live   # one path may span several lines (one per client, or options on a continuation line)
  live=$(exportfs -s 2>/dev/null | awk -v p="$1" '/^\//{cur=$1; $1=""} cur==p{print}' | paste -sd' ')
  [[ -n $live ]] || { _rec "exportfs -s" "$1 is not exported"; return 1; }
  grep -rhsEq "^\s*$1\s" /etc/exports /etc/exports.d/*.exports \
    || { _rec "grep $1 /etc/exports /etc/exports.d/*.exports" "$1 is exported now but not in /etc/exports or /etc/exports.d"; return 1; }
  [[ $3 == any || $(grep -oE '[^ ()]+\(' <<<"$live" | tr -d '(' | sort -u | paste -sd' ') =~ ^$NODE1_IP(/32)?$ ]] \
    || { _rec "exportfs -s" "$1 is exported to '$(grep -oE '[^ ()]+\(' <<<"$live" | tr -d '(' | paste -sd' ')', not only $NODE1_IP"; return 1; }
  grep -Eq "\(([^)]*,)?$2(,|\))" <<<"$live" && return 0
  _rec "exportfs -s" "$1 is not exported $2 (got: '${live# }')"; return 1
}
node_by_ip() {        # which node this is, from its IP (lab hostnames can be anything)
  [[ -n $NODE ]] && return 0
  ip -4 -o addr 2>/dev/null | grep -q " $NODE1_IP/" && THIS_NODE=node1
  ip -4 -o addr 2>/dev/null | grep -q " $NODE2_IP/" && THIS_NODE=node2
  return 0
}
iso_repo_baseos() {   # <mountpoint> — ISO mounted there at boot; a BaseOS repo from it
  need mount_persisted "$1"
  need expect_ok "test -d $1/BaseOS/repodata"
  need expect_match "grep -rhE '^\s*baseurl\s*=' /etc/yum.repos.d/" "file://$1/BaseOS/?\$"
}
