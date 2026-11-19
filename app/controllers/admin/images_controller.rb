class Admin::ImagesController < ApplicationController
  before_action :authorized
  before_action :set_current_user
  before_action :require_admin

  def index
    admin      = User.admin_user
    @usernames = User.pluck(:id, :username).to_h
    @users     = User.order(:id).reject { |u| u.id == admin&.id }
    @user_id   = params[:user_id].presence

    scope = Message.where.not(image: nil)

    if @user_id.present?
      scope = scope.where("user_id = ? OR recipient_id = ?", @user_id, @user_id)
    end

    rows = scope.order(created_at: :desc).to_a
    @total = rows.size

    # Group by whoever is NOT the admin, so each card is one person's pictures.
    @groups = rows.group_by do |m|
      m.user_id == admin&.id ? m.recipient_id : m.user_id
    end

    # This page can only show pictures a message still points at. Cloudinary
    # keeps the file when the message goes, so a purge leaves orphans that
    # look like "no photos" here. Say where they actually are.
    @storage = @user_id.present? ? storage_for(User.find_by(id: @user_id), admin) : nil
  end

  # Folders are named from the username AT UPLOAD TIME, so a renamed account
  # has its older pictures filed under the old name. Both shapes the app has
  # used are checked.
  def storage_for(user, admin)
    return nil if user.blank?

    prefixes = ["#{user.username}/", "#{admin&.username}-#{user.username}/"].uniq
    found = []

    prefixes.each do |prefix|
      %w[image video].each do |kind|
        response = Cloudinary::Api.resources(type: "upload", resource_type: kind,
                                             prefix: prefix, max_results: 100)
        count = Array(response["resources"]).size
        found << { prefix: prefix.chomp("/"), count: count } if count.positive?
      end
    end

    totals = found.group_by { |f| f[:prefix] }.map { |p, rows| { prefix: p, count: rows.sum { |r| r[:count] } } }
    { total: totals.sum { |t| t[:count] }, folders: totals }
  rescue StandardError => e
    Rails.logger.error("cloudinary lookup: #{e.class}: #{e.message}")
    nil
  end

  # Removes the picture from the conversation AND from storage, so it does
  # not leave an orphan behind - which is exactly how the old ones ended up
  # invisible in the first place.
  def destroy
    msg = Message.find_by(id: params[:id])

    if msg.nil? || msg.image.blank?
      flash[:error] = "That picture no longer exists."
      return redirect_to admin_images_path(user_id: params[:user_id])
    end

    public_id = msg.image.to_s[%r{/upload/(?:[^/]+/)*v\d+/(.+)\.\w+\z}, 1]
    kind      = msg.image.to_s.include?("/video/upload/") ? "video" : "image"
    notes     = []

    if public_id.present?
      begin
        result = Cloudinary::Uploader.destroy(public_id, resource_type: kind, invalidate: true)
        notes << (result["result"] == "ok" ? "removed from storage" : "storage said #{result["result"]}")
      rescue StandardError => e
        notes << "storage error: #{e.message}"
      end
    else
      notes << "could not work out the storage id"
    end

    msg.destroy
    notes << "removed from the conversation"

    flash[:success] = "Picture deleted - #{notes.join(", ")}."
    redirect_to admin_images_path(user_id: params[:user_id])
  end

  private

  def set_current_user
    @current_user = current_user
  end

  def require_admin
    unless @current_user.admin?
      flash[:error] = "Access denied. Admin privileges required."
      redirect_to dashboard_path
    end
  end
end
