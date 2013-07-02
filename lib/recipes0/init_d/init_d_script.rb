# -*- encoding: utf-8 -*-

module InitDScript

   # Runs +command+ as root invoking the command with su -c
   # and handling the root password prompt.
   #
   #   surun "/etc/init.d/apache reload"
   #   # Executes
   #   # su - -c '/etc/init.d/apache reload'
   #
   def surun(command)
     password = fetch(:root_password, Capistrano::CLI.password_prompt("root password: "))
     run("su - -c '#{command}'", :pty => true) do |channel, stream, output|
       #puts output.gsub(password, '') if output
       channel.send_data("#{password}\n") if output.include?('Password')
     end
   end

   # Устанавливает стартовый скрипт location/script в автозагрузку
   def install_initd(location, script)
      install_script = "install -o root -g root -m 755 #{location}/#{script} /etc/init.d/;"
      install_script <<= "/usr/sbin/update-rc.d #{script} defaults;"
      surun install_script
   end


   #Компилирует стартовый скрипт в examples
   def put_start_script_2_examples(service_name)
         location = fetch(:templates_dir, "config/deploy") + "/#{service_name}.sh.erb"
         if !File.file?(location)
            location = File.join(File.dirname(__FILE__), "../templates", "#{service_name}.sh.erb");
         end
         template = File.read(location)
         config = ERB.new(template)

         dst_fname = "#{service_name}-#{application}"
         run "mkdir -p #{shared_path}/examples/"
         put config.result(binding), "#{shared_path}/examples/#{dst_fname}"
   end

end

