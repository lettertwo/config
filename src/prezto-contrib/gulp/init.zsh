#
# Gulp
#

function _gulp_completion() {
  # Grap tasks
  compls=$(node -e "try { var gulp = require('gulp'); require('./gulpfile'); console.log(Object.keys(gulp.tasks).join(' ')); } catch (e) {}")
  if [ -z $compls ]; then
    compls=$(coffee -e "try gulp = require('./node_modules/gulp'); require('./gulpfile'); console.log Object.keys(gulp.tasks).join ' '")
  fi;
  # Trim whitespace.
  compls=$(echo "$compls" | sed -e 's/^ *//g' -e 's/ *$//g')
  completions=(${=compls})
  compadd -- $completions
}

compdef _gulp_completion gulp
