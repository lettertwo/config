#!/usr/bin/env fish
# Review app test suite: unit specs (plenary busted) + headless E2E scenarios.
# Run from anywhere; exits nonzero on any failure.

set -l config_dir (path resolve (status dirname)/../../..)
set -l e2e $config_dir/nvim/tests/review/e2e.lua
set -l failed 0

echo "── unit specs ──────────────────────────────────────────"
set -l spec_out (nvim --headless -c "PlenaryBustedDirectory $config_dir/nvim/lua/app/review/" 2>&1)
printf '%s\n' $spec_out | grep -aE "Testing:|Success: |Failed :|Errors :|^\s*Fail"
if string match -rq 'Failed : \D*[1-9]|Errors : \D*[1-9]' (string join ' ' $spec_out)
    set failed 1
end

for scenario in standalone degraded embedded stack trunk-ahead
    echo "── e2e: $scenario ──────────────────────────────────────"
    set -l app_env
    if test $scenario != embedded
        set app_env VIM_APP=review
    end
    if contains $scenario stack trunk-ahead
        set -a app_env REVIEW_KIND=stack
    end
    env $app_env REVIEW_E2E=$scenario timeout 90 \
        nvim --headless -c "lua dofile('$e2e')" 2>&1 | grep -aE "PASS|FAIL|E2E-RESULT"
    if test $pipestatus[1] -ne 0
        set failed 1
    end
end

if test $failed -eq 1
    echo "RESULT: FAIL"
    exit 1
end
echo "RESULT: PASS"
