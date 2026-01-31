## PLan for automation



SO i want to automate my Homelab. So this is what we have. 
The Concept  is that i have Repo with the Terraform. If there is a change, the change should be applied.
Then we have the nixos repo. there is a configuration. This workflow should only be called from a webhook. There will be a config comming. Based on the Role that is defined in this data, the role with its defined nix files should be applied on the Server with the IP. The Shh key will be in github secrtets. For connection to the server use tailscale actiin in the github action. Please change the code for this. The only thing you should touch is the nixos folder and the .github folder
