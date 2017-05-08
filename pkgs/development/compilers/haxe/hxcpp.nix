{ stdenv, fetchzip, pkgs, haxe, neko, xcodeBaseDir ? "/Applications/Xcode.app" }:

stdenv.mkDerivation rec {
  name = "hxcpp-3.4.64";

  src = let
    zipFile = stdenv.lib.replaceChars ["."] [","] name;
  in fetchzip {
    inherit name;
    url = "https://lib.haxe.org/files/3.0/${zipFile}.zip";
    sha256 = "02anhqpnakgmr30ddi5m862pj2158wcva75qbqcv308ir4gdwfa8";
  };

  outputs = [ "out" "lib" ];

  patchPhase = ''
    rm -rf bin
    sed -i -e 's/mFromFile = "@";/mFromFile = "";/' tools/hxcpp/Linker.hx
    sed -i -e 's|sgLibPath.push_back("");|&sgLibPath.push_back("'"$lib"'/");|' src/hx/Lib.cpp
  '';

  buildInputs = [ haxe neko ];

  targetOs = if stdenv.isLinux then
    "linux"
  else if stdenv.isDarwin then
    "mac"
  else
    "default";

  targetArch = "${targetOs}-m${if stdenv.is64bit then "64" else "32"}";

  buildPhase = ''
    mkdir .haxelib
    export HAXELIB_PATH=`pwd`/.haxelib
    haxelib dev hxcpp `pwd`
    pushd tools/run
      haxe compile.hxml
    popd
    pushd tools/hxcpp
      haxe compile.hxml
    popd
    pushd project
      neko build.n "ndll-$targetArch" "-DDEVELOPER_DIR=${xcodeBaseDir}/Contents/Developer"
      haxe compile-cppia.hxml -D "DEVELOPER_DIR=${xcodeBaseDir}/Contents/Developer"
    popd
  '';

  installPhase = ''
    for i in bin/*/*; do
      echo "$i"
      install -vD "$i" "$lib/$(basename "$i")"
    done
    find *.n toolchain/*.xml build-tool/BuildCommon.xml src include \
      -type f -exec install -vD -m 0644 {} "$out/lib/haxe/hxcpp/{}" \;
  '';

  meta = with stdenv.lib; {
    homepage = "https://lib.haxe.org/p/hxcpp";
    description = "Runtime support library for the Haxe C++ backend";
    license = stdenv.lib.licenses.bsd2;
    platforms = platforms.linux ++ platforms.darwin;
  };
}
