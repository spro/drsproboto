github_issues = require './github_issues'
util = require 'util'

# Helper functions for interpretation and formatting
repo_from_str = (repo_str) ->
    repo_parts = repo_str.split '/'
    if repo_parts.length == 1
        repo = {owner: {login: 'spro'}, name: repo_parts[0]}
    else
        repo = {owner: {login: repo_parts[0]}, name: repo_parts[1]}
    repo['full_name'] = "#{ repo.owner.login }/#{ repo.name }"
    repo

issues_sort = (a, b) ->
    a.repo.open_issues_count - b.repo.open_issues_count

issue_str = (issue) ->
    "[#{ issue.repo.full_name } ##{ issue.number }] #{ issue.title }"

# The main command handler
github_handler = (message, cb) ->

    args_str = message.args.join(' ')

    # Create an issue in the specified repository
    if matched = args_str.match /^issue ([a-zA-Z_\/-]+) (.*)/
        repo_name = matched[1]
        issue_title = matched[2]

        repo = repo_from_str repo_name

        github_issues.create_issue repo, issue_title, (err, issue) ->
            if err
                cb 'There was an issue creating that issue...\n' + util.inspect err

            else
                issue['repo'] = repo
                cb null, 'Created issue: ' + issue_str issue

    else if matched = args_str.match /^issues ?(.*)/
        repo_name = matched[1]

        # Report issues for specific repository
        if repo_name? and repo_name.length > 0
            console.log "going to get issues for '#{ repo_name }'"

            repo = repo_from_str repo_name
            github_issues.repo_issues repo, (err, issues) ->

                if err
                    cb 'You must have some issues...\n' + util.inspect err

                else
                    lines = []
                    for issue in issues
                        lines.push issue_str issue

                    if lines.length > 0
                        cb null, lines.join '\n'
                    else
                        cb null, "No issues for #{ repo_name }"

        # Loop through all repositories to report issues
        else
            github_issues.all_my_issues (err, issues) ->

                if err
                    cb 'You must have some issues...\n' + util.inspect err

                else
                    lines = []
                    for issue in issues
                        lines.push issue_str issue

                    if lines.length > 0
                        cb null, lines.join '\n'
                    else
                        cb null, "No issues found"

module.exports = github_handler
