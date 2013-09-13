class AdminController < ApplicationController

	skip_before_filter :require_admin, only: [ :claim ]
	skip_before_filter :require_users, only: [ :claim ]

	before_filter CASClient::Frameworks::Rails::Filter
	before_filter :require_admin

	def import_do
		Course.reload
		redirect_to :back
		# render :text => "Loaded!"
	end
	
	def users
		@groupless = User.where(active: true, done: false, group_id: nil).order('updated_at desc')
		@done = User.where(done: true).order('updated_at desc')
		@inactive = User.where(active: false).order('updated_at desc')
		@psets = Pset.order(:name)
		@title = "List users"
	end
	
	def dropbox
		logger.debug Settings['dropbox.session']
		@dropbox_session = Settings['dropbox.session'] != nil
		@dropbox_app_key = Settings['dropbox.app_key']
		@dropbox_app_secret = Settings['dropbox.app_secret']
	end
	
	def dropbox_save
		Settings['dropbox.app_key'] = params['dropbox_app_key']
		Settings['dropbox.app_secret'] = params['dropbox_app_secret']
		# redirect_to :back
		
		# Allows the admin user to link the course to dropbox.
		dropbox = DropboxConnection.new
		
		if not params[:oauth_token] then
			# pass to get_authorize_url a callback url that will return the user here
			redirect_to dropbox.create_session(url_for(:controller => 'admin', :action => 'link'))
		else
			# the user has returned from Dropbox so save the session and go away
			dropbox.authorized
			redirect_to :root
		end
		
		# render text: "Done"
	end
	
	def admins
		@admins = Settings.admins.join("\n")
	end
	
	def admins_save
		Settings.admins = params[:admins].split(/\r?\n/)
		redirect_to :back
	end
	
	def import_groups
		# this is very dependent on datanose export format: id's in col 0 and 1, group name in 7
		source = params[:paste]
		source.each_line do |line|
			next if line.strip == ""
			line = line.split("\t")
			next if line[7] == "Group"
			group = Group.where(:name => line[7]).first_or_create if line[7] != ""
			user = User.where('uvanetid in (?)', line[0..1]).first
			if user && group
				user.group = group
				user.save
			elsif user
				user.group = nil
				user.save
			end
		end
		
		redirect_to :back
	end
	
	def create_submit
		@submit = Submit.create do |s|
			s.user_id = params[:user_id]
			s.pset_id = params[:pset_id]
		end
		redirect_to new_submit_grade_url(submit_id:@submit.id)
	end
	
	def link
		# Allows the admin user to link the course to dropbox.
		dropbox = DropboxConnection.new
		
		if not params[:oauth_token] then
			# pass to get_authorize_url a callback url that will return the user here
			redirect_to dropbox.create_session(url_for(:action => 'link'))
		else
			# the user has returned from Dropbox so save the session and go away
			dropbox.authorized
			redirect_to :root
		end
	end
	
	##
	# POST
	# ajax-only enable/disable of students
	#
	def enable
		reg = User.find(params[:id])
		reg.update_attribute(:active, params[:active])
		render :nothing => true
	end

	##
	# POST
	# ajax-only done/not done of students
	#
	def done
		reg = User.find(params[:id])
		reg.update_attribute(:done, params[:done])
		render :nothing => true
	end
	
	private

	def require_admin
		redirect_to :root unless is_admin?
	end
	
end
