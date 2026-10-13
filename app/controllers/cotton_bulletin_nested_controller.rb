class CottonBulletinNestedController < ApplicationController
  # Nested report rows may be added by any signed-in user. Editing or deleting
  # a saved row remains restricted to administrators.
  before_action :require_admin, only: %i[edit update destroy]
  before_action :set_cotton_bulletin

  private
    def set_cotton_bulletin
      @cotton_bulletin = CottonBulletin.find(params[:cotton_bulletin_id])
    end
end
