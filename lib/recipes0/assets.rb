# -*- encoding: utf-8 -*-

Capistrano::Configuration.instance.load do
   namespace :deploy do
      namespace :assets do
         #http://www.bencurtis.com/2011/12/skipping-asset-compilation-with-capistrano/
         task :precompile, :roles => :web, :except => { :no_release => true } do
            cur = capture("cat #{current_path}/REVISION || true", :except => { :no_release => true }).chomp
            from = source.next_revision(cur)
            if  fetch(:force, false) || capture("cd #{latest_release} && #{source.local.log(from)} vendor/assets/ app/assets/ 2>&1 | wc -l").to_i > 0
               run %Q{cd #{latest_release} && #{rake} RAILS_ENV=#{rails_env} #{asset_env} assets:precompile}
            else
               logger.info "Skipping asset pre-compilation because there were no asset changes"
            end
         end
      end
   end
end

