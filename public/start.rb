#Script de lancement pour le telechargement des pages de Dokuwiki

load 'DokuwikiDownloader.rb'

#Initialisation
spider = DokuwikiDownloader.new

#Parametrer internet proxy
spider.set_proxy("localhost", 3128)

#Connexion a Dokuwiki
print "\tuser : "
user = gets.chomp
print "\tpassword : "
password = gets.chomp
connected = spider.connect_to_wiki(user, password)

#Download des pages de Dokuwiki
if(File.directory?("dokuwiki_pages")) #empecher exception lancee lors de l ecrasement d un dossier deja existant
			FileUtils.rm_rf "dokuwiki_pages"
end			
Dir.mkdir ("dokuwiki_pages")
Dir.chdir("dokuwiki_pages") do
	if(connected)
		spider.get_dokuwiki_pages
	end	
end

