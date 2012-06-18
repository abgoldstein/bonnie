require File.expand_path('../../../config/environment',  __FILE__)
require 'pathname'
require 'fileutils'
require './lib/measures/database_access'
require './lib/measures/importer'
require './lib/measures/exporter'

namespace :measures do

  desc 'Export definition fo a single measure'
  task :export,[:id] do |t, args|
    measure = Measure.by_measure_id(args.id)

    measure_path = File.join(".", "tmp", "measures")
    FileUtils.mkdir_p measure_path

    out_file = File.expand_path(File.join(measure_path, "measures.zip"))
    file = File.open(out_file, 'w')

    zip = Measures::Exporter.export(file, measure)
    puts "wrote measure #{args.id} definition to: #{out_file}"
  end

  desc 'Export definitions for all measures'
  task :export_all do |t, args|
    measure_path = File.join(".", "tmp", "measures")
    FileUtils.mkdir_p measure_path
    out_file = File.expand_path(File.join(measure_path, "measures.zip"))
    file = File.open(out_file, 'w')

    measures = Measure.all
    zip = Measures::Exporter.export(file, measures)
    puts "wrote #{measures.count} measure definitions to: #{out_file}"
  end

  desc 'Remove the measures and bundles collection'
  task :drop_measures do
    loader = Measures::Loader.new()
    loader.drop_measures()
  end

  desc 'Load a set of measures for popHealth'
  task :import, [:measures_zip, :db_name, :db_host, :db_port, :keep_existing] do |task, args|
    raise "The path to the measures zip file must be specified" unless args.measures_zip
    raise "The database name to load to must be specified" unless args.db_name
    importer = Measures::Importer.new(args.db_name, args.db_host, args.db_port)
    importer.drop_measures() unless args.keep_existing
    zip = File.open(args.measures_zip)

    count = importer.import(zip)
    puts "Successfully loaded #{count} measures from #{args.measures_zip} to #{args.db_name}"
  end

  desc 'Load a measure defintion into the DB'
  task :load, [:hqmf_path, :codes_path, :username, :delete_existing] do |t, args|
    hqmf_path = args.hqmf_path
    codes_path = args.codes_path
    username = args.username
    delete_existing = args.delete_existing
    if delete_existing.nil? && username.in?(['true', 'false', nil])
      delete_existing = args.username
      username = args.codes_path
      codes_path = './test/fixtures/measure-defs/' + args.hqmf_path + '/' + args.hqmf_path + '.xls'
      hqmf_path = './test/fixtures/measure-defs/' + args.hqmf_path + '/' + args.hqmf_path + '.xml'
    end

    raise "The path the the HQMF file must be specified" unless hqmf_path
    raise "The path the the Codes file must be specified" unless codes_path
    raise "The username to load the measures for must be specified" unless username

    user = User.by_username username
    raise "The user #{username} could not be found." unless user

    if delete_existing == 'true'
      count = user.measures.delete_all
      puts "Deleted #{count} measures assigned to #{user.username}"
    end

    Measures::Loader.load(hqmf_path, codes_path, user)

  end

  desc 'Load a measure defintion into the DB'
  task :load_all, [:measures_dir, :username, :delete_existing] do |t, args|
    raise "The path the the measure definitions must be specified" unless args.measures_dir
    raise "The username to load the measures for must be specified" unless args.username

    user = User.by_username args.username
    raise "The user #{args.username} could not be found." unless user

    if args.delete_existing
      count = user.measures.delete_all
      puts "Deleted #{count} measures assigned to #{user.username}"
    end

    Dir.foreach(args.measures_dir) do |entry|
      next if entry.starts_with? '.'
      hqmf_path = File.join(args.measures_dir,entry,"#{entry}.xml")
      codes_path = File.join(args.measures_dir,entry,"#{entry}.xls")
      begin
        Measures::Loader.load(hqmf_path, codes_path, user)
        puts "Measure #{entry} successfully loaded.\n"
      rescue Exception => e
        puts "Loading Measure #{entry} failed: #{e.message} \n"
      end

    end

  end

  desc 'Drop all measure defintions from the DB'
  task :drop_all, [:username] do |t, args|
    raise "The username to load the measures for must be specified" unless args.username

    user = User.by_username args.username
    raise "The user #{args.username} could not be found." unless user

    count = user.measures.delete_all
    puts "Deleted #{count} measures assigned to #{user.username}"
  end

  desc 'Convert a measure defintion to a format that can be loaded into popHealth'
  task :build, [:hqmf, :codes, :include_library, :patient] do |t, args|

    FileUtils.mkdir_p File.join(".","tmp",'measures')
    hqmf_path = File.expand_path(args.hqmf)
    codes_path = File.expand_path(args.codes)
    filename = Pathname.new(hqmf_path).basename

    measure = Measures::Loader.load(hqmf_path, codes_path, nil, nil, false)
    measure_js = Measures::Exporter.execution_logic(measure)

    if args.patient
      patient_file = File.expand_path(args.patient)
      patient_json = File.read(patient_file)
    end

    out_file = File.join(".","tmp",'measures',"#{filename}.js")
    File.open(out_file, 'w') do |f|

      if args.include_library
        library_functions = Measures::Exporter.library_functions
        ['underscore_min','map_reduce_utils'].each do |function|
          f.write("#{function}_js = function () { #{library_functions[function]} }\n")
          f.write("#{function}_js();\n")
        end
        f.write(library_functions['hqmf_utils'] + "\n")
      end

      f.write("execute_measure = function(patient) {\n #{measure_js} \n}\n")
      f.write("emitted = []; emit = function(id, value) { emitted.push(value); } \n")
      f.write("ObjectId = function(id, value) { return 1; } \n")

      if args.patient
        f.write("// #########################\n")
        f.write("// ######### PATIENT #######\n")
        f.write("// #########################\n\n")

        f.write("var patient = #{patient_json};\n")
      end

    end

    puts "wrote measure defintion to: #{out_file}"

    class ErbContext < OpenStruct
      def initialize(vars)
        super(vars)
      end
      def get_binding
        binding
      end
    end

    template_str = File.read(File.join('.','test','fixtures','html','test_measure.html.erb'))
    template = ERB.new(template_str, nil, '-', "_templ_html")
    params = {'measure_id' => filename}
    context = ErbContext.new(params)
    result = template.result(context.get_binding)

    out_file = File.join(".","tmp",'measures',"#{filename}.html")
    File.open(out_file, 'w') do |f|
      f.write(result)
    end

    puts "wrote test html to: #{out_file}"

  end


end
