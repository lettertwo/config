set -l expected_major 4
set -l expected_minor 3
set -l major (string split -m1 . $version)[1]
set -l minor (string split -m2 . $version)[2]

if test $major -lt $expected_major -o \( $major -eq $expected_major -a $minor -lt $expected_minor \)
    echo "Fish version $expected_major.$expected_minor or higher is required. You have version $version." >&2
    exit 1
end
