###
@author      Created by Marcus Spiegel <marcus.spiegel@gmail.com> on 2011-03-25.
@link        https://github.com/mashpie/i18n-node
@license      http://creativecommons.org/licenses/by-sa/3.0/

@version     0.3.5
###

#dependencies
vsprintf = require('sprintf').vsprintf
fs = require('fs')
url = require('url')
path = require('path')
locales = {}
defaultLocale = 'en'
updateFiles = true
cookiename = null
debug = false
verbose = false
extension = '.js'
directory = './locales'

#public exports
i18n = exports

i18n.version = '0.3.5'

i18n.configure = (opt)->
	#you may register helpers in global scope, up to you
	if typeof opt.register is 'object'
		opt.register.__ = i18n.__
		opt.register.__n = i18n.__n
		opt.register.getLocale = i18n.getLocale

	#sets a custom cookie name to parse locale settings from
	if typeof opt.cookie is 'string'
		cookiename = opt.cookie

	#where to store json files
	directory = if typeof opt.directory is 'string' then opt.directory else './locales'

	#write new locale information to disk
	if typeof opt.updateFiles is 'boolean'
		updateFiles = opt.updateFiles

	#where to store json files
	if typeof opt.extension is 'string'
		extension = opt.extension

	#enabled some debug output
	if opt.debug
		debug = opt.debug

	#implicitly read all locales
	if typeof opt.locales is 'object'
		Object.keys(opt.locales).forEach (l)->
			read(l)

i18n.init = (request, response, next)->
	if typeof request is 'object'
		guessLanguage(request)

	if typeof next is 'function'
		next()

i18n.__ = ()->

	if this.scope?
		locale = this.scope.locale

	args = [locale].concat(arguments[0])

	msg = translate.apply(this,args)

	slice = 1

	if Array.isArray(arguments[0])
		slice = 2
		count = parseInt(arguments[1], 10)
		switch count
			when 1 then msg = vsprintf(msg.one, [count])
			when 0 then msg = vsprintf(msg.none or msg.other, [count])
			else msg = vsprintf(msg.other, [count])

	msg = vsprintf(msg, Array.prototype.slice.call(arguments, slice))


#either gets called like
#setLocale('en') or like
#setLocale(req, 'en')
i18n.setLocale = (request, targetLocale)->

	unless targetLocale? and locales[targetLocale] or locales[request]
		[targetLocale, request] = [request,undefined]

	return unless locales[targetLocale]

	if request?
		request.locale = targetLocale
	else
		defaultLocale = targetLocale

	return i18n.getLocale(request)

i18n.getLocale = (request)->
	return if request? then request.locale else defaultLocale

i18n.overrideLocaleFromQuery = (req)->

	return unless req?

	urlObj = url.parse(req.url, true)
	if urlObj.query.locale?
		if debug then console.log("Overriding locale from query: " + urlObj.query.locale)
		i18n.setLocale(req, urlObj.query.locale.toLowerCase())


###
private methods
guess language setting based on http headers
###
guessLanguage = (request)->
	if typeof request is 'object'
		languageHeader = request.headers['accept-language']
		languages = []
		regions = []

		request.languages = [defaultLocale]
		request.regions = [defaultLocale]
		request.language = defaultLocale
		request.region = defaultLocale

		if language_header
			language_header.split(',').forEach (l)->

				header = l.split(';', 1)[0]
				lr = header.split('-', 2)

				languages.push(lr[0].toLowerCase()) if lr[0]?

				regions.push(lr[1].toLowerCase()) if lr[1]?

			if languages.length > 0
				request.languages = languages
				request.language = languages[0]

			if regions.length > 0
				request.regions = regions
				request.region = regions[0]

		#setting the language by cookie
		if cookiename and request.cookies[cookiename]
			request.language = request.cookies[cookiename]

		i18n.setLocale(request, request.language)

#read locale file, translate a msg and write to fs if new
translate = (locale,  singular, none, plural)->
	if locale is undefined
		if debug then console.warn("WARN: No locale found - check the context of the call to $__. Using " + defaultLocale + " (set by request) as current locale")
		locale = defaultLocale

	plural = none if arguments.length == 3

	read(locale) if locales[locale]?

	if plural? and not locales[locale][singular]?
			locales[locale][singular] =
				'none': none
				'one': singular,
				'other': plural
			write(locale)

	unless locales[locale][singular]?
		locales[locale][singular] = singular
		write(locale)

	return locales[locale][singular]

#try reading a file
read = (locale)->
	localeFile = {}
	file = locate(locale)
	try
		if verbose then console.log('read ' + file + ' for locale: ' + locale)

		localeFile = fs.readFileSync(file)
		try
			#parsing filecontents to locales[locale]
			locales[locale] = JSON.parse(localeFile)
		catch e
			console.error('unable to parse locales from file (maybe ' + file + ' is empty or invalid json?): ', e)
	catch e
		#unable to read, so intialize that file
		#locales[locale] are already set in memory, so no extra read required
		#or locales[locale] are empty, which initializes an empty locale.json file
		if verbose then console.log('initializing ' + file)

		write(locale)

#try writing a file in a created directory
write = (locale)->
	#don't write new locale information to disk if updateFiles isn't true
	return unless updateFiles

	#creating directory if necessary
	try
		stats = fs.lstatSync(directory)
	catch e
		if debug then console.log('creating locales dir in: ' + directory)
		fs.mkdirSync(directory, '0755')

	#first time init has an empty file
	locales[locale] or= {}

	#writing to tmp and rename on success
	try
		target = locate(locale)
		tmp = target + ".tmp"

		fs.writeFileSync(tmp, JSON.stringify(locales[locale], null, "\t"), "utf8")
		if fs.statSync(tmp).isFile() then fs.renameSync(tmp, target) else console.error('unable to write locales to file (either ' + tmp + ' or ' + target + ' are not writeable?): ', e)
	catch e
		console.error('unexpected error writing files (either ' + tmp + ' or ' + target + ' are not writeable?): ', e)

#basic normalization of filepath
locate = (locale)->
	path.normalize("#{directory}/#{locale}#{extension or ".js"}")
