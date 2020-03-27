;; org-static-site.el --- an org-mode based static site generator

;; Author: Matt Trzcinski
;; URL: https://github.com/excalamus/org-static-site
;; Version: 1.0.0
;; Package-Requires: ((emacs "25.1.1") (org "9.3.1"))

;;; Commentary:

;; =org-static-site= is designed to be simple.  There are no
;; templates[fn:2].  There are no complex rules for different folders
;; or obscure naming conventions.  Just put =.org= files in a =post/=
;; directory, run =org-static-site-publish=, and posts will be
;; converted to =.html= in a =publish/= directory[fn:1].

;; A website has a root directory which contains a =post/= and
;; =publish/= directory.  The =publish/= directory in turn contains a
;; =static/= directory.  These are all variables, so change them if
;; you want.

;; #+begin_example
;; <root>/
;;   post/
;;     <file-name-sans-extension>.org
;;     index.org
;;     about.org
;;   publish/
;;     index.html
;;     about.html
;;     <file-name-sans-extension>.html
;;     static/
;;       style.css
;;       about.jpg
;;       favicon.png
;; #+end_example

;; =org-static-site.el= only cares about =post/= and =publish/=.  A
;; post file is an =.org= file living in =post/=.  A publish file
;; lives in =publish/= and is an =.html= file which was created from a
;; post file.  =org-static-site.el= only looks for files in =post/=.
;; Only files in the =post/= directory will be converted.  You decide
;; what to do with the publishable files located in =publish/=.  Draft
;; files may therefore be kept at the root level (or wherever else
;; isn't the =post/= directory).  =org-static-site= requires an
;; =index.org= and an =about.org=.

;;; Code:

(require 'org)
(require 'seq)

(defcustom org-static-site-root-directory "~/site/"
  "Top level directory of website.")

(defcustom org-static-site-publish-directory "~/site/publish/"
  "Directory where published HTML files are stored.")

(defcustom org-static-site-post-directory "~/site/post/"
  "Directory where published HTML files are stored.")

(defcustom org-static-site-tld "."
  "Top level domain name for site.")

(defcustom org-static-site-about-pic "static/about.jpg"
  "About page picture.")

(defcustom org-static-site-about-pic-alt "Headshot"
  "About page picture alt text.")

(defcustom org-static-site-org-export-backend 'html
  "Backend to use during export.")

(defcustom org-static-site-author "Excalamus"
  "Author name.")

(defcustom org-static-site-site-name "org-static-site"
  "Website name.")

(defun org-static-site-static-head ()
"Non-changing part of the <head> element.

See `org-static-site-publish-post'."
  (concat
   "      <meta charset=\"UTF-8\">\n"
   "      <meta name=\"viewport\" content=\"width=device-width, initial-scale=1\">\n"
   "      <meta name=\"author\" content=\"" org-static-site-author "\">\n"
   "      <meta name=\"referrer\" content=\"no-referrer\">\n"
   "      <link href=\"static/style.css\" rel=\"stylesheet\" type=\"text/css\" />\n"
   "      <link rel='shortcut icon' type=\"image/png\" href=\"static/favicon.png\" />\n"))

(defun org-static-site-body-preamble ()
"First of three sections which compose the <body> of each page.
Contains things such as the <nav> element.

See `org-static-site-publish-post'."
(concat
"   <div id=\"preamble\" class=\"status\">\n"
"      <nav>\n"
"         <div class=\"flexcontainer\">\n"
"            <div class=\"smallitem\">\n"
"               <ul class=\"inline-list\">\n"
"                  <li>" org-static-site-site-name "</li>\n"
"               </ul>\n"
"            </div>\n"
"            <div class=\"bigitem\">\n"
"               <ul class=\"inline-list\">\n"
"                  <li><a href=\".\">Home</a></li>\n"
"                  <li><a href=\"about.html\">About</a></li>\n"
"               </ul>\n"
"            </div>\n"
"         </div>\n"
"      </nav>\n"
"      <hr/>\n"
"   </div>\n"))

(defun org-static-site-render-org-to-html (org-file &optional toc section-num backend)
  "Convert ORG-FILE to html.

TOC and SECTION-NUM generate table of contents and section
numbers, respectively.  BACKEND is the Org export backend to use.
See `org-export-as' for more details."
  (let* ((org-export-with-toc toc)
	 (org-export-with-section-numbers section-num)
	 (backend (or backend org-static-site-org-export-backend))
	 (converted
	  (with-temp-buffer
	    (insert-file-contents-literally org-file)
	    (org-export-as backend nil nil t nil))))
    converted))

(defun org-static-site-post-content (post-path)
  "Return POST-PATH as a rendered html string."
  (let* ((body-content (org-static-site-render-org-to-html post-path)))
    (concat
     "\n<div id=\"content\">\n"
     "<h1>" (org-static-site-get-keyword-value post-path "TITLE") "</h1>\n"
     body-content
     "<div class=\"post-date\">"
     (org-static-site-post-date post-path)
     "</div>\n"
     "</div>\n")))

(defun org-static-site-html-post-list ()
  "Return html list of post titles."
  (mapconcat
   (lambda (post-path)
     (concat
      "   <li><p class=\"post-title\"><a href=\""
      (org-static-site-relative-path post-path org-static-site-tld "\.html") "\">"
      (org-static-site-get-keyword-value post-path "TITLE")
      "</a></p></li>\n"))
   (org-static-site-post-list)
  ""))

(defun org-static-site-index-content (&optional index-path)
  "Generate index page content.

The home page (index.html) is primarily a list of available
posts.  If an Org file is provided by INDEX-PATH, it will be
rendered as html and inserted above the posts list."
  (let ((top-matter (if index-path (org-static-site-render-org-to-html index-path) "")))
	    (concat
	     "\n<div id=\"content\">\n"
	     top-matter
	     "<ul>\n"
	     (org-static-site-html-post-list)
	     "</ul>\n"
	     "</div>\n")))

(defun org-static-site-about-content (about-path &optional pic-path alt-text)
  "Generate about page content given ABOUT-PATH.

The about page is for information about the website, author, etc.
It includes a picture.  By default the picture is located in the
publish/static/ directory.  A PIC-PATH and alternate ALT-TEXT can
be passed.

See `org-static-site-publish-directory'."
  (let ((pic-path (or pic-path "static/about.jpg"))
	(alt-text (or alt-text "Headshot"))
	(about-content (org-static-site-render-org-to-html about-path)))
	    (concat
	     "\n<div id=\"content\">\n"
	    "\n<img id=\"img-float\" src=\"" pic-path "\" alt=\"" alt-text "\">\n"
	     "<h1 class=\"title\">" (org-static-site-get-keyword-value about-path "TITLE") "</h1>\n"
	     about-content
	     "</div>\n")))

(defun org-static-site-post-date (post-path &optional format)
  "Return date for POST-PATH.

FORMAT follows the syntax of `format-time-string'."
  (let ((format (or format "%F")))
    (format-time-string
     format
     (org-read-date nil t (org-static-site-get-keyword-value
			   post-path "DATE")))))

(defun org-static-site-body-postamble ()
"Last of three sections which compose the <body> of each page.
Contains things such as the copyright, web badges, and contact
information.

See `org-static-site-publish-post'."
(concat
"   <div id=\"postamble\" class=\"status\">\n"
"      <hr/>\n"
"      <p>Powered by <a href=\"https://github.com/excalamus/org-static-site\">org-static-site</a></p>\n"
"      <p>©2020 " org-static-site-site-name "</p>\n"
"    </div>\n"))

(defun org-static-site-org-time-stamp (&optional time inactive)
  "Return an Org time stamp.

TIME is specified as (HIGH LOW USEC PSEC), as returned by
`current-time' or `file-attributes'.  The `org-current-time' is
used unless non-nil.

INACTIVE means use square brackets instead of angular ones, so
that the stamp will not contribute to the agenda.

Examples:

(org-static-site-org-time-stamp nil t)
\"[2020-01-27 Mon 21:37]\"

(org-static-site-org-time-stamp nil nil)
\"<2020-01-27 Mon 21:38>\""
  (let ((time (or time (org-current-time))))
    (if inactive
	(org-format-time-string "[%F %a %H:%M]" time)
      (org-format-time-string "<%F %a %H:%M>" time))))

(defun org-static-site-new-post ()
  "Create new blog post."
  (interactive)
  (let ((title (read-string "Post title: ")))
    (find-file (read-string "Save as: "
			     (convert-standard-filename
			      (expand-file-name
			       (concat
				org-static-site-post-directory
				(format-time-string "%F" (current-time))
				"-"
				(url-encode-url (replace-regexp-in-string " " "+" (downcase title)))
				".org")))))
    (insert "#+TITLE: " title "\n"
	    "#+DATE: " (org-static-site-org-time-stamp (org-current-time) t) "\n")))

(defun org-static-site-get-keyword-value (post-path keyword)
  "Get KEYWORD value from given POST-PATH.

Keywords are the '#+' options given within an Org file.  These
are things like #+TITLE and #+DATE.  KEYWORD argument is
case-sensitive!

Examples:

(org-static-site-get-keyword-value my-file \"TITLE\")
(org-static-site-get-keyword-value my-file \"DATE\")"
(with-temp-buffer
  (insert-file-contents post-path)
	 (cdr (assoc keyword
	 ;; Returns alist of keyword elements; available elements in
	 ;; org-element-all-elements?
	  (org-element-map (org-element-parse-buffer 'element) 'keyword
		   (lambda (keyword) (cons (org-element-property :key keyword)
					   (org-element-property :value keyword))))))))

(defun org-static-site-variable-head (post-path)
  "The part of <head> which varies depending on the page."
  (concat
   "      <title>" (org-static-site-get-keyword-value post-path "TITLE") "</title>\n"))

(defun org-static-site-relative-path (path relative-to &optional extension)
  "Return PATH relative to RELATIVE-TO.

Optionally change extension to EXTENSION."
  (let ((relative-path (concat
			(file-name-as-directory relative-to)
			(file-name-nondirectory path))))
    (if extension
	(concat (file-name-sans-extension relative-path) extension)
      relative-path)))

(defun org-static-site-publish-page (page-path type)
  "Render PAGE-PATH as TYPE and publish as html file.

TYPE is a symbol indicating the type of page to render: 'index,
'post, or 'about.  Results are output to
`org-static-site-publish-directory'.

The rendered content is inserted into a generic html page
structure:

+--<head>-------------------------+
| `org-static-site-static-head'   |
| `org-static-site-variable-head' |
+--<body>-------------------------+
| `org-static-site-body-preamble' | ----->  <html>
|  rendered-content               |
| `org-static-site-body-postamble'|
+---------------------------------+

A page consists of two parts, <head> and <body>.  The <head> is
made of the `org-static-site-static-head' and
`org-static-site-variable-head'; the <body> of a
`org-static-site-body-preamble', the rendered content, and
`org-static-site-body-postamble'.

Content is rendered using one of `org-static-site-post-content',
`org-static-site-index-content', or
`org-static-site-about-content' depending on TYPE."
  (let ((outfile
	  (org-static-site-relative-path page-path org-static-site-publish-directory "\.html"))
	(body-content
	 (cond ((eq type 'post)
		(org-static-site-post-content page-path))
	       ((eq type 'index)
		(org-static-site-index-content page-path))
		((eq type 'about)
		 (org-static-site-about-content page-path
				    org-static-site-about-pic
				    org-static-site-about-pic-alt)))))
    (when body-content
      (with-temp-file outfile
	(insert (concat
		 "<!DOCTYPE html5>\n"
		 "<html lang=\"en\">\n"
		 "   <head>\n"
		 (org-static-site-static-head)
		 (org-static-site-variable-head page-path)
		 "   </head>\n"
		 "   <body>\n"
		 (org-static-site-body-preamble)
		 body-content
		 (org-static-site-body-postamble)
		 "   </body>\n"
		 "</html>")))
      ;; alert user
      (message "Wrote %s" outfile))))

(defun org-static-site-publish-post (post-path)
  "Publish POST-PATH to `org-static-site-publish-directory'.

When called interactively, prompt user for input file.  Current
buffer file name provided by default.

See `org-static-site-publish-page'."
  (interactive (list
		(read-file-name
		 "Post file: "
		 ;; requires absolute path
		 (expand-file-name org-static-site-post-directory)
		 nil
		 t
		 ;; buffer-file-name returns absolute path
		 (file-name-nondirectory (buffer-file-name)))))
    (org-static-site-publish-page
     (file-name-nondirectory post-path) 'post))

(defun org-static-site-publish-index (&optional path)
  "Publish index.html to `org-static-site-publish-directory',using Org file at PATH."
  (let ((index-path (or path (concat org-static-site-post-directory "index\.org"))))
    (org-static-site-publish-page index-path 'index)))

(defun org-static-site-publish-about (&optional path)
  "Publish about.html to `org-static-site-publish-directory', using Org file at PATH."
  (let ((about-path (or path (concat org-static-site-post-directory "about\.org"))))
    (org-static-site-publish-page about-path 'about)))

(defun org-static-site-dir-list (dir &optional match-regexp exclude)
  "Return list of files in DIR matching MATCH-REGEXP, excluding items in the list EXCLUDE."
    (mapcar (lambda (x) (concat dir x))
	    (seq-difference (directory-files dir nil match-regexp) exclude)))

(defun org-static-site-post-list ()
  "Return list of posts in `org-static-site-post-directory'."
  (let ((dir org-static-site-post-directory)
	(match "\\.org$")
	(exclude '("index.org" "about.org")))
    (org-static-site-dir-list dir match exclude)))

(defun org-static-site-publish ()
  "Publish all posts in `org-static-site-post-directory'."
  (interactive)
  (org-static-site-publish-about)
  (org-static-site-publish-index)
  ;; publish posts
  (mapc (lambda (x)
	    (funcall  #'org-static-site-publish-page x 'post))
	  (org-static-site-post-list))
  (message "Site rendered successfully."))

(provide 'org-static-site)

;;; org-static-site.el ends here
