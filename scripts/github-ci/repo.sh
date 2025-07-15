
if [[ -z $DEVLINE ]]; then
    echo "ERROR: an environment variable DEVLINE needs to be set for repo.sh to source properly"
    echo "Allowed values are \"develop\" and \"production_v4\""
    echo "It's possible you're running a script which has fallen out of maintenance; please contact John Freeman if you wish to use it"
    return 1
fi

if [[ "$DEVLINE" != "develop" && "$DEVLINE" != "production_v4" ]]; then
    echo "ERROR: environment variable DEVLINE set to an unexpected value \"$DEVLINE\""
    return 2
fi

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"

packges_with_ci=(
    "trace"
    "artdaq-core"
    "artdaq-utilities"
    "artdaq-mfextensions"
    "artdaq"
    "artdaq-database"
    "artdaq-core-demo"
    "artdaq-daqinterface"
    "artdaq-demo"
    "artdaq-epics-plugin"
    "otsdaq"
    "otsdaq-utilities"
    "otsdaq-components"
    "otsdaq-epics"
    "otsdaq-demo"
    "otsdaq-prepmodernization"
)

packages=(
  "${packages_with_ci[@]}"
  "daq-docker"
)
