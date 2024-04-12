[![Build packages](https://github.com/imincik/geospatial-nix/actions/workflows/build-packages.yml/badge.svg)](https://github.com/imincik/geospatial-nix/actions/workflows/build-packages.yml)

# Geospatial packages repository and environment

**Geospatial NIX** provides weekly updated geospatial packages and tools built
on top of the latest stable Nixpkgs branch for creating isolated and reproducible
geospatial environments.

Check out the user interface at
[https://geospatial-nix.today/](https://geospatial-nix.today/) .


## Quick start

### Installation

* Install Nix
  [(learn more about this installer)](https://zero-to-nix.com/start/install)
```bash
curl --proto '=https' --tlsv1.2 -sSf \
    -L https://install.determinate.systems/nix \
    | sh -s -- install
  ```

### Show this repository content

* Show Geospatial NIX content
```bash
nix flake show github:imincik/geospatial-nix
```

### Run shell environments

* Launch shell environment containing Python (with fiona) and GDAL
```bash
nix develop github:imincik/geospatial-nix#cli
```

### Run applications without installation

* Launch the latest stable QGIS version
```bash
nix run github:imincik/geospatial-nix#qgis
```

* Launch QGIS LTR version
```bash
nix run github:imincik/geospatial-nix#qgis-ltr
```
