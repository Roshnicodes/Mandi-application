class ApplicationController < ActionController::Base
  include Authentication
  include PermitsAttachments
  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  # Changes to the importmap will invalidate the etag for HTML responses
  stale_when_importmap_changes

  helper_method :current_user, :admin_user?, :regular_user?

  private
    def current_user
      Current.user
    end

    def admin_user?
      current_user&.admin?
    end

    def regular_user?
      current_user&.user?
    end

    def require_admin
      return if admin_user?

      redirect_to root_path, alert: "Aapke user account ko is action ka access nahi hai."
    end
end
