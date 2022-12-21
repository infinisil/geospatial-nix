{ lib
, stdenv
, buildPythonPackage
, fetchFromGitHub
, fiona
, packaging
, pandas
, pyproj
, pytestCheckHook
, pythonOlder
, Rtree
, shapely
}:

buildPythonPackage rec {
  pname = "geopandas";
  version = "0.12.2";
  format = "setuptools";

  disabled = pythonOlder "3.8";

  src = fetchFromGitHub {
    owner = "geopandas";
    repo = "geopandas";
    rev = "refs/tags/v${version}";
    hash = "sha256-ntOZ2WCoMz5ZpqPeupqPC3cN8mbQmEAvJGaFblu0ibY=";
  };

  propagatedBuildInputs = [
    fiona
    packaging
    pandas
    pyproj
    shapely
  ];

  checkInputs = [
    pytestCheckHook
    Rtree
  ];

  doCheck = !stdenv.isDarwin;

  preCheck = ''
    export HOME=$(mktemp -d);
  '';

  disabledTests = [
    # Requires network access
    "test_read_file_remote_geojson_url"
    "test_read_file_remote_zipfile_url"
  ];

  pytestFlagsArray = [
    "geopandas"
  ];

  pythonImportsCheck = [
    "geopandas"
  ];

  meta = with lib; {
    description = "Python geospatial data analysis framework";
    homepage = "https://geopandas.org";
    changelog = "https://github.com/geopandas/geopandas/blob/v${version}/CHANGELOG.md";
    license = licenses.bsd3;
    maintainers = with maintainers; [ knedlsepp ];
  };
}
