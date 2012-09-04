require 'net/http'
require 'rubygems'
require 'mechanize'
require 'nokogiri'
require 'open-uri'
require 'fileutils'
require 'logger'

class DokuwikiDownloader

	def initialize
		@agent = Mechanize.new 
		if(File.exist?("script_debug.log")) #to avoid the exception thrown  when trying to replace a folder already existant
			FileUtils.rm "script_debug.log"
		end	
		@log = Logger.new('script_debug.log')

	end

	def set_proxy(host,port)
		@agent.set_proxy(host, port)
		@agent.agent.http.verify_mode = OpenSSL::SSL::VERIFY_NONE
		rescue 
			puts "Warn : proxy incorrect in set_proxy function"
	end

	#set_proxy before connect_to_wiki
	def connect_to_wiki(user, password)
		connected=true
		begin
			Timeout.timeout(3) do 
			@agent.get("https://dokuwiki.application.ac.centre-serveur.i2/doku.php?id=start")
			@agent.page.link_with(:text => "Connexion").click
			form = @agent.page.forms[0]
			@agent.page.search('#focus_this')
			form.field_with('u').value = user
			form.field_with('p').value = password
			form.submit
			end
			if (!@agent.page.uri.to_s.eql?("https://dokuwiki.application.ac.centre-serveur.i2/doku.php?id=start"))
				puts "Error: not able to to connect to wiki"
				connected = false
			else
				puts_and_write_to_file "-------> Connected to dokuwiki as #{user} "	

			end	

		rescue Exception => e
			puts_and_write_to_file "#{e}"
		end	
		connected
	end

	#return the html cleaned code of the page
	def download(url)
		@agent.get(url)
		@page = @agent.page.search('.page') #section a garder et traiter
		@title = get_folder_title(url)
		puts_and_write_to_file "Page : #{@title}"
		if(File.directory?("#{@title}")) #to avoid the exception thrown  when trying to replace a folder already existant
			FileUtils.rm_rf "#{@title}"
		end	
		@page.to_s.scan(/href="\/doku.php\?id=[^(tag)].*?"/).each do |page_l|
				if(@list_of_wikipages_links.to_s.match(/#{page_l.split("id=").last.to_s.gsub(/"/,"")}/)== nil)
							@liste_temp	<< "https://dokuwiki.application.ac.centre-serveur.i2/doku.php?id=" + page_l.split("id=").last.to_s.gsub(/"/,"")
							@list_of_wikipages_links << "https://dokuwiki.application.ac.centre-serveur.i2/doku.php?id=" + page_l.split("id=").last.to_s.gsub(/"/,"")
					
				end	

		end	
		Dir.mkdir("#{@title}")
		Dir.chdir("#{@title}") do
			download_images
			download_documents
			@light_html = clean_html(@page)
			create_html_page
		end

	rescue Exception => e
			puts_and_write_to_file "Error : #{e}!"
	else	
		return @light_html
	end

	def get_dokuwiki_pages
		i=0
		@list_of_wikipages_links = extract_wikipages_url("../liste_pages_dokuwiki.txt")

		 @liste_temp = @list_of_wikipages_links.dup
		 while (@liste_temp.size > 0 && i <= 1000)
		 			link = @liste_temp.shift
					download(link)
					File.open("liste_new.txt", 'a') {|f| 
					f.puts (link)
					}
				i = i+1
	
		end
		puts_and_write_to_file "\n#{i} pages downloaded from dokuwiki "	
	end	


#------ PRIVATE FUNCTIONS ------------------------------------------------------------------

	#Definit le titre du dossier
	def get_folder_title(url)
		return url.match(/id=.*$/).to_s.split("=").last
	end	

	#last function do call 
	#Clean le code de la page traitée
	def clean_html(page)
	#remove unwanted doms such as edit,toc, breadcrumbs..
		page.css('.breadcrumbs').remove
		page.css('.secedit').remove
		page.css('.toc').remove
		page.css('.meta').remove
		node= page.css('a.media')
		node.each do |n|
			if (n.children.to_s.match(/<img.*?>/)) # remove links around images
				n.parent << n.children
				n.remove
			end	
		end				
		remove_anchors(page)
		@light_html = page.to_s.gsub(/<!-- wikipage stop -->(.*)/m,"")
	#remove class, id and styles
		@light_html = @light_html.to_s.gsub(/\s(id|class|style)\s*?=\s*?"(.*?)"/,"")
		@light_html = @light_html.gsub(/<style(.*?)<\/style>/m,"")
		@light_html = @light_html.gsub(/<table>/,"<table class=\"table table-bordered\">")

		return @light_html
	end	


	#Téléchargement des images présentes sur la page traitée
	def download_images
		@page.css('img').each do |image|
			if(!File.directory?("../imgs")) #to avoid the exception thrown  when trying to replace a folder already existant
				Dir.mkdir("../imgs")
			end		
		   	Dir.chdir("../imgs") do
				if(image.attributes['src'].to_s.include?("lib/images/"))
					image.remove
				else
			   		image_title = image.attributes['src'].to_s.gsub(/.*media=/, "")
					image_title = image_title.split(":").last
	       			 img = @agent.get(image.attributes['src']).save(image_title)
	       			 puts_and_write_to_file "\t img - "+image.attributes['src'] + "-> OK"
	       		end	 
			end 
		end	

	rescue Exception => e
		puts_and_write_to_file " In function download_images :Error: #{e} for Page : #{@title}"

			
	end	


	#Téléchargement des pièces jointes présentes sur la page 
	def download_documents
		media_names = []
		@page.css('.mediafile').each do |media|
			if(!File.directory?("../pj")) 
				Dir.mkdir("../pj")
			end		
			Dir.chdir("../pj") do
				doc_title = media.attributes['href'].to_s.gsub(/.*media=/, "").split(":").last
				@agent.get(media.attributes['href']).save(doc_title)
				puts_and_write_to_file "\tdoc : "+media.attributes['href'] + "-> OK"
			end	
		end	
		rescue Exception => e
		puts_and_write_to_file " In function download_documents :Error: #{e} for Page : #{@title}"
	end
	 
	#Intégration du code épuré de la page traitée  dans une page HTML
	def create_html_page
		File.open("index.html", 'w') {|f| 
		f.write(@light_html) 
		}
	end
	
	#Stockage dans un tableau des urls de toutes les pages de Dokuwiki
	def extract_wikipages_url(path_to_file)
		list= []
		File.open(path_to_file, "r") { |file| 
			file.each_line do |line|
				url = "https://dokuwiki.application.ac.centre-serveur.i2/doku.php?id="+line
				list<< url
			end
		 }
		return list
	end	

	#permet d afficher les messages dans la console et d ecrire dans dans un fichier log
	def puts_and_write_to_file(output)
		puts output
  		@log.debug(output)
	end

	#supprime les liens des ancres dans les titres
	def remove_anchors(page)
		for i in 1..6
			page.css("h#{i}").each do |a|
				a.content = a.children.inner_html
			end
		end
	end	
	
end

