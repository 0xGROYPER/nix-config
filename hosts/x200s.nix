{ config, pkgs, ... }:

{
  # X200s / NixOS specific Home Manager settings will go here.
  xsession.enable = true;

  xsession.windowManager.command = ''
    exec ${config.programs.emacs.finalPackage}/bin/emacs \
      --eval '(progn (require (quote exwm)) (exwm-wm-mode))'
    '';

  home.packages = [
    (pkgs.writeShellScriptBin "eww-browser" ''
    exec ${config.programs.emacs.finalPackage}/bin/emacsclient \
      --eval "(eww \"$1\")"
  '')
    pkgs.stdenv.cc
  ];

  home.sessionVariables = {
    BROWSER = "eww-browser";
  };

  # home.packages = [
  #   (pkgs.writeShellScriptBin "eww-browser" ''
  #   exec ${config.programs.emacs.finalPackage}/bin/emacsclient \
  #     --eval "(eww-open-file \"$1\")"
  # '')
  # ];

  # home.sessionVariables = {
  #   BROWSER = "eww-browser";
  # };


  #  xsession.windowManager.exwm = {
  #   enable = true;

  #   # Give EXWM Emacs the same packages as normal Emacs 
  #   extraPackages = config.programs.emacs.extraPackages;
  #   loadScript = ''
  #   (require 'exwm)
  #   (exwm-enable)
  #   '';
  # };
   
}
