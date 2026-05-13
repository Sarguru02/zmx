# Home Manager module for zmx
# Usage:
#   imports = [ inputs.zmx.homeManagerModules.default ];
#   programs.zmx.enable = true;

{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.programs.zmx;
in
{
  options.programs.zmx = {
    enable = mkEnableOption "zmx - session persistence for terminal processes";

    package = mkOption {
      type = types.package;
      default = pkgs.zmx;
      defaultText = literalExpression "pkgs.zmx";
      description = "The zmx package to use.";
    };

    enableBashPrompt = mkEnableOption "Bash prompt integration (shows session name in PS1)";

    enableBashCompletions = mkEnableOption "Bash completions for zmx commands and session names";

    enableZshPrompt = mkEnableOption "Zsh prompt integration (shows session name in PS1)";

    enableZshCompletions = mkEnableOption "Zsh completions for zmx commands and session names";

    enableFishPrompt = mkEnableOption "Fish prompt integration (shows session name)";

    enableFishCompletions = mkEnableOption "Fish completions for zmx commands and session names";

    sessionPrefix = mkOption {
      type = types.nullOr types.str;
      default = null;
      description = "Prefix added to all zmx session names via ZMX_SESSION_PREFIX environment variable.";
    };
  };

  config = mkIf cfg.enable {
    home.packages = [ cfg.package ];

    programs.bash.initExtra = mkIf (cfg.enableBashPrompt || cfg.enableBashCompletions) (
      optionalString cfg.enableBashPrompt ''
        # zmx prompt integration
        if [[ -n $ZMX_SESSION ]]; then
          export PS1="[$ZMX_SESSION] ''${PS1}"
        fi
      ''
      + optionalString cfg.enableBashCompletions ''

        # zmx completions
        if command -v zmx &> /dev/null; then
          eval "$(zmx completions bash)"
        fi
      ''
    );

    programs.zsh.initContent = mkIf (cfg.enableZshPrompt || cfg.enableZshCompletions) (
      optionalString cfg.enableZshPrompt ''
        # zmx prompt integration
        if [[ -n $ZMX_SESSION ]]; then
          export PS1="[$ZMX_SESSION] ''${PS1}"
        fi
      ''
      + optionalString cfg.enableZshCompletions ''

        # zmx completions
        if command -v zmx &> /dev/null; then
          eval "$(zmx completions zsh)"
        fi
      ''
    );

    programs.fish.interactiveShellInit = mkIf (cfg.enableFishPrompt || cfg.enableFishCompletions) (
      optionalString cfg.enableFishPrompt ''
        # zmx prompt integration
        functions -c fish_prompt _original_fish_prompt 2>/dev/null
        function fish_prompt --description 'Write out the prompt'
          if set -q ZMX_SESSION
            echo -n "[$ZMX_SESSION] "
          end
          _original_fish_prompt
        end
      ''
      + optionalString cfg.enableFishCompletions ''

        # zmx completions
        if type -q zmx
          zmx completions fish | source
        end
      ''
    );

    home.sessionVariables = mkIf (cfg.sessionPrefix != null) {
      ZMX_SESSION_PREFIX = cfg.sessionPrefix;
    };
  };
}
