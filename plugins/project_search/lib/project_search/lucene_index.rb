
class ProjectSearch
  class LuceneIndex
    attr_accessor :last_updated, :lucene_index
    
    def initialize(project)
      @project = project
      load
    end
    
    def timestamp_file_path
      File.join(@project.config_dir, 'lucene_last_updated')
    end
    
    def load
      @last_updated = Time.at(0)
      if File.exist?(timestamp_file_path)
        @last_updated = Time.at(File.read(timestamp_file_path).chomp.to_i)
      end
    end
    
    def dump
      File.open(timestamp_file_path, "w") do |fout|
        fout.puts(last_updated.to_i.to_s)
      end
    end
    
    def update
      changed_files = @project.file_list.changed_since(last_updated)
      @last_updated = Time.now
      changed_files.reject! do |fn, ts|
        fn.index(@project.config_dir)
      end
      Lucene::Transaction.run do 
        i = 0
        s = Time.now
        @lucene_index ||= Lucene::Index.new(File.join(@project.config_dir, "lucene")) 
        begin
          @lucene_index.field_infos[:contents][:store] = true 
          @lucene_index.field_infos[:contents][:tokenized] = true
            unless File.basename(fn)[0..0] == "." or fn.include?(".git")
              contents = File.read(fn)
              if BinaryDataDetector.binary?(contents[0..200])
                # puts "skipping binary: #{fn}"
              else
                # puts "lucene update: #{fn} @ #{ts}"
                adjusted_contents = contents.gsub(/\.([^\s])/, '. \1')
                @lucene_index << { :id => fn, :contents => adjusted_contents }
                i += 1
              end
            end
          end
          @lucene_index.commit
          puts "took #{Time.now - s}s to index #{i} files"
        rescue => e
          puts e.message
          puts e.backtrace
        end
      end
      dump
    end
    
  end
end