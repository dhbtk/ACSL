require 'rubygems'
require 'sinatra'
require 'json'
require 'yaml'
require 'data_mapper'
require 'inifile'

class ACSLSettings
	@@vote_start_time = nil
	@@settings = nil
	@@acsl_path = nil
	def self.init()
		@@acsl_path = File.dirname(File.absolute_path(__FILE__))
		@@settings = YAML.load(File.read("#{@@acsl_path}/acsl.yaml"))
		@@vote_start_time = nil
	end
	
	def self.settings
		@@settings
	end
	
	def self.acsl_path
		@@acsl_path
	end
	
	def self.vote_start_time(*args)
		if args.length == 0
			@@vote_start_time
		else
			@@vote_start_time = args[0]
		end
	end
end
configure do
	# Loading settings
	ACSLSettings::init()
end
# Vote storage
DataMapper::Logger.new($stdout,:error)
DataMapper.setup(:default,"sqlite://#{ACSLSettings::acsl_path}/votes.db")
class SessionType
	include DataMapper::Resource
	property :name, String, :key => true
	property :desc, Text
	has n, :voters
end

class Track
	include DataMapper::Resource
	property :name, String, :key => true
	property :variant, String
	property :desc, String
	has n, :voters
end

class Car
	include DataMapper::Resource
	property :name, String, :key => true
	property :desc, String
	has n, :voters
end

class Voter
	include DataMapper::Resource
	property :ip, Text, :key => true
	
	belongs_to :session_type, :required => false
	belongs_to :track, :required => false
	belongs_to :car, :required => false
end
DataMapper.finalize
DataMapper.auto_migrate!
#DataMapper::Model.raise_on_save_failure = true
# Loading data into database
for s in ACSLSettings::settings[:sessions]
	res = SessionType.create(:name => s.to_a[0][0],:desc => s.to_a[0][1])
end
for car in ACSLSettings::settings[:cars].split(' ')
	res = Car.create(:name => car)
end
for track in ACSLSettings::settings[:tracks].split(' ')
	res = Track.create(:name => track)
end

def get_server_status
	status = {}
	server_pid = `pidof #{ACSLSettings::settings[:paths][1]['binary_name']}`.to_i
	if server_pid != 0
		status[:running] = true
	else
		status[:running] = false
	end
	found_session = false
	found_ranking = false
	session_indexes = {}
	laps = []
	session_ranking = []
	session_offset = 0
	user_connect = {}
	user_disconnect = {}
	current_car = {}
	users_on = []
	"#{ACSLSettings::settings[:paths][0]['server_folder']}"
	if Dir["#{ACSLSettings::settings[:paths][0]['server_folder']}/logs/acs*.log"].sort[-1] != nil
		server_log = File.read(Dir["#{ACSLSettings::settings[:paths][0]['server_folder']}/logs/acs*.log"].sort[-1]).split("\n")
	else
		server_log = []
	end
	(server_log.length - 1).downto(0) do |i|
		match = server_log[i].match(/^(\d+) (.+)$/)
		if match == nil
			next
		end
		time = Time.at(match[1].to_i)
		line = match[2]
		# Finding current session
		if line == "NextSession" and not found_session
			session_offset = i
			session = {}
			session[:name] = server_log[i+1].match(/^\d+ SESSION: (.+)$/)[1]
			session[:type] = server_log[i+2].match(/^\d+ TYPE=(.+)$/)[1]
			session[:started] = time
			session[:length] = server_log[i+3].match(/^\d+ TIME=(.+)$/)[1].to_i
			session[:timeleft] = session[:length]*60 - (Time.now - time).to_i
			session[:laps] = server_log[i+4].match(/^\d+ LAPS=(.+)$/)[1].to_i
			status[:session] = session
			found_session = true
		end
		# Session ranking
		if line[/^1\) /] and not found_ranking
			j = i
			while server_log[j].match(/\d+ \d+\) (.+) BEST: (\d+:\d+:\d+) TOTAL: (\d+:\d+:\d+) Laps:(\d+) SesID:\d+$/)
				best_lap = $2.split(":")[0].to_i*60 + $2.split(":")[1].to_i + $2.split(":")[2].to_i/1000.0
				total_time = $3.split(":")[0].to_i*60 + $3.split(":")[1].to_i + $3.split(":")[2].to_i/1000.0
				entry = {:name => $1, :best => best_lap, :total => total_time, :laps => $4.to_i}
				session_ranking << entry
				j = j + 1
			end
			status[:session_ranking] = session_ranking
			found_ranking = true
		end
		# Lap tracking
		if line[/^LAP (.+) (\d+):(\d+):(\d+)$/] and not found_session # Don't want old laps in
			m = line.match(/^LAP (.+) (\d+):(\d+):(\d+)$/)
			if m != nil
				laps.unshift([m[1],m[2].to_i*60 + m[3].to_i + m[4].to_i/1000.0])
			end
		end
		# Current car
		# User connection
		if line[/^Sending first leaderboard to car/]
			m = line.match(/^Sending first leaderboard to car: ([a-z0-9_]+) \(\d+\) \[(.+) \[\]\]$/)
			if m != nil and current_car[m[2]] == nil
				current_car[m[2]] = m[1]
			end
			if m != nil
				if user_connect[m[2]] == nil
					user_connect[m[2]] = 1
				else
					user_connect[m[2]] += 1
				end
			end
		end
		# User disconnection
		if line[/^Clean exit, driver disconnected/]
			m = line.match(/^Clean exit, driver disconnected: (.+) \[\]$/)
			if m != nil
				driver = m[1].strip
				if user_disconnect[driver] == nil
					user_disconnect[driver] = 1
				else
					user_disconnect[driver] += 1
				end
			end
		end
	end
	for i in user_connect
		if user_disconnect[i[0]] == nil or i[1] - user_disconnect[i[0]] > 0
			users_on << i[0]
		end
	end
	status[:laps] = laps
	status[:users_on] = users_on
	return status
end

# Called at vote time
def can_vote?
	status = get_server_status()
	voting_allowed = false
	if not status[:running] or (status[:users_on].length == 0 and status[:session][:type] != "BOOK" and not (status[:session][:type] == "PRACTICE" and status[:session][:length]*60 - status[:session][:timeleft] < ACSLSettings::settings[:settings][3]['voting_length']))
		voting_allowed = true
	end
	if voting_allowed and (ACSLSettings::vote_start_time == nil)
		Voter.destroy
		return true
	elsif voting_allowed and (Time.now - ACSLSettings::vote_start_time) <= ACSLSettings::settings[:settings][3]['voting_length']
		return true
	elsif voting_allowed and (Time.now - ACSLSettings::vote_start_time) > ACSLSettings::settings[:settings][3]['voting_length'] and Voter.all.count > 0
		puts "Launching"
		start_server_from_votes
		Voter.destroy
		ACSLSettings::vote_start_time(nil)
		# LAUNCH SERVER
		return false
	elsif voting_allowed and (Time.now - ACSLSettings::vote_start_time) > ACSLSettings::settings[:settings][3]['voting_length']
		return true
	else
		# Mid session
		return false
	end
end

def start_server_from_votes
	voted_session = nil
	session_votes = 0
	tracks = {}
	voted_track = nil
	track_variant = nil
	track_votes = 0
	cars = {}
	car_list = []
	car_total_votes = 0
	for session_type in SessionType.all
		if session_type.voters.count > session_votes
			voted_session = session_type.name
			session_votes = session_type.voters.count
		end
	end
	for track in Track.all
		if track.voters.count > track_votes
			voted_track = track.name
			track_variant = track.variant
			track_votes = track.voters.count
		end
	end
	for car in Car.all
		if car.voters.count > 0
			cars[car.name] = car.voters.count
			car_list << car.name
			car_total_votes += car.voters.count
		end
	end
	if session_votes == 0 or track_votes == 0 or car_total_votes == 0
		return
	end
	server_config_file = File.read("#{ACSLSettings::acsl_path}/base_cfg_#{voted_session}.ini")
	server_config_file = server_config_file.gsub("$SERVERNAME$",ACSLSettings::settings[:settings][0]['server_name'])
	server_config_file = server_config_file.gsub("$CARS$",car_list.join(';'))
	server_config_file = server_config_file.gsub("$TRACK$",voted_track)
	if track_variant != nil
		server_config_file = server_config_file.gsub("$VARIANT$","CONFIG_TRACK=#{track_variant}")
	end
	server_config_file = server_config_file.gsub("$MAXCLIENTS$",ACSLSettings::settings[:settings][4]['max_clients'].to_s)
	server_config_file = server_config_file.gsub("$PASSWORD$",ACSLSettings::settings[:settings][1]['password'])
	server_config_file = server_config_file.gsub("$ADMPASSWORD$",ACSLSettings::settings[:settings][2]['admin_password'])
	File.write("#{ACSLSettings::settings[:paths][0]['server_folder']}/cfg/server_cfg.ini",server_config_file)
	if not server_config_file[/\[BOOK\]/] # if it's a pickup mode
		# We have to fill up entry_list.ini!
		multiplier = ACSLSettings::settings[:settings][4]['max_clients'] / car_total_votes
		difference = ACSLSettings::settings[:settings][4]['max_clients'] - car_total_votes*multiplier
		skins = YAML.load(File.read("skins.yaml"))
		i = 0
		entry_list = ""
		for car, count in cars
			1.upto(count*multiplier) do |j|
				entry_list += "[CAR_#{i}]\nDRIVERNAME=\nTEAM=\nMODEL=#{car}\nSKIN=#{skins[car].to_s.split(" ").sample}\nGUID=\nSPECTATOR_MODE=0\n\n"
				i += 1
			end
		end
		# Just adding more of the first one to fill things up
		if difference != 0
			for car, count in cars
				1.upto(difference) do |j|
					entry_list += "[CAR_#{i}]\nDRIVERNAME=\nTEAM=\nMODEL=#{car}\nSKIN=#{skins[car].to_s.split(" ").sample}\nGUID=\nSPECTATOR_MODE=0\n\n"
					i += 1
				end
				break
			end
		end
		File.write("#{ACSLSettings::settings[:paths][0]['server_folder']}/cfg/entry_list.ini",entry_list)
	else
		File.delete("#{ACSLSettings::settings[:paths][0]['server_folder']}/cfg/entry_list.ini")
	end
	# Killing the server
	`pkill #{ACSLSettings::settings[:paths][1]['binary_name']}`
	# Launch screen
	`screen -X -S acs quit`
	`screen -S acs -d -m #{ACSLSettings::settings[:paths][0]['server_folder']}/launch_acs.sh`
end


def get_server_ini_info
	file = IniFile.load("#{ACSLSettings::settings[:paths][0]['server_folder']}/cfg/server_cfg.ini")
	File.read("#{ACSLSettings::settings[:paths][0]['server_folder']}/cfg/server_cfg.ini")[/^CARS=([a-zA-Z0-9_;]+)/]
	cars = $1.split(';').join(', ')
	info = {:name => file['SERVER']['NAME'], :cars => cars, :track => file['SERVER']['TRACK'], :max_clients => file['SERVER']['MAX_CLIENTS'].to_i}
	info
end

get '/' do
	session_types = SessionType.all
	tracks = Track.all
	cars = Car.all
	erb :index, :locals => { :session_types => session_types, :tracks => tracks, :cars => cars, :title => ACSLSettings::settings[:settings][5]['page_title'] }
end

post '/vote' do
	if can_vote?
		ACSLSettings::vote_start_time(Time.now) if not ACSLSettings::vote_start_time
		voter = Voter.first_or_create(:ip => request.ip)
		if params['session']
			voter.update(:session_type => SessionType.get(params['session']))
		elsif params['track']
			voter.update(:track => Track.get(params['track']))
		elsif params['car']
			voter.update(:car => Car.get(params['car']))
		end
	end
	''
end

get '/vote_status' do
	content_type 'text/plain'
	voting = {}
	voting[:allowed] = can_vote?
	if ACSLSettings::vote_start_time
		voting[:in_progress] = true
		voting[:timeleft] = ACSLSettings::settings[:settings][3]['voting_length'] - (Time.now - ACSLSettings::vote_start_time)
	else
		voting[:in_progress] = false
	end
	voting[:sessions] = {}
	for s in SessionType.all
		voting[:sessions][s.name] = s.voters.count
	end
	voting[:tracks] = {}
	for track in Track.all
		voting[:tracks][track.name] = track.voters.count
	end
	voting[:cars] = {}
	for car in Car.all
		voting[:cars][car.name] = car.voters.count
	end
	voting.to_json
end

get '/server_status' do
	content_type 'text/plain'
	status = get_server_status()
	status[:ini] = get_server_ini_info()
	status.to_json
end