#lang scribble/manual
@require[@for-label[github-scripts
                    racket/base]]

@title[#:tag "top"]{github-scripts}
@author{Jonathan Chan}

@defmodule[github-scripts]

This package contains a teeny tiny interface to GitHub Enterprise's API and a couple of useful scripts.
The scripts are designed to help a course @racket[staff] team administer individual student repositories,
all of whom belong to a @racket[students] team.

@section{Parameters}

@defparam[host host-uri string? #:value "github.com"]{
 The URI of the GitHub instance.
}

@defparam[org org-name string? #:value "org"]{
 The organization name.
}

@defparam[staff team-name string? #:value "staff"]{
 The name of the staff team, which will be administrators of all student repositories created with the scripts.
}

@defparam[students team-name string? #:value "students"]{
 The name of the students team.
}

@defparam[token-file file-name string? #:value "TOKEN"]{
 The path of the file where the OAuth token is stored.
}

@defparam[sep separator string? #:value "-"]{
 When student repositories are created, the prefix and the suffix will be separated by this separator.
}

@section{API}

When @racket[verbose?] is not @racket[#f], all HTTP request statuses will be displayed.

@subsection{Organizations}

@defproc[(list-org-repos [#:v? verbose? any/c #f]) jsexpr?]{
 Lists the repositories in the organization.
 For details on the response content, see
 @url["https://docs.github.com/en/enterprise-server/rest/reference/repos#list-organization-repositories"].
}

@subsection{Teams}

@defproc[(list-org-teams [#:v? verbose? any/c #f]) jsexpr?]{
 Lists the teams in the organization.
 For details on the response content, see
 @url["https://docs.github.com/en/enterprise-server/rest/reference/teams#list-teams"].
}

@defproc[(list-team-members [team string?]
                            [#:v? verbose? any/c #f]) jsexpr?]{
 Lists the members of the given @racket[team].
 For details on the response content, see
 @url["https://docs.github.com/en/enterprise-server/rest/reference/teams#list-team-members"].
}

@defproc[(list-team-logins [team string?]
                           [#:v? verbose any/c #f]) (listof string?)]{
 Lists the login usernames of the members of the given @racket[team].
}

@defproc[(add-repo-team [team string?]
                        [repository string?]
                        [#:permission permission (or/c "push" "pull" "admin")]
                        [#:v? verbose? any/c #f]) jsexpr?]{
 Adds the @racket[team] with @racket[permission] to the @racket[repository].
 For details on the response content, see
 @url["https://docs.github.com/en/enterprise-server/rest/reference/teams#add-or-update-team-repository-permissions"].
}

@subsection{Repositories}

@defproc[(create-org-repo [repository string?]
                          [description string?]
                          [private boolean? #t]
                          [#:v? verbose? any/c #f]) jsexpr?]{
 Creates a new repository with the given @racket[repository] name and @racket[description].
 The repository is private by default.
 For details on the response content, see
 @url["https://docs.github.com/en/enterprise-server/rest/reference/repos#create-an-organization-repository"].
}

@defproc[(add-repo-collab [repository string?]
                          [username string?]
                          [#:permission permission (or/c "push" "pull" "admin")]
                          [#:v? verbose? any/c #f]) jsexpr?]{
 Adds the given user as a collaborator to the @racket[repository] with @racket[permission].
 For details on the response content, see
 @url["https://docs.github.com/en/enterprise-server/rest/reference/repos#add-a-repository-collaborator"].
}

@defproc[(remove-repo-collab [repository string?]
                             [username string?]
                             [#:v? verbose? any/c #f]) jsexpr?]{
 Removes the given user as a collaborator from the @racket[repository].
 For details on the response content, see
 @url["https://docs.github.com/en/enterprise-server/rest/reference/repos#remove-a-repository-collaborator"].
}

@defproc[(delete-repo [repository string?]
                      [#:v? verbose? any/c #f]) jsexpr?]{
 Deletes the given @racket[repository].
 For details on the response content, see
 @url["https://docs.github.com/en/enterprise-server/rest/reference/repos#delete-a-repository"].
}

@section{Scripts}

@defproc[(create-student-repos [prefix string?]
                               [description string?]) void?]{
 Creates repos for each student with the given @racket[prefix] and with student logins as suffix, and with the given repo @racket[description].
 The prefix and suffix are separated by @racket[(sep)].
 The staff team will be administrators of each repo.
}

@defproc[(delete-student-repos [prefix string?]) void?]{
 Deletes all student repositories with the given @racket[prefix].
}

@defproc[(add-student-collab [prefix string?]
                             [permission (or/c "push" "pull" "admin")]
                             [#:logins includes (listof string?) (list-team-logins (students))]
                             [#:except excludes (listof string?) '()]) void?]{
 For each student repository with the given @racket[prefix],
 add the student as a collaborator with the given @racket[permission],
 unless their username is in the @racket[excludes] list.
 By default, the usernames in the @racket[includes] list are those of the entire students team.
}

@defproc[(remove-student-collab [prefix string?]
                                [#:logins includes (listof string?) (list-team-logins (students))]
                                [#:except excludes (listof string?) '()]) void?]{
 For each student repository with the given @racket[prefix],
 remove the student from the repository as a collaborator,
 unless their username is in the @racket[excludes] list.
 By default, the usernames in the @racket[includes] list are those of the entire students team.
}

@defproc[(push-student-repos [prefix string?]
                             [directory string?]
                             [add-remotes? any/c #f]
                             [#:logins includes (listof string?) (list-team-logins (students))]
                             [#:except excludes (listof string?) '()]) void?]{
 For each student repository with the given @racket[prefix],
 unless their username is in the @racket[excludes] list,
 push the local repository in the given @racket[directory],
 adding a new remote with the repo name as the remote name if @racket[add-remotes] isn't @racket[#f].
 If @racket[add-remotes?] is @racket[#f], then there must already exist a remote with that name.
 By default, the usernames in the @racket[includes] list are those of the entire students team.
}

@defproc[(clone-student-repos [prefix string?]
                              [directory string?]
                              [init? any/c #f]
                              [#:logins includes (list-team-logins (students))]
                              [#:except excludes (listof string?) '()]) void?]{
 For each student repository with the given @racket[prefix],
 unless their username is in the @racket[excludes] list,
 clone the remote repository to the given @racket[directory] as a submodule,
 creating the directory and initializing it if @racket[init?] isn't @racket[#f].
 By default, the usernames in the @racket[includes] list are those of the entire students team.
}
