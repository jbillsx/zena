class ActiveRecord::Base
  class << self
    
    def fetch_ids(sql, id_attr='id')
      unless sql =~ /SELECT/i
        sql = "SELECT `#{id_attr}` FROM #{self.table_name} WHERE #{sql}"
      end
      connection.select_all(sql, "#{name} Load").map! do |record| 
        record[id_attr.to_s]
      end
    end
    
    def fetch_list(sql, *attr_list)
      unless sql =~ /SELECT/i
        sql = "SELECT #{attr_list.map {|a| "`#{a}`"}.join(', ')} FROM #{self.table_name} WHERE #{sql}"
      end
      connection.select_all(sql, "#{name} Load").map! do |record| 
        Hash[*(attr_list.map {|attr| [attr, record[attr.to_s]] }.flatten)]
      end
    end
    
    def next_zip(site_id)
      res = connection.update "UPDATE zips SET zip=@zip:=zip+1 WHERE site_id = '#{site_id}'"
      if res == 0
        # error
        raise Zena::BadConfiguration, "no zip entry for (#{site_id})"
      end
      rows = connection.execute "SELECT @zip"
      rows.fetch_row[0].to_i
    end
  end
end

module Zena
  # This exception occurs when we have configuration problems.
  class BadConfiguration < Exception
  end
end