github = require './github_connect'
async = require 'async'
config = require '../config'

update_hooks = (cb) ->
    github.repos.getAll {per_page: 50}, (err, repos) ->
        if err
            console.log "[error] #{ err }"
        else
            async.each repos, (repo) ->
                # Check it's mine
                if repo.owner.login != 'spro'
                    return
                # First delete existing hooks
                console.log "Working with #{ repo.name }"
                console.log "Belonging to #{ repo.owner.login }"
                github.repos.getHooks
                    user: repo.owner.login
                    repo: repo.name
                , (err, hooks) ->
                    if err
                        console.log "failed fetching hooks for #{ repo.full_name }:"
                        console.log err
                    else
                        delete_hook = (hook, cb) ->
                            github.repos.deleteHook
                                user: repo.owner.login
                                repo: repo.name
                                id: hook.id
                            , (err) ->
                                if err
                                    console.log 'failed deleting hook:'
                                    console.log err
                                    cb(err)
                                else
                                    console.log "Deleted #{ repo.full_name }/#{ hook.id }"
                                    cb(null)
                        create_hook = (err) ->
                            if err
                                console.log 'failed before creating hook:'
                                console.log err
                            else
                                github.repos.createHook
                                    user: repo.owner.login
                                    repo: repo.name
                                    name: 'web'
                                    config:
                                        url: config.github.webhook_url
                                        content_type: 'json'
                                    events: ['push', 'issues']
                                , (err, hook) ->
                                    if err
                                        console.log 'failed before creating hook:'
                                        console.log err
                                    else
                                        console.log "Created #{ repo.full_name }/#{ hook.id }"
                        async.each hooks, delete_hook, create_hook

update_hooks()
