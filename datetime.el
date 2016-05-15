;;; datetime.el --- Datetime functions

;; Copyright (C) 2016 USAMI Kenta

;; Author: USAMI Kenta <tadsan@zonu.me>
;; Created: 16 May 2016
;; Version: 0.0.1
;; Package-Requires: ()
;; Keywords: datetime calendar
;; Homepage: https://github.com/zonuexe/emacs-datetime

;; This file is NOT part of GNU Emacs.

;; This program is free software; you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation; either version 3, or (at your option)
;; any later version.
;;
;; This program is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.
;;
;; You should have received a copy of the GNU General Public License
;; along with GNU Emacs; see the file COPYING.  If not, write to the
;; Free Software Foundation, Inc., 51 Franklin Street, Fifth Floor,
;; Boston, MA 02110-1301, USA.

;;; Commentary:

;; (datetime 'atom) ;=> "2015-01-12 02:01:11+09:00"
;; (datetime 'atom (current-time))  ;=> "2015-01-12 02:01:11+09:00"
;; (datetime 'atom 0) ;=> "1970-01-01 09:01:00+09:00"
;; (datetime 'atom 0 :timezone "UTC") ;=> "1970-01-01 00:01:00+00:00"
;; (datetime 'atom "2015-01-12 02:01:11") ;=> "2015-01-12 02:01:11+09:00"
;; (datetime 'atom "2015-01-12 02:01:11" :timezone "Asia/Shanghai") ;=> "2015-01-12 01:01:11+08:00"
;; (datetime 'atom-utc "2015-01-12 02:01:11") ;=> "2015-01-11 17:01:11Z"
;; (datetime 'atom nil :timezone "JST")

;;; Code:
;;(require 'timezone)

(defconst datetime-fmt-atom
  '(local . "%Y-%m-%d %H:%m:%S%:z")
  "ATOM date construct format (local time).

RFC4287: The Atom Syndication Format \"3.3.  Date Constructs\"
https://www.ietf.org/rfc/rfc4287")

(defconst datetime-fmt-atom-utc
  '(utc . "%Y-%m-%d %H:%m:%SZ")
  "ATOM date construct format (UTC).

RFC4287: The Atom Syndication Format \"3.3.  Date Constructs\"
https://www.ietf.org/rfc/rfc4287")

(defconst datetime-fmt-cookie
  '(local . "%A, %d-%b-%Y %H:%m:%S %Z")
  "Cookie date format.

RFC6265: HTTP State Management Mechanism \"5.1.1.  Dates\"
https://tools.ietf.org/html/rfc6265#section-5.1.1")

(defconst datetime-fmt-rfc-822
  '(local . "%a, %d %b %y %H:%m:%S %z")
  "RFC 822 date-time format.

RFC822: Standard for ARPA Internet Text Messages
\"5. Date and Time Specification\"
https://www.w3.org/Protocols/rfc822/#z28")

(defconst datetime-fmt-rfc-850
  '(local . "%A, %d-%b-%y %H:%m:%S %Z")
  "RFC 850 \"Date\" line format.

RFC850: Standard for Interchange of USENET Messages \"2.1.4  Date\"
https://www.ietf.org/rfc/rfc0850")

(defconst datetime-fmt-rfc-1036
  '(local . "%a, %d %b %y %H:%m:%S %z")
  "RFC 1036 \"Date\" line format.

RFC1036 Standard for Interchange of USENET Messages \"2.1.2.  Date\"
https://www.ietf.org/rfc/rfc1036")

(defconst datetime-fmt-rfc-1123
  '(local . "%A, %d %b %y %H:%m:%S %z")
  "RFC 1123 Date and Time format.

RFC1123: Requirements for Internet Hosts -- Application and Support
\"5.2.14  RFC-822 Date and Time Specification\"
https://www.ietf.org/rfc/rfc1123")

(defconst datetime-fmt-rfc-2822
  '(local . "%A, %d %b %y %H:%m:%S %z")
  "RFC 2822 Date and Time format.

RFC2822: Internet Message Format \"3.3. Date and Time Specification\"
https://www.ietf.org/rfc/rfc2822.txt")

(defconst datetime-fmt-rfc-3339
  '(local . "%Y-%m-%d %H:%m:%S%:z")
  "RFC 3339 Timestamp format.

RFC3339: Date and Time on the Internet: Timestamps
https://www.ietf.org/rfc/rfc3339.txt")

(defconst datetime-fmt-rss
  '(local . "%A, %d %b %y %H:%m:%S %z")
  "RSS pubDate element format.

Really Simple Syndication 2.0
https://validator.w3.org/feed/docs/rss2.html")

(defconst datetime-fmt-w3c
  '(local . "%Y-%m-%d %H:%m:%S%:z")
  "W3C `Complete date plus hours, minutes and seconds' format.

W3C Date and Time Formats
https://www.w3.org/TR/NOTE-datetime")


;;;###autoload
(defun datetime (sym-or-fmt &optional time &rest option)
  "Use `SYM-OR-FMT' to format the time `TIME' and `OPTION' plist.

`OPTION' plist expect `:timezone'.
See https://en.wikipedia.org/wiki/List_of_tz_database_time_zones"
  (let ((timezone (plist-get option :timezone))
        is-utc format name)
    (cond
     ((integerp time) (setq time (datetime--int-to-timestamp time)))
     ((stringp time)  (setq time (datetime--parse-time-with-timezone time timezone))))
    (cond
     ((stringp sym-or-fmt)
      (setq format sym-or-fmt)
      (setq is-utc (equal "UTC" timezone)))
     ((symbolp sym-or-fmt)
      (setq name (intern (concat "datetime-fmt-" (symbol-name sym-or-fmt))))
      (unless (boundp name)
        (error (format "`%s' is invalid time format name."
                       (symbol-name sym-or-fmt))))
      (when (eq 'utc (car (eval name)))
        (setq is-utc t)
        (setq timezone nil))
      (setq format (cdr (eval name))))
     (:else (error "Wrong type argument")))
    (if (or is-utc (null timezone))
        (format-time-string format time is-utc)
      (datetime--format-time-with-timezone format time timezone))))

(defun datetime--int-to-timestamp (int)
  "Convert `INT' to time stamp list.

See describe `(current-time)' function."
  (let* ((low (- (lsh 1 16) 1)) (high (lsh low 16)))
    (list (lsh (logand high int) -16) (logand low int) 0 0)))

(defun datetime--format-time-with-timezone (fmt time timezone)
  "Use `FMT' to format the time `TIME' in `TIMEZONE'.

TIME is specified as (HIGH LOW USEC PSEC), as returned by
`current-time' or `file-attributes'."
  (let (real-time-zone (getenv "TZ"))
    (unwind-protect
        (progn
          (setenv "TZ" timezone)
          (format-time-string fmt time))
      (setenv "TZ" real-time-zone))))

(defun datetime--parse-time-with-timezone (time timezone)
  ""
  (let (real-time-zone (getenv "TZ"))
    (unwind-protect
        (progn
          (setenv "TZ" timezone)
          (apply #'encode-time (parse-time-string time)))
      (setenv "TZ" real-time-zone))))

(provide 'datetime)
;;; datetime.el ends here