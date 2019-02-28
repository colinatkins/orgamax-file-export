require 'digest'
require 'pathname'
require 'yaml'
require 'pp'
require 'json'
require 'fileutils'
require_relative 'zip_file_generator'

class OrgamaxExporter
  include FileUtils
  CONF_FILE = 'conf.yml'

  def init(orgamax_path, export_path, db_id, export_offers, export_receipts)
    conf = {
        orgamax_path: orgamax_path,
        export_path: export_path,
        db_id: db_id,
        export_offers: export_offers,
        export_receipts: export_receipts,
    }

    File.open(CONF_FILE, "w") { |file| file.write(conf.to_yaml) }
  end

  def export(export_all, export_year=nil, export_month=nil)
    conf = read_config
    folders = [
        "#{conf[:orgamax_path]}\\Dokumente\\#{conf[:db_id]}",
        "#{conf[:orgamax_path]}\\Archiv\\#{conf[:db_id]}"
    ]

    files_filtered = {
        offers: [],
        receipts: [],
        count: 0
    }

    folders.each do |folder|
      chdir folder do
        files = []
        Dir.glob('**/*').each do |file|
          # In archive pick only first files.
          is_archive = folder.include?('Archiv')
          matches = file.match? /^[\d]+.pdf$/i
          if is_archive and matches
            files << file
          elsif !is_archive
            files << file
          end
        end

        # Filter
        files.each do |file|
          hash = file_hash(file, folder)
          next if hash.nil?

          %i(export_offers export_receipts).each do |sym|
            if conf[sym]
              if file.start_with?('Angebote')
                key = :offers
              else
                key = :receipts
              end

              unless key.nil?
                unless export_year.nil? or export_month.nil?
                  if check_if_within_time_scope(hash[:path], export_year, export_month)
                    files_with_same_checksum = files_filtered[key].select {|file| file[:checksum] == hash[:checksum] }.compact
                    if files_with_same_checksum.length.zero?
                      files_filtered[key] << hash
                      files_filtered[:count] = files_filtered[:count] + 1
                    end
                  end
                else
                  files_with_same_checksum = files_filtered[key].select {|file| file[:checksum] == hash[:checksum] }.compact
                  if files_with_same_checksum.length.zero?
                    files_filtered[key] << hash
                    files_filtered[:count] = files_filtered[:count] + 1
                  end
                end
              end
            end
          end
        end
      end
    end

    conf[:export_path].each do |export_path|
      chdir export_path do
        if export_all
          input_dir = "#{export_path}\\Alle"
        else
          input_dir = "#{export_path}\\#{export_year}\\#{export_month}"
        end

        if Dir.exists? input_dir
          rm_rf input_dir
        end

        create_dir input_dir, files_filtered

        if files_filtered[:count].zero?
          puts "No files found for export."
        else
          output_file = "#{input_dir}.zip"

          # Remove existing zip.
          if File.exist? output_file
            remove output_file
          end

          zf = ZipFileGenerator.new(input_dir, output_file)
          zf.write()

          puts "Export-ZIP created to #{output_file} with total of #{files_filtered[:count]} files."
        end
      end
    end
  end


  private

  def create_dir(copy_path, files_filtered)
    return if files_filtered[:count].zero?
    mkdir_p copy_path unless Dir.exists? copy_path
    chdir copy_path do
      files_filtered.each do |key,files|
        if key == :count
          next
        end

        if key == :offers   and !files.length.zero?
          copy_files "#{copy_path}\\Angebote", files
        end
        if key == :receipts and !files.length.zero?
          copy_files "#{copy_path}\\Belege", files
        end
      end
    end
  end

  def file_hash(file, folder)
    path = "#{folder}/#{file}"

    if Dir.exist? path
      nil
    else
      pn = Pathname.new path
      filename = pn.basename
      checksum = Digest::MD5.file(path).hexdigest

      {
          filename: filename,
          path: path,
          checksum: checksum
      }
    end
  end

  def copy_files(current_copy_path, files)
    mkdir_p current_copy_path unless Dir.exists? current_copy_path
    chdir current_copy_path do
      files.each do |file|
        id, filename, path = file[:id], file[:filename], file[:path]
        destination = "#{current_copy_path}\\#{filename}"
        copy path, destination, {preserve: true} unless File.exists? destination
      end
    end
  end

  def read_config
    YAML.load(IO.read(CONF_FILE))
  end

  def check_if_within_time_scope(path, year, month)
    fs = File::Stat.new(path)
    ctime = fs.ctime
    if ctime > Time.local(year, month, 1) and ctime < (DateTime.new(year, month, 1).next_month(1).to_time)
      true
    else
      false
    end
  end
end