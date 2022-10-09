#lang racket/base

(require
  (only-in net/http-client
           http-sendrecv
           http-conn-sendrecv!
           http-conn-open
           http-conn-close!)
  (only-in json
           jsexpr->string
           string->jsexpr)
  (only-in racket/string
           string-join
           string-trim)
  (only-in racket/port
           port->string)
  (only-in racket/system
           system))

(provide
 ;; Parameters
 host
 org
 staff
 students
 token
 sep
 ;; GitHub API
 list-org-repos
 list-org-teams
 list-team-members
 list-team-logins
 add-repo-team
 create-org-repo
 add-repo-collab
 remove-repo-collab
 delete-repo
 ;; GitHub scripts
 create-student-repos
 delete-student-repos
 add-student-collab
 remove-student-collab
 push-student-repos
 clone-student-repos)

;; Library parameters
(define host (make-parameter "github.com"))
(define api-path (make-parameter "/api/v3"))
(define token (make-parameter "token"))
(define org (make-parameter "org"))
(define staff (make-parameter "staff"))
(define students (make-parameter "students"))
(define sep (make-parameter "-"))
(define verbose? (make-parameter #f))


;; Helpers ;;

;; diff : (listof any) (listof any) -> (listof any)
(define (diff include exclude)
  (filter (λ (elem) (not (member elem exclude))) include))

;; headers : -> string?
(define (headers)
  `(,(format "Authorization: token ~a" (token))
    "Accept: application/json"
    "content-type: application/json"))

;; get-response : input-port? -> string?
(define (get-response in)
  (let ([response (string->jsexpr (port->string in))])
    (close-input-port in)
    response))

;; make-command : *string? -> string?
(define (make-command . commands)
  (string-join commands " && "))


;; HTTP Request Methods ;;

;; make-request : string? string? jsexpr? [#:v? boolean?] -> jsexpr?
;; Make a request of the given method kind to the given API URI
;; with data in jsexpr? form and return the jsexpr? response.
;; The URI MUST begin with a forward slash.
;; If #:v? #t is provided, also display the response status.
(define (make-request method uri data)
  (define-values (status _ in)
    (http-sendrecv (host)
                   (format "~a~a" (api-path) uri)
                   #:ssl? #t
                   #:method method
                   #:headers (headers)
                   #:data (jsexpr->string data)))
  (when verbose? (displayln status))
  (get-response in))

;; get-request : string? -> jsexpr?
;; Make GET requests to all pages, collecting jsexpr? responses.
;; Assume that responses are lists.
;; Other preconditions apply as make-request above.
(define (get-request uri)
  (define hc (http-conn-open (host) #:ssl? #t #:auto-reconnect? #t))
  (let loop ([response '()]
             [page 1])
    (define-values (status _ in)
      (http-conn-sendrecv! hc
                           (format "~a~a?page=~a" (api-path) uri page)
                           #:method "GET"
                           #:headers (headers)))
    (define response-more (get-response in))
    (when verbose? (displayln status))
    (if (null? response-more)
        (begin (http-conn-close! hc) response)
        (loop (append response response-more) (add1 page)))))

;; post-request : string? jsexpr? -> jsexpr?
;; Make a POST request
(define (post-request uri data)
  (make-request "POST" uri data))

;; put-request : string? jsexpr? -> jsexpr?
;; Make a PUT request
(define (put-request uri data)
  (make-request "PUT" uri data))

;; patch-request : string? -> jsexpr?
;; Make a PATCH request
(define (patch-request uri data)
  (make-request "PATCH" uri data))

;; delete-request : string? -> jsexpr?
;; Make a DELETE request
(define (delete-request uri)
  (make-request "DELETE" uri #f))


;; Gradescope API ;;

;; login : string? string? -> string?
(define (login email password)
  (define response
    (parameterize ([host "www.gradescope.ca"]
                   [api-path "/api/v1"])
      (post-request "/user_session"
                    (hash 'email email
                          'password password))))
  (hash-ref response 'token))


;; GitHub API ;;

(define permissions '("push" "pull" "admin"))

;; Organizations

;; list-org-repos : jsexpr?
;; https://docs.github.com/rest/reference/repos#list-organization-repositories
(define (list-org-repos)
  (for/list ([repo (get-request (format "/orgs/~a/repos" (org)))])
    (hash-ref repo 'name)))

;; Teams

;; list-org-teams : jsexpr?
;; https://docs.github.com/rest/reference/teams#list-teams
(define (list-org-teams)
  (get-request (format "/orgs/~a/teams" (org))))

;; list-team-members : string? -> jsexpr?
;; https://docs.github.com/rest/reference/teams#list-team-members
(define (list-team-members team)
  (get-request (format "/orgs/~a/teams/~a/members" (org) team)))

;; list-team-logins : string? -> (listof string?)
;; List the login names for each member in the team
(define (list-team-logins team)
  (for/list ([member (list-team-members team)])
    (hash-ref member 'login)))

;; add-repo-team : string? string? (#:permission permission?) -> jsexpr?
;; https://docs.github.com/rest/reference/teams#add-or-update-team-repository-permissions
(define (add-repo-team team repo #:permission permission)
  (put-request (format "/orgs/~a/teams/~a/repos/~a/~a" (org) team (org) repo)
               (hash 'permission permission)))

;; Repositories

;; create-org-repo : string? string? [boolean?] -> jsexpr?
;; https://docs.github.com/rest/reference/repos#create-an-organization-repository
(define (create-org-repo repo desc [private? #t])
  (post-request (format "/orgs/~a/repos" (org))
                (hash 'name repo 'description desc 'private private?)))

;; set-default-branch : string? string? -> jsexpr?
;; https://docs.github.com/rest/reference/repos#update-a-repository
(define (set-default-branch repo branch)
  (patch-request (format "/repos/~a/~a" org repo)
                 (hash 'default_branch branch)))

;; add-repo-collab : string? string? (#:permission permission?) -> jsexpr?
;; https://docs.github.com/rest/reference/repos#add-a-repository-collaborator
(define (add-repo-collab repo username #:permission permission)
  (put-request (format "/repos/~a/~a/collaborators/~a" (org) repo username)
               (hash 'permission permission)))

;; remove-repo-collab : string? string? -> jsexpr?
;; https://docs.github.com/rest/reference/repos#remove-a-repository-collaborator
(define (remove-repo-collab repo username)
  (delete-request (format "/repos/~a/~a/collaborators/~a" (org) repo username)))

;; delete-repo : string? -> jsexpr?
;; https://docs.github.com/rest/reference/repos#delete-a-repository
(define (delete-repo repo)
  (delete-request (format "/repos/~a/~a" (org) repo)))


;; Scripts ;;

;; create-student-repos : string? string? -> void?
;; Create repositories for each student with the given prefix and with student logins as suffix,
;; and with the given repository description.
;; The staff team will be administrators of each repo.
(define (create-student-repos prefix desc)
  (for ([login (list-team-logins (students))])
    (define repo (string-join (list prefix login) sep))
    (printf "Creating repository ~a.\n" repo)
    (create-org-repo repo desc)
    (add-repo-team (staff) repo #:permission "admin")))

;; update-student-repos-default-branch : string? string? -> void?
;; For each student repository with the given prefix,
;; set the default branch to the given branch.
(define (update-student-repos-default-branch prefix branch)
  (for ([login (list-team-logins (students))])
    (define repo (string-join (list prefix login) sep))
    (set-default-branch repo branch)))

;; delete-student-repos : string? -> void?
;; Delete all student repositories with the given prefix.
;; Precondition: The student repositories must exist.
(define (delete-student-repos prefix)
  (for ([login (list-team-logins (students))])
    (define repo (string-join (list prefix login) sep))
    (printf "Deleting repository ~a.\n" repo)
    (delete-repo repo)))

;; add-student-collab : string? permission? [#:logins (listof string?)] [#:except (listof string?)] -> void?
;; For each student repository with the given prefix,
;; add student as collaborator with given permissions,
;; unless their login is in the exceptions list.
;; Precondition: The student repositories must exist.
(define (add-student-collab prefix permission #:logins [logins (list-team-logins (students))] #:except [except '()])
  (unless (member permission permissions)
    (error 'add-student-collab
           "Invalid permission ~s; must be one of ~s."
           permission permissions))
  (for ([login (diff logins except)])
    (define repo (string-join (list prefix login) sep))
    (printf "Adding ~a as collaborator to ~a with ~a permissions.\n" login repo permission)
    (add-repo-collab repo login #:permission permission)))

;; remove-student-collab : string? [#:logins (listof string?)] [#:except (listof string?)] -> void?
;; For each student repository with the given prefix,
;; remove student from the repository as collaborator,
;; unless their login is in the exceptions list.
;; Precondition: I think the student has to be a collaborator in that repo.
(define (remove-student-collab prefix #:logins [logins (list-team-logins (students))] #:except [except '()])
  (for ([login (diff logins except)])
    (define repo (string-join (list prefix login) sep))
    (printf "Removing ~a as collaborator from ~a.\n" login repo)
    (remove-repo-collab repo login)))

;; push-student-repos : string? string? [boolean?] [#:logins (listof string?)] [#:except (listof string?)] -> void?
;; For each student repository with the given prefix,
;; unless their login is in the exceptions list,
;; push from the given directory,
;; adding the repository as a new remote if specified.
;; Precondition: Repositories and directory must exist,
;; and there must be the right Git repo in that directory.
(define (push-student-repos prefix dir [add-remotes? #f] #:logins [logins (list-team-logins (students))] #:except [except '()])
  (printf "Pushing from ~a.\n" dir)
  (for ([login (diff logins except)])
    (define repo (string-join (list prefix login) sep))
    (define command
      (make-command
       (format "cd ~a" dir)
       (if add-remotes?
           (format "git remote add ~a git@~a:~a/~a.git" repo (host) (org) repo)
           ":")
       (format "git push ~a main" repo)))
    (printf "Pushing repository ~a.\n" repo)
    (system command)))

;; clone-student-repos : string? string? [boolean?] [#:logins (listof string?)] [#:except (listof string?)] -> void?
;; For each student repository with the given prefix,
;; unless their login is in the exceptions list,
;; clone it to the given directory,
;; creating the directory and initializing a Git repo there if specified.
;; Precondition: The student repositories must exist.
(define (clone-student-repos prefix dir [init? #f] #:logins [logins (list-team-logins (students))] #:except [except '()])
  (when init?
    (define command
      (make-command
       (format "mkdir ~a" dir)
       (format "cd ~a" dir)
       "git init"))
    (printf "Creating directory ~a.\n" dir)
    (system command))
  (for ([login (diff logins except)])
    (define repo (string-join (list prefix login) sep))
    (define command
      (make-command
       (format "cd ~a" dir)
       (format "git submodule add git@~a:~a/~a.git" (host) (org) repo)))
    (printf "Cloning repository ~a.\n" repo)
    (system command)))
