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
    folder = "#{conf[:orgamax_path]}\\Dokumente\\#{conf[:db_id]}"

    chdir folder do
      files = []
      Dir.glob('**/*').each do |file|
        files << file
      end

      files_filtered = {
          offers: [],
          receipts: []
      }
      # Filter
      files.each do |file|
        hash = file_hash(file, folder)

        unless hash.nil?
          if conf[:export_offers] and file.start_with?('Angebote')
            files_filtered[:offers] << hash
          end

          if conf[:export_receipts] and (file.start_with?('Eingangsrechnungen') or file.start_with?('Zahlungen') or file.start_with?('Rechnungen'))
            files_filtered[:receipts] << hash
          end
        end
      end

      conf[:export_path].each do |export_path|
        chdir export_path do
          if export_all
            input_dir = "#{export_path}\\Alle"
            create_dir input_dir, files_filtered
          else
            input_dir = "#{export_path}\\#{export_year}\\#{export_month}"
            create_dir input_dir, files_filtered, export_year, export_month
          end

          output_file = "#{input_dir}.zip"
          zf = ZipFileGenerator.new(input_dir, output_file)
          zf.write()
        end
      end
    end
  end


  private

  def create_dir(copy_path, files_filtered, year=nil, month=nil)
    mkdir_p copy_path unless Dir.exists? copy_path
    chdir copy_path do
      files_filtered.each do |key,files|
        unless year.nil? or month.nil?
          filtered_files = files.map do |file|
            path = file[:path]
            fs = File::Stat.new(path)
            ctime = fs.ctime
            if ctime > Time.local(year, month, 1) and ctime < (DateTime.new(year, month, 1).next_month(1).to_time)
              file
            end
          end.compact
        else
          filtered_files = files
        end
        copy_files "#{copy_path}\\Angebote", filtered_files if key == :offers
        copy_files "#{copy_path}\\Belege", filtered_files   if key == :receipts
      end
    end
  end

  def file_hash(file, folder)
    chunks = file.split('/')
    # Check if 3 chunks as it indicated a file and not the top and subsequent IDXX folder
    if chunks.length == 3
      {
          id: chunks[1],
          filename: chunks[2],
          path: "#{folder}/#{file}"
      }
    else
      nil
    end
  end

  def copy_files(current_copy_path, files)
    mkdir_p current_copy_path unless Dir.exists? current_copy_path
    chdir current_copy_path do
      files.each do |file|
        id, filename, path = file[:id], file[:filename], file[:path]
        destination = "#{current_copy_path}\\#{id}_#{filename}"
        copy path, destination, {preserve: true} unless File.exists? destination
      end
    end
  end

  def read_config
    YAML.load(IO.read(CONF_FILE))
  end
end