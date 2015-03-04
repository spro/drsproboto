moment = require 'moment'
Toggl = require 'toggl-api'
didYouMean = require 'didyoumean'
somata = require 'somata'
async = require 'async'
Client = require './client'
config = require './config'

didYouMean.threshold = 0.7

toggls =
    sean: new Toggl apiToken: config.toggl.api_tokens.sean
    bryn: new Toggl apiToken: config.toggl.api_tokens.bryn

state =
    current_entries: {}
    projects: {}

attachProject = (entry) ->
    entry.project = state.projects.filter((p) -> p.id == entry.pid)[0]

startEntry = (user_slug, project_slug, entry_description, cb) ->
    getProject project_slug, (err, project) ->

        new_entry =
            description: entry_description
            pid: project?.id

        toggls[user_slug].startTimeEntry new_entry, (err, started) ->
            attachProject started
            cb err, started

stopUser = (user_slug, cb) ->
    if entry = state.current_entries[user_slug]
        toggls[user_slug].stopTimeEntry entry.id, (err, closed_entry) ->
            console.log closed_entry
            duration = moment.duration closed_entry.duration, 'seconds'
            cb? null, "Stopped '#{entry.description}' after #{duration.humanize()}"
            #delete state.current_entries[user_slug]
    else
        cb? null, "Nothing to stop."

checkCurrent = (user_slug) ->
    toggls[user_slug].getCurrentTimeEntry (err, current_entry) ->

        if !current_entry

            if state.current_entries[user_slug]?
                console.log 'entry was stopped:', state.current_entries[user_slug].description
                toggls[user_slug].getTimeEntryData state.current_entries[user_slug].id, (err, stopped_entry) ->
                    toggl_service.publish 'stop', {entry: stopped_entry, user: user_slug}
                    console.log 'after', stopped_entry.duration
                    delete state.current_entries[user_slug]

            else
                console.log 'nothing to do'

        else
            attachProject current_entry

            if state.current_entries[user_slug]?.id != current_entry.id
                elapsed = moment().diff(current_entry.start)
                if elapsed < 10000
                    toggl_service.publish 'start', {entry: current_entry, user: user_slug}
                    console.log 'encountered new entry:', current_entry.description
                    state.current_entries[user_slug] = current_entry

                else
                    console.log 'continuing entry:', current_entry.description
                    state.current_entries[user_slug] = current_entry

            else
                console.log 'same on that entry', current_entry
                elapsed = moment().diff(current_entry.start)
                current_entry.elapsed = elapsed
                toggl_service.publish 'progress', {entry: current_entry, user: user_slug}
                console.log 'continuing from', moment.duration(elapsed).humanize()
                state.current_entries[user_slug] = current_entry

setInterval ->
    checkCurrent 'sean'
    checkCurrent 'bryn'
, 5000

loadProjects = (cb) ->
    user_slug = 'sean'
    toggls[user_slug].getWorkspaces (err, workspaces) ->
        toggls[user_slug].getWorkspaceProjects workspaces[0].id, (err, projects) ->
            state.projects = projects
            cb? null, projects

loadProjects()

getProject = (project_slug, cb) ->
    project_names = state.projects.map (p) -> p.name
    closest = didYouMean project_slug, project_names
    project = state.projects.filter((p) -> p.name == closest)[0]
    cb null, project

toggl_client = new Client
    name: 'toggl'
    commands:

        projects: (message, cb) -> loadProjects cb

        start: (message, cb) ->
            [user_slug, project_slug] = message.args
            entry_description = message.args.slice(2).join(' ')
            startEntry user_slug, project_slug, entry_description, (err, entry) ->
                console.log err if err
                #state.current_entries[user_slug] = entry
                summary = "Started '#{entry.description}'"
                summary += " on #{project.name}..." if project
                cb? null, summary

        stop: (message, cb) ->
            [user_slug] = message.args
            stopUser user_slug, cb

toggl_service = new somata.Service 'drsproboto:toggl',
    start: startEntry
    stop: stopUser

