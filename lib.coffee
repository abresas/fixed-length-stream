es = require 'event-stream'
fs = require 'fs'

# Create a through stream that ensures a certain output length is not underflowed.
# If the length is not reached, the stream is filled with zeros.
exports.underflowStream = underflowStream = (length) ->
	pipedLength = 0
	es.through(
		(data) ->
			pipedLength += data.length
			@emit('data', data)
		(data) ->
			if pipedLength < length
				zeroStream = fs.createReadStream '/dev/zero', 
					start: 0
					end: length - pipedLength - 1
				zeroStream.on 'data', (data) =>
					@emit('data', data)
				zeroStream.on('end', => @emit('end'))
			else
				@emit('end')
	)

# Create a through stream that ensures a certain output length is not overflowed.
# If the length is passed, an error event is emitted.
exports.overflowStream = overflowStream = (length) ->
	pipedLength = 0
	es.through (data) ->
		if length < pipedLength + data.length
			offset = length - pipedLength
			data = data.slice(0, offset)
			pipedLength = length
			@emit('data', data)
			@emit('error', new RangeError('Stream overflowed'))
		else
			pipedLength += data.length
			@emit('data', data)


# Create a stream that will pass through data of a specific length.
#
# If less data are piped to it, zeros are added to the stream.
# If more data are piped to it, the extra data are ignored and an error event is sent.
exports.fixedLengthStream = (length) ->
	es.pipe(underflowStream(length), overflowStream(length))
