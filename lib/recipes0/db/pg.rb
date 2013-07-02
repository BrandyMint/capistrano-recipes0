# -*- encoding: utf-8 -*-

#Задачи Postgresql БД
Capistrano::Configuration.instance.load do
   namespace :db do

      _cset(:full_dump) { false }
      _cset(:dst_file) { './db.dump.gz' }
      _cset(:pgdump_args) { '' }
      _cset(:replica_db_env) { 'replica' }
      _cset(:exclude_tables) { [] }

      #Скрипт, читает параметры подключения к БД из файла +database.yml+
      #окружения  +env+ и по ним формирует переменные окружения для
      # подключения psql (PGUSER, PGPASSWD, PGDATABASE)
      def init_psql_env_cmd(env='production', database_yml='config/database.yml')
	return <<-END.gsub(/\s+/, " ").strip
	 eval `RAILS_ENV='#{env}' DATABASE_YML='#{database_yml}' ruby -e '
	       require "yaml";
	       config=YAML.load_file(ENV["DATABASE_YML"])[ENV["RAILS_ENV"]];
	       print "PGUSER=\#{config["username"]}; PGPASSWD=\#{config["password"]}; PGDATABASE=\#{config["database"]}; PGHOST=\#{config["hostname"]}; export PGDATABASE PGUSER PGPASSWD PGHOST";
	 ' `
        END
      end

      #Выполняет pg_dump на удаленном сервере
      #
      # +env+ - окружение, чьи параметры подключения к БД будут
      # использоваться
      # Ключи +options+:
      #
      # * full_dump - Снять полный дамп вместо урезанного
      # * pgdump_args - дополнительные аргументы pg_dump
      # * exclude_tables - массив имен таблиц, данные из которых не
      #   сохраняются в урезанном дампе
      #
      # блок исплняется с теми же параметрами, что и #run (|channel, stream, data|)
      def dump_remote_db(env, options={})
	 dump_cmd = [ init_psql_env_cmd(env, "#{shared_path}/config/database.yml") ]
	 exclude_tables = options['exclude_tables'].nil? ? [] : options['exclude_tables'];

	 if (options['full_dump'] || (exclude_tables.size() == 0))
	    dump_cmd << "pg_dump -Fp -Z6 --no-privileges --no-owner #{options['pgdump_args']}"
	 else
	    dump_cmd << "pg_dump -Fp -Z6 --no-privileges --no-owner #{options['pgdump_args']} --schema-only"
	    dump_cmd << "pg_dump -Fp -Z6 --no-privileges --no-owner #{options['pgdump_args']} --data-only --exclude-table '#{exclude_tables.join("|")}'"
	 end

	 run dump_cmd.join(' && '), :pty=>false do |channel, stream, data|
	    yield channel, stream, data
	 end #run
      end

      desc <<-DESC
      Сохраняет базу - реплику со стейджа в файл.

      Параметры:
       replica_db_env - окружение, учетные данные которого будут
                        использоваться для дампа БД. Параметры читаются из
                        удаленного database.yml Если не указано, будет
                        использовано окружение 'replica'
       full_dump      - Снять полный дамп вместо урезанного
       dst_file       - Локальный файл для записи дампа (db.dump.gz)
       exclude_tables - Массив имен таблиц, данные из которых не сохраняются
                        в урезанном дампе
       pgdump_args    - Дополнительные аргументы pg_dump (например, --verbose)
      DESC
      task :download, roles => :db, :except => { :no_release => true } do

	 dst_file = fetch(:dst_file, './db.dump.gz')
	 replica_db_env = fetch(:replica_db_env, rails_env)
	 options = {}
	 options['full_dump'] = fetch(:full_dump, false)
	 options['pgdump_args'] = fetch(:pgdump_args, '')
	 options['exclude_tables'] = fetch(:exclude_tables, [])

	 File.open(dst_file, 'w') do |f|
	    dump_remote_db(replica_db_env, options) do |channel, stream, data|
	       if (stream == :out)
	 	  f.write data
	       else
	 	  $stderr.puts data
	       end
	    end #dump_remote_db
	 end #File.open
      end #task :download

      desc <<-DESC
      Загружает базу - реплику со стейджа в локальную базу.

      Учетные данные для подключения к локальной БД читаются
      из локального файла config/database.yml окружения ENV['RAILS_ENV'].
      Для подключения к удаленной БД используются данные из удаленного
      database.yml и окружения +replica_db_env+, либо, если он не определен,'replica'

      Параметры:
       replica_db_env - окружение, учетные данные которого будут
                        использоваться для дампа БД. Параметры читаются из
                        удаленного database.yml Если не указано, будет
                        использовано окружение 'replica'
       full_dump      - Снять полный дамп вместо урезанного
       exclude_tables - Массив имен таблиц, данные из которых не сохраняются
                        в урезанном дампе
       pgdump_args    - Дополнительные аргументы pg_dump (например, --verbose)
      DESC
      task :pull, roles => :db, :except => { :no_release => true } do
	 options = {}
	 options['full_dump'] = fetch(:full_dump, false)
	 options['pgdump_args'] = fetch(:pgdump_args, '')
	 options['exclude_tables'] = fetch(:exclude_tables, [])

	 replica_db_env = fetch(:replica_db_env, rails_env)
	 local_rails_env = ENV['RAILS_ENV'] || 'development'

	 #Читаем локальные параметры подключения к БД
	 cmd = [ init_psql_env_cmd(local_rails_env, "config/database.yml") ]
	 #Пересоздаем БД
	 cmd << "RAILS_ENV=#{local_rails_env} && export RAILS_ENV"
	 cmd << 'bundle exec rake db:drop db:create'
	 #Запускаем постгрес для загрузки базы
	 cmd << 'zcat -f | psql'
	 cmd << 'bundle exec rake db:migrate'

	 logger.trace "executing locally: #{cmd.join(' && ').inspect}" if logger
	 IO.popen(cmd.join(' && '), 'w') do |io|
	    dump_remote_db(replica_db_env, options) do |channel, stream, data|
	       if (stream == :out)
		  io.write data
	       else
		  $stderr.puts data
	       end
	    end #dump_remote_db
	 end #IO.popen
      end #task :pull


      _cset(:src_rails_env) { replica_db_env }
      _cset(:dst_rails_env) { rails_env }
      desc <<-DESC
      Пересоздает на стейдже базу из реплики.

      Параметры:
       src_rails_env -  Окружение, учетные данные которого будут
                        использоваться для дампа БД. (replica_db_env)
       dst_rails_env -  Окружение, в которое будет скопирована база
                        Если не указано, будет использован :rails_env
       full_dump      - Снять полный дамп вместо урезанного
       exclude_tables - Массив имен таблиц, данные из которых не сохраняются
                        в урезанном дампе
      DESC
      task :update, roles => :db, :except => { :no_release => true } do
	 options = {}
	 options['full_dump'] = fetch(:full_dump, false)
	 options['pgdump_args'] = fetch(:pgdump_args, '')
	 options['exclude_tables'] = fetch(:exclude_tables, [])

	 src_rails_env = fetch(:src_rails_env, 'replica')
	 dst_rails_env = fetch(:dst_rails_env, rails_env)

	 dump_cmd = [];
	 if (options['full_dump'] || (exclude_tables.size() == 0))
	    dump_cmd << "pg_dump -Fp -Z0 --no-privileges --no-owner #{options['pgdump_args']}"
	 else
	    dump_cmd << "pg_dump -Fp -Z0 --no-privileges --no-owner #{options['pgdump_args']} --schema-only"
	    dump_cmd << "pg_dump -Fp -Z0 --no-privileges --no-owner #{options['pgdump_args']} --data-only --exclude-table '#{exclude_tables.join("|")}'"
	 end

        # Запускаем пайп из двух сабшеллов
        # Первый шелл - pg_dump со своим окружением, второй - pgsql
        # XXX: похоже, rake не возвращает код ошибки в случае неудачи
        #	       psql -c 'DROP DATABASE ${PGDATABASE}' &&
        # psql -c 'CREATE DATABASE ${PGDATABASE} WITH TEMPLATE = template0' &&

	cmd =  <<-END.gsub(/\s+/, " ").strip
	    (
	      #{init_psql_env_cmd(src_rails_env, "#{shared_path}/config/database.yml")} &&
	      echo "Dumping database $PGDATABASE" >&2 &&
	      #{dump_cmd.join(" && ")}
	    )
	 |
	    (
	       cd #{current_path} &&
	       RAILS_ENV=#{dst_rails_env} && export RAILS_ENV &&
	       #{init_psql_env_cmd(dst_rails_env, "#{shared_path}/config/database.yml")} &&
	       echo "Dropping connections to ${PGDATABASE}" &&
	       psql -c "SELECT pg_terminate_backend(pg_stat_activity.procpid)
		  FROM pg_stat_activity WHERE pg_stat_activity.procpid != pg_backend_pid() AND pg_stat_activity.datname = '${PGDATABASE}'";
	       echo "Recreating database..." &&
	       bundle exec rake db:drop db:create &&
	       echo "Uploading data..." &&
	       psql -1 &&
	       echo "Migrating..." &&
	       bundle exec rake db:migrate
	     )
	END

	run cmd,  :pty  => false

      end


      namespace :cur do

	 desc <<-DESC
	 Сохраняет рабочую базу со стейджа в файл.

	 Параметры:
	 full_dump      - Снять полный дамп вместо урезанного
	 dst_file       - Локальный файл для записи дампа (db.dump.gz)
	 exclude_tables - Массив имен таблиц, данные из которых не сохраняются
			   в урезанном дампе
	 pgdump_args    - Дополнительные аргументы pg_dump (например, --verbose)
	 DESC
	 task :download, roles => :db, :except => { :no_release => true } do
	    set(:replica_db_env, rails_env )
	    self.db.download
	 end

	 desc <<-DESC
         Загружает рабочую базу со стейджа в локальную.

         Учетные данные для подключения к локальной БД читаются
         из локального файла config/database.yml окружения ENV['RAILS_ENV'].
         Для подключения к удаленной БД используются данные из удаленного
         database.yml и окружения +rail_env+

	 Параметры:
          full_dump      - Снять полный дамп вместо урезанного
          exclude_tables - Массив имен таблиц, данные из которых не сохраняются
                           в урезанном дампе
          pgdump_args    - Дополнительные аргументы pg_dump (например, --verbose)
         DESC
         task :pull, roles => :db, :except => { :no_release => true } do
	    set(:replica_db_env, rails_env )
	    self.db.pull
         end
      end #namespace :cur
   end #namespace :db

end

