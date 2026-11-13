module Api
  module V1
    # Read-only JSON API for other apps (website, mobile, partners).
    #
    # Every request must send the shared token:
    #   Authorization: Bearer <token>
    # The token comes from ENV["MANDI_API_TOKEN"], or `api: token:` in Rails
    # credentials. With neither set the API stays closed.
    class BaseController < ActionController::API
      before_action :authenticate_api_token!

      rescue_from Date::Error do |error|
        render_error(:bad_request, error.message)
      end

      def self.api_token
        ENV["MANDI_API_TOKEN"].presence || Rails.application.credentials.dig(:api, :token).presence
      end

      private
        def authenticate_api_token!
          expected = self.class.api_token
          return render_error(:service_unavailable, "API token is not configured on the server.") if expected.blank?

          provided = request.authorization.to_s[/\ABearer\s+(.+)\z/, 1].to_s.strip
          return if provided.present? && ActiveSupport::SecurityUtils.secure_compare(provided, expected)

          render_error(:unauthorized, "Missing or invalid API token.")
        end

        def render_error(status, message)
          render json: { error: message }, status: status
        end

        # "2026-09-29" -> Date; raises Date::Error for anything else.
        def date_param(key)
          value = params[key].presence
          value && Date.iso8601(value.to_s)
        rescue Date::Error
          raise Date::Error, "#{key} must be a date like 2026-09-29"
        end

        def number(value)
          value&.to_f
        end

        def named(record)
          record && { id: record.id, name: record.name }
        end

        def attachments_json(record)
          record.attachments.map do |attachment|
            {
              filename: attachment.filename.to_s,
              content_type: attachment.content_type,
              byte_size: attachment.byte_size,
              url: rails_blob_url(attachment, disposition: "attachment")
            }
          end
        end
    end
  end
end
