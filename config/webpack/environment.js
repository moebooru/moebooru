const { environment } = require('@rails/webpacker')
const coffee =  require('./loaders/coffee')
const erb = require('./loaders/erb')

environment.loaders.prepend('erb', erb)
environment.loaders.prepend('coffee', coffee)
module.exports = environment
