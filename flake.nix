{
  description = "Geonix - geospatial environment for Nix";

  nixConfig.extra-substituters = [ "https://geonix.cachix.org" ];
  nixConfig.extra-trusted-public-keys = [ "geonix.cachix.org-1:iyhIXkDLYLXbMhL3X3qOLBtRF8HEyAbhPXjjPeYsCl0=" ];

  nixConfig.bash-prompt = "\\[\\033[1m\\][geonix]\\[\\033\[m\\]\\040\\w >\\040";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-22.11";

  inputs.flake-utils.url = "github:numtide/flake-utils";

  inputs.flake-compat = {
    url = "github:edolstra/flake-compat";
    flake = false;
  };

  outputs = { self, nixpkgs, flake-utils, ... }:
    flake-utils.lib.eachSystem [ "x86_64-linux" "x86_64-darwin" ]
      (system:

        let
          # allow insecure QGIS dependency (QtWebkit)
          insecurePackages = [ "qtwebkit-5.212.0-alpha4" ];

          pkgs = import nixpkgs {
            inherit system;
            config = { permittedInsecurePackages = insecurePackages; };
          };

        in
        {

          # Each new package must be added to:
          # * flake.nix: packages
          # * flake.nix: packages.all-packages
          # * .github/workflows/update-version.yml: matrix.package

          #
          ### PACKAGES ###
          #

          packages = flake-utils.lib.filterPackages system rec {

            geonixcli = pkgs.callPackage ./pkgs/geonixcli { };

            geos = pkgs.callPackage ./pkgs/geos { };
            libspatialindex = pkgs.callPackage ./pkgs/libspatialindex { };
            proj = pkgs.callPackage ./pkgs/proj { };

            libgeotiff = pkgs.callPackage ./pkgs/libgeotiff {
              inherit proj;
            };

            librttopo = pkgs.callPackage ./pkgs/librttopo {
              inherit geos;
            };

            libspatialite = pkgs.callPackage ./pkgs/libspatialite {
              inherit geos librttopo proj;
            };

            gdal = pkgs.callPackage ./pkgs/gdal {
              inherit geos libgeotiff libspatialite proj;
            };

            pdal = pkgs.callPackage ./pkgs/pdal {
              inherit gdal libgeotiff;
            };


            # Python packages
            python-fiona = pkgs.python3.pkgs.callPackage ./pkgs/fiona {
              inherit gdal;
            };

            python-gdal = pkgs.python3.pkgs.toPythonModule (gdal.override {
              inherit geos libgeotiff libspatialite proj;
            });

            python-geopandas = pkgs.python3.pkgs.callPackage ./pkgs/geopandas {
              fiona = python-fiona;
              pyproj = python-pyproj;
              shapely = python-shapely;
            };

            python-owslib = pkgs.python3.pkgs.callPackage ./pkgs/owslib {
              pyproj = python-pyproj;
            };

            python-pyproj = pkgs.python3.pkgs.callPackage ./pkgs/pyproj {
              inherit proj;
              shapely = python-shapely;
            };

            python-rasterio = pkgs.python3.pkgs.callPackage ./pkgs/rasterio {
              inherit gdal;
              shapely = python-shapely;
            };

            python-shapely = pkgs.python3.pkgs.callPackage ./pkgs/shapely {
              inherit geos;
            };

            python-psycopg = pkgs.python3.pkgs.psycopg.override {
              shapely = python-shapely;
            };


            # PostgreSQL
            postgis = pkgs.callPackage ./pkgs/postgis/postgis.nix {
              inherit gdal geos proj;
            };


            # QGIS
            qgis =
              let
                qgis-python =
                  let
                    packageOverrides = final: prev: {
                      pyqt5 = prev.pyqt5.override { withLocation = true; };
                      owslib = python-owslib;
                      gdal = gdal;
                    };
                  in
                  pkgs.python3.override { inherit packageOverrides; self = qgis-python; };

                # geonix-grass = pkgs.grass.override {
                #   gdal = gdal;
                #   geos = geos;
                #   pdal = pdal;
                #   proj = proj;
                # };
              in
              pkgs.callPackage ./pkgs/qgis {
                qgis-unwrapped = pkgs.libsForQt5.callPackage ./pkgs/qgis/unwrapped.nix {
                  inherit geos gdal libspatialindex libspatialite pdal proj;

                  python3 = qgis-python;
                  # grass = geonix-grass;
                  withGrass = false;
                };
              };

            qgis-ltr =
              let
                qgis-python =
                  let
                    packageOverrides = final: prev: {
                      pyqt5 = prev.pyqt5.override { withLocation = true; };
                      owslib = python-owslib;
                      gdal = gdal;
                    };
                  in
                  pkgs.python3.override { inherit packageOverrides; self = qgis-python; };

                # geonix-grass = pkgs.grass.override {
                #   gdal = gdal;
                #   geos = geos;
                #   pdal = pdal;
                #   proj = proj;
                # };
              in
              pkgs.callPackage ./pkgs/qgis/ltr.nix {
                qgis-ltr-unwrapped = pkgs.libsForQt5.callPackage ./pkgs/qgis/unwrapped-ltr.nix {
                  inherit geos gdal libspatialindex libspatialite pdal proj;

                  python3 = qgis-python;
                  # grass = geonix-grass;
                  withGrass = false;
                };
              };


            # all-packages is built in CI. Add all packages here !
            all-packages = pkgs.symlinkJoin {
              name = "all-packages";
              paths = with self.packages; [
                gdal
                geonixcli
                geos
                libgeotiff
                librttopo
                libspatialindex
                libspatialite
                pdal
                postgis
                proj
                python-fiona
                python-gdal
                python-geopandas
                python-owslib
                python-psycopg
                python-pyproj
                python-rasterio
                python-shapely
              ] ++ pkgs.lib.optionals pkgs.stdenv.isLinux [ qgis qgis-ltr ];
            };


            # Container images
            image-python = pkgs.callPackage ./imgs/python {
              inherit
                python-fiona
                python-gdal
                python-geopandas
                python-owslib
                python-pyproj
                python-rasterio
                python-shapely;
            };

            image-postgres = pkgs.callPackage ./imgs/postgres {
              inherit postgis;
            };

            default = all-packages;
          };


          #
          ### APPS ##
          #

          apps = rec {

            qgis = {
              type = "app";
              program = "${self.packages.${system}.qgis}/bin/qgis";
            };

            qgis-ltr = {
              type = "app";
              program = "${self.packages.${system}.qgis-ltr}/bin/qgis";
            };

            default = qgis;

          };


          #
          ### SHELLS ###
          #

          devShells = rec {

            # CLI shell
            cli =
              let
                py = pkgs.python3;

                pythonPackage = py.withPackages (p: with self.packages.${system}; [
                  python-fiona
                  python-gdal
                  python-geopandas
                  python-owslib
                  python-pyproj
                  python-rasterio
                  python-shapely
                ]);

              in
              pkgs.mkShellNoCC {
                packages = with self.packages.${system}; [
                  gdal
                  geos
                  pdal
                  proj
                  pythonPackage
                ];
              };

            # PostgreSQL shell
            postgres =
              let
                pg = pkgs.postgresql;

                postgresPackage = pg.withPackages (p: with self.packages.${system}; [ postgis ]);

                postgresServiceDir = ".geonix/services/postgres";

                postgresInitdbArgs = [ "--locale=C" "--encoding=UTF8" ];

                postgresConf =
                  pkgs.writeText "postgresql.conf"
                    ''
                      log_connections = on
                      log_duration = on
                      log_statement = 'all'
                      log_disconnections = on
                      log_destination = 'stderr'
                    '';

                postgresPort = 15432;

                postgresServiceStart =
                  pkgs.writeShellScriptBin "service-start"
                    ''
                      set -euo pipefail

                      echo "POSTGRES_SERVICE_DIR: $POSTGRES_SERVICE_DIR"

                      export PGDATA=$POSTGRES_SERVICE_DIR/data
                      export PGUSER="postgres"
                      export PGHOST="$PGDATA"
                      export PGPORT="${toString postgresPort}"

                      if [ ! -d $PGDATA ]; then
                        pg_ctl initdb -o "${pkgs.lib.concatStringsSep " " postgresInitdbArgs} -U $PGUSER"
                        cat "${postgresConf}" >> $PGDATA/postgresql.conf

                        echo -e "\nPostgreSQL init process complete. Ready for start up.\n"
                      fi

                      exec ${postgresPackage}/bin/postgres -p $PGPORT -k $PGDATA
                    '';

                postgresServiceProcfile =
                  pkgs.writeText "service-procfile"
                    ''
                      postgres: ${postgresServiceStart}/bin/service-start
                    '';
              in
              pkgs.mkShellNoCC {
                packages = [ postgresPackage pkgs.honcho ];

                shellHook = ''
                  mkdir -p ${postgresServiceDir}
                  export POSTGRES_SERVICE_DIR="$(pwd)/${postgresServiceDir}"

                  honcho -f ${postgresServiceProcfile} start postgres
                '';
              };

            # psql shell
            psql =
              let
                postgresServiceDir = ".geonix/services/postgres";
                postgresPort = 15432;
              in
              pkgs.mkShellNoCC {

                packages = [ pkgs.postgresql pkgs.pgcli ]; # add pkgs.pgcli here if you like it

                shellHook = ''
                  export POSTGRES_SERVICE_DIR="$(pwd)/${postgresServiceDir}"

                  export PGDATA=$POSTGRES_SERVICE_DIR/data
                  export PGUSER="postgres"
                  export PGHOST="$PGDATA"
                  export PGPORT="${toString postgresPort}"
                '';
              };

            # PgAdmin shell
            pgadmin =
              let
                pgAdminServiceDir = ".geonix/services/pgadmin";

                pgAdminConf =
                  pkgs.writeText "config_local.py"
                    ''
                      import logging

                      DATA_DIR = ""
                      SERVER_MODE = False  # force desktop mode behavior

                      AZURE_CREDENTIAL_CACHE_DIR = f"{DATA_DIR}/azurecredentialcache"
                      CONSOLE_LOG_LEVEL = logging.CRITICAL
                      DEFAULT_SERVER_PORT = ${toString pgAdminPort}
                      ENABLE_PSQL = True
                      LOG_FILE = f"{DATA_DIR}/log/pgadmin.log"
                      MASTER_PASSWORD_REQUIRED = False
                      SESSION_DB_PATH = f"{DATA_DIR}/sessions"
                      SQLITE_PATH = f"{DATA_DIR}/pgadmin.db"
                      STORAGE_DIR = f"{DATA_DIR}/storage"
                    '';

                pgAdminPort = 15050;

                pgAdminServiceStart =
                  pkgs.writeShellScriptBin "service-start"
                    ''
                      set -euo pipefail

                      echo "PGADMIN_SERVICE_DIR: $PGADMIN_SERVICE_DIR"
                      mkdir -p $PGADMIN_SERVICE_DIR/config $PGADMIN_SERVICE_DIR/data

                      cat ${pgAdminConf} \
                        | sed "s|DATA_DIR.*=.*|DATA_DIR = '$PGADMIN_SERVICE_DIR/data'|" \
                        > $PGADMIN_SERVICE_DIR/config/config_local.py

                      PYTHONPATH=$PYTHONPATH:$PGADMIN_SERVICE_DIR/config
                      exec pgadmin4
                    '';

                pgAdminServiceProcfile =
                  pkgs.writeText "service-procfile"
                    ''
                      pgadmin: ${pgAdminServiceStart}/bin/service-start
                    '';
              in
              pkgs.mkShellNoCC {
                packages = [ pkgs.pgadmin4 pkgs.honcho ];

                shellHook = ''
                  mkdir -p ${pgAdminServiceDir}
                  export PGADMIN_SERVICE_DIR="$(pwd)/${pgAdminServiceDir}"

                  honcho -f ${pgAdminServiceProcfile} start pgadmin
                '';
              };

            # NIX dev shell
            dev = pkgs.mkShellNoCC {

              packages = with pkgs; [
                nix-prefetch-git
                nix-prefetch-github
                jq
              ];
            };

            default = cli;
          };

        }) // {


      #
      ### OVERLAYS ###
      #

      overlays = {

        x86_64-linux = _: _: {
          geonix = self.packages.x86_64-linux;
        };

        x86_64-darwin = _: _: {
          geonix = self.packages.x86_64-darwin;
        };

      };


      #
      ### TEMPLATES ###
      #

      templates = import ./templates.nix;

    };
}
