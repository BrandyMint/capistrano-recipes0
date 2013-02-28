# -*- encoding: utf-8 -*-

require 'recipes0/init_d/init_d_script'

unless Capistrano::Configuration.respond_to?(:instance)
  abort "This extension requires Capistrano 2"
end

Capistrano::Configuration.instance.load do
   namespace :unicorn do

      self.extend InitDScript

      def self.service_name
	 :unicorn
      end

      _cset(:unicorn_start_script) { "/etc/init.d/#{service_name}-#{application}" }
      desc <<-DESC
	 Создает стартовый скрипт #{service_name} в shared/examples.

	 Шаблон скрипта должен быть в директории :templates_dir, либо config/deploy/
	 и называться #{service_name}.sh.erb
      DESC
      task :create_start_script, :except => { :no_release => true } do
	 put_start_script_2_examples(service_name)
      end

      desc "Устанавливает скрипт #{service_name.to_s.capitalize} в автозагрузку"
      task :setup, :except => { :no_release => true } do
	 create_start_script
	 install_initd "#{shared_path}/examples", "#{service_name}-#{application}"
      end

      [ :start, :stop, :force_stop, :restart, :reload, :upgrade, :reopen_logs ].each do |action|
	 desc "#{action.to_s.capitalize} #{service_name.to_s.capitalize}"
	 task action, :roles => :web do
	    #Здесь su скрипта запуска не должен запрашивать пароль, так как
	    # скрипт запускается от того же пользователя, от которого работает
	    # service_name. Поэтому не используем ни su ни sudo
	    run "#{fetch(:unicorn_start_script)} #{action.to_s}"
	 end
      end

      if ( !fetch(:skip_unicorn_auto_actions, false))
	 after 'deploy:restart', 'unicorn:upgrade'
	 after 'deploy', 'unicorn:create_start_script'
	 after 'deploy:setup', 'unicorn:create_start_script'
      end
   end
end
