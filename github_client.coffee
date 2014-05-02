Client = require './client'
github_handler = require './github/github_handler'

github_client = new Client
    name: "Github handler"
    commands: github: github_handler

