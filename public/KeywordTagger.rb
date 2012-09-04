#!/usr/bin/env ruby

require File.expand_path("../../config/environment", __FILE__)

class KeywordTagger

	def get_hash_regex_tags(path_to_file)
		resultat = {}

		@keywords = get_all_keywords_hash

		File.readlines(path_to_file).select do |line|
			regex = extract_regex_from_line(line)
			raw_tags = extract_raw_tags_from_line(line)
			real_tags = transform_raw_tags_into_real_tags(raw_tags)
			level = get_level_from_line(line)
			resultat[regex] = [real_tags, level]
		end
		resultat	
	end

	def get_all_keywords_hash
		keywords_hash = {}
		Keyword.all.each do |keyword|
			keywords_hash[keyword.name.parameterize] = keyword
		end
		keywords_hash
	end

	def extract_regex_from_line(line)
		string = line.split(Regexp.new("=>")).first.strip
		r = Regexp.new(string.gsub(".", "\\.").gsub("*",".*"))
		return r
	end

	def extract_raw_tags_from_line(line)
		line.split(Regexp.new("=>")).last.split("//").first.strip.split(",")
	end

	def transform_raw_tags_into_real_tags(raw_keys)
		real_keys = []
		raw_keys.each do |raw_key|
			real_key = @keywords[raw_key.strip.parameterize]
			if real_key.nil? 
				#binding.pry if raw_key.include?("supprim")
				real_key = Keyword.create(:name => raw_key.strip.humanize, :keyword_category_id => 2)
			  	@keywords[raw_key.strip.parameterize] = real_key
			end
			real_keys << real_key

		end
		binding.pry if real_keys.include?(nil)
		return real_keys
	end

	def get_level_from_line(line)
		if !line.split("//").last.split("=").last.strip.match(/\d/).nil?
			level = line.split("//").last.split("=").last.strip.to_i		 
		else	
			level = 1 #default value for level
		end	
	end	

	
end
