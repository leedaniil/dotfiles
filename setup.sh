#!/usr/bin/env zsh

# ---------------------------------------------------------
# Utils
# ---------------------------------------------------------
ask_for_confirmation() {
  while true; do
    read "?$(print_question "$1")" yn
    case $yn in
      [Yy]* ) return 0;;
      [Nn]* ) return 1;;
      * ) echo "Please answer yes or no.";;
    esac
  done
  unset yn
}

print_log() {
  printf "$1"
  printf "$1" |\
    sed "s/\x1B\[\([0-9]\{1,2\}\(;[0-9]\{1,2\}\)\?\)\?[mGK]//g"\
    >>"$LOGFILE"
}

execute() {
  echo "$ EVAL $1" >>"$LOGFILE"
  ( eval $1 ) >>"$LOGFILE" 2>&1
  print_result $? "${2:-$1}"
}

print_error() {
  # Print output in red
  print_log "\e[0;31m  [✖] $1 $2\e[0m\n"
}

print_info() {
  # Print output in purple
  print_log "\e[0;35m  $1\e[0m\n"
}

print_question() {
  # Print output in yellow
  print_log "\e[0;33m  [?] $1 [y/n] \e[0m"
}

print_result() {
  [ $1 -eq 0 ] \
    && print_success "$2" \
    || print_error "$2"

  [[ "$3" == "true" ]] && [ $1 -ne 0 ] \
    && exit
}

print_success() {
  # Print output in green
  print_log "\e[0;32m  [✔] $1\e[0m\n"
}

execute() {
  echo "$ EVAL $1" >>"$LOGFILE"
  ( eval $1 ) >>"$LOGFILE" 2>&1
  print_result $? "${2:-$1}"
}

mklink () {
  local sourceFile="$1"
  local targetFile="$2"
  local backupToDir="$3"

  if [ -d "$backupToDir" ]; then
    backupTo="$backupToDir/$(basename "$targetFile")"
  fi

  if [ ! -e "$targetFile" ]; then
    execute "ln -fs \"$sourceFile\" \"$targetFile\"" "$targetFile → $sourceFile"
  elif [[ "$(readlink "$targetFile")" == "$sourceFile" ]]; then
    print_success "$targetFile → $sourceFile"
  else
    if [ ! -z "$backupTo" ]; then
      mkdir -p "$backupToDir"
      execute "mv \"$targetFile\" \"$backupTo\"" "Backup'd $targetFile → $backupTo"
      execute "ln -fs \"$targetFile\" \"$sourceFile\"" "$targetFile → $sourceFile"
    elif ask_for_confirmation "'$targetFile' already exists, do you want to overwrite it?"; then
      rm -r "$targetFile"
      execute "ln -fs \"$sourceFile\" \"$targetFile\"" "$targetFile → $sourceFile"
    else
      print_error "$targetFile → $sourceFile"
    fi
  fi
}


print_info "Workdir: $PWD"


# ---------------------------------------------------------
# Logging
# ---------------------------------------------------------
LOGFILE="$PWD/setup.log"
: >"$LOGFILE"


# ---------------------------------------------------------
# Oh My Zsh install
# ---------------------------------------------------------
if [ ! -d "$HOME/.oh-my-zsh" ]; then
  if ask_for_confirmation "Install oh-my-zsh?"; then
    sh -c "$(curl -fsSL https://raw.githubusercontent.com/robbyrussell/oh-my-zsh/master/tools/install.sh); exit"

    mklink "$PWD/zsh-custom/themes/materialshell.zsh-theme" "$HOME/.oh-my-zsh/themes/materialshell.zsh-theme"
  else
    print_error "Oh My Zsh is not installed!"
    exit 1
  fi
fi


# ---------------------------------------------------------
# Brew stuff
# ---------------------------------------------------------
if ask_for_confirmation "Install pkgs (brew/cask/mas, pip3, npm, vscode)?"; then
  pushd packages
  if [ "$(uname)" = "Darwin" ]; then
    if ! type "brew" >/dev/null; then
      print_error "No homebrew found, skipping"
    else
      execute "brew tap Homebrew/bundle"
      execute "brew bundle --file=Brewfile" "Homebrew & Cask & Mac AppStore"
    fi
  fi

  execute "pip3 install -U -r requirements3.txt" "pip3"

  execute "<npm-list.txt xargs npm i -g" "npm"
  
  if command -v code >/dev/null; then
    print_info "Installing VSCode extensions, this might take a while..."
    execute "<vscode-list.txt xargs -n1 code --install-extension" "vscode"
  fi
  popd
fi


# ---------------------------------------------------------
# Actual symlink stuff
# ---------------------------------------------------------
FILES_TO_SYMLINK=(
  'shell/shell_aliases'
  'shell/shell_exports'
  'shell/shell_functions'
  'shell/zshrc'

  'git/gitattributes'
  'git/gitignore'
  'git/gitconfig'
  'git/gitconfig.local'
  'git/gitconfig.work'
)

for i in ${FILES_TO_SYMLINK[@]}; do
  sourceFile="$PWD/$i"
  targetFile="$HOME/.$(printf "%s" "$i" | sed "s/.*\/\(.*\)/\1/g")"

  mklink "$sourceFile" "$targetFile" "$BACKUP_DIR"
done

unset FILES_TO_SYMLINK


# ---------------------------------------------------------
# Install Golang stuff
# ---------------------------------------------------------
mkdir -p $GOPATH/bin $GOPATH/src $GOPATH/pkg

curl -sSfL https://raw.githubusercontent.com/golangci/golangci-lint/master/install.sh | sh -s -- -b $(go env GOPATH)/bin v1.38.0


# ---------------------------------------------------------
# Reload zsh settings
# ---------------------------------------------------------
source ~/.zshrc


print_info "Done. You can check $LOGFILE for logs."