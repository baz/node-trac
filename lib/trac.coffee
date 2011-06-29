url = require 'url'
TracRPC = require './tracrpc'

class Trac
	constructor: ->
		@tracRPC = new TracRPC()

	projectURL: ->
		return @tracRPC.apiPath

	dateForDatetime: (classHintObject) ->
		unwrapped = classHintObject['__jsonclass__']
		if unwrapped and unwrapped.hasOwnProperty 'length'
			return new Date(unwrapped[1])
		else
			return null

	authenticate: (username, password, location, callback) ->
		@tracRPC.apiPath = url.resolve location, 'login/jsonrpc'
		@tracRPC.username = username
		@tracRPC.password = password
		# Fetch components to verify credentials, requires TICKET_VIEW permission
		@tracRPC.callMethod 'ticket.component.getAll', null, (error, response) ->
			callback error, if response then true else false

	allMilestones: (callback) ->
		@_expandedCall 'ticket.milestone.getAll', 'ticket.milestone.get', callback

	allComponents: (callback) ->
		@tracRPC.callMethod 'ticket.component.getAll', null, callback

	allPriorities: (callback) ->
		@_expandedCall 'ticket.priority.getAll', 'ticket.priority.get', callback

	allResolutions: (callback) ->
		@_expandedCall 'ticket.resolution.getAll', 'ticket.resolution.get', callback

	allSeverities: (callback) ->
		@_expandedCall 'ticket.severity.getAll', 'ticket.severity.get', callback

	allStatuses: (callback) ->
		@tracRPC.callMethod 'ticket.status.getAll', null, callback

	allTypes: (callback) ->
		@_expandedCall 'ticket.type.getAll', 'ticket.type.get', callback

	allVersions: (callback) ->
		@_expandedCall 'ticket.version.getAll', 'ticket.version.get', callback

	allTickets: (limit, callback) ->
		# Fetch ticket IDs up to limit specified
		@tracRPC.callMethod 'ticket.query', ['max='+limit], (error, ticketIDs) =>
			if error then callback error, null else @_populateTickets ticketIDs, callback

	changedTickets: (sinceUTC, callback) ->
		formattedDate = @_ISODateString(sinceUTC)
		date = {}
		date['__jsonclass__'] = []
		date['__jsonclass__'].push 'datetime'
		date['__jsonclass__'].push formattedDate
		@tracRPC.callMethod 'ticket.getRecentChanges', [date], (error, ticketIDs) =>
			if error then callback error, null else @_populateTickets ticketIDs, callback

	_populateTickets: (ticketIDs, callback) ->
		allTickets = null
		allActions = null
		# Fetch ticket details
		@tracRPC.multiCallMethod 'ticket.get', ticketIDs, (error, tickets) =>
			if error then callback error, null else consolidate(tickets, null)

		# Fetch each ticket's actions
		@tracRPC.multiCallMethod 'ticket.getActions', ticketIDs, (error, actions) ->
			if error then callback error, null else consolidate(null, actions)

		consolidate = (tickets, actions) =>
			if tickets then allTickets = tickets
			if actions then allActions = actions

			if allTickets and allActions
				# Consolidate
				index = 0
				flattened = []
				for ticket in allTickets
					# Flatten ticket
					id = ticket.shift()
					dateCreated = @dateForDatetime(ticket.shift())
					dateUpdated = @dateForDatetime(ticket.shift())
					ticket = ticket.pop()
					ticket.id = id
					ticket.dateCreated = dateCreated
					ticket.dateUpdated = dateUpdated

					ticketActions = allActions[index]
					ticket.actions = ticketActions
					index++
					flattened.push ticket

				callback null, flattened

	_ISODateString: (UTCDate) ->
		pad = (n) ->
			return if n < 10 then '0' + n else n
		return UTCDate.getUTCFullYear() + '-' + pad(UTCDate.getUTCMonth() + 1) + '-' + pad(UTCDate.getUTCDate()) + 'T' + pad(UTCDate.getUTCHours()) + ':' + pad(UTCDate.getUTCMinutes()) + ':' + pad(UTCDate.getUTCSeconds()) + 'Z'

	_expandedCall: (methodName, expandedMethodName, callback) ->
		@tracRPC.callMethod methodName, null, (error, initialResponse) =>
			if error then callback error, null else
				# Fetch details for each response
				@tracRPC.multiCallMethod expandedMethodName, initialResponse, (error, response) ->
					if error then callback error, null else
						completed = []
						index = 0
						for value in response
							key = initialResponse[index]
							item = {}
							item[key] = value
							completed.push item
							index++

						callback null, completed

module.exports = new Trac
