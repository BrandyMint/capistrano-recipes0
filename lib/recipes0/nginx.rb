# -*- encoding: utf-8 -*-

require 'recipes0/init_d/init_d_script'

Capistrano::Configuration.instance.load do
   namespace :nginx do

      #XXX используется только surun
      self.extend InitDScript

      desc <<-DESC
         Создает стартовый скрипт nginx в shared/examples/nginx.

         Шаблон скрипта должен быть в директории :templates_dir, либо config/deploy/
         и называться nginx.conf.erb
      DESC
      task :create_start_script, :except => { :no_release => true } do

         location = fetch(:templates_dir, "config/deploy") + '/nginx.conf.erb'
         if !File.file?(location)
            location = File.join(File.dirname(__FILE__), "templates", "nginx.conf.erb");
         end

         template = File.read(location)
         config = ERB.new(template)

         dst_fname = application
         run "mkdir -p #{shared_path}/examples/nginx"
         put config.result(binding), "#{shared_path}/examples/nginx/#{dst_fname}"
      end

      desc "Устанавливает конфиг nginx"
      task :setup, :except => { :no_release => true } do
         nginx.create_start_script
         install_script = "install -o root -g root -m 644 #{shared_path}/examples/nginx/#{application} /etc/nginx/sites-available;"
         install_script <<= "ln -s /etc/nginx/sites-available/#{application} /etc/nginx//sites-enabled/#{application};"
         install_script <<= "/etc/init.d/nginx restart;"
         surun install_script
      end

      after 'deploy', "nginx:create_start_script" unless fetch(:skip_nginx_auto_actions, false)
      after 'deploy:setup', "nginx:create_start_script" unless fetch(:skip_nginx_auto_actions, false)
   end
end

