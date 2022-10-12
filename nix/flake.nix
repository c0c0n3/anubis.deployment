{
  description = "Cluster install & dev tools.";

  inputs = {
    nixpkgs.url = "github:NixOs/nixpkgs/nixos-21.11";
    nixie = {
      url = "github:c0c0n3/nixie";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, nixie }:
    let
      buildWith = nixie.lib.flakes.mkOutputSetForCoreSystems nixpkgs;
      mkSysOutput = { system, sysPkgs }:
      let
        opa = sysPkgs.callPackage ./opa.nix {};
      in {
        defaultPackage.${system} = with sysPkgs; buildEnv {
          name = "cluster-tools-shell";
          paths = [ git kubectl kubernetes-helm kustomize opa argocd ];
        };
      };
    in
      buildWith mkSysOutput;
}
