;; extends
(comment) @comment.outer

;; Handle comment_content with leading whitespace or dash
((comment_content) @comment.inner
  (#match? @comment.inner "^[ -]")
  (#offset! @comment.inner 0 1 0 0))

;; Handle comment_content without leading whitespace or dash
((comment_content) @comment.inner
  (#match? @comment.inner "^[^ -]"))
