# CLIProxyAPI (MIT), github.com/router-for-me/CLIProxyAPI: the project's
# release builds, by the SHA-256 in its checksums.txt (Linux: the build
# without plugins, which needs no system libraries). Used by ai-proxy.nix.
{
  lib,
  stdenvNoCC,
  fetchurl,
}:
let
  version = "8.0.23";
  release =
    {
      aarch64-darwin = { file = "darwin_aarch64"; sha256 = "3c056b42ec4c80d06a74d3c5abf47ae0adb06285e32f5cf31a29bdd07017feb3"; };
      x86_64-darwin = { file = "darwin_amd64"; sha256 = "bfa737b927cd7680ca78a4126c2e09edd1ed510c18605123cf15f2dbae47d896"; };
      aarch64-linux = { file = "linux_aarch64_no-plugin"; sha256 = "38e8df7a83bc5974f1599ff9c9b8a88ba920ce9f00b5291e6a7ab6d70ce96eaf"; };
      x86_64-linux = { file = "linux_amd64_no-plugin"; sha256 = "0e38f3e66c4ffb6fbe0c97f0e1db3c20bddce7111a09efb6d71dab78f4c08d3c"; };
    }
    .${stdenvNoCC.hostPlatform.system};
in
stdenvNoCC.mkDerivation {
  pname = "cliproxyapi";
  inherit version;
  src = fetchurl {
    url = "https://github.com/router-for-me/CLIProxyAPI/releases/download/v${version}/CLIProxyAPI_${version}_${release.file}.tar.gz";
    inherit (release) sha256;
  };
  sourceRoot = ".";
  installPhase = "install -Dm755 cli-proxy-api $out/bin/cliproxyapi";
  meta = {
    mainProgram = "cliproxyapi";
    license = lib.licenses.mit;
    platforms = [ "aarch64-darwin" "x86_64-darwin" "aarch64-linux" "x86_64-linux" ];
  };
}
