# FIXME: search for build errors not terminating the build
# error GRASS is not configured with LAPACK
# fatal error: dwg.h: No such file or directory

{ lib
, stdenv
, fetchFromGitHub

, grass
, postgresql
, pkg-config
, python3
}:

stdenv.mkDerivation rec {
  pname = "grass-addons";
  version = "0250797";   # FIXME: use grass8 branch ?
 
  src = fetchFromGitHub {
    owner = "OSGeo";
    repo = "grass-addons";
    rev = version;
    hash = "sha256-9jOwEjVSpmuNsMmUMqalasiF+53gW1qfKLQ7ACVLuG4=";
  };

  postPatch = ''
    # Makefile:7: *** snakebite library is missing. Traceback (most recent call last):   File "/build/source/src/hadoop/hd/dependency.py", line 24, in <module>     from snakebite.client import Client, HAClient, Namenode   File "/nix/store/dkdy9vr8cx2c5hmk6b8mkbannpw81c61-python3.11-snakebite-2.11.0/lib/python3.11/site-packages/snakebite/client.py", line 1473     baseTime = min(time * (1L << retries), cap);                            ^ SyntaxError: invalid decimal literal.  Stop.
    rm -rf src/hadoop/hd
  
    # /nix/store/5548r74myxbs7zld41v23skyf5876i82-grass-8.3.2/include/grass/vect/dig_structs.h:31:10: fatal error: libpq-fe.h: No such file or directory
    rm -rf src/raster3d/r3.what

    # sh: line 1: /nix/store/5548r74myxbs7zld41v23skyf5876i82-grass-8.3.2/grass83/locale/scriptstrings/v.what.strds.timestamp_to_translate.c: No such file or directory
    rm -rf src/vector/v.what.*

    # make scripts executable, otherwise they are not processed by patchShebangs
    find src -type f -name "*.sh" -exec chmod 744 {} \;
    find src -type f -name "*.py" -exec chmod 744 {} \;

    patchShebangs src
  '';

  nativeBuildInputs = with python3.pkgs; [
    pkg-config

    grass
    postgresql  # for libpq-fe.h
    python3

    # python
    matplotlib
    numpy
    six
  ];

  propagatedBuildInputs = with python3.pkgs; [
    # required by hadoop/hd
    hdfs
    sqlalchemy
    snakebite
    thrift
  ];


  # see: https://github.com/OSGeo/grass/blob/75375c90ab6057ac9aa2dc1642a62ccc54da7624/scripts/g.extension/g.extension.py#L2046
  buildPhase = let
    gmajor = lib.versions.major grass.version;
    gminor = lib.versions.minor grass.version;

    in ''
    pushd src

    # export GRASS_ADDON_BASE=$out

    cp -a ${grass}/grass${gmajor}${gminor} grasscopy
    find grasscopy -type f -exec chmod 666 {} \;
    find grasscopy -type d -exec chmod 777 {} \;

    sed -i "s|GISDBASE:.*|GISDBASE: $(pwd)/grasscopy|" $(pwd)/grasscopy/demolocation/.grassrc${gmajor}${gminor}

    builddir=$(pwd)/build

    make \
      MODULE_TOPDIR=${grass} \
      BIN=$builddir/bin \
      HTMLDIR=$builddir/docs/html \
      RESTDIR=$builddir/docs/rest \
      MANBASEDIR=$builddir/docs/man \
      SCRIPTDIR=$builddir/scripts \
      STRINGDIR=${grass} \
      ETC=$builddir/etc \
      RUN_GISRC=$(pwd)/grasscopy/demolocation/.grassrc${gmajor}${gminor}

    popd
  '';

  # see: https://github.com/OSGeo/grass/blob/75375c90ab6057ac9aa2dc1642a62ccc54da7624/scripts/g.extension/g.extension.py#L2060
  installPhase = ''
    # builddir=$(pwd)/src/build

    # pushd $builddir

    # make \
    #   MODULE_TOPDIR=${grass} \
    #   INST_DIR=$out \
    # install

    # popd

    cp -av src/build $out
  '';

  meta = with lib; {
    description = "GRASS addons";
    homepage = "https://github.com/OSGeo/grass-addons";
    license = licenses.gpl2Plus;
    maintainers = with maintainers; teams.geospatial.members;
    platforms = platforms.all;
  };
}
