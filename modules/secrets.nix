{ username, ... }:
{
  sops = {
    defaultSopsFile = ../secrets/claude-code.yaml;
    age.sshKeyPaths = [ "/etc/ssh/ssh_host_ed25519_key" ];

    secrets.claude-code-auth-token = {
      owner = username;
      mode = "0400";
    };
  };
}
