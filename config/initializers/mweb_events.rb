Rails.application.config.after_initialize do
  if configatron.modules.events.loaded
    if defined?(Site) && Site.current &&
        Site.current.respond_to?(:events_enabled) &&
        Site.current.events_enabled?
      configatron.modules.events.enabled = true
    end
  end
end

Rails.application.config.to_prepare do

  if defined?(MwebEvents)
    configatron.modules.events.loaded = true
  end

  if configatron.modules.events.loaded

    # Monkey patching events controller for pagination and recent activity
    MwebEvents::EventsController.class_eval do
      before_filter(:only => [:index]) do
        @events = @events.accessible_by(current_ability).paginate(:page => params[:page])
      end

      after_filter :only => [:create, :update] do
        @event.new_activity params[:action], current_user unless @event.errors.any?
      end
    end

    MwebEvents::Event.class_eval do
      include PublicActivity::Common

      def new_activity key, user
        create_activity key, :owner => owner, :parameters => { :user_id => user.try(:id), :username => user.try(:name) }
      end
    end

    # Same for participants, public activity is still missing
    MwebEvents::ParticipantsController.class_eval do
      before_filter(:only => [:index]) do
        @participants = @participants.accessible_by(current_ability).paginate(:page => params[:page])
      end

      after_filter :only => [:create] do
        @participant.new_activity params[:action], current_user unless @participant.errors.any?
      end
    end

    MwebEvents::Participant.class_eval do
      include PublicActivity::Common

      def new_activity key, user
        create_activity key, :owner => owner, :parameters => { :user_id => user.try(:id), :username => user.try(:name) }
      end
    end

    MwebEvents::EventsHelper.instance_eval do
      def build_message_path(participant)
        main_app.new_message_path(
         :user_id => current_user.to_param, :receiver => participant.owner.id,
         :private_message => { :title => t('mweb_events.participants.index.event', :event => participant.event.name) }
        )
      end
    end

  end
end
