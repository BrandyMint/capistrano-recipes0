# -*- encoding: utf-8 -*-

require 'recipes0/init_d/init_d_script'

unless Capistrano::Configuration.respond_to?(:instance)
  abort "This extension requires Capistrano 2"
end

Capistrano::Configuration.instance.load do
   namespace :delayed_job do

      self.extend InitDScript

      def self.service_name
         :delayed_job
      end

      _cset(:delayed_job_start_script) { "/etc/init.d/#{service_name}-#{application}" }
      desc <<-DESC
         Создает стартовый скрипт #{service_name.to_s.capitalize} в shared/examples.

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

      [ :start, :stop, :restart ].each do |action|
         desc "#{action.to_s.capitalize} #{service_name.to_s.capitalize}"
         task action, :roles => :web do
            #Здесь su скрипта запуска не должен запрашивать пароль, так как
            # скрипт запускается от того же пользователя, от которого работает
            # service_name. Поэтому не используем ни su ни sudo
            run "#{fetch(:delayed_job_start_script)} #{action.to_s}"
         end
      end

      if ( ! fetch(:skip_delayed_job_auto_actions, false) )
         after 'deploy:restart', 'delayed_job:restart'
         after 'deploy', 'delayed_job:create_start_script'
         after 'deploy:setup', 'delayed_job:create_start_script'
      end
   end
end

