#!/bin/bash
# fzf-kill macOS Port
# Based on: https://github.com/Zeioth/fzf-kill.git

# PARAMETERS THAT CAN BE OVERRIDED BY THE USER (DEFAULTS)
DETAILED_MODE="false"
LOOP_MODE="false"
EXCLUDE_LIST='myprogramtoexcludehere'
# Export to ensure fzf subshell sees the prompt
export FZF_DEFAULT_OPTS="--min-height=100 --prompt 'kill -9 '"
SHOW_ROOT="false"
SHOW_HELP="false"

# macOS portable User ID detection (macOS doesn't always set $UID)
CURRENT_UID=$(id -u)


# PARSE PARAMETERS
# ========================================================
# Loop through all command line arguments
for arg in "$@"; do
  # Check if the argument contains the "all" string
  if echo "$arg" | grep -q "all"; then
    DETAILED_MODE="true"
  fi

  # Check if the argument contains the "loop" string
  if echo "$arg" | grep -q "loop"; then
    LOOP_MODE="true"
  fi

  # Check if the argument contains the "exclude=" string
  if echo "$arg" | grep -q "exclude="; then
    # Use cut to extract everything after the "=" symbol
    EXCLUDE_LIST=$(echo "$arg" | cut -d= -f2-)
  fi

  # Check if the argument contains the "fzf_default_ops=" string
  if echo "$arg" | grep -q "fzf_default_ops="; then
    # Use cut to extract everything after the "=" symbol
    export FZF_DEFAULT_OPTS=$(echo "$arg" | cut -d= -f2-)
  fi

  # Check if the argument contains the "showroot" string
  if echo "$arg" | grep -q "showroot"; then
    # Pretend we are root during this program
    SHOW_ROOT="true"
  fi

  # Check if the argument contains the "help" string
  if echo "$arg" | grep -q "help"; then
    # Use cut to extract everything after the "=" symbol
    SHOW_HELP="true"
  fi

done


# FUNCTIONS
# ========================================================

# CONSTANTS
# macOS ps -ef column 2 is PID, column 8 is CMD
EXTRACT_COLS_2_AND_8='{print $2, $8}'


detailed_mode(){
  # Advanced mode (show subprocesses, if one is selected, parent is killed)
  if [[ "$CURRENT_UID" != "0" && "$SHOW_ROOT" == "false" ]]; then
    pid=$(ps -u "$CURRENT_UID" -ef | \
      # Eliminate headers and started by this command.
      # macOS: BSD head doesn't support negative lines. We use sed to trim the last 6.
      sed 1d | sed -n -e :a -e '1,6!P;N;D;ba' | \
      # Exclude specific words from the output
      grep -vE "($EXCLUDE_LIST|fzf-kill)" | \
      # pipe to fzf
      fzf -m | \
      # Store the user selection on the pid variable
      # macOS ps -ef PID is column 2
      awk '{print $2}')
  else
    pid=$(ps -ef | \
      # Eliminate headers
      sed 1d | \
      # Exclude specific words from the output
      grep -vE "($EXCLUDE_LIST|fzf-kill)" | \
      # pipe to fzf
      fzf -m | \
      # Store the user selection on the pid variable
      awk '{print $2}')
  fi

  if [[ "x$pid" != "x" ]]; then
    # Kill the process, no mater if child or parent is selected.
    # macOS: Manual loop ensures stability as BSD ps -o ppid requires a valid PID.
    for p in $pid; do
      ppid=$(ps -p "$p" -o ppid= | tr -d ' ')
      [[ -n "$ppid" ]] && kill "-${1:-9}" "$ppid" > /dev/null 2>&1
      kill -9 "$p" > /dev/null 2>&1
    done
  fi
}

simple_mode(){
  # Simple mode (We only list parent processes)
  # (Slower but more visually appealing).
  if [[ "$CURRENT_UID" != "0" && "$SHOW_ROOT" == "false" ]]; then
    # Extract running processes
    pid=$(ps -u "$CURRENT_UID" -ef | \
      # Extract cols 2 and 8
      awk "$EXTRACT_COLS_2_AND_8" | \
      # Eliminate headers and started by this command.
      sed 1d  | \
      # Exclude specific words from the output
      grep -vE "($EXCLUDE_LIST|fzf-kill)" | \
      # De-duplicate entries
      awk '{if($2 in seen){}else{seen[$2]=$0; print}}' | \
      # Get parent process
      # macOS: BSD ps fails on comma-lists if a PID is missing. xargs -n 1 handles them safely.
      # macOS: BSD requires separate -o flags for each column.
      awk '{print $1}' | xargs -n 1 -I {} ps -p {} -o pid= -o comm= 2>/dev/null | \
      # pipe to fzf
      fzf -m | \
      # Store the user selection on the pid variable
      awk '{print $1}')
  else
    pid=$(ps -ef | \
      # Extract cols 2 and 8
      awk "$EXTRACT_COLS_2_AND_8" | \
      # Eliminate headers and started by this command.
      sed 1d | \
      # Exclude specific words from the output
      grep -vE "($EXCLUDE_LIST|fzf-kill)" | \
      # De-duplicate entries
      awk '{if($2 in seen){}else{seen[$2]=$0; print}}' | \
      # Get parent process
      awk '{print $1}' | xargs -n 1 -I {} ps -p {} -o pid= -o comm= 2>/dev/null | \
      # pipe to fzf
      fzf -m | \
      # Store the user selection on the pid variable
      awk '{print $1}')
  fi

  if [[ "x$pid" != "x" ]]; then
    # Kill the parent process
    kill -9 $pid 2>&1
  fi
}

show_help(){
echo "HELP:
 fzf-kill allow you to kill your programs in a quick and intuitive way
 without the cluttered user experience,
 or the uncomfortable keybindings of other task killers.


 # BASIC COMMANDS
 * --parents           Show only parent processes. (default)
 * --all               Show both parent and children processes.


 # ADVANCED OPTIONS
 * --exclude           You can exclude a list of programs from appearing on the list.

                       Use it like:
                       fzf-kill --exclude='word1|word2|word2'

                       You can also pipe it from a file like:
                       fzf-kill --exclude=\"\$(cat ~/.config/fzf-kill/my_excludes.txt)\"

 * --loop              fzf-kill will stay open even after killing a program.


 * --fzf_default_ops   You can  use it to override the env var FZF_DEFAULT_OPTS.

                       Use it like:
                       fzf-kill --fzf_default_ops=\"--min-height=100 --prompt 'kill -9 '\"

 * --showroot          List both root and user processes running in the session.
                       By default is disabled. Meaning by default we show only
                       processes owned by the user.

                       Please note that this option won't let you kill anything
                       launched by root unless you are root, or run fzf-kill with
                       sudo privileges (which by general rule, you shouldn't).
 "
}


# ENTRY POINT
# ========================================================

# Do while
do_program="true"
while [ "$do_program" = "true" ] ; do

    # Help
    if [ "$SHOW_HELP" = "true" ]; then
      show_help
      break
    fi

    # Code
    if [ "$DETAILED_MODE" = "true" ]; then
      detailed_mode
    else
      simple_mode
    fi

    # Exit condition
    if [ "$LOOP_MODE" = "false" ]; then
      do_program="false"
    fi

done

