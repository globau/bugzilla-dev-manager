BZ_ROOT="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

alias bz="$BZ_ROOT/bz"

function bznew {
    bz new "$@"
    BZ_DOCS=`perl -I"$BZ_ROOT" -MBz -e 'print Bz->config->htdocs_path'`
    cd "$BZ_DOCS/$1"
}

function cdb() {
    cd `bz path "$@"`
    bz summary
}

function cdr() {
    cd `bz path --repo "$@"`
}
