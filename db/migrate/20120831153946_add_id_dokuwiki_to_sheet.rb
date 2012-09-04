class AddIdDokuwikiToSheet < ActiveRecord::Migration
  def change
    add_column :sheets, :id_dokuwiki, :string
  end

   def self.down
    remove_column :sheets, :id_dokuwiki
  end
end
