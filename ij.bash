# IJ bash environment
# $Revision: 1.4 $
# See http://mbreen.com/ij.html
# This is free software with NO WARRANTY of any kind.
# License: GNU GPL v3 - see http://www.gnu.org/licenses

# Apart from the following aliases (which can be unaliased),
# a namespace prefix of 'ij' is used in this file so that
# it should be safe to source it globally by default:
# any adjustments - for example, a redefinition of PS1 -
# can be done after the 'source ij.bash'.

alias d=ij_rd
alias h=ij_hist
alias fts=ij_fts

# Prompt as null command transparent to bash on copy/paste.
# (This is not truly transparent since it resets the
# exit status of the last executed command to 0 - so avoid copying
# the prompt where the command following it tests '$?')
PS1=": \W \!; "
# For PS2, this function tries to generate a string of spaces
# of the same visible width as PS1.
# As this is only for aesthetics, it doesn't try very hard.
# If changes to PS1 cause it to fail, it is best to change
# it to simply echo a fixed width string of, say, 3 spaces.
_ij_ps2() {
    local dirfull=$(dirs +0)
    local dirbase=$(basename $dirfull)
    local histnum=$(history 1|sed 's/ *//;s/ .*//;q')
    echo $PS1|perl -pe's/\\\[.*?\\\]//g;
        s#\\w#'$dirfull'#; s/\\W/'$dirbase'/; s/\\!/'$histnum'/;
        s/./ /g;'
}
# _ij_ps2() { echo "   "; }

# Now add colour and other non-printing characters...
XF_PROMPT_BACKGROUND="\[\e[37;44;1m\]"
# (use red for root)
((UID == 0)) && XF_PROMPT_BACKGROUND="\[\e[37;41;1m\]"
XF_RESET_BACKGROUND="\[\e[0m\]"
# (extra space after background colour border for readability)
PS1="${XF_PROMPT_BACKGROUND}${PS1}${XF_RESET_BACKGROUND} "
# \r turns the prompt into a mere background colour splash
PS2="${XF_PROMPT_BACKGROUND}\$(_ij_ps2)${XF_RESET_BACKGROUND} \r"
# Keep prompts short by putting anything else, such as the full
# path to the working directory (\w), in the window titlebar.
case $TERM in
    xterm*|rxvt|Eterm) PS1="\[\033]0;\A \h \w \007\]$PS1" ;;
esac

# HISTTIMEFORMAT assumed unset (if it is set then there is little
# we can do to cope with the fact, since (1) unsetting it will not
# change the output of previous history lines, and (2), it may
# have been changed - i.e., its current value does not allow us to
# derive a filter for previous commands.

# Annotate directory changes in history: this highlights all
# directory changes and may be especially helpful where the new
# working directory is not obvious from the command, e.g., where
# $CDPATH is used or where 'popd' or an alias effects the cd.
_ij_fixhist() {
    # First strip off the history number to retrieve the command.
    # Also strip any leading transparent prompts (null commands)
    # included with a command line copied from a terminal session.
    local cmd=$(history 1|
        perl -pe '$. > 1 or s/^ *\d*  ( *: .*?;  )*// or exit')
    local hdir=`dirs +0`  # or `pwd -P` (no symlinks) or $PWD (no ~)
    [ "$ij_hfirst" ] || ij_hfirst=$hdir
    if [ "$hdir" != "$ij_hlast" ]; then
        ij_hlast=$hdir
        if [ "$cmd" ]; then
            cmd=$(echo "$cmd"|sed "s/ *## cd [^\"']\+$//")
            local annote="  ## cd $hdir"
            let local width=20-${#cmd}+${#annote}
            printf -v cmd "%s%${width}s" "$cmd" "$annote"
        fi
    fi
    local hnum=`history 1|sed 's/ *//;s/ .*//;q'`
    # Set the history only if a prior command exists.
    [ "$cmd" ] && history -s "$cmd"
    # In certain circumstances, 'history -s' adds a new entry to
    # the history rather than modifying the most recent one.
    # Correct for this if necessary.
    local hnew=`history 1|sed 's/ *//;s/ .*//;q'`
    ((hnew==hnum)) || history -d $hnum
}
# bash executes this prior to displaying each primary (PS1) prompt
PROMPT_COMMAND=_ij_fixhist

# Embed the numbers labelling the history output in null commands
# so commands can be line- (triple-click-) copied from it.
# A leading space distinguishes history output from actual prompts.
# One optional argument: the number of commands to be listed.
ij_hist() { history $1|
    perl -pe 's/^ *(\d+)(\*?) / / && printf " : %3s%s;",$1,$2'; }

# Filter a Terminal Session copied from an xterm window by turning
# lines not beginning with a transparent prompt into line comments.
# This provides a record which can be fed back into bash to
# repeat the commands. The prompts are stripped from the commands
# unless an argument (conventionally '-p') is passed.
ij_fts() { perl -pe '$p=": .*?;";
    if (/^$p/) { '$#' || s/( *$p)*// } else { s/^/# / }'; }

# return to a directory logged in the working directory history
ij_rd() {
    local item
    unset item
    while read; do item[${#item[*]}]="cd $REPLY"; done < \
        <(ij_dirhist|head -n -1)
    if ((${#item[*]} > 0)); then
        local cmd
        cmd=$(ijmenu -1 0 -1 "${item[@]}")
        if (($? == 0)); then echo $cmd; eval $cmd; fi
    else
        echo "No directory changes logged." >&2 && false
    fi
}

# Outputs the working directory history, most recent last,
# and showing only the most recent visit to each directory
# (so each visited directory is listed only once).
ij_dirhist() {
    [ "$ij_hfirst" ] && (echo "## cd $ij_hfirst"; history)|
        sed -n "s/.*## cd \([^\"' #]\+\)$/\1/p"|
        tac|awk '!x[$0]++{print}'|tac;
}

# Restore a saved directory history for easy navigation via
# ij_rd. Use like this:
#   ij_dirhist > ~/dirlog
# ... in a new terminal session:
#   ij_restore < ~/dirlog
ij_restore() { while read; do history -s "## cd $REPLY"; done }
