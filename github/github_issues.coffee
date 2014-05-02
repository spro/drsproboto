async = require 'async'
util = require 'util'
_ = require 'underscore'
github = require './github_connect'

repo_issues = (repo, cb) ->
    github.issues.repoIssues
        user: repo.owner.login
        repo: repo.name
    , (err, issues) ->
        if err
            cb err
        else
            issues.map (i) -> i.repo = repo
            cb null, issues

create_issue = (repo, title, cb) ->
    github.issues.create
        user: repo.owner.login
        repo: repo.name
        title: title
        labels: []
    , (err, issue) ->
        if err
            cb err
        else
            cb null, issue

all_my_issues = (cb) ->
    github.repos.getAll {per_page: 50}, (err, repos) ->
        if err
            cb(err, null)
        else
            # Collect repos with num issues > 0
            repos_with_issues = []
            for repo in repos
                if repo.open_issues_count
                    repos_with_issues.push repo

            # Get issue list for each repo
            async.map repos_with_issues, repo_issues
            , (err, all_repo_issues) ->
                # Flatten groups of issues into one array
                cb null, _.flatten all_repo_issues

module.exports =
    create_issue: create_issue
    all_my_issues: all_my_issues
    repo_issues: repo_issues
