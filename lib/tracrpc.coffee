rest = require 'restler'
url = require 'url'

class TracRPC
	constructor: (@apiPath = null, @username = null, @password = null) ->

	callMethod: (methodName, params = null, callback) ->
		body =
			method: methodName
			params: params
			id: null
		bodyData = JSON.stringify(body)
		options =
			data: bodyData
			username: @username
			password: @password
			headers:
				'Content-Type': 'application/json'
				'Content-Length': bodyData.length

		request = rest.get @apiPath, options
		request.on 'success', (data) ->
			if data.error
				return callback data.error.message, null
			else
				return callback null, data.result
		request.on 'error', (data, response) =>
			error = 'Error with HTTP status code: ' + response.statusCode + '\n'
			error += 'Your credentials or location (' + @apiPath + ') may be incorrect, please try again.'
			return callback error, null

	multiCallMethod: (methodName, params = [], callback) ->
		methods = []
		for param in params
			method =
				method: methodName
				params: [param]
			methods.push method

		@callMethod 'system.multicall', methods, (error, response) ->
			if error
				callback error, null
			else
				# Clean up response
				cleaned = []
				cleaned.push arg.result for arg in response
				callback null, cleaned
	
module.exports = TracRPC
