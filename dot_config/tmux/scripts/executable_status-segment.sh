#!/bin/sh
# status-segment.sh — tmux status segments for macOS and Linux.
#
# The usage block that used to sit here is now the here-doc in usage() below.
# `--help` has to print it and a comment cannot be printed, so keeping both
# would have been two copies of the verb list, free to drift apart the first
# time a verb is renamed.
#
# This comment used to claim the verb names appear exactly twice. That was true
# once and has been false since the $OS pre-detection block was added. There are
# THREE naming sites, and a rename that edits fewer than three ships a verb that
# is dispatched but never sampled — a silently blank segment, which is the one
# failure this script's contract cannot report:
#
#   1. the here-doc in usage(), which `--help` prints;
#   2. the `case ${1:-} in` below that decides whether to pay for `uname -s`;
#   3. the case labels of the dispatcher at the bottom.
#
# Only the verbs that read $OS need to appear in (2) — see the note there.
#
# Linux behavior:
#   - Outside a container, CPU and memory are system-wide.
#   - In a container, cgroup usage and limits are used when available.
#
# Each successful command prints one complete segment with two trailing spaces.

LC_ALL=C
export LC_ALL

# `set -u` costs nothing here because the file was already written for it: every
# positional is read as ${1:-}, $OS is initialised empty below the comment that
# explains why, and every variable a `read` might never reach is cleared on the
# line before the read. It is worth turning on precisely because the failure
# contract is silent — a mistyped variable name would otherwise expand to empty,
# blank a segment, and leave nothing anywhere to say that it had.
#
# `set -e` is deliberately ABSENT. Do not add it. Two independent reasons, each
# sufficient on its own:
#
#   - The dispatcher spells its optional segments `[ -n "$value" ] && print_segment …`.
#     When value is empty that AND-list yields 1, and for the last command of the
#     script -e would make that the exit status — turning every legitimately
#     blank segment into the non-zero exit the failure contract promises tmux it
#     will never see.
#   - The progressive fallthroughs (linux_cgroup2_container_cpu || linux_machine_cpu, and
#     the `[ -n "$x" ] || return 1` guards throughout) use a non-zero exit as
#     ordinary control flow. Today they sit in the positions -e exempts, so -e
#     would look harmless on the day it was added and would start eating segments
#     the first time one of them is rewrapped.
set -u

# THE ERROR CHANNEL.
#
# Every `2>&3` in this file is a stderr suppression, and this is the single place
# that decides what suppression means: /dev/null normally, a duplicate of stderr
# when STATUS_SEGMENT_DEBUG is set to anything non-empty. Resolved once, here, in
# the same idiom as SAMPLE_SECONDS and the two path roots below — one place to
# read, one place to change, and no way for two sites to disagree.
#
# The suppressions themselves are load-bearing and are NOT up for removal. The
# progressive fallthroughs treat a failed read as ordinary control flow, and the
# diagnostics that failure produces are noise on a status bar, not news. What was
# missing was never the suppression; it was a way to ASK what got swallowed.
#
# Why a file descriptor rather than the alternatives:
#   - `2>"$sink"` with sink=/dev/null or /dev/stderr re-OPENS at every site on
#     every invocation, and `>` on /dev/stderr carries O_TRUNC — when stderr is a
#     regular file, which is exactly how every gate here captures it, that
#     truncates the capture. `2>&3` is a dup2 of an already-open descriptor: no
#     open, no truncation, and strictly cheaper than the `2>/dev/null` it
#     replaces.
#   - `if debug; then cmd; else cmd 2>/dev/null; fi` would duplicate 39 call
#     sites, which is 39 chances for the two copies to drift.
#   - a single `exec 2>/dev/null` at the top, unset under debug, would widen the
#     suppression from 39 deliberate sites to everything — including the
#     unknown-verb message, which is contract.
#
# Known cost, stated rather than hidden: a failed `exec` redirection is fatal to
# a non-interactive shell, so if /dev/null cannot be opened this aborts before
# the dispatcher and the failure contract is not honoured. The DEPENDENCY is not
# new — all 39 sites already needed /dev/null, and losing it already broke every
# one of them — but its TIMING is: startup rather than per site.
if [ -n "${STATUS_SEGMENT_DEBUG:-}" ]; then
    exec 3>&2
else
    exec 3>/dev/null
fi

# The trace channel IS the error channel, deliberately: one switch, so a trace
# line and the suppressed stderr that prompted it cannot end up in two different
# places — and so that nothing here can ever reach stdout. tmux consumes stdout
# on a redraw path; a trace line landing there would BE the class of bug this
# was added to find.
#
# Unconditional, with no `if` of its own. With STATUS_SEGMENT_DEBUG unset fd 3 is
# /dev/null and this is a builtin write to a discarded descriptor: no fork, no
# exec, and no second copy of the condition above to keep in sync.
trace()
{
    printf 'status-segment: %s\n' "$*" >&3
}

# Hand-maintained: nothing generates it and nothing parses it. It exists so that
# a copy of this script found installed on a machine can be identified against
# the repository it came from, which `--help` alone cannot do.
#
# 0.x, not 1.0.0. Under semver a 1.0.0 declares a stable public API, and the
# verb surface was renamed wholesale after that number was first written here
# (git→checkout, branch→head, mem→memory, batt→battery). 1.0.0 was therefore
# promising a contract this script had already broken. 0.1.0 says the honest
# thing instead: the surface is still moving. Raise it to 1.0.0 when the verbs
# have held still long enough to be worth depending on.
VERSION=0.1.0

# Naming site 1 of 3 (see the header comment). A later rename (mem→memory,
# batt→battery, git→checkout, branch→head) edits the body of this here-doc, the
# $OS case below, and the case labels of the dispatcher at the bottom, and
# nothing else — the unknown-verb hint at the foot of the dispatcher deliberately
# points at --help rather than repeating the verbs, so it cannot go stale.
usage()
{
    cat <<'USAGE'
Usage:
  status-segment.sh checkout <path>  # repository:branch
  status-segment.sh repo <path>      # repository name
  status-segment.sh head <path>      # branch, or short commit when detached
  status-segment.sh cpu              # aggregate CPU utilization
  status-segment.sh memory           # memory utilization
  status-segment.sh battery          # battery percentage, when available
  status-segment.sh doctor           # capability report, on stdout
  status-segment.sh --help           # this text, on stdout
  status-segment.sh --version        # version string, on stdout
USAGE
}

# Naming site 2 of 3 — the one a previous rename missed, which is why the header
# comment above now spells out that there are three.
#
# uname is an exec on tmux's status-refresh path, and only the sampled
# subcommands read $OS — checkout, repo and head never do, so they should not pay
# for it. $OS stays defined, and empty, on those paths: no code outside these
# three reads it, and leaving it undefined would be a trap for a later `set -u`.
#
# `doctor` belongs here, and the reasoning is the reasoning for the whole verb.
# doctor REPORTS the resolved OS and probes the battery through battery_percent,
# whose body is a `case "$OS"`. Left out of this block, $OS would be empty, and
# doctor would report the OS as unknown and the battery as unsupported on a Mac
# with a battery — a diagnostic that lies is worse than no diagnostic, and this
# verb exists precisely for the moment when the segment is already suspect. It
# does not share the cost argument either: doctor is typed by a human, once, and
# never runs on the refresh path.
OS=
case ${1:-} in
    cpu | memory | battery | doctor)
        OS=$(uname -s 2>&3 || printf 'unknown')
        ;;
esac

# Width of the CPU sampling window, in seconds. 0.5 rather than the original
# 0.20 because /proc/stat and /proc/uptime are centisecond quantities: a 200 ms
# window carries a >=5% systematic error floor before scheduling jitter even
# enters it. Widening it costs staleness, not latency, because tmux runs `#()`
# jobs asynchronously and redraws with the previous result. Only the Linux paths
# read this — macOS CPU comes from `iostat -c 2`, which has its own 1 s window.
SAMPLE_SECONDS_DEFAULT=0.5
SAMPLE_SECONDS=${STATUS_SEGMENT_SAMPLE_SECONDS:-$SAMPLE_SECONDS_DEFAULT}

# Validated once, here, so the three `sleep` call sites can only ever be handed
# a value sleep(1) accepts. An unvalidated one is not an injection vector (the
# quoting holds), but it is a correctness and availability problem: a value
# sleep rejects puts both samples in the same jiffy, which makes the awk exit 1
# and the segment go blank with only stderr to say why, and a mistyped 999 parks
# a tmux status job for 999 seconds.
#
# The rule: a decimal from 0.01 to 5 inclusive, spelled as a single digit 0-5
# (or nothing) before the point and at most two digits after it. A third decimal
# place is below the resolution of the counters being sampled, and `05` is not a
# spelling worth admitting. Everything else — empty, non-numeric, signed, zero,
# or past the 5 s ceiling — falls back to the default.
#
# Kept only so the trace below can say what was asked for as well as what was
# used. Nothing else reads it: the validation itself is unchanged.
SAMPLE_SECONDS_REQUESTED=$SAMPLE_SECONDS

case $SAMPLE_SECONDS in
    # Zero, and the over-the-ceiling values the shapes below would admit.
    0 | 0.0 | 0.00 | .0 | .00 | 5.[1-9] | 5.0[1-9] | 5.[1-9][0-9])
        SAMPLE_SECONDS=$SAMPLE_SECONDS_DEFAULT
        ;;
    # 0 through 5 with at most two decimal places, leading digit optional.
    [0-5] | [0-5].[0-9] | [0-5].[0-9][0-9] | .[0-9] | .[0-9][0-9]) ;;
    *)
        SAMPLE_SECONDS=$SAMPLE_SECONDS_DEFAULT
        ;;
esac

if [ "$SAMPLE_SECONDS" = "$SAMPLE_SECONDS_REQUESTED" ]; then
    trace "sample window: ${SAMPLE_SECONDS}s"
else
    trace "sample window: ${SAMPLE_SECONDS}s" \
        "(rejected '$SAMPLE_SECONDS_REQUESTED', clamped to the default)"
fi

# Filesystem roots for the two kernel interfaces this script reads. They exist
# so the Linux code paths can be pointed at a fixture tree on a machine that has
# neither: every Linux function below is otherwise unreachable on macOS, and
# both existing gates were measured blind to all six of them (all six were
# replaced with `return 99` and both still passed).
#
# Resolved once here rather than spelled ${VAR:-/proc} at each of the eleven
# read sites, matching SAMPLE_SECONDS above: one place to read, one place to
# change, and no way for two sites to disagree about the default.
#
# Deliberately unvalidated, unlike SAMPLE_SECONDS. That value is handed to
# sleep(1), where a rejected spelling silently ruins the sample; a root that
# does not exist merely makes the reads fail, which every guard here already
# treats as "no data" and the failure contract already covers. No trailing
# slash is stripped either — `/proc//stat` opens the same file as `/proc/stat`.
PROC_ROOT_DEFAULT=/proc
PROC_ROOT=${STATUS_SEGMENT_PROC_ROOT:-$PROC_ROOT_DEFAULT}

CGROUP_ROOT_DEFAULT=/sys/fs/cgroup
CGROUP_ROOT=${STATUS_SEGMENT_CGROUP_ROOT:-$CGROUP_ROOT_DEFAULT}

# The third root, for the same reason as the two above and covering the last two
# unparameterized Linux read sites: is_container's /.dockerenv and
# /run/.containerenv. Those are marker files at the filesystem root rather than
# under /proc or /sys/fs/cgroup, so neither existing root can name them, and
# reusing PROC_ROOT for them would be a lie about where they live.
#
# Without this, is_container is the one branch point no fixture can drive: its
# first test is an absolute path that EXISTS whenever the gate itself runs in a
# container, so `is_container` answered "yes" no matter what the fixture tree
# said, and every check of the not-a-container branch of linux_cpu, linux_mem and
# doctor was unreachable there. That is the highest-leverage function in the file
# to be able to fixture, being the branch point for all three.
#
# Default is EMPTY, not "/": these two paths are already absolute, so an empty
# prefix reproduces /.dockerenv and /run/.containerenv byte for byte. That is why
# there is no FS_ROOT_DEFAULT constant to match the two above -- the default is
# the absence of a prefix, and a "/" default would spell //.dockerenv instead.
FS_ROOT=${STATUS_SEGMENT_FS_ROOT:-}

# Rewritten from a three-link `||` chain into if/elif so the WINNING link can be
# named. Same three tests, same order, same short-circuit, same exit status —
# what changes is that "true" is no longer the whole answer. "Why does my segment
# think it is in a container" was previously unanswerable without a debugger.
#
# container_evidence deliberately outlives the call: doctor reads it back rather
# than re-running the probe, so the line doctor prints and the branch linux_cpu
# took cannot disagree with each other.
container_evidence=
is_container()
{
    if [ -f "$FS_ROOT/.dockerenv" ]; then
        container_evidence="$FS_ROOT/.dockerenv exists"
    elif [ -f "$FS_ROOT/run/.containerenv" ]; then
        container_evidence="$FS_ROOT/run/.containerenv exists"
    elif grep -qaE '(docker|containerd|kubepods|libpod|lxc)' \
        "$PROC_ROOT/1/cgroup" 2>&3; then
        container_evidence="$PROC_ROOT/1/cgroup matches the container pattern"
    else
        container_evidence="no $FS_ROOT/.dockerenv, no $FS_ROOT/run/.containerenv,"
        container_evidence="$container_evidence no match in $PROC_ROOT/1/cgroup"
        trace "is_container: no - $container_evidence"
        return 1
    fi

    trace "is_container: yes - $container_evidence"
    return 0
}

print_segment()
{
    # Parameters are named distinctly because print_segment is called from
    # branches that hold their own `value`, and a bare `value=$2` here would
    # clobber the caller's copy behind its back.
    segment_icon=$1
    segment_value=$2

    if [ -z "$segment_value" ]; then
        trace 'print_segment: declined, empty value (blank segment, rc 0)'
        return 1
    fi

    # tmux expands `#[...]`, `#{...}` and `#(...)` in the OUTPUT of a `#()`
    # job, so a branch named `x#[bg=red]y` injects a style attribute into the
    # status bar. `##` is tmux's literal-`#` escape.
    #
    # This has to happen here and not in tmux.conf: tmux's format parser
    # consumes the `#` characters of a `sed 's/#/##/g'` written inside the
    # `#()` format string before any shell sees them, and the injection still
    # lands. Verified with a real pty client.
    #
    # Done with parameter expansion rather than a sed exec because this runs on
    # tmux's status-refresh path, once per segment per interval; the loop keeps
    # that at zero extra processes.
    #
    # The icon is not escaped: it is a fixed literal chosen in this script, not
    # external input, and none of the six contain `#`.
    segment_escaped=
    segment_rest=$segment_value

    while :; do
        case $segment_rest in
            *'#'*)
                segment_escaped=$segment_escaped${segment_rest%%\#*}'##'
                segment_rest=${segment_rest#*\#}
                ;;
            *)
                segment_escaped=$segment_escaped$segment_rest
                break
                ;;
        esac
    done

    if [ "$segment_escaped" = "$segment_value" ]; then
        trace "print_segment: [$segment_escaped]"
    else
        trace "print_segment: [$segment_escaped] (# escaped from [$segment_value])"
    fi

    # One output shape, because all six call sites now pass a non-empty glyph:
    # icon, one space, value, two trailing spaces, no newline. Those two
    # trailing spaces are contract — they are the inter-segment gap tmux does
    # not add itself — and $segment_escaped rather than $segment_value is what
    # makes the `#`->`##` loop above load-bearing: this printf is the only path
    # by which a segment reaches stdout, so an unescaped `#` here is a style
    # attribute injected into the status bar (B-13).
    #
    # This carried an `else printf '%s  '` for the era when five of the six
    # sites passed an empty icon. That count is now zero, and the branch was
    # removed only after an instrumented build wrote a marker from inside it
    # and stayed silent across every verb, doctor, --help, --version, an
    # unknown verb, no-args, and the git verbs against a non-repo, a
    # nonexistent path and no path at all (F-26).
    #
    # A future segment that genuinely wants no icon should restore the branch,
    # NOT pass an empty string: '%s %s  ' with an empty icon emits a stray
    # leading space, which costs a cell of a status bar already over budget.
    printf '%s %s  ' "$segment_icon" "$segment_escaped"
}

# First remote URL, preferring origin. Two execs in the common case collapse to
# one, since `get-url origin` succeeds outright for any repo with an origin.
git_remote_url()
{
    path=${1:-}
    [ -n "$path" ] || return 1

    if git -C "$path" remote get-url origin 2>&3; then
        trace 'git_remote_url: origin'
        return 0
    fi

    # Remote names cannot contain whitespace, so splitting the listing is safe.
    for remote_name in $(git -C "$path" remote 2>&3); do
        if git -C "$path" remote get-url "$remote_name" 2>&3; then
            trace "git_remote_url: $remote_name (no origin)"
            return 0
        fi
    done

    trace "git_remote_url: declined, no usable remote in $path"
    return 1
}

git_repo()
{
    path=${1:-}
    [ -n "$path" ] || return 1

    repo_name=$(git_remote_url "$path" 2>&3)

    if [ -n "$repo_name" ]; then
        # The remote basename, not the directory: a linked worktree's directory
        # is named for its branch, and ~/.local/share/chezmoi is named for the
        # tool rather than the repository (whose remote says `dotfiles`).
        #
        # Trailing `/` and `.git` come off in a loop because they nest, e.g. a
        # local remote spelled `/srv/git/myrepo/.git/`. Then both URL forms
        # have to reduce alike, and the SSH form's separator is `:`, not `/`:
        #   git@github.com:rinman24/dotfiles.git -> dotfiles
        #   https://github.com/rinman24/dotfiles -> dotfiles
        #   git@github.com:dotfiles.git          -> dotfiles  (no `/` at all)
        while :; do
            case $repo_name in
                */)
                    repo_name=${repo_name%/}
                    ;;
                *.git)
                    repo_name=${repo_name%.git}
                    ;;
                *)
                    break
                    ;;
            esac
        done

        repo_name=${repo_name##*/}
        repo_name=${repo_name##*:}
        trace "git_repo: from the remote url"
    else
        # No remote: fall back to the repository directory name. It cannot come
        # from --show-toplevel, which names the WORKTREE directory in a linked
        # worktree; --git-common-dir is `<repo>/.git` from every worktree of the
        # repository. Parameter expansion rather than basename/dirname so a
        # leading-`-` path can never be read as an option (a path containing a
        # newline still defeats `$( )`, which is unfixable in sh).
        common_dir=$(git -C "$path" rev-parse --path-format=absolute \
            --git-common-dir 2>&3) || return 1
        [ -n "$common_dir" ] || return 1

        repo_dir=${common_dir%/}

        # A bare repository's common dir IS the repository, with no `.git`
        # component to strip; taking its parent would name the containing
        # directory instead.
        case ${repo_dir##*/} in
            .git)
                repo_dir=${repo_dir%/*}
                ;;
        esac

        repo_name=${repo_dir##*/}
        trace "git_repo: from git-common-dir $common_dir (no remote)"
    fi

    if [ -z "$repo_name" ]; then
        trace 'git_repo: declined, empty repository name'
        return 1
    fi

    trace "git_repo: $repo_name"
    printf '%s\n' "$repo_name"
}

git_branch()
{
    path=${1:-}
    [ -n "$path" ] || return 1

    if git -C "$path" symbolic-ref --quiet --short HEAD 2>&3; then
        trace 'git_branch: symbolic-ref (attached HEAD)'
        return 0
    fi

    trace 'git_branch: no symbolic ref, using rev-parse --short (detached HEAD)'
    git -C "$path" rev-parse --short HEAD 2>&3
}

linux_machine_cpu()
{
    trace "machine_cpu: sampling $PROC_ROOT/stat over ${SAMPLE_SECONDS}s"

    # printf "%.0f", not print. `total` is a sum of cumulative jiffies from the
    # aggregate `cpu ` line, so it grows at cores x HZ per second: a 64-core host
    # crosses 2^31 after four days of uptime, a 16-core host after thirty.
    # mawk 1.3.4 20200120 (Debian bookworm) renders any COMPUTED integral value
    # above 2^31 through OFMT, i.e. as 1.65888e+10, and six significant figures
    # cannot hold a one-second delta of a few thousand jiffies. Both samples then
    # round to the same string, total_delta comes out 0, and the awk below exits
    # 1 -- the CPU segment fails outright rather than merely losing precision.
    # %.0f is exact to 2^53 on every awk here; %d is NOT (mawk saturates it at
    # INT_MAX) and OFMT is ignored on this path by the affected build.
    first=$(awk '
        /^cpu / {
            total = 0
            for (i = 2; i <= NF && i <= 9; i++) {
                total += $i
            }

            idle = $5 + $6
            printf "%.0f %.0f\n", total, idle
            exit
        }
    ' "$PROC_ROOT/stat" 2>&3) || return 1

    sleep "$SAMPLE_SECONDS" || return 1

    second=$(awk '
        /^cpu / {
            total = 0
            for (i = 2; i <= NF && i <= 9; i++) {
                total += $i
            }

            idle = $5 + $6
            printf "%.0f %.0f\n", total, idle
            exit
        }
    ' "$PROC_ROOT/stat" 2>&3) || return 1

    # The two "total idle" pairs the percentage is computed from. Traced because
    # the 0/100 clamps below live inside awk, where no shell trace can reach
    # them; from these two pairs an operator can tell a clamped 100 from a real
    # one, which is the question the clamp itself cannot answer.
    trace "machine_cpu: samples [$first] -> [$second]"

    awk -v a="$first" -v b="$second" '
        BEGIN {
            split(a, x, " ")
            split(b, y, " ")

            total_delta = y[1] - x[1]
            idle_delta = y[2] - x[2]

            if (total_delta <= 0) {
                exit 1
            }

            percent = 100 * (total_delta - idle_delta) / total_delta

            if (percent < 0) {
                percent = 0
            }

            if (percent > 100) {
                percent = 100
            }

            printf "%.0f", percent
        }
    '
}

count_cpu_list()
{
    awk -F, '
        NF {
            count = 0

            for (i = 1; i <= NF; i++) {
                if ($i ~ /^[0-9]+-[0-9]+$/) {
                    split($i, range, "-")
                    count += range[2] - range[1] + 1
                } else if ($i ~ /^[0-9]+$/) {
                    count++
                }
            }

            print count
        }
    '
}

linux_default_cpu_capacity()
{
    if getconf _NPROCESSORS_ONLN 2>&3; then
        trace 'default_cpu_capacity: getconf _NPROCESSORS_ONLN'
        return 0
    fi

    trace "default_cpu_capacity: getconf declined, counting $PROC_ROOT/cpuinfo"

    awk '
        /^processor[[:space:]]*:/ {
            count++
        }

        END {
            if (count) {
                print count
            }
        }
    ' "$PROC_ROOT/cpuinfo" 2>&3
}

# cgroup2_resolved and cgroup2_evidence follow the container_evidence pattern
# above: the branch that decided is recorded, not just its result, so doctor can
# report which of the five outcomes below produced (or failed to produce) the
# directory without re-deriving any of it.
#
# The two success branches print cgroup2_resolved rather than printing one
# expression and recording another. That is not tidiness: doctor's whole claim is
# that it reports what the segment actually used, and two spellings of the same
# path are two things that can drift.
#
# Note for the caller — and this cost a `doctor` line reading "unresolved ()"
# before it was noticed: `dir=$(linux_cgroup2_dir)` runs the function in a
# SUBSHELL, so neither variable survives. doctor therefore calls it directly,
# with stdout discarded, and reads both back from the parent shell.
cgroup2_resolved=
cgroup2_evidence=
linux_cgroup2_dir()
{
    cgroup2_resolved=

    if [ ! -r "$CGROUP_ROOT/cgroup.controllers" ]; then
        cgroup2_evidence="unresolved - $CGROUP_ROOT/cgroup.controllers is not readable"
        trace "cgroup2_dir: $cgroup2_evidence"
        return 1
    fi

    relative_path=$(awk -F: '
        $1 == "0" {
            print $3
            exit
        }
    ' "$PROC_ROOT/self/cgroup" 2>&3)

    # No `0::` line means this process has no cgroup v2 membership to speak of,
    # so the v2 reader is simply inapplicable — say so and let the caller fall
    # through. Distinguishing "empty" from "/" has to happen here, because
    # ${relative_path:-/} below deliberately collapses the two, which is what
    # keeps a genuine `0::/` (cgroupns=private, the common container case)
    # resolving to the root it actually names.
    if [ -z "$relative_path" ]; then
        cgroup2_evidence="unresolved - no 0:: line in $PROC_ROOT/self/cgroup"
        trace "cgroup2_dir: $cgroup2_evidence"
        return 1
    fi

    directory=$CGROUP_ROOT${relative_path:-/}

    # A path we cannot find is not an invitation to substitute the root cgroup:
    # its cpu.stat is system-wide, so doing that reports machine CPU as container
    # CPU with nothing to show it happened. Under cgroupns=host the relative
    # path can legitimately be absent from this namespace's view, and that is
    # exactly the case that must fail rather than lie. A missing path that was
    # the root to begin with still resolves to the root, since that is the
    # cgroup it names.
    if [ -d "$directory" ]; then
        cgroup2_resolved=$directory
        cgroup2_evidence="$directory - from 0::$relative_path, which exists"
        trace "cgroup2_dir: $cgroup2_evidence"
        printf '%s\n' "$cgroup2_resolved"
    elif [ "${relative_path:-/}" = / ]; then
        cgroup2_resolved=$CGROUP_ROOT
        cgroup2_evidence="$CGROUP_ROOT - from 0::$relative_path, the root cgroup"
        trace "cgroup2_dir: $cgroup2_evidence"
        printf '%s\n' "$cgroup2_resolved"
    else
        cgroup2_evidence="unresolved - 0::$relative_path names $directory,"
        cgroup2_evidence="$cgroup2_evidence which does not exist"
        trace "cgroup2_dir: $cgroup2_evidence"
        return 1
    fi
}

linux_cgroup2_cpu_capacity()
{
    directory=$1
    capacity=$(linux_default_cpu_capacity)
    [ -n "$capacity" ] || capacity=1

    cpu_list=

    # `IFS= read -r` replaces $(cat …) here and at every other single-line
    # /sys or /proc read in this file: no exec, and no subshell either.
    #
    # Its exit status is deliberately not tested. `read` reports failure when it
    # hits EOF without a terminating newline, which several of these files do, so
    # a complete and successful read would be indistinguishable from a missing
    # one. The contents are the success signal, and every use is already guarded
    # by [ -n … ].
    #
    # Two placement details: 2>&3 comes BEFORE the input redirection, so
    # that it is already in force if the open itself fails (redirections apply
    # left to right); and the target variable is cleared first, because a failed
    # open means `read` never runs, and these names outlive a single function —
    # the fallthrough chains reach them across calls.
    if [ -r "$directory/cpuset.cpus.effective" ]; then
        IFS= read -r cpu_list 2>&3 <"$directory/cpuset.cpus.effective"
        trace "cpu_capacity: cpuset.cpus.effective [$cpu_list]"
    elif [ -r "$directory/cpuset.cpus" ]; then
        IFS= read -r cpu_list 2>&3 <"$directory/cpuset.cpus"
        trace "cpu_capacity: cpuset.cpus [$cpu_list] (no .effective)"
    else
        trace "cpu_capacity: no cpuset file in $directory, default $capacity"
    fi

    if [ -n "$cpu_list" ]; then
        cpuset_count=$(printf '%s\n' "$cpu_list" | count_cpu_list)

        if [ -n "$cpuset_count" ] &&
            [ "$cpuset_count" -gt 0 ] 2>&3; then
            trace "cpu_capacity: cpuset [$cpu_list] = $cpuset_count," \
                "replacing default $capacity"
            capacity=$cpuset_count
        fi
    fi

    if [ -r "$directory/cpu.max" ]; then
        cpu_max=
        IFS= read -r cpu_max 2>&3 <"$directory/cpu.max"

        # cpu.max is "<quota|max> <period>" on one line. Splitting it used to
        # cost a cat and two awk processes; parameter expansion costs none.
        # The space has to be there before splitting, so that a malformed
        # single-field line leaves period empty and is rejected below — which is
        # exactly where `awk '{print $2}'` left it.
        quota=
        period=

        case $cpu_max in
            *' '*)
                quota=${cpu_max%% *}
                period=${cpu_max##* }
                ;;
        esac

        if [ -n "$quota" ] &&
            [ "$quota" != max ] &&
            [ -n "$period" ]; then
            # The clamp itself is awk's. Whether it BOUND is decided here, by
            # comparing the value before and after rather than by re-implementing
            # awk's test — a second copy of `quota/period < current` in shell
            # arithmetic would be wrong for the fractional case the awk exists to
            # handle, and would eventually disagree with it.
            capacity_before=$capacity

            capacity=$(awk \
                -v current="$capacity" \
                -v quota="$quota" \
                -v period="$period" '
                BEGIN {
                    quota_capacity = quota / period

                    if (quota_capacity > 0 &&
                        quota_capacity < current) {
                        print quota_capacity
                    } else {
                        print current
                    }
                }
            ')

            if [ "$capacity" = "$capacity_before" ]; then
                trace "cpu_capacity: quota $quota/$period does not bind," \
                    "capacity stays $capacity"
            else
                trace "cpu_capacity: quota $quota/$period clamps" \
                    "$capacity_before to $capacity"
            fi
        else
            trace "cpu_capacity: cpu.max [$cpu_max] sets no quota"
        fi
    else
        trace "cpu_capacity: no readable cpu.max in $directory"
    fi

    trace "cpu_capacity: $capacity"
    printf '%s\n' "$capacity"
}

linux_cgroup2_container_cpu()
{
    directory=$(linux_cgroup2_dir) || return 1

    if [ ! -r "$directory/cpu.stat" ]; then
        trace "container_cpu: declined, $directory/cpu.stat not readable"
        return 1
    fi

    capacity=$(linux_cgroup2_cpu_capacity "$directory")

    if [ -z "$capacity" ]; then
        trace 'container_cpu: declined, no capacity'
        return 1
    fi

    # cpu.stat is readable in every non-root cgroup v2 hierarchy, limits or not,
    # so it cannot decide scope. Report cgroup scope only when a limit actually
    # binds — a real quota, or a cpuset narrower than the machine — matching the
    # rule memory.max already applies. Otherwise fall through to machine scope, so
    # the cpu and mem segments never show two different denominators.
    #
    # Same read-and-split as linux_cgroup2_cpu_capacity, for the same reason and with
    # the same outcome: quota is the first field, and empty when the file cannot
    # be read, which ${quota:-max} then reads as "no quota".
    cpu_max=
    IFS= read -r cpu_max 2>&3 <"$directory/cpu.max"
    quota=${cpu_max%% *}
    machine_capacity=$(linux_default_cpu_capacity)

    # The scope gate, spelled as if/elif/else rather than the `|| … || return 1`
    # chain it replaces. Identical truth table and identical short-circuit order;
    # what it buys is that the DECLINE has a reason attached. "The cpu segment
    # shows machine scope inside a container" is one of the three defects that
    # motivated this whole channel, and this is the branch that causes it.
    if [ "${quota:-max}" != max ]; then
        trace "container_cpu: cgroup scope, cpu.max quota $quota binds"
    elif [ "$capacity" -lt "${machine_capacity:-1}" ] 2>&3; then
        trace "container_cpu: cgroup scope, capacity $capacity is narrower" \
            "than machine ${machine_capacity:-1}"
    else
        trace "container_cpu: declined, no limit binds (quota max, capacity" \
            "$capacity, machine ${machine_capacity:-1}) - machine scope instead"
        return 1
    fi

    usage_start=$(awk '
        $1 == "usage_usec" {
            print $2
            exit
        }
    ' "$directory/cpu.stat" 2>&3)

    time_start=$(awk '{print $1; exit}' "$PROC_ROOT/uptime" 2>&3)

    [ -n "$usage_start" ] &&
        [ -n "$time_start" ] ||
        return 1

    sleep "$SAMPLE_SECONDS" || return 1

    usage_end=$(awk '
        $1 == "usage_usec" {
            print $2
            exit
        }
    ' "$directory/cpu.stat" 2>&3)

    time_end=$(awk '{print $1; exit}' "$PROC_ROOT/uptime" 2>&3)

    [ -n "$usage_end" ] &&
        [ -n "$time_end" ] ||
        return 1

    # Same reason as machine_cpu's sample trace: the 0/100 clamps are inside the
    # awk below and cannot report themselves, so the inputs are traced instead.
    trace "container_cpu: usage $usage_start -> $usage_end usec," \
        "uptime $time_start -> $time_end s, capacity $capacity"

    awk \
        -v usage_start="$usage_start" \
        -v usage_end="$usage_end" \
        -v time_start="$time_start" \
        -v time_end="$time_end" \
        -v capacity="$capacity" '
        BEGIN {
            elapsed = time_end - time_start

            if (elapsed <= 0 || capacity <= 0) {
                exit 1
            }

            percent = 100 \
                * (usage_end - usage_start) \
                / (elapsed * 1000000 * capacity)

            if (percent < 0) {
                percent = 0
            }

            if (percent > 100) {
                percent = 100
            }

            printf "%.0f", percent
        }
    '
}

# The fallthrough chain below is left exactly as it was. Nothing was rewrapped to
# make it traceable: each link reports its own entry, its own decline and its own
# reason, so "which link produced the value" is answerable without touching the
# chain that four reviewers flagged as knowledgeable code.
linux_cpu()
{
    if is_container; then
        trace 'linux_cpu: container, trying the cgroup v2 reader first'

        linux_cgroup2_container_cpu 2>&3 ||
            linux_machine_cpu
    else
        trace 'linux_cpu: not a container, machine scope'
        linux_machine_cpu
    fi
}

linux_machine_total_bytes()
{
    trace "machine_total_bytes: reading $PROC_ROOT/meminfo"

    # printf "%.0f", not print -- see linux_machine_cpu for the full account of
    # the mawk 1.3.4 20200120 defect. Here `total` is $2 * 1024, so it exceeds
    # 2^31 on every machine with more than 2 GiB of RAM: `print` emitted
    # 8.32568e+09, which the shell guard `[ "$machine_total" -gt 0 ]` at the
    # container_mem clamp rejected outright ("Illegal number"), leaving the trace
    # claiming "no machine clamp" while the inner awk -- which re-parses the
    # scientific notation happily -- went on to clamp. The trace contradicted the
    # number it was printed beside.
    #
    # `available` is uninitialised when meminfo has no MemAvailable line (pre-3.14
    # kernels only). It printed as the empty string before and prints as 0 now.
    # Every consumer already coerced it: linux_machine_mem's `total - available`
    # reads "" as 0, so the percentage is unchanged -- only the trace text is,
    # and it now says what the arithmetic actually does.
    awk '
        $1 == "MemTotal:" {
            total = $2 * 1024
        }

        $1 == "MemAvailable:" {
            available = $2 * 1024
        }

        END {
            if (total > 0) {
                printf "%.0f %.0f\n", total, available
            }
        }
    ' "$PROC_ROOT/meminfo" 2>&3
}

linux_machine_mem()
{
    values=$(linux_machine_total_bytes) || return 1
    trace "machine_mem: MemTotal/MemAvailable bytes [$values]"

    awk -v values="$values" '
        BEGIN {
            split(values, memory, " ")

            total = memory[1]
            available = memory[2]

            if (total <= 0) {
                exit 1
            }

            if (available < 0) {
                available = 0
            }

            percent = 100 * (total - available) / total

            if (percent < 0) {
                percent = 0
            }

            if (percent > 100) {
                percent = 100
            }

            printf "%.0f", percent
        }
    '
}

linux_cgroup2_container_mem()
{
    directory=$(linux_cgroup2_dir) || return 1

    if [ ! -r "$directory/memory.current" ] ||
        [ ! -r "$directory/memory.max" ]; then
        trace "container_mem: declined, memory.current or memory.max" \
            "not readable in $directory"
        return 1
    fi

    used=
    limit=
    IFS= read -r used 2>&3 <"$directory/memory.current"
    IFS= read -r limit 2>&3 <"$directory/memory.max"

    # De Morgan of the `[ -n … ] && [ -n … ] && [ … != max ] || return 1` chain
    # this replaces: same three tests, same order, same result. Split into two
    # so the "max" case — a container with no memory limit, which is the single
    # most common reason the mem segment silently shows machine scope — reports
    # itself as a distinct outcome rather than as "something was empty".
    if [ -z "$used" ] || [ -z "$limit" ]; then
        trace "container_mem: declined, memory.current [$used] or" \
            "memory.max [$limit] read empty"
        return 1
    fi

    if [ "$limit" = max ]; then
        trace 'container_mem: declined, memory.max is "max" -' \
            'no limit binds, machine scope instead'
        return 1
    fi

    if [ -r "$directory/memory.stat" ]; then
        cache=$(awk '
            $1 == "inactive_file" {
                print $2
                exit
            }
        ' "$directory/memory.stat" 2>&3)

        if [ -n "$cache" ]; then
            used_before=$used

            used=$(awk -v used="$used" -v cache="$cache" '
                BEGIN {
                    value = used - cache

                    if (value < 0) {
                        value = 0
                    }

                    printf "%.0f", value
                }
            ')

            if [ "$used" = 0 ] && [ "$used_before" != 0 ]; then
                trace "container_mem: inactive_file $cache exceeds usage" \
                    "$used_before, used clamped to 0"
            else
                trace "container_mem: used $used_before -" \
                    "inactive_file $cache = $used"
            fi
        else
            trace "container_mem: no inactive_file line in memory.stat," \
                "no cache subtracted"
        fi
    else
        trace "container_mem: no readable memory.stat in $directory," \
            "no cache subtracted"
    fi

    machine_values=$(linux_machine_total_bytes)
    machine_total=$(printf '%s\n' "$machine_values" | awk '{print $1}')

    # Diagnostic only — it mirrors the awk condition below rather than feeding
    # it, and it is spelled in shell integers where the awk uses floats. Both
    # branches are pinned by fixture_test, so if the two ever drift apart the
    # gate says so instead of the trace quietly lying.
    if [ -n "$machine_total" ] &&
        [ "$machine_total" -gt 0 ] 2>&3 &&
        [ "$machine_total" -lt "$limit" ] 2>&3; then
        trace "container_mem: memory.max $limit exceeds machine total" \
            "$machine_total, limit clamped to the machine"
    else
        trace "container_mem: limit $limit, machine total" \
            "[${machine_total:-none}], no machine clamp"
    fi

    trace "container_mem: used $used of limit $limit"

    awk \
        -v used="$used" \
        -v limit="$limit" \
        -v machine="$machine_total" '
        BEGIN {
            if (machine > 0 && machine < limit) {
                limit = machine
            }

            if (limit <= 0) {
                exit 1
            }

            percent = 100 * used / limit

            if (percent < 0) {
                percent = 0
            }

            if (percent > 100) {
                percent = 100
            }

            printf "%.0f", percent
        }
    '
}

# Unrewrapped, for the reason given above linux_cpu.
linux_mem()
{
    if is_container; then
        trace 'linux_mem: container, trying the cgroup v2 reader first'

        linux_cgroup2_container_mem 2>&3 ||
            linux_machine_mem
    else
        trace 'linux_mem: not a container, machine scope'
        linux_machine_mem
    fi
}

macos_cpu()
{
    # Was "top -l 1 -n 0". Two reasons it is gone:
    #   cost - top burned 0.76 s user + 3.88 s system = ~4.6 s of CPU per
    #     sample (kernel-side, walking 800+ processes), and got dearer exactly
    #     as the load it reported rose. "iostat -c 2" costs ~0.10 s + 0.03 s.
    #   correctness - top's "CPU usage:" line is a since-boot-weighted average,
    #     not an interval delta. iostat -c 2 is a true 1 s
    #     host_processor_info delta, so we read the LAST (second) row.
    # "-n 0" is load-bearing: it suppresses the disk columns, fixing the layout
    # at NF=6 ("us sy id 1m 5m 15m") so idle is always $3. Drop the flag and
    # idle moves, and you would have to read it as $(NF-3) instead.
    trace 'macos_cpu: iostat -c 2 -n 0 (its own 1 s window)'

    iostat -c 2 -n 0 2>&3 | awk '
        {
            fields = NF
            idle = $3
        }

        END {
            if (fields < 6) {
                exit 1
            }

            percent = 100 - idle

            if (percent < 0) {
                percent = 0
            }

            if (percent > 100) {
                percent = 100
            }

            printf "%.0f", percent
        }
    '
}

macos_mem()
{
    # `memory_pressure -Q` was abandoned here. Its "System-wide memory free
    # percentage" counts inactive, speculative, purgeable and compressor-
    # reclaimable pages as free, so it is a reclaim-urgency signal, not a
    # utilization one, and hw.memsize never enters it — the result cannot be
    # reconciled against Activity Monitor. Measured: -Q said 64% free (old
    # formula: 36% used) while Activity Monitor showed 80% used.
    #
    # The numerator below is Activity Monitor's "Memory Used": app memory
    # (anonymous pages less the purgeable ones) + wired + compressor-occupied,
    # in pages, scaled by the page size. hw.memsize is the denominator.
    total=$(sysctl -n hw.memsize 2>&3) || return 1
    trace "macos_mem: hw.memsize $total, reading vm_stat"

    vm_stat 2>&3 | awk -v total="$total" '
        /page size of/ {
            match($0, /[0-9]+ bytes/)
            page = substr($0, RSTART, RLENGTH) + 0
        }

        /^Pages wired down:/ {
            wired = $4 + 0
        }

        /^Pages occupied by compressor:/ {
            compressed = $5 + 0
        }

        /^Anonymous pages:/ {
            anonymous = $3 + 0
        }

        /^Pages purgeable:/ {
            purgeable = $3 + 0
        }

        END {
            if (total <= 0 || page <= 0) {
                exit 1
            }

            used = (anonymous - purgeable + wired + compressed) * page
            percent = 100 * used / total

            if (percent < 0) {
                percent = 0
            }

            if (percent > 100) {
                percent = 100
            }

            printf "%.0f", percent
        }
    '
}

# A bare integer, like macos_cpu, linux_cpu, macos_mem and linux_mem. The `%`
# belongs to the dispatcher, which appends it for every sampled segment; having
# one producer hand back a pre-formatted string and the other four hand back
# numbers is how a `%%` or a missing `%` gets in.
battery_percent()
{
    case "$OS" in
        Darwin)
            trace 'battery: pmset -g batt'

            # RLENGTH - 1 drops the `%` that anchored the match.
            pmset -g batt 2>&3 | awk '
                match($0, /[0-9]+%/) {
                    print substr($0, RSTART, RLENGTH - 1)
                    exit
                }
            '
            ;;
        Linux)
            # An unmatched glob is left literal — POSIX sh has no nullglob — so
            # the no-match case falls out of [ -r "$file" ] and the function
            # returns 0 having printed nothing, which is the contract.
            #
            # The return belongs INSIDE the [ -n "$value" ] guard. Outside it, a
            # BAT0 whose capacity reads empty (it does, briefly, during ACPI
            # init) abandoned the search and hid a perfectly good BAT1.
            for file in /sys/class/power_supply/BAT*/capacity; do
                if [ -r "$file" ]; then
                    value=
                    IFS= read -r value 2>&3 <"$file"

                    if [ -n "$value" ]; then
                        trace "battery: $file = $value"
                        printf '%s\n' "$value"
                        return 0
                    fi

                    trace "battery: $file read empty, continuing the search"
                fi
            done

            trace 'battery: no readable' \
                '/sys/class/power_supply/BAT*/capacity'
            ;;
        *)
            # New branch, and it adds no behaviour: the case already fell
            # through to rc 0 with nothing printed on an unrecognised $OS, which
            # is the contract. All it does is say so out loud.
            trace "battery: no reader for OS [$OS]"
            ;;
    esac
}

# ---------------------------------------------------------------------------
# doctor — one line per capability, each stating a decision AND the evidence for
# it. This is what an operator runs when the segment is blank, and blank is the
# one symptom the failure contract guarantees will otherwise be silent.
#
# Four rules, all contract rather than taste:
#
#   - stdout, not the error channel. A human reads this; tmux never does. It is
#     also the reason doctor is exempt from the two-trailing-spaces segment
#     shape: it is not a segment.
#   - exit 0, like every other verb.
#   - it never emits `#[` and never reads an @billet_* option. Those are
#     architectural invariants of this file and a diagnostic is not exempt from
#     them; a `#[` on stdout is a style injection wherever it is read.
#   - it probes by CALLING the functions the verbs call — is_container,
#     linux_cgroup2_dir, battery_percent — and reads back the evidence they
#     record, rather than re-deriving any of it. A doctor with its own copy of
#     the logic agrees with the segment right up until the moment they differ,
#     which is the only moment doctor is ever run.
doctor_line()
{
    printf '%-15s %s\n' "$1" "$2"
}

# Absolute path of this file, so a report pasted into a bug can be matched to the
# copy that produced it. Parameter expansion for the basename, `cd`+`pwd` for the
# directory; if that fails, $0 unchanged is still more use than nothing.
doctor_self_path()
{
    self_dir=$(CDPATH='' cd -- "$(dirname -- "$0")" 2>&3 && pwd) || self_dir=

    if [ -n "$self_dir" ]; then
        printf '%s/%s\n' "${self_dir%/}" "${0##*/}"
    else
        printf '%s\n' "$0"
    fi
}

# mawk and gawk answer `-W version`; BSD awk IGNORES -W, then reads the word
# `version` as its program text and blocks forever on stdin. `</dev/null` is what
# stops doctor hanging on macOS, and is not decoration.
doctor_awk_flavour()
{
    flavour=$(awk -W version </dev/null 2>&3 | head -1)

    if [ -z "$flavour" ]; then
        flavour=$(awk --version </dev/null 2>&3 | head -1)
    fi

    printf '%s\n' "${flavour:-unknown}"
}

doctor_path_state()
{
    if [ ! -e "$1" ]; then
        printf 'does not exist'
    elif [ ! -d "$1" ]; then
        printf 'exists but is not a directory'
    elif [ ! -r "$1" ]; then
        printf 'exists but is not readable'
    else
        printf 'exists and is readable'
    fi
}

doctor()
{
    # Defensive under `set -u`: both are set by the probes below, but reading a
    # name the probe never reached would blank the line that is supposed to
    # explain why the probe never reached it.
    container_evidence=
    cgroup2_evidence=
    cgroup2_resolved=

    doctor_line script "$(doctor_self_path)"
    doctor_line version "$VERSION"
    doctor_line os "${OS:-unknown} (uname -s)"
    doctor_line awk "$(doctor_awk_flavour) at $(command -v awk 2>&3)"

    if [ -n "${STATUS_SEGMENT_DEBUG:-}" ]; then
        doctor_line 'error channel' 'open (STATUS_SEGMENT_DEBUG set; fd 3 -> stderr)'
    else
        doctor_line 'error channel' \
            'suppressed (set STATUS_SEGMENT_DEBUG=1 for the full trace)'
    fi

    if [ "$SAMPLE_SECONDS" = "$SAMPLE_SECONDS_REQUESTED" ]; then
        doctor_line 'sample window' "${SAMPLE_SECONDS}s"
    else
        doctor_line 'sample window' \
            "${SAMPLE_SECONDS}s (rejected '$SAMPLE_SECONDS_REQUESTED')"
    fi

    if [ -n "${STATUS_SEGMENT_PROC_ROOT:-}" ]; then
        doctor_origin='STATUS_SEGMENT_PROC_ROOT'
    else
        doctor_origin='default'
    fi

    doctor_line 'proc root' \
        "$PROC_ROOT ($doctor_origin, $(doctor_path_state "$PROC_ROOT"))"

    if [ -n "${STATUS_SEGMENT_CGROUP_ROOT:-}" ]; then
        doctor_origin='STATUS_SEGMENT_CGROUP_ROOT'
    else
        doctor_origin='default'
    fi

    doctor_line 'cgroup root' \
        "$CGROUP_ROOT ($doctor_origin, $(doctor_path_state "$CGROUP_ROOT"))"

    # Reported only when it is set, unlike the two roots above, because its
    # default is the empty prefix: "fs root: (default, ...)" would be a line
    # about nothing. Suppressing it when unset also keeps doctor's default output
    # byte-identical to the build before this root existed, which is the property
    # the identity check pins.
    if [ -n "${STATUS_SEGMENT_FS_ROOT:-}" ]; then
        doctor_line 'fs root' \
            "$FS_ROOT (STATUS_SEGMENT_FS_ROOT, $(doctor_path_state "$FS_ROOT"))"
    fi

    if is_container; then
        doctor_line container "yes - $container_evidence"
    else
        doctor_line container "no - $container_evidence"
    fi

    if [ -r "$CGROUP_ROOT/cgroup.controllers" ]; then
        doctor_line 'cgroup v2' "available ($CGROUP_ROOT/cgroup.controllers readable)"
    else
        doctor_line 'cgroup v2' \
            "unavailable ($CGROUP_ROOT/cgroup.controllers not readable)"
    fi

    # Called directly, not as `$(linux_cgroup2_dir)`: a command substitution runs
    # it in a subshell and the two globals it records die with that subshell.
    linux_cgroup2_dir >/dev/null || :
    doctor_cgroup_dir=$cgroup2_resolved

    doctor_line 'cgroup dir' "$cgroup2_evidence"

    doctor_battery=$(battery_percent)

    if [ -n "$doctor_battery" ]; then
        doctor_line battery "present, $doctor_battery percent"
    else
        case "$OS" in
            Darwin)
                doctor_line battery 'absent (pmset -g batt reported no percentage)'
                ;;
            Linux)
                doctor_line battery \
                    'absent (no readable /sys/class/power_supply/BAT*/capacity)'
                ;;
            *)
                doctor_line battery "unsupported (no reader for OS [${OS:-unknown}])"
                ;;
        esac
    fi

    if doctor_git=$(command -v git 2>&3); then
        doctor_state="available (git at $doctor_git; needs a <path> argument)"
    else
        doctor_state='unavailable (git(1) not on PATH)'
    fi

    doctor_line 'verb checkout' "$doctor_state"
    doctor_line 'verb repo' "$doctor_state"
    doctor_line 'verb head' "$doctor_state"

    case "$OS" in
        Darwin)
            if doctor_tool=$(command -v iostat 2>&3); then
                doctor_state="available (macos_cpu, iostat at $doctor_tool)"
            else
                doctor_state='unavailable (iostat(1) not on PATH)'
            fi
            ;;
        Linux)
            if [ -r "$PROC_ROOT/stat" ]; then
                doctor_state="available (machine scope, $PROC_ROOT/stat readable)"
            else
                doctor_state="unavailable ($PROC_ROOT/stat not readable)"
            fi

            if [ -n "$doctor_cgroup_dir" ] &&
                [ -r "$doctor_cgroup_dir/cpu.stat" ]; then
                doctor_state="$doctor_state; cgroup scope readable"
            else
                doctor_state="$doctor_state; no cgroup scope (cpu.stat unreadable)"
            fi
            ;;
        *)
            doctor_state="unavailable (no CPU reader for OS [${OS:-unknown}])"
            ;;
    esac

    doctor_line 'verb cpu' "$doctor_state"

    case "$OS" in
        Darwin)
            if doctor_tool=$(command -v vm_stat 2>&3); then
                doctor_state="available (macos_mem, vm_stat at $doctor_tool)"
            else
                doctor_state='unavailable (vm_stat(1) not on PATH)'
            fi
            ;;
        Linux)
            if [ -r "$PROC_ROOT/meminfo" ]; then
                doctor_state="available (machine scope, $PROC_ROOT/meminfo readable)"
            else
                doctor_state="unavailable ($PROC_ROOT/meminfo not readable)"
            fi

            if [ -n "$doctor_cgroup_dir" ] &&
                [ -r "$doctor_cgroup_dir/memory.current" ] &&
                [ -r "$doctor_cgroup_dir/memory.max" ]; then
                doctor_state="$doctor_state; cgroup scope readable"
            else
                doctor_state="$doctor_state; no cgroup scope (memory.current or"
                doctor_state="$doctor_state memory.max unreadable)"
            fi
            ;;
        *)
            doctor_state="unavailable (no memory reader for OS [${OS:-unknown}])"
            ;;
    esac

    doctor_line 'verb memory' "$doctor_state"

    if [ -n "$doctor_battery" ]; then
        doctor_line 'verb battery' "available (reports $doctor_battery percent)"
    else
        doctor_line 'verb battery' 'prints nothing (no battery found; rc 0)'
    fi
}

case ${1:-} in
    checkout)
        repo=$(git_repo "${2:-}" 2>&3) || exit 0
        branch=$(git_branch "${2:-}" 2>&3) || exit 0
        # Icon is U+E702 (UTF-8: ee 9c 82), resolves in Symbols Nerd Font.
        print_segment '' "$repo:$branch"
        ;;
    repo)
        value=$(git_repo "${2:-}" 2>&3) || exit 0
        # Icon is U+F401 (UTF-8: ef 90 81), resolves in Symbols Nerd Font.
        print_segment '' "$value"
        ;;
    head)
        value=$(git_branch "${2:-}" 2>&3) || exit 0
        # Icon is U+F418 (UTF-8: ef 90 98), resolves in Symbols Nerd Font.
        print_segment '' "$value"
        ;;
    cpu)
        case "$OS" in
            Darwin)
                trace 'cpu: Darwin branch'
                value=$(macos_cpu)
                ;;
            Linux)
                trace 'cpu: Linux branch'
                value=$(linux_cpu)
                ;;
            *)
                trace "cpu: no branch for OS [$OS], segment stays blank"
                value=
                ;;
        esac

        # Icon is U+F4BC (UTF-8: ef 92 bc), resolves in Symbols Nerd Font.
        [ -n "$value" ] && print_segment '' "$value%"
        ;;
    memory)
        case "$OS" in
            Darwin)
                trace 'memory: Darwin branch'
                value=$(macos_mem)
                ;;
            Linux)
                trace 'memory: Linux branch'
                value=$(linux_mem)
                ;;
            *)
                trace "memory: no branch for OS [$OS], segment stays blank"
                value=
                ;;
        esac

        # Icon is U+F04C5 (UTF-8: f3 b0 93 85), resolves in Symbols Nerd Font.
        # Recorded here so a glyph mangled or stripped in transit is visible in
        # review rather than silently becoming an empty icon.
        [ -n "$value" ] && print_segment '󰓅' "$value%"
        ;;
    battery)
        value=$(battery_percent)
        # Icon is U+26A1 (UTF-8: e2 9a a1), resolves in Apple Color Emoji. Two
        # accepted consequences of that choice: east_asian_width=Wide, so it
        # occupies 2 cells rather than 1, and being a colour font it renders in
        # its own colours and ignores the #[fg=...] style tmux sets.
        [ -n "$value" ] && print_segment '⚡' "$value%"
        ;;
    # Placed after the six real verbs, not before them: those are what tmux runs
    # on every status refresh, and a `case` is matched top to bottom. These three
    # are typed by a human, once.
    #
    # Naming site 3 of 3. `doctor` is here, in usage()'s here-doc, and in the $OS
    # pre-detection block at the top — all three, deliberately; see the note
    # there for why the middle one is not optional for this verb.
    doctor)
        doctor
        exit 0
        ;;
    --help | -h)
        usage
        exit 0
        ;;
    # -V rather than -v: -v conventionally means verbose, and leaving it
    # unclaimed keeps that option open. -V is the unambiguous short spelling.
    --version | -V)
        printf 'status-segment.sh %s\n' "$VERSION"
        exit 0
        ;;
    # A bare invocation is an operator error exactly as an unknown verb is, and
    # it keeps the same treatment: stderr, exit 2. What it is not is an UNKNOWN
    # COMMAND. Left in `*)` below it reported `unknown command: ''`, naming a
    # verb the operator never typed and inviting them to go looking for the
    # place they mistyped it. Split out here so the message can say the thing
    # that actually happened and point at the one place that lists the verbs.
    #
    # This is deliberately NOT the failure contract (print nothing, exit 0).
    # That contract covers data being unavailable — no battery, no cgroup, no
    # repository — where silence is right because tmux has no segment to draw
    # and nothing went wrong. Misuse is the other category: nothing to draw
    # either, but a reason worth telling the human who typed it.
    #
    # The hint line below is a verbatim copy of the one in `*)`. Two copies of
    # one short literal, deliberately, rather than a helper: it keeps the
    # unknown-verb path byte-for-byte what it already was, and the thing that
    # would actually go stale — the verb list — is not repeated in either.
    '')
        printf 'status-segment.sh: no command given.\n' >&2
        printf "Try 'status-segment.sh --help' for the list of commands.\n" >&2
        exit 2
        ;;
    *)
        # The only write to stderr anywhere in this script, and it has to stay
        # that way: smoke_test.sh asserts stderr is exactly 0 bytes for all six
        # real verbs, and that assertion is the project's only cheap detector
        # for awk-dialect breakage. Exit 2 is unchanged — an unknown verb was
        # always a usage error; all that is new is saying so.
        # The `%s` stays quoted now that the empty case is caught above: a verb
        # that is whitespace, or one that arrived from an unquoted expansion,
        # still lands here, and the quotes are what make its shape legible.
        printf "status-segment.sh: unknown command: '%s'\n" "${1:-}" >&2
        printf "Try 'status-segment.sh --help' for the list of commands.\n" >&2
        exit 2
        ;;
esac

exit 0
