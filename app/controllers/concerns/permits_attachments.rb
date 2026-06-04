module PermitsAttachments
  extend ActiveSupport::Concern

  private
    def permit_with_attachments(record_key, *fields)
      params.require(record_key).permit(*fields, attachments: [])
    end
end
