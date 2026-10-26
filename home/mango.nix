{ config, lib, ... }:
{
  xdg.configFile."mango/config.conf".source = ./mango.conf;

  # Noctalia can update its palette without modifying the managed config.
  # Monitor rules are first-match, so the writable include precedes fallback.
  home.activation.ensureMangoRuntimeIncludes = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    $DRY_RUN_CMD mkdir -p ${config.xdg.configHome}/mango
    for file in noctalia.conf monitors.conf; do
      if [[ ! -f ${config.xdg.configHome}/mango/$file ]]; then
        $DRY_RUN_CMD touch ${config.xdg.configHome}/mango/$file
      fi
    done
  '';
}
