require 'pry'
require 'yaml'
require 'net/http'
require 'digest'

class BattleArena
	CONFIG = YAML.load(File.read('config.yml'))

	def initialize
		user_input
	end

	def select_char(number)
		puts "Please type in your #{number} Marvel character"
		char = gets.chomp
		res = api_call(char)

		# Only parse the API response if the response comes back with 200, otherwise we out put generic api error and 
		# recursively call this function again. We also call this function again if the character input doesn't exist
		if res.code == "200"
			char_result = parse_response(res)
			if !char_result
				puts "Marvel character not found. Please try again"
				select_char(number)
			else
				return char_result
			end
		else
			puts "API Error"
			select_char(number)
		end
	end

	def get_seed
		#Input must be an integer between 1-9, if not, this function will be called until the input is a correct type
		puts "Please choose a number between 1-9"
		seed = gets.chomp

		if !(1..9).include?(seed.to_i)
			puts "Error: The input is not a number between 1-9. Please try again."
			get_seed 
		else
			seed.to_i
		end
	end

	def user_input
		first_char = select_char('first')
		second_char = select_char('second')
		seed = get_seed
		args = { first_char: first_char, second_char: second_char, seed: seed}
		begin_battle(args)
	end

	def api_call(character)
		# Construct the md5hash as instructed from Marvel developer docs then send a GET request to the api with the params
		uri = URI(CONFIG['settings']['marvel_char_api'])
		timestamp = Time.now.to_s
		md5hash = Digest::MD5.hexdigest(timestamp + CONFIG['settings']['private_key'] + CONFIG['settings']['public_key'])
		char_params = { apikey: CONFIG['settings']['public_key'], ts: timestamp, hash: md5hash, name: character }

		begin
			uri.query = URI.encode_www_form(char_params)
			res = Net::HTTP.get_response(uri)
		rescue => e
			res = "API Error: #{e}"
		end
	end

	def parse_response(response)
		parsed_data = JSON.parse(response.body)
		found_result = parsed_data["data"]["results"].first
	end

	def magic_word(character)
		if character["description"].downcase.include?('gamma') || character["description"].downcase.include?('radioactive')
			puts "#{character["name"]} wins!"
			true
		end
	end

	def desc_split(description)
		description.gsub(/\.|,|'/, '').split
	end

	def begin_battle(battle_params)
		#Assuming if character description is empty, the other character automatically wins. 
		#If both descriptions are empty, then the first character wins.
		return puts "#{battle_params[:first_char]["name"]} wins!" if battle_params[:first_char]["description"].empty? && battle_params[:second_char]["description"].empty?
		return puts "#{battle_params[:first_char]["name"]} wins!" if battle_params[:second_char]["description"].empty?
		return puts "#{battle_params[:second_char]["name"]} wins!" if battle_params[:first_char]["description"].empty?
		#Check if the description contains "gamma" or "radioactive". If it does, that character automatically wins
		return if magic_word(battle_params[:first_char])
		return if magic_word(battle_params[:second_char])

		first_char_desc_array = desc_split(battle_params[:first_char]["description"])
		second_char_desc_array = desc_split(battle_params[:second_char]["description"])

		#Assuming if the seed number is relative to the order of the words of the description, we compare the size of the word 
		#to determine the winner
		if first_char_desc_array[battle_params[:seed] - 1].size > second_char_desc_array[battle_params[:seed] - 1].size
			puts "#{battle_params[:first_char]["name"]} wins!"
		else
			puts "#{battle_params[:second_char]["name"]} wins!"
		end
	end
end

start_game = BattleArena.new