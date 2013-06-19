
BZ_ROOT="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
BZ_DOCS=`perl -I"$BZ_ROOT" -MBugzillaDevConfig -e 'print \$HTDOCS_PATH'`
BZ_REPO=`perl -I"$BZ_ROOT" -MBugzillaDevConfig -e 'print \$REPO_PATH'`

alias bz="$BZ_ROOT/bz"

function bznew {
    bz new $@
    cd "$BZ_DOCS/$1"
}

function cdb() {
    if [ -z "$1" ]; then
        PWD=`pwd -P`
        if [[ "$PWD" =~ ^$BZ_DOCS/ ]]; then
            LEN=`expr length "$BZ_DOCS/"`
            P=${PWD:$LEN}
            IFS=/ A=( $P )
            cd "$BZ_DOCS/${A[0]}"
            return
        fi;
        cd "$BZ_DOCS"
        return;
    fi
    if [ -d "$BZ_DOCS/$1" ]; then
        cd "$BZ_DOCS/$1"
    else
        cd "$BZ_DOCS/`bz grep -n $@`"
    fi
    if [ -f "data/summary" ]; then
        echo "[Bug ${PWD##*/}] `cat data/summary`" | perl -MTerm::ANSIColor -ne "print colored(\$_,'green')"
    fi
}

function cdr() {
    cd "$BZ_REPO/$1"
}
