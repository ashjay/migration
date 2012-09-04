# encoding: utf-8

require File.expand_path("../../../public/KeywordTagger", __FILE__)
#-------------------------------------------------------------------------------------------------------
#----------------- UPLOAD ------------------------------------------------------------------------------
#-------------------------------------------------------------------------------------------------------

desc "Create sheets from dokuwiki_pages"
task :upload_sheets => :environment do 
	hash = return_hash  
	contains = Dir.entries("public/dokuwiki_pages")
	i=0
	Dir.chdir("public/dokuwiki_pages/")
	contains.each do |c|
		content =""
		if(File.directory?("#{c}") && c.match(/^\w.*$/))
			begin
				Dir.chdir("#{c}") do 	
					if(File.file?"index.html")
						f = File.open("index.html", "r")
						f.each_line {|line|content << line }
						f.close
						keys, level = get_keywords_for_sheet(c,hash)
						if(!keys.nil? && !content.include?("<h1>Cette page n'existe pas encore</h1>"))
							create_new_sheet("#{c}", content, keys, level)
							print "."
							i= i+1
						end	 		
					end		
				end
			rescue Exception => e
				puts "Probleme with the sheet #{c} : #{e}"	
				@log.debug(" Probleme with the sheet #{c} : #{e}")
			end			
		end	
	end	
	puts "\n #{i} sheets Uploaded"

end

#FUNCTION TO CREATE NEW SHEET
def create_new_sheet(title,description, keys, level)
	acai = Keyword.find_by_name("ACAI") #default skill keywords required
	sheet = Sheet.new
	sheet.title = title.split(":").last.humanize 
	sheet.id_dokuwiki = title
	if(level.to_s.match(/[0-3]/))
		sheet.level = level
	else 
		sheet.level = 1	#default level
	end	 
	sheet.keywords << keys
	sheet.description = description 
	if !sheet.valid?
		sheet.keywords << acai
	end	
	sheet.save
end	

desc"Upload all pictures from public/dokuwiki_pages/imgs "
task :upload_images  => :environment do
	if File.directory?("imgs")
		begin
			pictures = Dir.entries("imgs")
			Dir.chdir("imgs")
			pictures.each do |picture|
				if(picture.match(/^\w.*\.(jpg|png|gif)$/) && File.size?("#{picture}")) # the file shouldn't be empty
					pict = Ckeditor::Picture.new
					pict.data = File.new("#{picture}")
					pict.save
				end
			end	
		rescue Exception => e
			puts "#{e}"
			@log.debug("upload_images : #{e}")
		end	
	else
		puts "false"	
	end	
	puts "Images Uploaded"
end	


desc"Upload all attachments from public/dokuwiki_pages/pj"
task :upload_attachments => :environment do 
	if File.directory?("../pj")
		begin
			attachments = Dir.entries("../pj")
			Dir.chdir("../pj")
			attachments.each do |pj|
				if(pj.match(/^\w.*\..*$/) && File.size?("#{pj}")) # the file shouldn't be empty
					attachment = Ckeditor::AttachmentFile.new
					puts attachment
					attachment.data = File.new("#{pj}")
					attachment.save
				end
			end	
		rescue Exception => e
			@log.debug("upload attach : #{e}")
		end	
	else
		puts "false"	
	end	
end

#-------------------------------------------------------------------------------------------------------
#----------------- CORRECT LINKS -----------------------------------------------------------------------
#-------------------------------------------------------------------------------------------------------
desc "correct the image lings in html sheets"
task :correct_links => :environment do
	Sheet.all.each do |s|
		if(s.description)
			@log.debug("------------"+ s.title+ "------------")
			s.description = get_image_links(s.description)
			s.description = get_attachment_links(s.description)	
			s.description = get_sheet_links(s.description)	
			s.save
		end	
	end
end



def get_attachment_links(text_to_parse)
		attachment_url = text_to_parse.scan(/href=".*?\.pdf"/)
		attachment_url << text_to_parse.scan(/href=".*?\.odt"/)
		attachment_url << text_to_parse.scan(/href=".*?\.zip"/)

		attachment_url.each do |pj|
		 	if(!pj.blank?)
		 		attachment_name = pj.to_s.gsub(/"/,"").split(":").last.gsub("\\]","") 
		 		begin
					attachment = Ckeditor::AttachmentFile.find_by_data_file_name("#{attachment_name}")
		 			puts attachment_name.to_s
		 			text_to_parse = text_to_parse.sub(/href=".*?#{attachment_name}"/, 
		 				"href=\"/system/ckeditor_assets/attachments/#{attachment.id}/#{attachment_name}\"")		 			
		 		rescue Exception => e
		 			@log.debug("Unable to attachg file => #{attachment_name}")
		 		end		
		 	end	
		end		
	return text_to_parse
end


def get_image_links(text_to_parse)
		image_url = text_to_parse.scan(/src=".*?"/)
		image_url.each do |img|
		 	if(!img.blank?)	
		 		image_name = img.gsub(/"/,"").split(":").last.split("media=").last.gsub("%","_")
		 		begin
					pic = Ckeditor::Picture.find_by_data_file_name("#{image_name}")
		 			puts image_name.to_s
		 			text_to_parse = text_to_parse.sub(/src=".*?#{image_name}"/, "src=\"/system/ckeditor_assets/pictures/#{pic.id}/#{image_name}\"")		 			
		 		rescue Exception => e
		 			puts "#{e}"
		 			@log.debug("\t Unable to link to image : #{image_name}")
		 		end		
		 	end	
		end		
	return text_to_parse
end


def get_sheet_links(text_to_parse)
page_links = text_to_parse.scan(/href="\/doku.php\?id=[^(tag)].*?"/)
		if(!page_links.blank?)
			page_links.each do |pl|
				doku_id = pl.gsub(/"/,"").split("id=").last.to_s
				begin
					page = Sheet.find_by_id_dokuwiki("#{doku_id}")
					puts "\t#{doku_id} --- #{page.id}"
					text_to_parse=text_to_parse.sub(/href="\/doku.php\?id=#{doku_id}"/,
						"href=\"/sheets/#{page.id}\"")
			 	rescue	Exception => e
			 		text_to_parse = text_to_parse.gsub(/href="\/doku.php\?id=#{doku_id}"/, 
		 				"href=\"/sheets/new\" style=\"color:red\"")
			 		@log.debug("\t Dead link to page  => #{doku_id}")

			 	end	 
			end	
		end	
	return text_to_parse	
end



#-------------------------------------------------------------------------------------------------------
#----------------- MIGRATION --- -----------------------------------------------------------------------
#-------------------------------------------------------------------------------------------------------

desc "Upload sheets with attachments and pictures"
task :migrate_sheets => [:upload_sheets, :upload_images, :upload_attachments, :correct_links]

desc "Reset the database "
task :reinit_database => :environment do 
	begin 
		Rake::Task["db:drop"].invoke
		Sheet.destroy_all
		Ckeditor::Picture.destroy_all
		Ckeditor::AttachmentFile.destroy_all
		%x(curl -XDELETE 'http://localhost:9200/mdd-development_sheets')
	rescue Exception => e
		puts "#{e}"
	end			
	FileUtils.rm_rf "public/system/ckeditor_assets/attachments"
	FileUtils.rm_rf "public/system/ckeditor_assets/pictures"
	puts "DATABASE destroyed"
	Rake::Task["db:setup"].invoke
	puts "Base reinit"

end


desc "Create user"
task :create_user  => :environment do
	u = User.find_or_initialize_by_email("admin@developpement-durable.gouv.fr")
	u.password = 'password'
	u.roles = [:administrator]
	u.save
	puts "User created"

end

desc "Destroy database and Migrate sheets to the new appli"
task :migrate_to_new_appli  => :environment do
	@log = Logger.new('public/dokuwiki_rake_debug.log')
	Dir.chdir("public") do 
		sh %{ruby start.rb}
	end
	Rake::Task["migrate_sheets"].invoke
	puts "migrate sheets"
	Rake::Task["es:reindex:all"].invoke
	Rake::Task["create_user"].invoke
		
end
	
#-------------------------------------------------------------------------------------------------------
#----------------- KEYWORDS ----------------------------------------------------------------------------
#-------------------------------------------------------------------------------------------------------	

#return a hash table associating : /regexp/ => [an array of keywords objects]
def  return_hash  
	kt = KeywordTagger.new
	hash = kt.get_hash_regex_tags("public/conversion.txt") 
end


def get_keywords_for_sheet(title, hash)
	keywords = []
	suppr = keyword_to_skip("Supprimer")
	for k, v in hash
  		if(title.match(k) and !v[0].empty?)
  				v[0].each do |tag|
  					return keywords if(tag == suppr)	
  					if(!keywords.include?(tag))
						keywords << tag	
					end	
				end	
				level = v[1] || 1

		end		
	end

	if(keywords.empty?)
		keywords << Keyword.first #default keyword here : ACAI
	end	
	return keywords,level 		
end	

#define a keyword  to skip the sheet upload"
def keyword_to_skip(keyword_name)
	kw = Keyword.find_by_name(keyword_name)
end	

