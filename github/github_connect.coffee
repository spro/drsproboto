Github = require 'github'
config = require '../config'

github = new Github
    version: '3.0.0'
github.authenticate config.github

module.exports = github

