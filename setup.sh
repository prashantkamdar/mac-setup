#!/bin/zsh
# New Mac Terminal Setup Script
# Run this on a fresh macOS install to replicate terminal environment.
# Usage: chmod +x new-mac-setup.sh && ./new-mac-setup.sh

set -e

echo "\n=== 1. Install Homebrew ===\n"
if ! command -v brew &>/dev/null; then
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
  eval "$(/opt/homebrew/bin/brew shellenv zsh)"
else
  echo "Homebrew already installed."
fi

echo "\n=== 2. Install CLI tools via Homebrew ===\n"
brew install \
  atuin \
  bat \
  bottom \
  btop \
  eza \
  fd \
  fzf \
  htop \
  node \
  ollama \
  python@3.14 \
  ripgrep \
  zoxide

echo "\n=== 3. Install GUI apps via Homebrew Cask ===\n"
brew install --cask \
  alt-tab \
  cursor \
  font-jetbrains-mono-nerd-font \
  font-meslo-lg-nerd-font \
  forklift \
  iterm2 \
  postman \
  sublime-text \
  tableplus \
  visual-studio-code

echo "\n=== 3b. Install Cursor CLI ===\n"
if ! command -v cursor &>/dev/null; then
  curl https://cursor.com/install -fsS | bash
else
  echo "Cursor CLI already installed."
fi

echo "\n=== 4. Install Oh My Zsh ===\n"
if [ ! -d "$HOME/.oh-my-zsh" ]; then
  sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended
else
  echo "Oh My Zsh already installed."
fi

echo "\n=== 5. Install Powerlevel10k theme ===\n"
P10K_DIR="${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/themes/powerlevel10k"
if [ ! -d "$P10K_DIR" ]; then
  git clone --depth=1 https://github.com/romkatv/powerlevel10k.git "$P10K_DIR"
else
  echo "Powerlevel10k already installed."
fi

echo "\n=== 6. Install custom zsh plugins ===\n"
PLUGINS_DIR="${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/plugins"

if [ ! -d "$PLUGINS_DIR/zsh-autosuggestions" ]; then
  git clone https://github.com/zsh-users/zsh-autosuggestions "$PLUGINS_DIR/zsh-autosuggestions"
fi
if [ ! -d "$PLUGINS_DIR/zsh-syntax-highlighting" ]; then
  git clone https://github.com/zsh-users/zsh-syntax-highlighting "$PLUGINS_DIR/zsh-syntax-highlighting"
fi
if [ ! -d "$PLUGINS_DIR/zsh-completions" ]; then
  git clone https://github.com/zsh-users/zsh-completions "$PLUGINS_DIR/zsh-completions"
fi

echo "\n=== 7. Import iTerm2 Preferences ===\n"
SCRIPT_DIR="${0:A:h}"
ITERM2_PLIST="$SCRIPT_DIR/com.googlecode.iterm2.plist"
if [ -f "$ITERM2_PLIST" ]; then
  cp "$ITERM2_PLIST" ~/Library/Preferences/com.googlecode.iterm2.plist
  defaults read com.googlecode.iterm2 &>/dev/null
  echo "  iTerm2 preferences imported (includes Catppuccin Frappe color theme)."
  echo "  Restart iTerm2 after setup for changes to take effect."
else
  echo "  com.googlecode.iterm2.plist not found next to setup.sh — skipping."
fi

echo "\n=== 8. Install iTerm2 Shell Integration ===\n"
if [ ! -f "$HOME/.iterm2_shell_integration.zsh" ]; then
  curl -L https://iterm2.com/shell_integration/zsh -o ~/.iterm2_shell_integration.zsh
else
  echo "iTerm2 shell integration already installed."
fi

echo "\n=== 9. Write dotfiles ===\n"

cat > "$HOME/.zprofile" << 'EOF'

eval "$(/opt/homebrew/bin/brew shellenv zsh)"
EOF

cat > "$HOME/.zshrc" << 'EOF'
# Path to your Oh My Zsh installation.
export ZSH="$HOME/.oh-my-zsh"

# Powerlevel10k instant prompt (keep at top)
if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
  source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
fi

ZSH_THEME="powerlevel10k/powerlevel10k"

zstyle ':omz:update' mode auto

HIST_STAMPS="yyyy-mm-dd"

plugins=(
  git
  docker
  docker-compose
  npm
  node
  zsh-autosuggestions
  zsh-syntax-highlighting
  zsh-completions
)

source $ZSH/oh-my-zsh.sh

# --- User Configuration ---

export PATH="$HOME/.local/bin:$PATH"

# fzf
eval "$(fzf --zsh)"

# zoxide (smarter cd)
eval "$(zoxide init zsh)"

# atuin (better shell history)
eval "$(atuin init zsh)"

# List all Cursor agent chats across all workspaces
# Usage:
#   cursor-chats                  list all chats (oldest first, newest at bottom)
#   cursor-chats <keyword>        filter chats by keyword
#   cursor-chats resume <n>       show how to resume chat #n
#   cursor-chats -h               show this help
cursor-chats() {
  local arg1="${1:-}"
  local arg2="${2:-}"

  if [[ "$arg1" == "-h" || "$arg1" == "--help" ]]; then
    echo ""
    echo "  cursor-chats                  list all chats (newest at bottom)"
    echo "  cursor-chats <keyword>        filter by keyword or workspace"
    echo "  cursor-chats resume <n>       show how to resume chat #n"
    echo ""
    return
  fi

  python3 << PYEOF
import json, os, re, sys
from datetime import datetime

base     = os.path.expanduser('~/.cursor/projects')
arg1     = '${arg1}'
arg2     = '${arg2}'
is_resume = arg1 == 'resume'
filter_str = '' if is_resume else arg1

# --- build workspace path map from worker.log ---
workspace_paths = {}
for proj in os.listdir(base):
    log = os.path.join(base, proj, 'worker.log')
    if os.path.exists(log):
        with open(log) as f:
            for line in f:
                m = re.search(r'workspacePath=([^\s]+)', line)
                if m:
                    workspace_paths[proj] = m.group(1)
                    break

sessions = []
for project_dir in os.listdir(base):
    transcript_dir = os.path.join(base, project_dir, 'agent-transcripts')
    if not os.path.isdir(transcript_dir):
        continue
    for session_dir in os.listdir(transcript_dir):
        jsonl = os.path.join(transcript_dir, session_dir, session_dir + '.jsonl')
        if not os.path.exists(jsonl):
            continue
        mtime = os.path.getmtime(jsonl)
        with open(jsonl) as f:
            first_line = f.readline()
        try:
            obj = json.loads(first_line)
            msg = obj.get('message', {})
            content = msg.get('content', [])
            text = ''
            if isinstance(content, list):
                for c in content:
                    if isinstance(c, dict) and c.get('type') == 'text':
                        text = c.get('text', '')
                        break
            elif isinstance(content, str):
                text = content
            orig_text = text
            text = re.sub(r'<[^>]+>', '', text).strip()
            text = re.sub(r'^[A-Z][a-z]+,\s+\w+\s+\d+,\s+\d{4},.*?[-+]\d+\)', '', text).strip()
            uq = re.search(r'<user_query>(.*?)</user_query>', orig_text, re.DOTALL)
            if uq:
                text = uq.group(1).strip()
            else:
                text = re.sub(r'\s+', ' ', text).strip()
            lines = [l for l in text.splitlines() if l.strip()]
            if len(lines) > 5:
                text = '\n'.join(lines[:5]) + '\n...'
            else:
                text = '\n'.join(lines) if lines else text
            ws_path = workspace_paths.get(project_dir, '')
            sessions.append((mtime, project_dir, session_dir, text, ws_path))
        except:
            pass

sessions.sort()  # oldest first → newest at bottom
filtered = [s for s in sessions if not filter_str or filter_str.lower() in s[3].lower() or filter_str.lower() in s[1].lower()]

BOLD  = '\033[1m'
CYAN  = '\033[36m'
GREEN = '\033[32m'
GRAY  = '\033[90m'
RESET = '\033[0m'
SEP   = GRAY + '-' * 72 + RESET

if is_resume:
    try:
        n = int(arg2)
        if n < 1 or n > len(filtered):
            print(f'\n  No chat #{n}. Run cursor-chats to see the list.\n')
        else:
            mtime, proj, sess, text, ws_path = filtered[n - 1]
            ws = ws_path or proj
            print()
            print(f'{BOLD}To resume chat #{n}:{RESET}')
            print()
            print(f'  1. {GREEN}cd {ws}{RESET}')
            print(f'  2. {GREEN}cursor{RESET}   (or however you launch the CLI)')
            print(f'  3. Inside the session, type: {GREEN}/resume {sess}{RESET}')
            print()
    except ValueError:
        print('\n  Usage: cursor-chats resume <number>\n')
    sys.exit(0)

print()
for i, (mtime, proj, sess, text, ws_path) in enumerate(filtered, 1):
    dt        = datetime.fromtimestamp(mtime).strftime('%Y-%m-%d  %H:%M')
    workspace = ws_path or proj.replace('Users-prashant-', '').replace('Users-prashant', '~')
    print(f'{BOLD}{i:>3}.{RESET}  {CYAN}{dt}{RESET}  {BOLD}{workspace}{RESET}')
    for line in text.splitlines():
        if line.strip():
            print(f'      {line}')
    print(f'      {GRAY}{sess}{RESET}')
    if i < len(filtered):
        print(SEP)
print()
PYEOF
}

# Aliases
alias ls="eza --icons"
alias ll="eza -la --icons --git"
alias lt="eza --tree --icons --level=2"
alias cat="bat --paging=never"
alias find="fd"
alias grep="rg"
alias gtop="TERM=xterm gtop"

# iTerm2 shell integration
test -e "${HOME}/.iterm2_shell_integration.zsh" && source "${HOME}/.iterm2_shell_integration.zsh"

# Powerlevel10k config (run `p10k configure` to customize)
[[ ! -f ~/.p10k.zsh ]] || source ~/.p10k.zsh
EOF

cat > "$HOME/.p10k.zsh" << 'EOF'
# Generated by Powerlevel10k configuration wizard on 2026-06-24 at 18:47 EDT.
# Based on romkatv/powerlevel10k/config/p10k-lean.zsh, checksum 2674.
# Wizard options: nerdfont-v3 + powerline, small icons, ascii, lean, 1 line, compact,
# concise, transient_prompt, instant_prompt=verbose.
# Type `p10k configure` to generate another config.
#
# Config for Powerlevel10k with lean prompt style. Type `p10k configure` to generate
# your own config based on it.
#
# Tip: Looking for a nice color? Here's a one-liner to print colormap.
#
#   for i in {0..255}; do print -Pn "%K{$i}  %k%F{$i}${(l:3::0:)i}%f " ${${(M)$((i%6)):#3}:+$'\n'}; done

# Temporarily change options.
'builtin' 'local' '-a' 'p10k_config_opts'
[[ ! -o 'aliases'         ]] || p10k_config_opts+=('aliases')
[[ ! -o 'sh_glob'         ]] || p10k_config_opts+=('sh_glob')
[[ ! -o 'no_brace_expand' ]] || p10k_config_opts+=('no_brace_expand')
'builtin' 'setopt' 'no_aliases' 'no_sh_glob' 'brace_expand'

() {
  emulate -L zsh -o extended_glob

  # Unset all configuration options. This allows you to apply configuration changes without
  # restarting zsh. Edit ~/.p10k.zsh and type `source ~/.p10k.zsh`.
  unset -m '(POWERLEVEL9K_*|DEFAULT_USER)~POWERLEVEL9K_GITSTATUS_DIR'

  # Zsh >= 5.1 is required.
  [[ $ZSH_VERSION == (5.<1->*|<6->.*) ]] || return

  # The list of segments shown on the left. Fill it with the most important segments.
  typeset -g POWERLEVEL9K_LEFT_PROMPT_ELEMENTS=(
    # os_icon               # os identifier
    dir                     # current directory
    vcs                     # git status
    prompt_char             # prompt symbol
  )

  # The list of segments shown on the right. Fill it with less important segments.
  # Right prompt on the last prompt line (where you are typing your commands) gets
  # automatically hidden when the input line reaches it. Right prompt above the
  # last prompt line gets hidden if it would overlap with left prompt.
  typeset -g POWERLEVEL9K_RIGHT_PROMPT_ELEMENTS=(
    status                  # exit code of the last command
    command_execution_time  # duration of the last command
    background_jobs         # presence of background jobs
    direnv                  # direnv status (https://direnv.net/)
    asdf                    # asdf version manager (https://github.com/asdf-vm/asdf)
    virtualenv              # python virtual environment (https://docs.python.org/3/library/venv.html)
    anaconda                # conda environment (https://conda.io/)
    pyenv                   # python environment (https://github.com/pyenv/pyenv)
    goenv                   # go environment (https://github.com/syndbg/goenv)
    nodenv                  # node.js version from nodenv (https://github.com/nodenv/nodenv)
    nvm                     # node.js version from nvm (https://github.com/nvm-sh/nvm)
    nodeenv                 # node.js environment (https://github.com/ekalinin/nodeenv)
    # node_version          # node.js version
    # go_version            # go version (https://golang.org)
    # rust_version          # rustc version (https://www.rust-lang.org)
    # dotnet_version        # .NET version (https://dotnet.microsoft.com)
    # php_version           # php version (https://www.php.net/)
    # laravel_version       # laravel php framework version (https://laravel.com/)
    # java_version          # java version (https://www.java.com/)
    # package               # name@version from package.json (https://docs.npmjs.com/files/package.json)
    rbenv                   # ruby version from rbenv (https://github.com/rbenv/rbenv)
    rvm                     # ruby version from rvm (https://rvm.io)
    fvm                     # flutter version management (https://github.com/leoafarias/fvm)
    luaenv                  # lua version from luaenv (https://github.com/cehoffman/luaenv)
    jenv                    # java version from jenv (https://github.com/jenv/jenv)
    plenv                   # perl version from plenv (https://github.com/tokuhirom/plenv)
    perlbrew                # perl version from perlbrew (https://github.com/gugod/App-perlbrew)
    phpenv                  # php version from phpenv (https://github.com/phpenv/phpenv)
    scalaenv                # scala version from scalaenv (https://github.com/scalaenv/scalaenv)
    haskell_stack           # haskell version from stack (https://haskellstack.org/)
    kubecontext             # current kubernetes context (https://kubernetes.io/)
    terraform               # terraform workspace (https://www.terraform.io)
    # terraform_version     # terraform version (https://www.terraform.io)
    aws                     # aws profile (https://docs.aws.amazon.com/cli/latest/userguide/cli-configure-profiles.html)
    aws_eb_env              # aws elastic beanstalk environment (https://aws.amazon.com/elasticbeanstalk/)
    azure                   # azure account name (https://docs.microsoft.com/en-us/cli/azure)
    gcloud                  # google cloud cli account and project (https://cloud.google.com/)
    google_app_cred         # google application credentials (https://cloud.google.com/docs/authentication/production)
    toolbox                 # toolbox name (https://github.com/containers/toolbox)
    context                 # user@hostname
    nordvpn                 # nordvpn connection status, linux only (https://nordvpn.com/)
    ranger                  # ranger shell (https://github.com/ranger/ranger)
    yazi                    # yazi shell (https://github.com/sxyazi/yazi)
    nnn                     # nnn shell (https://github.com/jarun/nnn)
    lf                      # lf shell (https://github.com/gokcehan/lf)
    xplr                    # xplr shell (https://github.com/sayanarijit/xplr)
    vim_shell               # vim shell indicator (:sh)
    midnight_commander      # midnight commander shell (https://midnight-commander.org/)
    nix_shell               # nix shell (https://nixos.org/nixos/nix-pills/developing-with-nix-shell.html)
    chezmoi_shell           # chezmoi shell (https://www.chezmoi.io/)
    # vpn_ip                # virtual private network indicator
    # load                  # CPU load
    # disk_usage            # disk usage
    # ram                   # free RAM
    # swap                  # used swap
    todo                    # todo items (https://github.com/todotxt/todo.txt-cli)
    timewarrior             # timewarrior tracking status (https://timewarrior.net/)
    taskwarrior             # taskwarrior task count (https://taskwarrior.org/)
    per_directory_history   # Oh My Zsh per-directory-history local/global indicator
    # cpu_arch              # CPU architecture
    # time                  # current time
    # ip                    # ip address and bandwidth usage for a specified network interface
    # public_ip             # public IP address
    # proxy                 # system-wide http/https/ftp proxy
    # battery               # internal battery
    # wifi                  # wifi speed
    # example               # example user-defined segment (see prompt_example function below)
  )

  # Defines character set used by powerlevel10k. It's best to let `p10k configure` set it for you.
  typeset -g POWERLEVEL9K_MODE=ascii
  # When set to `moderate`, some icons will have an extra space after them. This is meant to avoid
  # icon overlap when using non-monospace fonts. When set to `none`, spaces are not added.
  typeset -g POWERLEVEL9K_ICON_PADDING=none

  # Basic style options that define the overall look of your prompt. You probably don't want to
  # change them.
  typeset -g POWERLEVEL9K_BACKGROUND=                            # transparent background
  typeset -g POWERLEVEL9K_{LEFT,RIGHT}_{LEFT,RIGHT}_WHITESPACE=  # no surrounding whitespace
  typeset -g POWERLEVEL9K_{LEFT,RIGHT}_SUBSEGMENT_SEPARATOR=' '  # separate segments with a space
  typeset -g POWERLEVEL9K_{LEFT,RIGHT}_SEGMENT_SEPARATOR=        # no end-of-line symbol

  # When set to true, icons appear before content on both sides of the prompt. When set
  # to false, icons go after content. If empty or not set, icons go before content in the left
  # prompt and after content in the right prompt.
  #
  # You can also override it for a specific segment:
  #
  #   POWERLEVEL9K_STATUS_ICON_BEFORE_CONTENT=false
  #
  # Or for a specific segment in specific state:
  #
  #   POWERLEVEL9K_DIR_NOT_WRITABLE_ICON_BEFORE_CONTENT=false
  typeset -g POWERLEVEL9K_ICON_BEFORE_CONTENT=true

  # Add an empty line before each prompt.
  typeset -g POWERLEVEL9K_PROMPT_ADD_NEWLINE=false

  # Connect left prompt lines with these symbols.
  typeset -g POWERLEVEL9K_MULTILINE_FIRST_PROMPT_PREFIX=
  typeset -g POWERLEVEL9K_MULTILINE_NEWLINE_PROMPT_PREFIX=
  typeset -g POWERLEVEL9K_MULTILINE_LAST_PROMPT_PREFIX=
  # Connect right prompt lines with these symbols.
  typeset -g POWERLEVEL9K_MULTILINE_FIRST_PROMPT_SUFFIX=
  typeset -g POWERLEVEL9K_MULTILINE_NEWLINE_PROMPT_SUFFIX=
  typeset -g POWERLEVEL9K_MULTILINE_LAST_PROMPT_SUFFIX=

  # The left end of left prompt.
  typeset -g POWERLEVEL9K_LEFT_PROMPT_FIRST_SEGMENT_START_SYMBOL=
  # The right end of right prompt.
  typeset -g POWERLEVEL9K_RIGHT_PROMPT_LAST_SEGMENT_END_SYMBOL=

  # Ruler, a.k.a. the horizontal line before each prompt. If you set it to true, you'll
  # probably want to set POWERLEVEL9K_PROMPT_ADD_NEWLINE=false above and
  # POWERLEVEL9K_MULTILINE_FIRST_PROMPT_GAP_CHAR=' ' below.
  typeset -g POWERLEVEL9K_SHOW_RULER=false
  typeset -g POWERLEVEL9K_RULER_CHAR='-'        # reasonable alternative: '·'
  typeset -g POWERLEVEL9K_RULER_FOREGROUND=242

  # Filler between left and right prompt on the first prompt line. You can set it to '·' or '-'
  # to make it easier to see the alignment between left and right prompt and to separate prompt
  # from command output. It serves the same purpose as ruler (see above) without increasing
  # the number of prompt lines. You'll probably want to set POWERLEVEL9K_SHOW_RULER=false
  # if using this. You might also like POWERLEVEL9K_PROMPT_ADD_NEWLINE=false for more compact
  # prompt.
  typeset -g POWERLEVEL9K_MULTILINE_FIRST_PROMPT_GAP_CHAR=' '
  if [[ $POWERLEVEL9K_MULTILINE_FIRST_PROMPT_GAP_CHAR != ' ' ]]; then
    # The color of the filler.
    typeset -g POWERLEVEL9K_MULTILINE_FIRST_PROMPT_GAP_FOREGROUND=242
    # Add a space between the end of left prompt and the filler.
    typeset -g POWERLEVEL9K_LEFT_PROMPT_LAST_SEGMENT_END_SYMBOL=' '
    # Add a space between the filler and the start of right prompt.
    typeset -g POWERLEVEL9K_RIGHT_PROMPT_FIRST_SEGMENT_START_SYMBOL=' '
    # Start filler from the edge of the screen if there are no left segments on the first line.
    typeset -g POWERLEVEL9K_EMPTY_LINE_LEFT_PROMPT_FIRST_SEGMENT_END_SYMBOL='%{%}'
    # End filler on the edge of the screen if there are no right segments on the first line.
    typeset -g POWERLEVEL9K_EMPTY_LINE_RIGHT_PROMPT_FIRST_SEGMENT_START_SYMBOL='%{%}'
  fi

  #################################[ os_icon: os identifier ]##################################
  # OS identifier color.
  typeset -g POWERLEVEL9K_OS_ICON_FOREGROUND=
  # Custom icon.
  # typeset -g POWERLEVEL9K_OS_ICON_CONTENT_EXPANSION='⭐'

  ################################[ prompt_char: prompt symbol ]################################
  # Green prompt symbol if the last command succeeded.
  typeset -g POWERLEVEL9K_PROMPT_CHAR_OK_{VIINS,VICMD,VIVIS,VIOWR}_FOREGROUND=76
  # Red prompt symbol if the last command failed.
  typeset -g POWERLEVEL9K_PROMPT_CHAR_ERROR_{VIINS,VICMD,VIVIS,VIOWR}_FOREGROUND=196
  # Default prompt symbol.
  typeset -g POWERLEVEL9K_PROMPT_CHAR_{OK,ERROR}_VIINS_CONTENT_EXPANSION='>'
  # Prompt symbol in command vi mode.
  typeset -g POWERLEVEL9K_PROMPT_CHAR_{OK,ERROR}_VICMD_CONTENT_EXPANSION='<'
  # Prompt symbol in visual vi mode.
  typeset -g POWERLEVEL9K_PROMPT_CHAR_{OK,ERROR}_VIVIS_CONTENT_EXPANSION='V'
  # Prompt symbol in overwrite vi mode.
  typeset -g POWERLEVEL9K_PROMPT_CHAR_{OK,ERROR}_VIOWR_CONTENT_EXPANSION='^'
  typeset -g POWERLEVEL9K_PROMPT_CHAR_OVERWRITE_STATE=true
  # No line terminator if prompt_char is the last segment.
  typeset -g POWERLEVEL9K_PROMPT_CHAR_LEFT_PROMPT_LAST_SEGMENT_END_SYMBOL=''
  # No line introducer if prompt_char is the first segment.
  typeset -g POWERLEVEL9K_PROMPT_CHAR_LEFT_PROMPT_FIRST_SEGMENT_START_SYMBOL=

  ##################################[ dir: current directory ]##################################
  # Default current directory color.
  typeset -g POWERLEVEL9K_DIR_FOREGROUND=31
  # If directory is too long, shorten some of its segments to the shortest possible unique
  # prefix. The shortened directory can be tab-completed to the original.
  typeset -g POWERLEVEL9K_SHORTEN_STRATEGY=truncate_to_unique
  # Replace removed segment suffixes with this symbol.
  typeset -g POWERLEVEL9K_SHORTEN_DELIMITER=
  # Color of the shortened directory segments.
  typeset -g POWERLEVEL9K_DIR_SHORTENED_FOREGROUND=103
  # Color of the anchor directory segments. Anchor segments are never shortened. The first
  # segment is always an anchor.
  typeset -g POWERLEVEL9K_DIR_ANCHOR_FOREGROUND=39
  # Display anchor directory segments in bold.
  typeset -g POWERLEVEL9K_DIR_ANCHOR_BOLD=true
  # Don't shorten directories that contain any of these files. They are anchors.
  local anchor_files=(
    .bzr
    .citc
    .git
    .hg
    .node-version
    .python-version
    .go-version
    .ruby-version
    .lua-version
    .java-version
    .perl-version
    .php-version
    .tool-versions
    .mise.toml
    .shorten_folder_marker
    .svn
    .terraform
    CVS
    Cargo.toml
    composer.json
    go.mod
    package.json
    stack.yaml
  )
  typeset -g POWERLEVEL9K_SHORTEN_FOLDER_MARKER="(${(j:|:)anchor_files})"
  typeset -g POWERLEVEL9K_DIR_TRUNCATE_BEFORE_MARKER=false
  # Don't shorten this many last directory segments. They are anchors.
  typeset -g POWERLEVEL9K_SHORTEN_DIR_LENGTH=1
  typeset -g POWERLEVEL9K_DIR_MAX_LENGTH=80
  typeset -g POWERLEVEL9K_DIR_MIN_COMMAND_COLUMNS=40
  typeset -g POWERLEVEL9K_DIR_MIN_COMMAND_COLUMNS_PCT=50
  typeset -g POWERLEVEL9K_DIR_HYPERLINK=false
  typeset -g POWERLEVEL9K_DIR_SHOW_WRITABLE=v3
  typeset -g POWERLEVEL9K_DIR_CLASSES=()

  #####################################[ vcs: git status ]######################################
  # Branch icon. Set this parameter to '\UE0A0 ' for the popular Powerline branch icon.
  typeset -g POWERLEVEL9K_VCS_BRANCH_ICON=

  # Untracked files icon. It's really a question mark, your font isn't broken.
  # Change the value of this parameter to show a different icon.
  typeset -g POWERLEVEL9K_VCS_UNTRACKED_ICON='?'

  # Formatter for Git status.
  #
  # Example output: master wip <42>42 *42 merge ~42 +42 !42 ?42.
  #
  # You can edit the function to customize how Git status looks.
  #
  # VCS_STATUS_* parameters are set by gitstatus plugin. See reference:
  # https://github.com/romkatv/gitstatus/blob/master/gitstatus.plugin.zsh.
  function my_git_formatter() {
    emulate -L zsh

    if [[ -n $P9K_CONTENT ]]; then
      # If P9K_CONTENT is not empty, use it. It's either "loading" or from vcs_info (not from
      # gitstatus plugin). VCS_STATUS_* parameters are not available in this case.
      typeset -g my_git_format=$P9K_CONTENT
      return
    fi

    if (( $1 )); then
      # Styling for up-to-date Git status.
      local       meta='%f'     # default foreground
      local      clean='%76F'   # green foreground
      local   modified='%178F'  # yellow foreground
      local  untracked='%39F'   # blue foreground
      local conflicted='%196F'  # red foreground
    else
      # Styling for incomplete and stale Git status.
      local       meta='%244F'  # grey foreground
      local      clean='%244F'  # grey foreground
      local   modified='%244F'  # grey foreground
      local  untracked='%244F'  # grey foreground
      local conflicted='%244F'  # grey foreground
    fi

    local res

    if [[ -n $VCS_STATUS_LOCAL_BRANCH ]]; then
      local branch=${(V)VCS_STATUS_LOCAL_BRANCH}
      # If local branch name is at most 32 characters long, show it in full.
      # Otherwise show the first 12 .. the last 12.
      # Tip: To always show local branch name in full without truncation, delete the next line.
      (( $#branch > 32 )) && branch[13,-13]=".."  # <-- this line
      res+="${clean}${(g::)POWERLEVEL9K_VCS_BRANCH_ICON}${branch//\%/%%}"
    fi

    if [[ -n $VCS_STATUS_TAG
          # Show tag only if not on a branch.
          # Tip: To always show tag, delete the next line.
          && -z $VCS_STATUS_LOCAL_BRANCH  # <-- this line
        ]]; then
      local tag=${(V)VCS_STATUS_TAG}
      # If tag name is at most 32 characters long, show it in full.
      # Otherwise show the first 12 .. the last 12.
      # Tip: To always show tag name in full without truncation, delete the next line.
      (( $#tag > 32 )) && tag[13,-13]=".."  # <-- this line
      res+="${meta}#${clean}${tag//\%/%%}"
    fi

    # Display the current Git commit if there is no branch and no tag.
    # Tip: To always display the current Git commit, delete the next line.
    [[ -z $VCS_STATUS_LOCAL_BRANCH && -z $VCS_STATUS_TAG ]] &&  # <-- this line
      res+="${meta}@${clean}${VCS_STATUS_COMMIT[1,8]}"

    # Show tracking branch name if it differs from local branch.
    if [[ -n ${VCS_STATUS_REMOTE_BRANCH:#$VCS_STATUS_LOCAL_BRANCH} ]]; then
      res+="${meta}:${clean}${(V)VCS_STATUS_REMOTE_BRANCH//\%/%%}"
    fi

    # Display "wip" if the latest commit's summary contains "wip" or "WIP".
    if [[ $VCS_STATUS_COMMIT_SUMMARY == (|*[^[:alnum:]])(wip|WIP)(|[^[:alnum:]]*) ]]; then
      res+=" ${modified}wip"
    fi

    if (( VCS_STATUS_COMMITS_AHEAD || VCS_STATUS_COMMITS_BEHIND )); then
      # <42 if behind the remote.
      (( VCS_STATUS_COMMITS_BEHIND )) && res+=" ${clean}<${VCS_STATUS_COMMITS_BEHIND}"
      # >42 if ahead of the remote; no leading space if also behind the remote: <42>42.
      (( VCS_STATUS_COMMITS_AHEAD && !VCS_STATUS_COMMITS_BEHIND )) && res+=" "
      (( VCS_STATUS_COMMITS_AHEAD  )) && res+="${clean}>${VCS_STATUS_COMMITS_AHEAD}"
    elif [[ -n $VCS_STATUS_REMOTE_BRANCH ]]; then
      # Tip: Uncomment the next line to display '=' if up to date with the remote.
      # res+=" ${clean}="
    fi

    # <-42 if behind the push remote.
    (( VCS_STATUS_PUSH_COMMITS_BEHIND )) && res+=" ${clean}<-${VCS_STATUS_PUSH_COMMITS_BEHIND}"
    (( VCS_STATUS_PUSH_COMMITS_AHEAD && !VCS_STATUS_PUSH_COMMITS_BEHIND )) && res+=" "
    # ->42 if ahead of the push remote; no leading space if also behind: <-42->42.
    (( VCS_STATUS_PUSH_COMMITS_AHEAD  )) && res+="${clean}->${VCS_STATUS_PUSH_COMMITS_AHEAD}"
    # *42 if have stashes.
    (( VCS_STATUS_STASHES        )) && res+=" ${clean}*${VCS_STATUS_STASHES}"
    # 'merge' if the repo is in an unusual state.
    [[ -n $VCS_STATUS_ACTION     ]] && res+=" ${conflicted}${VCS_STATUS_ACTION}"
    # ~42 if have merge conflicts.
    (( VCS_STATUS_NUM_CONFLICTED )) && res+=" ${conflicted}~${VCS_STATUS_NUM_CONFLICTED}"
    # +42 if have staged changes.
    (( VCS_STATUS_NUM_STAGED     )) && res+=" ${modified}+${VCS_STATUS_NUM_STAGED}"
    # !42 if have unstaged changes.
    (( VCS_STATUS_NUM_UNSTAGED   )) && res+=" ${modified}!${VCS_STATUS_NUM_UNSTAGED}"
    # ?42 if have untracked files. It's really a question mark, your font isn't broken.
    # See POWERLEVEL9K_VCS_UNTRACKED_ICON above if you want to use a different icon.
    # Remove the next line if you don't want to see untracked files at all.
    (( VCS_STATUS_NUM_UNTRACKED  )) && res+=" ${untracked}${(g::)POWERLEVEL9K_VCS_UNTRACKED_ICON}${VCS_STATUS_NUM_UNTRACKED}"
    # "-" if the number of unstaged files is unknown. This can happen due to
    # POWERLEVEL9K_VCS_MAX_INDEX_SIZE_DIRTY (see below) being set to a non-negative number lower
    # than the number of files in the Git index, or due to bash.showDirtyState being set to false
    # in the repository config. The number of staged and untracked files may also be unknown
    # in this case.
    (( VCS_STATUS_HAS_UNSTAGED == -1 )) && res+=" ${modified}-"

    typeset -g my_git_format=$res
  }
  functions -M my_git_formatter 2>/dev/null

  typeset -g POWERLEVEL9K_VCS_MAX_INDEX_SIZE_DIRTY=-1
  typeset -g POWERLEVEL9K_VCS_DISABLED_WORKDIR_PATTERN='~'
  typeset -g POWERLEVEL9K_VCS_DISABLE_GITSTATUS_FORMATTING=true
  typeset -g POWERLEVEL9K_VCS_CONTENT_EXPANSION='${$((my_git_formatter(1)))+${my_git_format}}'
  typeset -g POWERLEVEL9K_VCS_LOADING_CONTENT_EXPANSION='${$((my_git_formatter(0)))+${my_git_format}}'
  typeset -g POWERLEVEL9K_VCS_{STAGED,UNSTAGED,UNTRACKED,CONFLICTED,COMMITS_AHEAD,COMMITS_BEHIND}_MAX_NUM=-1
  typeset -g POWERLEVEL9K_VCS_VISUAL_IDENTIFIER_COLOR=76
  typeset -g POWERLEVEL9K_VCS_LOADING_VISUAL_IDENTIFIER_COLOR=244
  typeset -g POWERLEVEL9K_VCS_VISUAL_IDENTIFIER_EXPANSION=
  typeset -g POWERLEVEL9K_VCS_BACKENDS=(git)
  typeset -g POWERLEVEL9K_VCS_CLEAN_FOREGROUND=76
  typeset -g POWERLEVEL9K_VCS_UNTRACKED_FOREGROUND=76
  typeset -g POWERLEVEL9K_VCS_MODIFIED_FOREGROUND=178

  ##########################[ status: exit code of the last command ]###########################
  typeset -g POWERLEVEL9K_STATUS_EXTENDED_STATES=true
  typeset -g POWERLEVEL9K_STATUS_OK=false
  typeset -g POWERLEVEL9K_STATUS_OK_FOREGROUND=70
  typeset -g POWERLEVEL9K_STATUS_OK_VISUAL_IDENTIFIER_EXPANSION='ok'
  typeset -g POWERLEVEL9K_STATUS_OK_PIPE=true
  typeset -g POWERLEVEL9K_STATUS_OK_PIPE_FOREGROUND=70
  typeset -g POWERLEVEL9K_STATUS_OK_PIPE_VISUAL_IDENTIFIER_EXPANSION='ok'
  typeset -g POWERLEVEL9K_STATUS_ERROR=false
  typeset -g POWERLEVEL9K_STATUS_ERROR_FOREGROUND=160
  typeset -g POWERLEVEL9K_STATUS_ERROR_VISUAL_IDENTIFIER_EXPANSION='err'
  typeset -g POWERLEVEL9K_STATUS_ERROR_SIGNAL=true
  typeset -g POWERLEVEL9K_STATUS_ERROR_SIGNAL_FOREGROUND=160
  typeset -g POWERLEVEL9K_STATUS_VERBOSE_SIGNAME=false
  typeset -g POWERLEVEL9K_STATUS_ERROR_SIGNAL_VISUAL_IDENTIFIER_EXPANSION=
  typeset -g POWERLEVEL9K_STATUS_ERROR_PIPE=true
  typeset -g POWERLEVEL9K_STATUS_ERROR_PIPE_FOREGROUND=160
  typeset -g POWERLEVEL9K_STATUS_ERROR_PIPE_VISUAL_IDENTIFIER_EXPANSION='err'

  ###################[ command_execution_time: duration of the last command ]###################
  typeset -g POWERLEVEL9K_COMMAND_EXECUTION_TIME_THRESHOLD=3
  typeset -g POWERLEVEL9K_COMMAND_EXECUTION_TIME_PRECISION=0
  typeset -g POWERLEVEL9K_COMMAND_EXECUTION_TIME_FOREGROUND=101
  typeset -g POWERLEVEL9K_COMMAND_EXECUTION_TIME_FORMAT='d h m s'
  typeset -g POWERLEVEL9K_COMMAND_EXECUTION_TIME_VISUAL_IDENTIFIER_EXPANSION=

  #######################[ background_jobs: presence of background jobs ]#######################
  typeset -g POWERLEVEL9K_BACKGROUND_JOBS_VERBOSE=false
  typeset -g POWERLEVEL9K_BACKGROUND_JOBS_FOREGROUND=70

  #######################[ direnv: direnv status (https://direnv.net/) ]########################
  typeset -g POWERLEVEL9K_DIRENV_FOREGROUND=178

  ###############[ asdf: asdf version manager (https://github.com/asdf-vm/asdf) ]###############
  typeset -g POWERLEVEL9K_ASDF_FOREGROUND=66
  typeset -g POWERLEVEL9K_ASDF_SOURCES=(shell local global)
  typeset -g POWERLEVEL9K_ASDF_PROMPT_ALWAYS_SHOW=false
  typeset -g POWERLEVEL9K_ASDF_SHOW_SYSTEM=true
  typeset -g POWERLEVEL9K_ASDF_SHOW_ON_UPGLOB=
  typeset -g POWERLEVEL9K_ASDF_RUBY_FOREGROUND=168
  typeset -g POWERLEVEL9K_ASDF_PYTHON_FOREGROUND=37
  typeset -g POWERLEVEL9K_ASDF_GOLANG_FOREGROUND=37
  typeset -g POWERLEVEL9K_ASDF_NODEJS_FOREGROUND=70
  typeset -g POWERLEVEL9K_ASDF_RUST_FOREGROUND=37
  typeset -g POWERLEVEL9K_ASDF_DOTNET_CORE_FOREGROUND=134
  typeset -g POWERLEVEL9K_ASDF_FLUTTER_FOREGROUND=38
  typeset -g POWERLEVEL9K_ASDF_LUA_FOREGROUND=32
  typeset -g POWERLEVEL9K_ASDF_JAVA_FOREGROUND=32
  typeset -g POWERLEVEL9K_ASDF_PERL_FOREGROUND=67
  typeset -g POWERLEVEL9K_ASDF_ERLANG_FOREGROUND=125
  typeset -g POWERLEVEL9K_ASDF_ELIXIR_FOREGROUND=129
  typeset -g POWERLEVEL9K_ASDF_POSTGRES_FOREGROUND=31
  typeset -g POWERLEVEL9K_ASDF_PHP_FOREGROUND=99
  typeset -g POWERLEVEL9K_ASDF_HASKELL_FOREGROUND=172
  typeset -g POWERLEVEL9K_ASDF_JULIA_FOREGROUND=70

  ##########[ nordvpn: nordvpn connection status, linux only (https://nordvpn.com/) ]###########
  typeset -g POWERLEVEL9K_NORDVPN_FOREGROUND=39
  typeset -g POWERLEVEL9K_NORDVPN_{DISCONNECTED,CONNECTING,DISCONNECTING}_CONTENT_EXPANSION=
  typeset -g POWERLEVEL9K_NORDVPN_{DISCONNECTED,CONNECTING,DISCONNECTING}_VISUAL_IDENTIFIER_EXPANSION=

  #################[ ranger: ranger shell (https://github.com/ranger/ranger) ]##################
  typeset -g POWERLEVEL9K_RANGER_FOREGROUND=178

  ####################[ yazi: yazi shell (https://github.com/sxyazi/yazi) ]#####################
  typeset -g POWERLEVEL9K_YAZI_FOREGROUND=178

  ######################[ nnn: nnn shell (https://github.com/jarun/nnn) ]#######################
  typeset -g POWERLEVEL9K_NNN_FOREGROUND=72

  ######################[ lf: lf shell (https://github.com/gokcehan/lf) ]#######################
  typeset -g POWERLEVEL9K_LF_FOREGROUND=72

  ##################[ xplr: xplr shell (https://github.com/sayanarijit/xplr) ]##################
  typeset -g POWERLEVEL9K_XPLR_FOREGROUND=72

  ###########################[ vim_shell: vim shell indicator (:sh) ]###########################
  typeset -g POWERLEVEL9K_VIM_SHELL_FOREGROUND=34

  ######[ midnight_commander: midnight commander shell (https://midnight-commander.org/) ]######
  typeset -g POWERLEVEL9K_MIDNIGHT_COMMANDER_FOREGROUND=178

  #[ nix_shell: nix shell (https://nixos.org/nixos/nix-pills/developing-with-nix-shell.html) ]##
  typeset -g POWERLEVEL9K_NIX_SHELL_FOREGROUND=74

  ##################[ chezmoi_shell: chezmoi shell (https://www.chezmoi.io/) ]##################
  typeset -g POWERLEVEL9K_CHEZMOI_SHELL_FOREGROUND=33

  ##################################[ disk_usage: disk usage ]##################################
  typeset -g POWERLEVEL9K_DISK_USAGE_NORMAL_FOREGROUND=35
  typeset -g POWERLEVEL9K_DISK_USAGE_WARNING_FOREGROUND=220
  typeset -g POWERLEVEL9K_DISK_USAGE_CRITICAL_FOREGROUND=160
  typeset -g POWERLEVEL9K_DISK_USAGE_WARNING_LEVEL=90
  typeset -g POWERLEVEL9K_DISK_USAGE_CRITICAL_LEVEL=95
  typeset -g POWERLEVEL9K_DISK_USAGE_ONLY_WARNING=false

  ######################################[ ram: free RAM ]#######################################
  typeset -g POWERLEVEL9K_RAM_FOREGROUND=66

  #####################################[ swap: used swap ]######################################
  typeset -g POWERLEVEL9K_SWAP_FOREGROUND=96

  ######################################[ load: CPU load ]######################################
  typeset -g POWERLEVEL9K_LOAD_WHICH=5
  typeset -g POWERLEVEL9K_LOAD_NORMAL_FOREGROUND=66
  typeset -g POWERLEVEL9K_LOAD_WARNING_FOREGROUND=178
  typeset -g POWERLEVEL9K_LOAD_CRITICAL_FOREGROUND=166

  ################[ todo: todo items (https://github.com/todotxt/todo.txt-cli) ]################
  typeset -g POWERLEVEL9K_TODO_FOREGROUND=110
  typeset -g POWERLEVEL9K_TODO_HIDE_ZERO_TOTAL=true
  typeset -g POWERLEVEL9K_TODO_HIDE_ZERO_FILTERED=false

  ###########[ timewarrior: timewarrior tracking status (https://timewarrior.net/) ]############
  typeset -g POWERLEVEL9K_TIMEWARRIOR_FOREGROUND=110
  typeset -g POWERLEVEL9K_TIMEWARRIOR_CONTENT_EXPANSION='${P9K_CONTENT:0:24}${${P9K_CONTENT:24}:+..}'

  ##############[ taskwarrior: taskwarrior task count (https://taskwarrior.org/) ]##############
  typeset -g POWERLEVEL9K_TASKWARRIOR_FOREGROUND=74

  ######[ per_directory_history: Oh My Zsh per-directory-history local/global indicator ]#######
  typeset -g POWERLEVEL9K_PER_DIRECTORY_HISTORY_LOCAL_FOREGROUND=135
  typeset -g POWERLEVEL9K_PER_DIRECTORY_HISTORY_GLOBAL_FOREGROUND=130

  ################################[ cpu_arch: CPU architecture ]################################
  typeset -g POWERLEVEL9K_CPU_ARCH_FOREGROUND=172

  ##################################[ context: user@hostname ]##################################
  typeset -g POWERLEVEL9K_CONTEXT_ROOT_FOREGROUND=178
  typeset -g POWERLEVEL9K_CONTEXT_{REMOTE,REMOTE_SUDO}_FOREGROUND=180
  typeset -g POWERLEVEL9K_CONTEXT_FOREGROUND=180
  typeset -g POWERLEVEL9K_CONTEXT_ROOT_TEMPLATE='%B%n@%m'
  typeset -g POWERLEVEL9K_CONTEXT_{REMOTE,REMOTE_SUDO}_TEMPLATE='%n@%m'
  typeset -g POWERLEVEL9K_CONTEXT_TEMPLATE='%n@%m'
  typeset -g POWERLEVEL9K_CONTEXT_{DEFAULT,SUDO}_{CONTENT,VISUAL_IDENTIFIER}_EXPANSION=

  ###[ virtualenv: python virtual environment (https://docs.python.org/3/library/venv.html) ]###
  typeset -g POWERLEVEL9K_VIRTUALENV_FOREGROUND=37
  typeset -g POWERLEVEL9K_VIRTUALENV_SHOW_PYTHON_VERSION=false
  typeset -g POWERLEVEL9K_VIRTUALENV_SHOW_WITH_PYENV=false
  typeset -g POWERLEVEL9K_VIRTUALENV_{LEFT,RIGHT}_DELIMITER=

  #####################[ anaconda: conda environment (https://conda.io/) ]######################
  typeset -g POWERLEVEL9K_ANACONDA_FOREGROUND=37
  typeset -g POWERLEVEL9K_ANACONDA_CONTENT_EXPANSION='${${${${CONDA_PROMPT_MODIFIER#\(}% }%\)}:-${CONDA_PREFIX:t}}'

  ################[ pyenv: python environment (https://github.com/pyenv/pyenv) ]################
  typeset -g POWERLEVEL9K_PYENV_FOREGROUND=37
  typeset -g POWERLEVEL9K_PYENV_SOURCES=(shell local global)
  typeset -g POWERLEVEL9K_PYENV_PROMPT_ALWAYS_SHOW=false
  typeset -g POWERLEVEL9K_PYENV_SHOW_SYSTEM=true
  typeset -g POWERLEVEL9K_PYENV_CONTENT_EXPANSION='${P9K_CONTENT}${${P9K_CONTENT:#$P9K_PYENV_PYTHON_VERSION(|/*)}:+ $P9K_PYENV_PYTHON_VERSION}'

  ################[ goenv: go environment (https://github.com/syndbg/goenv) ]################
  typeset -g POWERLEVEL9K_GOENV_FOREGROUND=37
  typeset -g POWERLEVEL9K_GOENV_SOURCES=(shell local global)
  typeset -g POWERLEVEL9K_GOENV_PROMPT_ALWAYS_SHOW=false
  typeset -g POWERLEVEL9K_GOENV_SHOW_SYSTEM=true

  ##########[ nodenv: node.js version from nodenv (https://github.com/nodenv/nodenv) ]##########
  typeset -g POWERLEVEL9K_NODENV_FOREGROUND=70
  typeset -g POWERLEVEL9K_NODENV_SOURCES=(shell local global)
  typeset -g POWERLEVEL9K_NODENV_PROMPT_ALWAYS_SHOW=false
  typeset -g POWERLEVEL9K_NODENV_SHOW_SYSTEM=true

  ##############[ nvm: node.js version from nvm (https://github.com/nvm-sh/nvm) ]###############
  typeset -g POWERLEVEL9K_NVM_FOREGROUND=70
  typeset -g POWERLEVEL9K_NVM_PROMPT_ALWAYS_SHOW=false
  typeset -g POWERLEVEL9K_NVM_SHOW_SYSTEM=true

  ############[ nodeenv: node.js environment (https://github.com/ekalinin/nodeenv) ]############
  typeset -g POWERLEVEL9K_NODEENV_FOREGROUND=70
  typeset -g POWERLEVEL9K_NODEENV_SHOW_NODE_VERSION=false
  typeset -g POWERLEVEL9K_NODEENV_{LEFT,RIGHT}_DELIMITER=

  ##############################[ node_version: node.js version ]###############################
  typeset -g POWERLEVEL9K_NODE_VERSION_FOREGROUND=70
  typeset -g POWERLEVEL9K_NODE_VERSION_PROJECT_ONLY=true

  #######################[ go_version: go version (https://golang.org) ]########################
  typeset -g POWERLEVEL9K_GO_VERSION_FOREGROUND=37
  typeset -g POWERLEVEL9K_GO_VERSION_PROJECT_ONLY=true

  #################[ rust_version: rustc version (https://www.rust-lang.org) ]##################
  typeset -g POWERLEVEL9K_RUST_VERSION_FOREGROUND=37
  typeset -g POWERLEVEL9K_RUST_VERSION_PROJECT_ONLY=true

  ###############[ dotnet_version: .NET version (https://dotnet.microsoft.com) ]################
  typeset -g POWERLEVEL9K_DOTNET_VERSION_FOREGROUND=134
  typeset -g POWERLEVEL9K_DOTNET_VERSION_PROJECT_ONLY=true

  #####################[ php_version: php version (https://www.php.net/) ]######################
  typeset -g POWERLEVEL9K_PHP_VERSION_FOREGROUND=99
  typeset -g POWERLEVEL9K_PHP_VERSION_PROJECT_ONLY=true

  ##########[ laravel_version: laravel php framework version (https://laravel.com/) ]###########
  typeset -g POWERLEVEL9K_LARAVEL_VERSION_FOREGROUND=161

  ####################[ java_version: java version (https://www.java.com/) ]####################
  typeset -g POWERLEVEL9K_JAVA_VERSION_FOREGROUND=32
  typeset -g POWERLEVEL9K_JAVA_VERSION_PROJECT_ONLY=true
  typeset -g POWERLEVEL9K_JAVA_VERSION_FULL=false

  ###[ package: name@version from package.json (https://docs.npmjs.com/files/package.json) ]####
  typeset -g POWERLEVEL9K_PACKAGE_FOREGROUND=117

  #############[ rbenv: ruby version from rbenv (https://github.com/rbenv/rbenv) ]##############
  typeset -g POWERLEVEL9K_RBENV_FOREGROUND=168
  typeset -g POWERLEVEL9K_RBENV_SOURCES=(shell local global)
  typeset -g POWERLEVEL9K_RBENV_PROMPT_ALWAYS_SHOW=false
  typeset -g POWERLEVEL9K_RBENV_SHOW_SYSTEM=true

  #######################[ rvm: ruby version from rvm (https://rvm.io) ]########################
  typeset -g POWERLEVEL9K_RVM_FOREGROUND=168
  typeset -g POWERLEVEL9K_RVM_SHOW_GEMSET=false
  typeset -g POWERLEVEL9K_RVM_SHOW_PREFIX=false

  ###########[ fvm: flutter version management (https://github.com/leoafarias/fvm) ]############
  typeset -g POWERLEVEL9K_FVM_FOREGROUND=38

  ##########[ luaenv: lua version from luaenv (https://github.com/cehoffman/luaenv) ]###########
  typeset -g POWERLEVEL9K_LUAENV_FOREGROUND=32
  typeset -g POWERLEVEL9K_LUAENV_SOURCES=(shell local global)
  typeset -g POWERLEVEL9K_LUAENV_PROMPT_ALWAYS_SHOW=false
  typeset -g POWERLEVEL9K_LUAENV_SHOW_SYSTEM=true

  ###############[ jenv: java version from jenv (https://github.com/jenv/jenv) ]################
  typeset -g POWERLEVEL9K_JENV_FOREGROUND=32
  typeset -g POWERLEVEL9K_JENV_SOURCES=(shell local global)
  typeset -g POWERLEVEL9K_JENV_PROMPT_ALWAYS_SHOW=false
  typeset -g POWERLEVEL9K_JENV_SHOW_SYSTEM=true

  ###########[ plenv: perl version from plenv (https://github.com/tokuhirom/plenv) ]############
  typeset -g POWERLEVEL9K_PLENV_FOREGROUND=67
  typeset -g POWERLEVEL9K_PLENV_SOURCES=(shell local global)
  typeset -g POWERLEVEL9K_PLENV_PROMPT_ALWAYS_SHOW=false
  typeset -g POWERLEVEL9K_PLENV_SHOW_SYSTEM=true

  ###########[ perlbrew: perl version from perlbrew (https://github.com/gugod/App-perlbrew) ]############
  typeset -g POWERLEVEL9K_PERLBREW_FOREGROUND=67
  typeset -g POWERLEVEL9K_PERLBREW_PROJECT_ONLY=true
  typeset -g POWERLEVEL9K_PERLBREW_SHOW_PREFIX=false

  ############[ phpenv: php version from phpenv (https://github.com/phpenv/phpenv) ]############
  typeset -g POWERLEVEL9K_PHPENV_FOREGROUND=99
  typeset -g POWERLEVEL9K_PHPENV_SOURCES=(shell local global)
  typeset -g POWERLEVEL9K_PHPENV_PROMPT_ALWAYS_SHOW=false
  typeset -g POWERLEVEL9K_PHPENV_SHOW_SYSTEM=true

  #######[ scalaenv: scala version from scalaenv (https://github.com/scalaenv/scalaenv) ]#######
  typeset -g POWERLEVEL9K_SCALAENV_FOREGROUND=160
  typeset -g POWERLEVEL9K_SCALAENV_SOURCES=(shell local global)
  typeset -g POWERLEVEL9K_SCALAENV_PROMPT_ALWAYS_SHOW=false
  typeset -g POWERLEVEL9K_SCALAENV_SHOW_SYSTEM=true

  ##########[ haskell_stack: haskell version from stack (https://haskellstack.org/) ]###########
  typeset -g POWERLEVEL9K_HASKELL_STACK_FOREGROUND=172
  typeset -g POWERLEVEL9K_HASKELL_STACK_SOURCES=(shell local)
  typeset -g POWERLEVEL9K_HASKELL_STACK_ALWAYS_SHOW=true

  #############[ kubecontext: current kubernetes context (https://kubernetes.io/) ]#############
  typeset -g POWERLEVEL9K_KUBECONTEXT_SHOW_ON_COMMAND='kubectl|helm|kubens|kubectx|oc|istioctl|kogito|k9s|helmfile|flux|fluxctl|stern|kubeseal|skaffold|kubent|kubecolor|cmctl|sparkctl'
  typeset -g POWERLEVEL9K_KUBECONTEXT_CLASSES=(
      '*'       DEFAULT)
  typeset -g POWERLEVEL9K_KUBECONTEXT_DEFAULT_FOREGROUND=134
  typeset -g POWERLEVEL9K_KUBECONTEXT_DEFAULT_CONTENT_EXPANSION=
  POWERLEVEL9K_KUBECONTEXT_DEFAULT_CONTENT_EXPANSION+='${P9K_KUBECONTEXT_CLOUD_CLUSTER:-${P9K_KUBECONTEXT_NAME}}'
  POWERLEVEL9K_KUBECONTEXT_DEFAULT_CONTENT_EXPANSION+='${${:-/$P9K_KUBECONTEXT_NAMESPACE}:#/default}'

  ################[ terraform: terraform workspace (https://www.terraform.io) ]#################
  typeset -g POWERLEVEL9K_TERRAFORM_SHOW_DEFAULT=false
  typeset -g POWERLEVEL9K_TERRAFORM_CLASSES=(
      '*'         OTHER)
  typeset -g POWERLEVEL9K_TERRAFORM_OTHER_FOREGROUND=38

  #############[ terraform_version: terraform version (https://www.terraform.io) ]##############
  typeset -g POWERLEVEL9K_TERRAFORM_VERSION_FOREGROUND=38

  #[ aws: aws profile (https://docs.aws.amazon.com/cli/latest/userguide/cli-configure-profiles.html) ]#
  typeset -g POWERLEVEL9K_AWS_SHOW_ON_COMMAND='aws|awless|cdk|terraform|tofu|pulumi|terragrunt'
  typeset -g POWERLEVEL9K_AWS_CLASSES=(
      '*'       DEFAULT)
  typeset -g POWERLEVEL9K_AWS_DEFAULT_FOREGROUND=208
  typeset -g POWERLEVEL9K_AWS_CONTENT_EXPANSION='${P9K_AWS_PROFILE//\%/%%}${P9K_AWS_REGION:+ ${P9K_AWS_REGION//\%/%%}}'

  #[ aws_eb_env: aws elastic beanstalk environment (https://aws.amazon.com/elasticbeanstalk/) ]#
  typeset -g POWERLEVEL9K_AWS_EB_ENV_FOREGROUND=70

  ##########[ azure: azure account name (https://docs.microsoft.com/en-us/cli/azure) ]##########
  typeset -g POWERLEVEL9K_AZURE_SHOW_ON_COMMAND='az|terraform|tofu|pulumi|terragrunt'
  typeset -g POWERLEVEL9K_AZURE_CLASSES=(
      '*'         OTHER)
  typeset -g POWERLEVEL9K_AZURE_OTHER_FOREGROUND=32

  ##########[ gcloud: google cloud account and project (https://cloud.google.com/) ]###########
  typeset -g POWERLEVEL9K_GCLOUD_SHOW_ON_COMMAND='gcloud|gcs|gsutil'
  typeset -g POWERLEVEL9K_GCLOUD_FOREGROUND=32
  typeset -g POWERLEVEL9K_GCLOUD_PARTIAL_CONTENT_EXPANSION='${P9K_GCLOUD_PROJECT_ID//\%/%%}'
  typeset -g POWERLEVEL9K_GCLOUD_COMPLETE_CONTENT_EXPANSION='${P9K_GCLOUD_PROJECT_NAME//\%/%%}'
  typeset -g POWERLEVEL9K_GCLOUD_REFRESH_PROJECT_NAME_SECONDS=60

  #[ google_app_cred: google application credentials (https://cloud.google.com/docs/authentication/production) ]#
  typeset -g POWERLEVEL9K_GOOGLE_APP_CRED_SHOW_ON_COMMAND='terraform|tofu|pulumi|terragrunt'
  typeset -g POWERLEVEL9K_GOOGLE_APP_CRED_CLASSES=(
      '*'             DEFAULT)
  typeset -g POWERLEVEL9K_GOOGLE_APP_CRED_DEFAULT_FOREGROUND=32
  typeset -g POWERLEVEL9K_GOOGLE_APP_CRED_DEFAULT_CONTENT_EXPANSION='${P9K_GOOGLE_APP_CRED_PROJECT_ID//\%/%%}'

  ##############[ toolbox: toolbox name (https://github.com/containers/toolbox) ]###############
  typeset -g POWERLEVEL9K_TOOLBOX_FOREGROUND=178
  typeset -g POWERLEVEL9K_TOOLBOX_CONTENT_EXPANSION='${P9K_TOOLBOX_NAME:#fedora-toolbox-*}'

  ###############################[ public_ip: public IP address ]###############################
  typeset -g POWERLEVEL9K_PUBLIC_IP_FOREGROUND=94

  ########################[ vpn_ip: virtual private network indicator ]#########################
  typeset -g POWERLEVEL9K_VPN_IP_FOREGROUND=81
  typeset -g POWERLEVEL9K_VPN_IP_CONTENT_EXPANSION=
  typeset -g POWERLEVEL9K_VPN_IP_INTERFACE='(gpd|wg|(.*tun)|tailscale)[0-9]*|(zt.*)'
  typeset -g POWERLEVEL9K_VPN_IP_SHOW_ALL=false

  ###########[ ip: ip address and bandwidth usage for a specified network interface ]###########
  typeset -g POWERLEVEL9K_IP_FOREGROUND=38
  typeset -g POWERLEVEL9K_IP_CONTENT_EXPANSION='$P9K_IP_IP${P9K_IP_RX_RATE:+ %70F<$P9K_IP_RX_RATE}${P9K_IP_TX_RATE:+ %215F>$P9K_IP_TX_RATE}'
  typeset -g POWERLEVEL9K_IP_INTERFACE='[ew].*'

  #########################[ proxy: system-wide http/https/ftp proxy ]##########################
  typeset -g POWERLEVEL9K_PROXY_FOREGROUND=68

  ################################[ battery: internal battery ]#################################
  typeset -g POWERLEVEL9K_BATTERY_LOW_THRESHOLD=20
  typeset -g POWERLEVEL9K_BATTERY_LOW_FOREGROUND=160
  typeset -g POWERLEVEL9K_BATTERY_{CHARGING,CHARGED}_FOREGROUND=70
  typeset -g POWERLEVEL9K_BATTERY_DISCONNECTED_FOREGROUND=178
  typeset -g POWERLEVEL9K_BATTERY_STAGES=('battery')
  typeset -g POWERLEVEL9K_BATTERY_VERBOSE=false

  #####################################[ wifi: wifi speed ]#####################################
  typeset -g POWERLEVEL9K_WIFI_FOREGROUND=68

  ####################################[ time: current time ]####################################
  typeset -g POWERLEVEL9K_TIME_FOREGROUND=66
  typeset -g POWERLEVEL9K_TIME_FORMAT='%D{%H:%M:%S}'
  typeset -g POWERLEVEL9K_TIME_UPDATE_ON_COMMAND=false
  typeset -g POWERLEVEL9K_TIME_VISUAL_IDENTIFIER_EXPANSION=

  # Example of a user-defined prompt segment. Function prompt_example will be called on every
  # prompt if `example` prompt segment is added to POWERLEVEL9K_LEFT_PROMPT_ELEMENTS or
  # POWERLEVEL9K_RIGHT_PROMPT_ELEMENTS. It displays an icon and orange text greeting the user.
  #
  # Type `p10k help segment` for documentation and a more sophisticated example.
  function prompt_example() {
    p10k segment -f 208 -i '*' -t 'hello, %n'
  }

  function instant_prompt_example() {
    prompt_example
  }

  typeset -g POWERLEVEL9K_TRANSIENT_PROMPT=always
  typeset -g POWERLEVEL9K_INSTANT_PROMPT=verbose
  typeset -g POWERLEVEL9K_DISABLE_HOT_RELOAD=true

  # If p10k is already loaded, reload configuration.
  # This works even with POWERLEVEL9K_DISABLE_HOT_RELOAD=true.
  (( ! $+functions[p10k] )) || p10k reload
}

# Tell `p10k configure` which file it should overwrite.
typeset -g POWERLEVEL9K_CONFIG_FILE=${${(%):-%x}:a}

(( ${#p10k_config_opts} )) && setopt ${p10k_config_opts[@]}
'builtin' 'unset' 'p10k_config_opts'
EOF

echo "  Dotfiles written: ~/.zprofile, ~/.zshrc, ~/.p10k.zsh"

echo "\n=== Done! ===\n"
echo "If iTerm2 preferences were imported, restart iTerm2 to apply them."
echo "Open a new terminal tab to see your full setup."
echo "If the prompt looks off, run: p10k configure"
