;; extends
(comment) @comment.outer

;; Handle single-line comments with space (e.g., "// comment")
((comment) @comment.inner
  (#match? @comment.inner "^// ")
  (#offset! @comment.inner 0 3 0 0))

;; Handle single-line comments without space (e.g., "//comment")
((comment) @comment.inner
  (#match? @comment.inner "^//[^ ]")
  (#offset! @comment.inner 0 2 0 0))

;; Handle block comments with extra * and space (e.g., "/** comment */")
((comment) @comment.inner
  (#match? @comment.inner "^/\\*\\*[ ]")
  (#offset! @comment.inner 0 4 0 -3))

;; Handle block comments with space (e.g., "/* comment */")
((comment) @comment.inner
  (#match? @comment.inner "^/\\*[ ]")
  (#offset! @comment.inner 0 3 0 -3))

;; Handle block comments without space (e.g., "/*comment*/")
((comment) @comment.inner
  (#match? @comment.inner "^/\\*+[^ ]")
  (#offset! @comment.inner 0 2 0 -2))
