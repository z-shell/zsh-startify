# Standarized way of handling finding plugin dir,
# regardless of functionargzero and posixargzero,
# and with an option for a plugin manager to alter
# the plugin directory (i.e. set ZERO parameter)
# http://zdharma.org/Zsh-100-Commits-Club/Zsh-Plugin-Standard.html
0="${${ZERO:-${0:#$ZSH_ARGZERO}}:-${(%):-%N}}"

typeset -g ZSHSIFY_DIR="${0:h}"
typeset -g ZSHSIFY_CACHE_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/zsh-startify"
typeset -gA ZSHSIFY

# Support loading without a plugin manager
if [[ -z "$ZPLG_CUR_PLUGIN" && "${fpath[(r)$ZSHSIFY_DIR]}" != "$ZSHSIFY_DIR" ]]; then
    fpath+=( "$ZSHSIFY_DIR" )
fi

#
# Ensure there is a zsh/datetime module,
# but only if it's needed
#

typeset -g __fork="no"
zstyle -t ":plugin:zsh-startify:tracking" fork && __fork="yes"

if [[ "$__fork" = "no" ]]; then
    [[ "${+modules}" = 1 && "${modules[zsh/datetime]}" != "loaded" && "${modules[zsh/datetime]}" != "autoloaded" ]] && zmodload zsh/datetime
    [ "${+modules}" = 0 ] && zmodload zsh/datetime
    zmodload -e zsh/datetime || { unset __fork; print "zdharma/zsh-startify (plugin): No module \`zsh/datetime' available, aborting setup."; return 0; }
fi
unset __fork

#
# Create the cache directory
#

command mkdir -p "${ZSHSIFY_CACHE_DIR}"

#
# FUNCTION: @zsh-startify-tracking-hook
# DESCRIPTION: The preexec hook that harvests all the data
#

@zsh-startify-tracking-hook() {
    # Trust own CPU-time limiting SECONDS-based mechanism,
    # block Ctrl-C. Also, any infinite loop is impossible
    setopt localtraps; trap '' INT

    local -F SECONDS
    local -F start_time="$SECONDS" diff
    local time_limit=150
    integer new_zsh=0
    is-at-least 5.0.6 && new_zsh=1

    local first second third
    first="${(q)${(q)PWD}}"
    second="${(q)1}"
    third="${(q)2}"

    ##
    # Get timestamp: via datetime module or via date command
    ##

    local fork=0 ts
    zstyle -t ":plugin:zsh-startify:tracking" fork && fork=1
    (( !fork )) && ts="$EPOCHSECONDS"
    (( fork )) && ts="$( date +%s )"

    local proj_discovery_nparents
    local -a project_starters unit_starters
    zstyle -s ":plugin:zsh-startify:tracking" proj_discovery_nparents proj_discovery_nparents || proj_discovery_nparents=4
    zstyle -s ":plugin:zsh-startify:tracking" time_limit time_limit || time_limit="150"
    zstyle -a ":plugin:zsh-startify:tracking" project_starters project_starters \
        || project_starters=( .git .hg Makefile CMakeLists.txt configure SConstruct \*.pro \*.xcodeproj \*.cbp \*.kateproject \*.plugin.zsh )
    zstyle -a ":plugin:zsh-startify:tracking" unit_starters unit_starters || unit_starters=( Makefile CMakeLists.txt \*.pro )

    # A map of possible project files into compact mark
    local -A pfile_to_mark
    pfile_to_mark=( ".git" "GIT" ".hg" "HG" "Makefile" "MAKEFILE" "CMakeLists.txt" "CMAKELISTS"
                    "configure" "CONFIGURE" "SConstruct" "SCONSTRUCT" "*.pro" "PRO" "*.xcodeproj" "XCODE"
                    "*.cbp" "CBP" "*.kateproject" "KATE" "*.plugin.zsh" "ZSHPLUGIN" )

    local look_in="$PWD" ps
    local -a tmp subtract entries paths marks
    integer current_entry=1 result

    # -ge not -gt -> one run of the loop more than *_nparents,
    while [[ "$proj_discovery_nparents" -ge 0 && "$look_in" != "/" && "$look_in" != "$HOME" ]]; do
        (( proj_discovery_nparents = proj_discovery_nparents - 1 ))

        for ps in "${project_starters[@]}"; do
            (( (diff=(SECONDS-start_time)*1000) > time_limit )) && { (( ZSHSIFY[DEBUG] )) && echo "${fg_bold[red]}TRACKING ABORTED, TOO SLOW (${diff%.*}ms / $proj_discovery_nparents / $ps )${reset_color}"; break 2; }
            result=0
            if [ "${ps/\*/}" != "$ps" ]; then
                (( new_zsh )) && \
                    tmp=( $look_in/$~ps(NY1) ) || \
                    tmp=( $look_in/$~ps(N[1]) )
                [ "${#tmp}" != "0" ] && result=1
            else
                [ -e "$look_in/$ps" ] && result=1
            fi

            if (( result )); then
                entries[current_entry]="project"
                paths[current_entry]="$look_in"
                if (( ${+pfile_to_mark[$ps]} )); then
                    marks[current_entry]="${marks[current_entry]}${pfile_to_mark[$ps]}:1:"
                else
                    marks[current_entry]="${marks[current_entry]}NEW:$ps:"
                fi
            fi
        done

        if [ "${entries[current_entry]}" = "project" ]; then
            if [[ "$current_entry" -gt "1" ]]; then
                entries[current_entry-1]="subproject"
                # Check if previous entry will have any unit_starters
                # and will not have project_starters:|unit_starters
                tmp=( ${paths[current_entry-1]}/$^~unit_starters(NY1) )
                if [ "${#tmp}" != "0" ]; then
                    subtract=( "${(@)project_starters:|unit_starters}" )
                    tmp=( ${paths[current_entry-1]}/$^~subtract(NY1) )

                    if [ "${#tmp}" = "0" ]; then
                        # We have unit_starters-only project, turn it into unit
                        entries[current_entry-1]="unit"
                    fi
                fi
            fi

            current_entry+=1
        fi

        look_in="${look_in:h}"
    done

    integer count=${#entries} i
    local -a variadic
    for (( i=1; i<=count; i ++ )); do
        variadic+=( "${(q)entries[i]}" "${(q)paths[i]}" ":${(q)marks[i]}" )
    done

    # Zconvey plugin integration
    local convey_id="${(q)ZCONVEY_ID}" convey_name="${(q)ZCONVEY_NAME}"

    print -r -- "$ts $convey_id $convey_name $first $second $third ${variadic[*]}" >>! "${ZSHSIFY_CACHE_DIR}/harvested.db"

    [[ "$ZSH_STARTIFY_DEBUG" = (1|yes|true) ]] && {
        local -F 3 t=$(( SECONDS - start_time ))
        echo preexec ran ${t}s
    }
}

function @zsh-sify-register-plugin() {
    local program="$1" initial="$2" generator="$3" final="$4"

    # Ability to register multiple generators per single command
    ZSHSIFY_PLUGS_INITIAL_TEXT_GENERATORS[$program]="${ZSHSIFY_PLUGS_INITIAL_TEXT_GENERATORS[$program]} $initial"
    ZSHSIFY_PLUGS_INITIAL_TEXT_GENERATORS[$program]="${ZSHSIFY_PLUGS_INITIAL_TEXT_GENERATORS[$program]# }"
    ZSHSIFY_PLUGS_TEXT_GENERATORS[$program]="${ZSHSIFY_PLUGS_TEXT_GENERATORS[$program]} $generator"
    ZSHSIFY_PLUGS_TEXT_GENERATORS[$program]="${ZSHSIFY_PLUGS_TEXT_GENERATORS[$program]# }"
    ZSHSIFY_PLUGS_FINAL_TEXT_GENERATORS[$program]="${ZSHSIFY_PLUGS_FINAL_TEXT_GENERATORS[$program]} $final"
    ZSHSIFY_PLUGS_FINAL_TEXT_GENERATORS[$program]="${ZSHSIFY_PLUGS_FINAL_TEXT_GENERATORS[$program]# }"
}

autoload -Uz add-zsh-hook is-at-least
add-zsh-hook preexec @zsh-startify-tracking-hook

unfunction __from-zhistory-accumulate 2>/dev/null
autoload zaccu-process-buffer zsh-startify __from-zhistory-accumulate

#
# Initialize infrastructure globals
#

typeset -gA ZSHSIFY_PLUGS_INITIAL_TEXT_GENERATORS ZSHSIFY_PLUGS_TEXT_GENERATORS
typeset -gA ZSHSIFY_PLUGS_FINAL_TEXT_GENERATORS ZSHSIFY_CONFIG

ZSHSIFY_PLUGS_INITIAL_TEXT_GENERATORS=()
ZSHSIFY_PLUGS_TEXT_GENERATORS=()
ZSHSIFY_PLUGS_FINAL_TEXT_GENERATORS=()
ZSHSIFY_CONFIG=()


#
# Load standard library
#

source "$ZSHSIFY_DIR"/plugins/stdlib.laccu

#
# Load plugins
#

() {
    local p
    for p in "$ZSHSIFY_DIR"/plugins/*.accu; do
        # The sourced plugin should provide 2 functions
        # and call zaccu_register_plugin() for them
        source "$p"
    done
}

zle -N zsh-startify
bindkey '^T' zsh-startify

